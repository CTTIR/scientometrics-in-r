#!/usr/bin/env python3
"""Add accessible, static download links only for verified artifacts."""
import argparse
import html
import os
from pathlib import Path
import re
import subprocess
from pypdf import PdfReader
import zipfile

MARKER=re.compile(r'\n<!-- verified-downloads:start -->.*?<!-- verified-downloads:end -->\n',re.S)

def finalize(root, name):
    pdf=root/(name+'.pdf'); epub=root/(name+'.epub')
    if not len(PdfReader(pdf).pages): raise ValueError('The full PDF is empty')
    with zipfile.ZipFile(epub) as z:
        if z.read('mimetype')!=b'application/epub+zip' or z.testzip(): raise ValueError('EPUB integrity failure')
        z.read('META-INF/container.xml')
    dates=subprocess.check_output(['git','log','--format=%as'],text=True).splitlines()
    count=0
    for page in root.rglob('*.html'):
        text=MARKER.sub('',page.read_text())
        if '</main>' not in text: continue
        paths=[(pdf,'Entire book (PDF)'),(epub,'Entire book (EPUB)')]
        links=' · '.join('<a href="'+html.escape(os.path.relpath(p,page.parent).replace(os.sep,'/'),quote=True)+'">'+label+'</a>' for p,label in paths)
        fallback=''
        if 'class="page-provenance"' not in text:
            fallback=f'<p class="page-provenance"><small>R. Heller · Date: {min(dates)} · Last changed: {max(dates)}</small></p>'
        block='\n<!-- verified-downloads:start -->\n'+fallback+'<nav class="book-download-footer" aria-label="Book downloads"><p>'+links+'</p></nav>\n<!-- verified-downloads:end -->\n'
        text=text.replace('</main>',block+'</main>',1);page.write_text(text);count+=1
    print(f'Added verified download links to {count} reading pages')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('root',type=Path,nargs='?',default=Path('docs'));p.add_argument('--book',default=Path.cwd().name)
    a=p.parse_args();finalize(a.root,a.book)
