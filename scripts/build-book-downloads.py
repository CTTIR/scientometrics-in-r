#!/usr/bin/env python3
"""Build and verify a common full-book/chapter PDF and EPUB download surface."""
import argparse, copy, datetime, html, json, mimetypes, os, posixpath, re, subprocess, zipfile
from pathlib import Path
from urllib.parse import unquote, urlsplit, urljoin
from bs4 import BeautifulSoup
from lxml import etree as ET
from pypdf import PdfReader, PdfWriter

X='http://www.w3.org/1999/xhtml'; O='http://www.idpf.org/2007/opf'; D='http://purl.org/dc/elements/1.1/'
TRACKING=re.compile(rb'(?:[\w.-]+\.)?met\.'+rb'vgwort\.de|vgwort[-_]pixel\s*:', re.I)
CSS='''
.book-downloads--unified {display:flex!important;flex-wrap:wrap;gap:12px 24px;margin:16px 0 24px!important;padding:14px 16px!important;border:1px solid #a8adb4;border-radius:8px;background:transparent;color:inherit;font-family:system-ui,sans-serif;font-size:14px;line-height:1.4;box-sizing:border-box;max-width:100%;}
.book-downloads--unified .book-download-group {display:flex;align-items:center;flex-wrap:wrap;gap:8px;}
.book-downloads--unified .book-download-label {font-weight:600;margin-right:4px;}
.book-downloads--unified a {display:inline-flex;align-items:center;gap:5px;padding:6px 9px;border:1px solid currentColor;border-radius:5px;text-decoration:none!important;font-weight:600;color:inherit;}
.book-downloads--unified a:hover {background:rgba(127,127,127,.14);}
.book-downloads--unified a:focus-visible {outline:3px solid #2684d9;outline-offset:3px;}
.book-downloads--unified svg {height:20px;width:20px;flex:none;fill:none;stroke:currentColor;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round;}
.book-downloads:not(.book-downloads--unified),.book-download-footer,.sidebar-downloads {display:none!important;}
@media(max-width:500px){.book-downloads--unified{gap:12px;padding:12px!important;}.book-downloads--unified .book-download-group{width:100%;}.book-downloads--unified .book-download-label{min-width:92px;}}
@media print{.book-downloads--unified{display:none!important;}}
'''
SVG={'pdf':'<path d="M14 2H5v20h14V7z"/><path d="M14 2v6h5M8 13h8M8 17h6"/>','epub':'<path d="M3 4h7a3 3 0 0 1 3 3v14a3 3 0 0 0-3-3H3zM21 4h-5a3 3 0 0 0-3 3v14a3 3 0 0 1 3-3h5z"/>'}
def local(base,ref):
    u=urlsplit(ref)
    if u.scheme or u.netloc or not u.path:return None
    return posixpath.normpath(posixpath.join(posixpath.dirname(base),unquote(u.path)))
def xml(data):return ET.fromstring(data,ET.XMLParser(resolve_entities=False,no_network=True))
def serialize(tree):return ET.tostring(tree,encoding='UTF-8',xml_declaration=True)
def epub_write(path,files):
    with zipfile.ZipFile(path,'w') as z:
        z.writestr('mimetype',b'application/epub+zip',compress_type=zipfile.ZIP_STORED)
        for name,data in files.items():
            if name!='mimetype':z.writestr(name,data,compress_type=zipfile.ZIP_DEFLATED)
def validate_epub(path):
    with zipfile.ZipFile(path) as z:
        assert z.namelist()[0]=='mimetype' and z.read('mimetype')==b'application/epub+zip'
        assert z.testzip() is None
        for n in z.namelist():
            data=z.read(n)
            if n.endswith(('.xhtml','.html','.css','.xml','.opf','.ncx','.js')):
                assert not TRACKING.search(data),(path,n,'counting endpoint')
            if n.endswith(('.xhtml','.xml','.opf','.ncx')):xml(data)
        ids={n:set(xml(z.read(n)).xpath('//@id')) for n in z.namelist() if n.endswith('.xhtml')}
        for n in ids:
            tree=xml(z.read(n))
            for ref in tree.xpath('//@href | //@src | //@*[local-name()="href"]'):
                u=urlsplit(ref)
                if u.scheme or u.netloc or ref.startswith('data:'):continue
                target=local(n,ref) if u.path else n
                assert target in z.namelist(),(path,n,ref,'missing resource')
                if u.fragment and target in ids:assert unquote(u.fragment) in ids[target],(path,n,ref,'missing anchor')
        container=xml(z.read('META-INF/container.xml'));opf=container.xpath('//*[local-name()="rootfile"]/@full-path')[0]
        package=xml(z.read(opf));items={e.get('id'):e for e in package.findall('{'+O+'}manifest/{'+O+'}item')}
        for item in items.values():assert local(opf,item.get('href')) in z.namelist(),(path,item.get('href'))
        for ref in package.findall('{'+O+'}spine/{'+O+'}itemref'):assert ref.get('idref') in items

def main():
    p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('--book',required=True);p.add_argument('--site',required=True);p.add_argument('--skip-pdf-render',action='store_true');a=p.parse_args();root=a.root.resolve();site=a.site.rstrip('/')+'/'
    epub=root/(a.book+'.epub')
    if not epub.exists():
        candidates=list(root.glob('*.epub'));assert len(candidates)==1,'Cannot identify complete EPUB';epub=candidates[0]
    with zipfile.ZipFile(epub) as z:archive={n:z.read(n) for n in z.namelist()}
    container=xml(archive['META-INF/container.xml']);opfpath=container.xpath('//*[local-name()="rootfile"]/@full-path')[0];opf=xml(archive[opfpath]);epubdir=posixpath.dirname(opfpath)
    title=opf.findtext('{'+O+'}metadata/{'+D+'}title') or a.book
    language=opf.findtext('{'+O+'}metadata/{'+D+'}language') or 'en'
    if language in ['C','POSIX']:language='en'
    # R's C locale is not a publication language tag.
    if opf.findtext('{'+O+'}metadata/{'+D+'}language') in ['C','POSIX']:
        opf.find('{'+O+'}metadata/{'+D+'}language').text=language
        archive[opfpath]=serialize(opf)
        for name,data in list(archive.items()):
            if name.endswith('.xhtml'):
                tree=xml(data)
                for node in tree.iter():
                    for attr in ['lang','{http://www.w3.org/XML/1998/namespace}lang']:
                        if node.get(attr) in ['C','POSIX']:node.set(attr,language)
                archive[name]=serialize(tree)
        epub_write(epub,archive)
    # Normalize legacy HTML attributes without changing text, figures or table data.
    for name,data in list(archive.items()):
        if not name.endswith('.xhtml'):continue
        tree=xml(data);head=tree.find('{'+X+'}head');renamed={}
        for node in tree.iter():
            ident=node.get('id')
            if ident and re.search(r'\s',ident):
                replacement=re.sub(r'\s+','-',ident);node.set('id',replacement);renamed[ident]=replacement
            if node.get('align'):
                align=node.attrib.pop('align');rule=('float:' if node.tag=='{'+X+'}img' and align in ['left','right'] else 'text-align:')+align
                node.set('style',(node.get('style','')+';'+rule).strip(';'))
            if node.get('alt') is not None and node.tag not in ['{'+X+'}img','{'+X+'}area','{'+X+'}input']:
                label=node.attrib.pop('alt');images=node.xpath('.//*[local-name()="img"]')
                if images:
                    if not images[0].get('alt'):images[0].set('alt',label)
                else:
                    node.set('aria-label',label)
                    if not node.get('role'):node.set('role','img')
        for table in tree.xpath('//*[local-name()="table"]'):
            headers=set(table.xpath('.//*[local-name()="th"]/@id'))
            for cell in table.xpath('.//*[@headers]'):
                valid=[x for x in cell.get('headers').split() if x in headers]
                if valid:cell.set('headers',' '.join(valid))
                else:del cell.attrib['headers']
        for style in list(tree.xpath('//*[local-name()="body"]//*[local-name()="style"]')):
            style.getparent().remove(style);head.append(style)
        for node in tree.xpath('//*[@href]'):
            value=node.get('href');u=urlsplit(value)
            if not u.scheme and unquote(u.fragment) in renamed:
                node.set('href',u.path+'#'+renamed[unquote(u.fragment)])
        archive[name]=serialize(tree)
    original_items={e.get('id'):e for e in opf.findall('{'+O+'}manifest/{'+O+'}item')}
    fallback_paths={local(opfpath,e.get('href')):local(opfpath,original_items[e.get('fallback')].get('href')) for e in original_items.values() if e.get('fallback') in original_items}
    spine=opf.find('{'+O+'}spine');spine_ids={e.get('idref') for e in spine}
    for itemid,item in original_items.items():
        name=local(opfpath,item.get('href'))
        if name in archive and name.endswith('.xhtml'):
            tree=xml(archive[name]);properties=set(item.get('properties','').split())
            if tree.xpath('//*[local-name()="math" and namespace-uri()="http://www.w3.org/1998/Math/MathML"]'):properties.add('mathml')
            if properties:item.set('properties',' '.join(sorted(properties)))
            if itemid not in spine_ids:ET.SubElement(spine,'{'+O+'}itemref',idref=itemid,linear='no')
    # Keep package-level language attributes valid as well as dc:language.
    for node in opf.iter():
        for attr in ['lang','{http://www.w3.org/XML/1998/namespace}lang']:
            if node.get(attr) in ['C','POSIX']:node.set(attr,language)
    for ref in list(spine):
        item=original_items[ref.get('idref')]
        if 'nav' in item.get('properties','').split() and ref.get('linear')=='no':spine.remove(ref)
        elif local(opfpath,item.get('href')).endswith('.xhtml'):ref.attrib.pop('linear',None)
    linked={local(name,value) for name,data in archive.items() if name.endswith('.xhtml') for value in xml(data).xpath('//@href')}
    spine_ids={e.get('idref') for e in spine}
    for itemid,item in original_items.items():
        name=local(opfpath,item.get('href'))
        if name in linked and (name.endswith('.svg') or name in fallback_paths) and itemid not in spine_ids:ET.SubElement(spine,'{'+O+'}itemref',idref=itemid,linear='no')
    archive[opfpath]=serialize(opf)
    texts={n:xml(data) for n,data in archive.items() if n.endswith('.xhtml') and '/text/' in n}
    ids={n:set(t.xpath('//@id')) for n,t in texts.items()}
    pages=[]
    for file in root.rglob('*.html'):
        soup=BeautifulSoup(file.read_text(errors='replace'),'html.parser');body=soup.find('main')
        if body is None or file.name=='404.html' or '/libs/' in str(file):continue
        heading=body.find('h1')
        if heading is None:continue
        for e in heading.select('.anchor,.anchorjs-link'):e.decompose()
        label=heading.get_text(' ',strip=True);pageids={e['id'] for e in body.find_all(id=True)}
        scores=sorted([(len(pageids&values),name) for name,values in ids.items()],reverse=True)
        assert scores and scores[0][0]>0,(file,'No corresponding EPUB chapter')
        assert len(scores)==1 or scores[0][0]>scores[1][0],(file,'Ambiguous EPUB chapter')
        rel=file.relative_to(root).as_posix();stem=rel[:-5].replace('/','--')
        pages.append(dict(path=rel,title=label,epub_source=scores[0][1],pdf='downloads/chapters/'+stem+'.pdf',epub='downloads/chapters/'+stem+'.epub'))
    assert len({x['epub_source'] for x in pages})==len(pages),'EPUB chapter mapping is not one-to-one'
    # Preserve the published table-of-contents order for the assembled PDF.
    index=BeautifulSoup((root/'index.html').read_text(),'html.parser');order=[]
    for link in index.select('.book-toc a, #quarto-sidebar a.sidebar-item-text'):
        u=urlsplit(link.get('href',''));path=unquote(u.path).removeprefix('./')
        if path and path not in order:order.append(path)
    pages.sort(key=lambda x:order.index(x['path']) if x['path'] in order else (-1 if x['path']=='index.html' else len(order)))
    mapping={x['epub_source']:x['path'] for x in pages};reference=next((x['epub_source'] for x in pages if Path(x['path']).stem=='references'),None)
    # Resolve book-wide anchors that Pandoc left relative to the current EPUB section.
    global_ids={}
    for name,values in ids.items():
        for ident in values:global_ids.setdefault(ident,[]).append(name)
    reverse_mapping={v:k for k,v in mapping.items()}
    for name,data in list(archive.items()):
        if not name.endswith('.xhtml'):continue
        tree=xml(data)
        for image in tree.xpath('//*[local-name()="img"]'):
            for dimension in ['width','height']:
                value=image.get(dimension)
                if value and not value.isdigit():
                    image.set('style',(image.get('style','')+';'+dimension+':'+value).strip(';'))
                    del image.attrib[dimension]
        for node in tree.xpath('//*[@href]'):
            ref=node.get('href');u=urlsplit(ref)
            if u.scheme or u.netloc:continue
            target=local(name,ref) if u.path else name
            valid=target in archive and (not u.fragment or target not in ids or unquote(u.fragment) in ids[target])
            if valid:continue
            candidates=global_ids.get(unquote(u.fragment),[]) if u.fragment else []
            if len(candidates)==1:
                node.set('href',posixpath.relpath(candidates[0],posixpath.dirname(name))+'#'+u.fragment)
            elif unquote(u.path) in reverse_mapping:
                node.set('href',posixpath.relpath(reverse_mapping[unquote(u.path)],posixpath.dirname(name))+('#'+u.fragment if u.fragment else ''))
            else:
                resource=target.removeprefix(epubdir+'/')
                if (root/resource).is_file():
                    node.set('href',site+resource+('#'+u.fragment if u.fragment else ''))

        archive[name]=serialize(tree)
        if name in texts:texts[name]=tree
    epub_write(epub,archive)
    dest=root/'downloads/chapters';dest.mkdir(parents=True,exist_ok=True)
    for page in pages:
        selected={page['epub_source']}
        if reference:selected.add(reference)
        files={};needed=set()
        for name in selected:
            tree=copy.deepcopy(texts[name])
            for node in tree.xpath('//*[local-name()="script" or local-name()="iframe"]'):node.getparent().remove(node)
            for node in tree.iter():
                if node.get('lang') in ('C','POSIX'):node.set('lang',language)
                if node.get('{http://www.w3.org/XML/1998/namespace}lang') in ('C','POSIX'):node.set('{http://www.w3.org/XML/1998/namespace}lang',language)
                for attr,value in list(node.attrib.items()):
                    if attr.split('}')[-1] not in ['src','href','poster','data']:continue
                    target=local(name,value)
                    if not target:continue
                    if target in mapping and target not in selected:
                        fragment=urlsplit(value).fragment;node.set(attr,site+mapping[target]+('#'+fragment if fragment else ''))
                    elif target in archive and target not in selected:needed.add(target)
            files[name]=serialize(tree)
        # Include only referenced assets, including dependencies of stylesheets/SVGs.
        while needed:
            name=needed.pop()
            if name in files or name in selected:continue
            if name.endswith(('.ncx','.opf')) or name==epubdir+'/nav.xhtml':continue
            data=archive[name]
            if name in fallback_paths and fallback_paths[name] not in files:needed.add(fallback_paths[name])
            if name.endswith('.xhtml'):
                tree=xml(data)
                for node in tree.iter():
                    for attr,value in list(node.attrib.items()):
                        if attr.split('}')[-1] not in ['src','href','poster','data']:continue
                        target=local(name,value)
                        if target in mapping and target not in selected:
                            fragment=urlsplit(value).fragment
                            node.set(attr,site+mapping[target]+('#'+fragment if fragment else ''))
                        elif target in archive and target not in files and target not in selected:needed.add(target)
                data=serialize(tree)
            files[name]=data
            if name.endswith(('.css','.svg')):
                refs=re.findall(r'url\([\'\"]?([^\)\'\"]+)',data.decode(errors='replace'))
                if name.endswith('.svg'):
                    try:refs+=xml(data).xpath('//@href | //@*[local-name()="href"]')
                    except ET.XMLSyntaxError:pass
                for ref in refs:
                    target=local(name,ref)
                    if target in archive and target not in files:needed.add(target)
        navpath=epubdir+'/nav.xhtml';nav=ET.Element('{'+X+'}html',nsmap={None:X,'epub':'http://www.idpf.org/2007/ops'},lang=language);head=ET.SubElement(nav,'{'+X+'}head');ET.SubElement(head,'{'+X+'}title').text=page['title'];body=ET.SubElement(nav,'{'+X+'}body');toc=ET.SubElement(body,'{'+X+'}nav',{'{http://www.idpf.org/2007/ops}type':'toc','id':'toc'});ET.SubElement(toc,'{'+X+'}h1').text=page['title'];ol=ET.SubElement(toc,'{'+X+'}ol')
        sequence=[page['epub_source']]+([reference] if reference and reference!=page['epub_source'] else [])
        for name in sequence:
            li=ET.SubElement(ol,'{'+X+'}li');ET.SubElement(li,'{'+X+'}a',href=posixpath.relpath(name,epubdir)).text=page['title'] if name==page['epub_source'] else 'References'
        files[navpath]=serialize(nav)
        package=ET.Element('{'+O+'}package',nsmap={None:O,'dc':D},version='3.0',attrib={'unique-identifier':'chapter-id'});meta=ET.SubElement(package,'{'+O+'}metadata')
        for key,value in [('identifier',site+page['path']),('title',page['title']+' — '+title),('creator','R. Heller'),('language',language)]:
            el=ET.SubElement(meta,'{'+D+'}'+key);el.text=value
            if key=='identifier':el.set('id','chapter-id')
        rights=opf.findtext('{'+O+'}metadata/{'+D+'}rights')
        if rights:ET.SubElement(meta,'{'+D+'}rights').text=rights
        ET.SubElement(meta,'{'+O+'}meta',property='dcterms:modified').text=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        manifest=ET.SubElement(package,'{'+O+'}manifest');itemids={}
        for i,name in enumerate(files):
            itemid='item'+str(i);itemids[name]=itemid;media=next((e.get('media-type') for e in opf.findall('{'+O+'}manifest/{'+O+'}item') if local(opfpath,e.get('href',''))==name),None) or ('application/xhtml+xml' if name.endswith('.xhtml') else mimetypes.guess_type(name)[0] or 'application/octet-stream')
            item=ET.SubElement(manifest,'{'+O+'}item',id=itemid,href=posixpath.relpath(name,epubdir),attrib={'media-type':media})
            if name==navpath:item.set('properties','nav')
            elif name.endswith('.xhtml'):
                t=xml(files[name]);props=[]
                if t.xpath('//*[local-name()="math" and namespace-uri()="http://www.w3.org/1998/Math/MathML"]'):props.append('mathml')
                if t.xpath('//*[local-name()="svg" and namespace-uri()="http://www.w3.org/2000/svg"]'):props.append('svg')
                if props:item.set('properties',' '.join(props))
        for item in manifest:
            name=local(opfpath,item.get('href'))
            if name in fallback_paths and fallback_paths[name] in itemids:item.set('fallback',itemids[fallback_paths[name]])
        spine=ET.SubElement(package,'{'+O+'}spine')
        for name in sequence:ET.SubElement(spine,'{'+O+'}itemref',idref=itemids[name])
        for name in files:
            if name.endswith('.xhtml') and name not in sequence and name!=navpath:ET.SubElement(spine,'{'+O+'}itemref',idref=itemids[name])
        linked={local(n,value) for n,data in files.items() if n.endswith('.xhtml') for value in xml(data).xpath('//@href')}
        for name in linked:
            if name in itemids and (name.endswith('.svg') or name in fallback_paths):ET.SubElement(spine,'{'+O+'}itemref',idref=itemids[name],linear='no')
        files[opfpath]=serialize(package);files['META-INF/container.xml']=archive['META-INF/container.xml']
        epub_write(root/page['epub'],files);validate_epub(root/page['epub'])
    # Use the EPUB's static equivalent of interactive figures for print.
    for page in pages:
        source=BeautifulSoup((root/page['path']).read_text(),'html.parser')
        if source.select('main iframe'):
            page['print_images']=[]
            for i,node in enumerate(texts[page['epub_source']].xpath('//*[local-name()="img"]')):
                image=local(page['epub_source'],node.get('src',''))
                if image in archive:
                    destination='downloads/assets/'+Path(page['path']).stem+'-'+str(i)+Path(image).suffix
                    (root/destination).parent.mkdir(exist_ok=True)
                    (root/destination).write_bytes(archive[image])
                    page['print_images'].append({'alt':node.get('alt',''),'src':destination})
    fullpdf=root/(a.book+'.pdf')
    plan={'book':a.book,'title':title,'site':site,'root':str(root),'whole':{'pdf':fullpdf.name,'epub':epub.name},'chapters':pages}
    (root/'book-downloads.json').write_text(json.dumps(plan,indent=2)+'\n')
    if not a.skip_pdf_render:subprocess.run(['node',str(Path(__file__).with_name('render-chapter-downloads.cjs')),str(root/'book-downloads.json')],check=True)
    if not fullpdf.exists():
        writer=PdfWriter()
        for page in pages:writer.append(str(root/page['pdf']),outline_item=page['title'])
        writer.add_metadata({'/Title':title,'/Author':'R. Heller','/Subject':'Complete book; chapters in published reading order'})
        with fullpdf.open('wb') as stream:writer.write(stream)
    assert len(PdfReader(fullpdf).pages)>0
    validate_epub(epub)
    for page in pages:
        pdf=PdfReader(root/page['pdf']);assert len(pdf.pages)>0
        assert (pdf.pages[0].extract_text() or '').strip(),page['pdf']
        writer=PdfWriter();writer.clone_document_from_reader(pdf);writer.add_metadata({'/Title':page['title'],'/Author':'R. Heller'})
        with (root/page['pdf']).open('wb') as stream:writer.write(stream)
        file=root/page['path'];soup=BeautifulSoup(file.read_text(),'html.parser');main=soup.find('main')
        for old in soup.select('.book-downloads,.book-download-footer,.sidebar-downloads,style#unified-book-download-style'):old.decompose()
        for script in soup.find_all('script'):
            if re.search(r'className\s*=\s*[\'\"](?:book-downloads|sidebar-downloads)[\'\"]',script.get_text()):script.decompose()
        style=soup.new_tag('style',id='unified-book-download-style');style.string=CSS;soup.head.append(style)
        markup='<nav class="book-downloads book-downloads--unified" aria-label="Book and chapter downloads">'
        for label,targets in [('Entire book',plan['whole']),('This chapter',page)]:
            markup+='<div class="book-download-group"><span class="book-download-label">'+label+'</span>'
            for ext in ['pdf','epub']:
                url=os.path.relpath(root/targets[ext],file.parent).replace(os.sep,'/')
                markup+='<a href="'+html.escape(url,quote=True)+'" download aria-label="Download '+label.lower()+' as '+ext.upper()+'" title="Download '+label.lower()+' as '+ext.upper()+'"><svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">'+SVG[ext]+'</svg><span>'+ext.upper()+'</span></a>'
            markup+='</div>'
        markup+='</nav>';panel=BeautifulSoup(markup,'html.parser').nav
        anchor=main.find(id='title-block-header') or main.find('h1');anchor.insert_after(panel)
        file.write_text(str(soup))
    # Do not publish local filesystem paths in the public manifest.
    del plan['root'];(root/'book-downloads.json').write_text(json.dumps(plan,indent=2)+'\n')
    print(json.dumps({'book':a.book,'chapters':len(pages),'pdf_pages':len(PdfReader(fullpdf).pages),'chapter_formats':['pdf','epub'],'verified':True}))
if __name__=='__main__':main()
