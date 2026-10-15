"""Keep physical RPM filenames while selecting binaries by exact source identity."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CurrentRpmFiles(unittest.TestCase):
    def select(self, packages, source='eepm-3.64.70-alt1rosa.src.rpm'):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name, header in packages.items():
                (root/name).write_text(header)
            code = (ROOT/'share/eterbuild/korinf/filelist').read_text()
            harness = '''
rpm() { case "$(cat "${@: -1}")" in broken) return 7;; *) cat "${@: -1}";; esac; }
error() { echo "$*" >&2; }
list_current_rpm_files "$PKGDIR" "$SOURCE"
'''
            result = subprocess.run(['bash'], input=code+'\n'+harness, text=True,
                capture_output=True, env=dict(os.environ, PKGDIR=str(root), SOURCE=source))
            return result, [Path(p).name for p in result.stdout.splitlines()]

    def test_disttag_filenames_are_preserved(self):
        name = 'eepm-3.64.70-alt1rosa-rosa2021.1.noarch.rpm'
        result, files = self.select({name:'eepm-3.64.70-alt1rosa.src.rpm'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files, [name])

    def test_renamed_subpackages_selected_but_stale_packages_excluded(self):
        result, files = self.select({'different-binary-1.x86_64.rpm':'eepm-3.64.70-alt1rosa.src.rpm',
            'eepm-old.noarch.rpm':'eepm-3.64.69-alt1rosa.src.rpm',
            'eepm-3.64.70-alt1rosa.src.rpm':'broken'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files, ['different-binary-1.x86_64.rpm'])

    def test_source_name_is_literal_not_a_regular_expression(self):
        result, files = self.select({'wrong.rpm':'eepm-3x64x70-alt1rosa.src.rpm'})
        self.assertEqual(result.returncode, 0)
        self.assertEqual(files, [])

    def test_invalid_rpm_stops_selection(self):
        result, files = self.select({'broken.rpm':'broken'})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(files, [])


if __name__ == '__main__':
    unittest.main()
