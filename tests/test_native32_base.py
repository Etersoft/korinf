"""Native base images must not change architecture selection for Wine."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeBase(unittest.TestCase):
    def test_base_and_module_rules(self):
        for module, target, expected in [('', 'Debian/13', 0), ('', 'i586/Debian/13', 0),
                                         ('', 'Debian/12', 1), ('wine-11.12', 'Debian/13', 1),
                                         ('wine-10.0', 'Debian/12', 0), ('rx', 'Debian/13', 1)]:
            with self.subTest(module=module, target=target):
                result = subprocess.run(['bash', '-c', f'''
                    . {ROOT}/share/eterbuild/korinf/list
                    KORINFETC={ROOT}/etc KORINFMODULE={module}
                    check_native_32_system {target}
                '''], capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)
