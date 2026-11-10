#!/usr/bin/env python3
"""Fail a release on broken local navigation, absent notes or invalid downloads."""
import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit
import zipfile

class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(); self.refs=[]; self.ids=set(); self.main=False; self.provenance=False
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        attrs=dict(attrs)
        if tag=='main': self.main=True
        if 'id' in attrs: self.ids.add(attrs['id'])
        if 'page-provenance' in attrs.get('class','').split(): self.provenance=True
        for key in ['href'] if tag in ['a','link'] else ['src'] if tag in ['img','script','iframe'] else []:
            if key in attrs: self.refs.append((tag,attrs[key]))

def check(root, book, downloads=True):
    root=root.resolve(); pages={p:Page(p.read_text(errors='replace')) for p in root.rglob('*.html')}
    errors=[]; refs=0
    if not (root/'index.html').is_file(): errors.append(['index.html','missing landing page'])
    # Chapter downloads live in downloads/chapters/, not the retired split.
    if (root/'pdf-chapters').exists(): errors.append(['pdf-chapters','retired chapter PDF folder'])
    for file,page in pages.items():
        relative=str(file.relative_to(root))
        if page.main and not page.provenance: errors.append([relative,'missing author/date note'])
        text=file.read_text(errors='replace')
        if re.search(r'\?@(?:sec|fig|tbl)-',text): errors.append([relative,'unresolved cross-reference'])
        for tag,ref in page.refs:
            u=urlsplit(ref)
            if u.scheme or u.netloc or not ref: continue
            path=unquote(u.path)
            if path.startswith('/'+book+'/'): path=path[len(book)+1:]
            target=(root/path.lstrip('/') if path.startswith('/') else file.parent/path).resolve() if path else file
            if target.is_dir(): target=target/'index.html'
            refs+=1
            if not target.exists(): errors.append([relative,ref,'missing file'])
            elif tag=='a' and u.fragment and target in pages and unquote(u.fragment) not in pages[target].ids:
                errors.append([relative,ref,'missing anchor'])
    artifacts={}
    if downloads:
        from pypdf import PdfReader
        pdf=root/(book+'.pdf');epub=root/(book+'.epub')
        try:
            reader=PdfReader(pdf);artifacts['pdf_pages']=len(reader.pages)
            if not len(reader.pages): raise ValueError('No PDF pages')
        except Exception as e: errors.append([pdf.name,str(e)])
        try:
            with zipfile.ZipFile(epub) as z:
                if z.read('mimetype')!=b'application/epub+zip' or z.testzip(): raise ValueError('Invalid EPUB archive')
                z.read('META-INF/container.xml');artifacts['epub_members']=len(z.namelist())
        except Exception as e: errors.append([epub.name,str(e)])
    report={'html_pages':len(pages),'book_pages':sum(p.main for p in pages.values()),'local_references':refs,'artifacts':artifacts,'errors':errors}
    (root/'book-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({**report,'errors':errors[:15]},indent=2))
    return not errors

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('root',type=Path,nargs='?',default=Path('docs'))
    p.add_argument('--book',default=Path.cwd().name);p.add_argument('--html-only',action='store_true')
    a=p.parse_args();raise SystemExit(not check(a.root,a.book,not a.html_only))
