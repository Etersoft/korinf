"""Keep Debian 11 archive changes scoped to the affected source and idempotent."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'share/eterbuild/korinf/prepare-debian11-container'


class DebianArchive(unittest.TestCase):
    def test_scoped_archive_migration_and_idempotence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'sources.list.d').mkdir()
            source = root / 'sources.list'
            unaffected = ('deb http://deb.debian.org/debian bullseye main\n'
                          'deb https://security.debian.org/debian-security bookworm-security main\n'
                          '# deb http://security.debian.org/debian-security bullseye-security main\n')
            source.write_text(unaffected + 'deb http://security.debian.org/debian-security bullseye-security main\n')
            extra = root / 'sources.list.d/security.list'
            extra.write_text('deb-src [signed-by=/key.gpg arch=i386 check-valid-until=yes] https://deb.debian.org/debian-security bullseye-security main\n'
                             'deb [arch=amd64] http://security.debian.org/debian-security bullseye-security main\n')
            subprocess.run(['sh', str(SCRIPT), tmp], check=True)
            first = source.read_text(), extra.read_text()
            self.assertTrue(first[0].startswith(unaffected))
            self.assertIn('deb [check-valid-until=no] https://archive.debian.org/debian-security bullseye-security main', first[0])
            self.assertIn('[signed-by=/key.gpg arch=i386 check-valid-until=no]', first[1])
            self.assertIn('[arch=amd64 check-valid-until=no]', first[1])
            self.assertNotIn('trusted=yes', ''.join(first))
            subprocess.run(['sh', str(SCRIPT), tmp], check=True)
            self.assertEqual(first, (source.read_text(), extra.read_text()))

    def test_missing_sources_are_harmless(self):
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(['sh', str(SCRIPT), tmp], check=True)
            self.assertEqual(list(Path(tmp).iterdir()), [])


if __name__ == '__main__':
    unittest.main()
