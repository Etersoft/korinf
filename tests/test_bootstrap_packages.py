"""Verify package selection and migration without modifying the host package DB."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPERS = ROOT / 'share/eterbuild/korinf'
FAKE = 'Faked provides package\nThis package is empty. It has been created to put fake entry in rpmdb.'


class BootstrapPackages(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = dict(os.environ, PATH=str(self.root)+':'+os.environ['PATH'],
                        CALLS=str(self.root/'calls'), STATE='{}', FAIL='')
        stub = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
a = sys.argv[1:]
state = json.loads(os.environ['STATE'])
if name == 'rpm' and '-qp' in a or name == 'dpkg-deb':
    f = a[-1] if name == 'rpm' else a[1]
    print(Path(f).read_text(), end='')
elif name == 'rpm' and '-q' in a or name == 'dpkg-query':
    if a[-1] not in state: sys.exit(1)
    if name == 'dpkg-query' and 'Status' in a[1]: print('install ok installed', end='')
    else: print(state[a[-1]], end='')
else:
    with open(os.environ['CALLS'], 'a') as out: out.write(json.dumps([name]+a)+'\\n')
    if os.environ['FAIL'] and os.environ['FAIL'] in a: sys.exit(7)
'''
        for name in ['rpm', 'dpkg-query', 'dpkg', 'dpkg-deb', 'epm']:
            path = self.root/name
            path.write_text(stub)
            path.chmod(0o755)

    def run_helper(self, name, *args):
        result = subprocess.run(['bash', str(HELPERS/name), *args], env=self.env,
                                text=True, capture_output=True)
        calls = self.root/'calls'
        return result, [json.loads(s) for s in calls.read_text().splitlines()] if calls.exists() else []

    def test_selection_keeps_core_and_devel_and_defers_both_full_packages(self):
        for fmt in ['rpm', 'deb']:
            with self.subTest(fmt=fmt):
                files = []
                for name in ['wine-etersoft', 'wine-etersoft-common', 'wine-etersoft-devel',
                             'wine-etersoft-full', 'wine32-etersoft-full']:
                    f = self.root/(name+'.'+fmt)
                    f.write_text(name)
                    files.append(str(f))
                result, calls = self.run_helper('install-bootstrap-packages', fmt,
                    'wine-etersoft-full wine32-etersoft-full', *files)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(calls[-1], ['epm', '--verbose', '--auto', '--force', 'install']+files[:3])
                self.assertTrue(all(Path(f).exists() for f in files))

    def test_missing_artifacts_and_empty_selection_fail(self):
        result, calls = self.run_helper('install-bootstrap-packages', 'rpm', '', '/missing.rpm')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])
        f = self.root/'full.rpm'; f.write_text('wine-etersoft-full')
        result, calls = self.run_helper('install-bootstrap-packages', 'rpm', 'wine-etersoft-full', str(f))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_rpm_migration_preserves_real_components(self):
        self.env['STATE'] = json.dumps({'wine-etersoft-full':'Full Wine',
            'wine-etersoft-gecko':FAKE, 'wine-etersoft-mono':'Real mono'})
        result, calls = self.run_helper('prepare-build-image', 'rpm', 'wine-etersoft-full',
                                       'wine-etersoft-gecko wine-etersoft-mono')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [['rpm', '-e', '--test', 'wine-etersoft-full', 'wine-etersoft-gecko'],
                                 ['rpm', '-e', 'wine-etersoft-full', 'wine-etersoft-gecko']])

    def test_deb_migration_preserves_real_components(self):
        self.env['STATE'] = json.dumps({'wine-etersoft-full':'Upstream|Full Wine',
            'wine-etersoft-gecko':'Korinf <builder@etersoft.ru>|Temporary bootstrap dependency for wine-etersoft-gecko\n empty',
            'wine-etersoft-mono':'Upstream|Real mono'})
        result, calls = self.run_helper('prepare-build-image', 'deb', 'wine-etersoft-full',
                                       'wine-etersoft-gecko wine-etersoft-mono')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [['dpkg', '--dry-run', '--remove', 'wine-etersoft-full', 'wine-etersoft-gecko'],
                                 ['dpkg', '--remove', 'wine-etersoft-full', 'wine-etersoft-gecko']])

    def test_dependency_conflict_stops_before_removal(self):
        for fmt, flag in [('rpm', '--test'), ('deb', '--dry-run')]:
            with self.subTest(fmt=fmt):
                (self.root/'calls').unlink(missing_ok=True)
                self.env.update(STATE=json.dumps({'wine-etersoft-full':'full'}), FAIL=flag)
                result, calls = self.run_helper('prepare-build-image', fmt, 'wine-etersoft-full', '')
                self.assertEqual(result.returncode, 7)
                self.assertEqual(len(calls), 1)
                self.assertIn(flag, calls[0])

    def test_clean_image_needs_no_changes(self):
        result, calls = self.run_helper('prepare-build-image', 'rpm', 'wine-etersoft-full', 'wine-etersoft-gecko')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_install_error_is_propagated(self):
        f = self.root/'wine.rpm'; f.write_text('wine-etersoft')
        self.env['FAIL'] = 'install'
        result, calls = self.run_helper('install-bootstrap-packages', 'rpm', '', str(f))
        self.assertEqual(result.returncode, 7)


if __name__ == '__main__':
    unittest.main()
