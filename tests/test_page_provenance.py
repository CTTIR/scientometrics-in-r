import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/update-page-provenance.py'

class ProvenanceTest(unittest.TestCase):
    def test_source_dates_and_markup(self):
        spec = importlib.util.spec_from_file_location('provenance', SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            module.ROOT = root
            def git(*args, day='2025-01-06'):
                env = dict(os.environ, GIT_AUTHOR_NAME='R. Heller', GIT_COMMITTER_NAME='R. Heller',
                           GIT_AUTHOR_EMAIL='58561665+r-heller@users.noreply.github.com',
                           GIT_COMMITTER_EMAIL='58561665+r-heller@users.noreply.github.com',
                           GIT_AUTHOR_DATE=day+'T12:00:00+0000', GIT_COMMITTER_DATE=day+'T12:00:00+0000')
                return subprocess.check_output(['git', '-C', str(root), '-c', 'commit.gpgsign=false', *args], env=env, stderr=subprocess.PIPE)
            git('init')
            chapter = root / 'chapter.Rmd'
            original = '---\ntitle: Example\n# YAML comment\ndate: today\n---\n\n```{r}\n# Code comment\n```\n\n# Real chapter {#example}\n\nText.\n'
            chapter.write_text(original)
            git('add', 'chapter.Rmd'); git('commit', '-m', 'Add chapter')
            module.refresh()
            first = chapter.read_text()
            self.assertIn('Date: 2025-01-06 · Last changed: 2025-01-06', first)
            self.assertGreater(first.index('page-provenance:start'), first.index('# Real chapter'))
            self.assertEqual(module.content(first), module.content(original))
            module.refresh(); self.assertEqual(first, chapter.read_text())
            git('add', 'chapter.Rmd'); git('commit', '-m', 'Add chapter notes', day='2025-03-03')
            module.refresh(); self.assertEqual(first, chapter.read_text())
            chapter.write_text(first.replace('Text.', 'Revised text.'))
            git('add', 'chapter.Rmd'); git('commit', '-m', 'Revise chapter', day='2025-04-07')
            module.refresh()
            self.assertIn('Date: 2025-01-06 · Last changed: 2025-04-07', chapter.read_text())
            self.assertIn('Last changed: 2025-04-07', (root/'style/provenance.tex').read_text())
            git('add', 'chapter.Rmd'); git('commit', '-m', 'Refresh notes', day='2025-04-08')
            main = git('rev-parse', '--abbrev-ref', 'HEAD').decode().strip()
            # A merge that adopts a branch's page credits the branch commit.
            git('checkout', '-b', 'branch')
            chapter.write_text(chapter.read_text().replace('Revised text.', 'Branch text.'))
            git('commit', '-am', 'Edit on a branch', day='2025-05-05')
            git('checkout', main)
            git('merge', '--no-ff', '-m', 'Merge branch', 'branch', day='2025-06-02')
            module.refresh()
            self.assertIn('Last changed: 2025-05-05', chapter.read_text())
            git('commit', '-am', 'Refresh notes', day='2025-06-03')
            # A merge that writes new content is the change; later note-only
            # commits are not.
            git('checkout', '-b', 'other', main + '~1')
            (root / 'other.txt').write_text('other\n')
            git('add', 'other.txt'); git('commit', '-m', 'Unrelated branch', day='2025-06-09')
            git('checkout', main)
            git('merge', '--no-ff', '--no-commit', 'other', day='2025-07-07')
            chapter.write_text(chapter.read_text().replace('Branch text.', 'Merged text.'))
            git('commit', '-am', 'Integrate branch', day='2025-07-07')
            module.refresh()
            git('commit', '-am', 'Refresh notes', day='2025-08-04')
            module.refresh()
            merged = chapter.read_text()
            self.assertIn('Date: 2025-01-06 · Last changed: 2025-07-07', merged)
            module.refresh(); self.assertEqual(merged, chapter.read_text())

if __name__ == '__main__':
    unittest.main()
