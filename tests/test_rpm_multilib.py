import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RpmMultilib(unittest.TestCase):
    def run_case(self, query_output="", query_status=0, install_status=1):
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
exit "$INSTALL_STATUS"
''')
            dnf = root / 'dnf'
            dnf.write_text('''#!/bin/sh
printf '%s' "$QUERY_OUTPUT"
exit "$QUERY_STATUS"
''')
            for p in (rpm, epm, dnf): p.chmod(0o755)
            args, calls = root / 'args', root / 'calls'
            result = subprocess.run(['sh', str(ROOT / 'share/eterbuild/korinf/install-rpm-multilib')],
                env=dict(os.environ, PATH=str(root)+':'+os.environ['PATH'], ARGS=str(args), CALLS=str(calls), QUERY_OUTPUT=query_output, QUERY_STATUS=str(query_status), INSTALL_STATUS=str(install_status)),
                capture_output=True, text=True)
            self.assertEqual(result.returncode, int(install_status != 0 and (bool(query_output) or query_status != 0)), result.stderr)
            self.assertIn('%{NAME}.%{ARCH}', args.read_text())
            self.assertEqual(calls.read_text().splitlines(), [
                '--auto --skip-installed install freetype-devel.i686',
                '--auto --skip-installed install libX11-devel.i686'])

    def test_selects_explicit_arch_and_skips_unavailable_counterparts(self):
        self.run_case()

    def test_transaction_failure_is_fatal_for_available_package(self):
        self.run_case(query_output="freetype-devel.i686\n")

    def test_failed_repository_query_is_not_absence(self):
        self.run_case(query_status=1)

    def test_successful_install(self):
        self.run_case(install_status=0)


if __name__ == '__main__':
    unittest.main()
