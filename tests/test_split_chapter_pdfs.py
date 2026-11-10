import importlib.util
from pathlib import Path
import tempfile
from pypdf import PdfReader, PdfWriter
script=Path(__file__).resolve().parents[1] / 'scripts/split-chapter-pdfs.py'
spec=importlib.util.spec_from_file_location('split',script);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as folder:
 root=Path(folder);w=PdfWriter()
 for _ in range(6):w.add_blank_page(width=300,height=400)
 a=w.add_outline_item('1 First chapter',0);w.add_outline_item('1.1 Section',1,parent=a)
 w.add_outline_item('Citing',1,parent=a)
 w.add_outline_item('2 Unmatched chapter',2);last=w.add_outline_item('3 Last chapter',4)
 w.add_outline_item('Citing',5,parent=last)
 with (root/'example.pdf').open('wb') as f:w.write(f)
 for slug,title in [('first','Chapter 1 First chapter'),('last','Chapter 3 Last chapter'),('citing-1','Citing')]:
  (root/(slug+'.html')).write_text('<title>'+title+' | Example</title>')
 assert m.split(root,'example')==3
 assert m.normalize('Appendix A R Setup') == 'r setup'
 assert len(PdfReader(root/'pdf-chapters/citing-1.pdf').pages)==1
 assert len(PdfReader(root/'pdf-chapters/first.pdf').pages)==2
 assert len(PdfReader(root/'pdf-chapters/last.pdf').pages)==2
print('Chapter boundaries, nested sections, unmatched chapters and final pages passed')

assert m.normalize("Replicating Axelrod’s Tournament") == m.normalize("Replicating Axelrod's Tournament")
