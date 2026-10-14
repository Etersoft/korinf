"""A shared hasher repository must not choose an unrelated cached source."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import os

ROOT = Path(__file__).resolve().parents[1]

class HasherSourceSelection(unittest.TestCase):
    def check_selection(self, candidates, version='10'):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root / 'repo/SRPMS.hasher'
            repo.mkdir(parents=True)
            requested = root / 'input.src.rpm'
            requested.write_text('wine-etersoft ' + version)
            for name, identity in candidates.items():
                (repo / name).write_text(identity)
            harness = '''
load_mod() { :; }
error() { echo "$*" >&2; }
rpm() { cat "${@: -1}"; }
'''
            source = (ROOT / 'share/eterbuild/korinf/build/hasher').read_text()
            return subprocess.run(['bash'], input=harness+source+'\nselect_hasher_srpm\n',
                text=True, capture_output=True,
                env=dict(os.environ, HASHERDIR=str(root), BUILDSRPM=str(requested)))

    def test_selects_requested_version_and_exact_name(self):
        result = self.check_selection({'wine-etersoft-11-alt1.src.rpm':'wine-etersoft 11',
            'wine-etersoft-10-alt1.src.rpm':'wine-etersoft 10',
            'wine-etersoft-grdwine-10-alt1.src.rpm':'wine-etersoft-grdwine 10'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.strip().endswith('/wine-etersoft-10-alt1.src.rpm'))

    def test_accepts_version_starting_with_letter(self):
        result = self.check_selection({
            'wine-etersoft-beta1-alt1.src.rpm': 'wine-etersoft beta1',
        }, version='beta1')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_ambiguous_releases(self):
        result = self.check_selection({'wine-etersoft-10-alt1.src.rpm':'wine-etersoft 10',
            'wine-etersoft-10-alt2.src.rpm':'wine-etersoft 10'})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Ambiguous', result.stderr)

    def test_rejects_only_stale_version(self):
        result = self.check_selection({'wine-etersoft-11-alt1.src.rpm':'wine-etersoft 11'})
        self.assertNotEqual(result.returncode, 0)

if __name__ == '__main__':
    unittest.main()
