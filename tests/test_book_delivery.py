import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile
from pypdf import PdfWriter

SCRIPTS=Path(__file__).resolve().parents[1]/'scripts'
def module(name):
 spec=importlib.util.spec_from_file_location(name,SCRIPTS/(name+'.py'))
 result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

class DeliveryTest(unittest.TestCase):
 def test_nested_links_validation_and_repeat_operation(self):
  finalizer=module('finalize-book');checker=module('check-book')
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);out=root/'docs';(out/'chapters').mkdir(parents=True)
   env=dict(os.environ,GIT_AUTHOR_NAME='R. Heller',GIT_COMMITTER_NAME='R. Heller',
            GIT_AUTHOR_EMAIL='58561665+r-heller@users.noreply.github.com',GIT_COMMITTER_EMAIL='58561665+r-heller@users.noreply.github.com')
   subprocess.run(['git','init',str(root)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   subprocess.run(['git','-C',str(root),'-c','commit.gpgsign=false','commit','--allow-empty','-m','Initialize book'],env=env,check=True,stdout=subprocess.DEVNULL)
   writer=PdfWriter();writer.add_blank_page(width=300,height=400)
   with (out/'example.pdf').open('wb') as stream:writer.write(stream)
   with zipfile.ZipFile(out/'example.epub','w') as z:
    z.writestr('mimetype','application/epub+zip');z.writestr('META-INF/container.xml','<container/>')
   (out/'index.html').write_text('<main><a href="chapters/one.html#one">Read</a></main>')
   chapter=out/'chapters/one.html';chapter.write_text('<main><h1 id="one">One</h1></main>')
   previous=Path.cwd()
   try:
    os.chdir(root);finalizer.finalize(out,'example')
    self.assertIn('href="../example.pdf"',chapter.read_text())
    first=chapter.read_text();finalizer.finalize(out,'example');self.assertEqual(first,chapter.read_text())
    self.assertTrue(checker.check(out,'example'))
    chapter.write_text(chapter.read_text().replace('id="one"','id="renamed"'))
    self.assertFalse(checker.check(out,'example'))
    (out/'example.pdf').write_bytes(b'%PDF-truncated')
    with self.assertRaises(Exception):finalizer.finalize(out,'example')
   finally:os.chdir(previous)

if __name__=='__main__':unittest.main()
