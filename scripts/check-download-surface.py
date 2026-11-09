#!/usr/bin/env python3
import json, sys, zipfile
from pathlib import Path
from urllib.parse import unquote,urlsplit
from bs4 import BeautifulSoup
from pypdf import PdfReader
root=Path(sys.argv[1]);data=json.loads((root/'book-downloads.json').read_text());assert data['chapters']
checked=set()
for chapter in data['chapters']:
 page=root/chapter['path'];soup=BeautifulSoup(page.read_text(),'html.parser');panels=soup.select('.book-downloads--unified');assert len(panels)==1,page
 links=panels[0].find_all('a');assert len(links)==4,page
 expected=[root/data['whole']['pdf'],root/data['whole']['epub'],root/chapter['pdf'],root/chapter['epub']]
 assert [(page.parent/unquote(urlsplit(x['href']).path)).resolve() for x in links]==[x.resolve() for x in expected],page
 for link,file in zip(links,expected):
  assert link.find('svg') and link.get('aria-label') and file.is_file(),file
  if file in checked:continue
  checked.add(file)
  if file.suffix=='.pdf':
   pdf=PdfReader(file);assert len(pdf.pages)>0,file
  else:
   with zipfile.ZipFile(file) as z:assert z.read('mimetype')==b'application/epub+zip' and z.testzip() is None,file
 pdf=PdfReader(root/chapter['pdf']);assert pdf.metadata.author=='R. Heller',chapter
print(f"Verified four icon download links on each of {len(data['chapters'])} chapters.")
