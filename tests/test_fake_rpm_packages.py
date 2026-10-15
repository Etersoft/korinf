"""Exercise versioned bootstrap dependencies without modifying host rpmdb."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'share/eterbuild/korinf/install-fake-rpm-packages'
FAKE = 'Faked provides package\nThis package is empty. It has been created to put fake entry in rpmdb.'


class FakeRpmPackages(unittest.TestCase):
    def run_case(self, state, requirement='wine-etersoft-gecko = 2.47.4', built=True, fail=False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'state').write_text(json.dumps(state))
            rpm = root / 'rpm'
            rpm.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
state = json.loads(Path(os.environ['STATE']).read_text())
a = sys.argv[1:]
if a[0] == '-qp':
    print(os.environ['REQUIREMENT'])
elif '--qf' in a:
    if state is None: sys.exit(1)
    print(state['metadata'], end='')
elif '--whatprovides' in a:
    r = a[-1].split()
    if state is None: sys.exit(1)
    if len(r) > 1 and state['version'] != r[2]: sys.exit(1)
else:
    sys.exit(0 if state else 1)
''')
            epm = root / 'epm'
            epm.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
Path(os.environ['CALL']).write_text(json.dumps(sys.argv[1:]))
if os.environ['FAIL'] == '1': sys.exit(3)
version = next(a.split('=', 1)[1] for a in sys.argv if a.startswith('--version='))
Path(os.environ['STATE']).write_text(json.dumps(dict(metadata=os.environ['FAKE'], version=version)))
''')
            rpm.chmod(0o755)
            epm.chmod(0o755)
            env = dict(os.environ, PATH=str(root)+':'+os.environ['PATH'], STATE=str(root/'state'),
                       CALL=str(root/'call'), REQUIREMENT=requirement, FAKE=FAKE, FAIL=str(int(fail)))
            result = subprocess.run(['sh', str(SCRIPT), 'wine-etersoft-gecko'] +
                                    (['wine-full.rpm'] if built else []), env=env, capture_output=True, text=True)
            calls = json.loads((root/'call').read_text()) if (root/'call').exists() else []
            return result, calls

    def test_missing_and_old_fake_get_required_version(self):
        for state in (None, dict(metadata=FAKE, version='0')):
            result, call = self.run_case(state)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('--version=2.47.4', call)
            self.assertIn('--name=wine-etersoft-gecko', call)

    def test_minimum_version(self):
        result, call = self.run_case(None, 'wine-etersoft-gecko >= 20250102')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--version=20250102', call)

    def test_real_and_current_packages_are_preserved(self):
        for metadata, version in [('real package', '0'), (FAKE, '2.47.4')]:
            result, call = self.run_case(dict(metadata=metadata, version=version))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(call, [])

    def test_initial_creation_and_no_downgrade(self):
        result, call = self.run_case(None, built=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--version=0', call)
        result, call = self.run_case(dict(metadata=FAKE, version='2.47.4'), built=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(call, [])

    def test_ambiguous_and_unsupported_constraints_fail(self):
        for req in ['wine-etersoft-gecko = 2\nwine-etersoft-gecko = 3',
                    'wine-etersoft-gecko < 3', 'wine-etersoft-gecko = 1:2']:
            result, call = self.run_case(None, req)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(call, [])

    def test_install_failure_propagates(self):
        result, call = self.run_case(None, fail=True)
        self.assertEqual(result.returncode, 3)


if __name__ == '__main__':
    unittest.main()
