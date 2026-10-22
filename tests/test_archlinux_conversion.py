"""Exercise the generated converter script with several RPM paths."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ArchConversion(unittest.TestCase):
    def test_multiline_rpm_list_is_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            script = f'''
                . {ROOT}/share/eterbuild/korinf/converts/archlinux
                assert_var() {{ :; }}
                prepare_convert() {{ :; }}
                estrlist() {{ :; }}
                get_numpartrelease() {{ echo 1; }}
                run_in_chroot() {{ cat > {tmp}/generated; return 1; }}
                BUILTBINPKGLIST=$'/tmp/eepm.rpm\\n/tmp/eepm-full.rpm\\n/tmp/eepm-repack.rpm'
                BUILDARCH=x86_64 PACKAGERELEASE=1 WRKDIR={tmp}/work
                convert_archlinux
            '''
            subprocess.run(['bash', '-c', script], capture_output=True, check=False)
            generated = Path(tmp, 'generated').read_text()
            check = subprocess.run(['bash', '-n'], input=generated, text=True, capture_output=True)
            self.assertEqual(check.returncode, 0, check.stderr)
            # Execute the actual generated assignment and loop header.
            start = generated.index('\tbinpkglist=')
            end = generated.index('\n\t\tpkg=', start)
            loop = generated[start:end] + '\n printf "%s\\n" "$i"; done\n'
            result = subprocess.run(['bash', '-c', loop], capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.splitlines(),
                             ['/tmp/eepm.rpm', '/tmp/eepm-full.rpm', '/tmp/eepm-repack.rpm'])
