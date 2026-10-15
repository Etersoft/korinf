import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RpmMultilib(unittest.TestCase):
    def test_selects_only_native_development_packages_with_explicit_arch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rpm = root / 'rpm'
            rpm.write_text('''#!/bin/sh
printf '%s\\n' "$@" > "$ARGS"
printf '%s\\n' libX11-devel.x86_64 freetype-devel.x86_64 libX11-devel.i686 libX11.x86_64 tool-devel.noarch python-devel.aarch64 libX11-devel.x86_64
''')
            epm = root / 'epm'
            epm.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$CALLS"
exit 1
''')
            for p in (rpm, epm): p.chmod(0o755)
            args, calls = root / 'args', root / 'calls'
            result = subprocess.run(['sh', str(ROOT / 'share/eterbuild/korinf/install-rpm-multilib')],
                env=dict(os.environ, PATH=str(root)+':'+os.environ['PATH'], ARGS=str(args), CALLS=str(calls)),
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('%{NAME}.%{ARCH}', args.read_text())
            self.assertEqual(calls.read_text().splitlines(), [
                '--auto --skip-installed install freetype-devel.i686',
                '--auto --skip-installed install libX11-devel.i686'])


if __name__ == '__main__':
    unittest.main()
