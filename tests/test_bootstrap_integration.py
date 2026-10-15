"""Check that build/install entry points actually use the bootstrap policy."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BootstrapIntegration(unittest.TestCase):
    def shell(self, module, body):
        source = (ROOT/'share/eterbuild/korinf'/module).read_text()
        return subprocess.run(['bash'], input='kormod() { :; }; load_mod() { :; }; assert_var() { :; }\n'+
            source+'\nKORINFDIR='+str(ROOT/'share/eterbuild')+'\n'+body, text=True, capture_output=True)

    def test_core_dependencies_are_checked_and_aggregate_dependencies_deferred(self):
        harness = '''
get_target_package_names() { echo 'wine-etersoft wine-etersoft-full'; }
get_target_deplist() { echo "checked:$1" >&2; echo libneeded; }
rhas() { return 1; }
estrlist() { echo "$3"; }
quote_pkgname() { echo "$*"; }
run_in_chroot() { echo "$*"; return 7; }
BOOTSTRAP_EXCLUDE=wine-etersoft-full
PKGFORMAT=rpm
dist=test
test_package_requirements
'''
        result = self.shell('check_reqs', harness)
        self.assertEqual(result.returncode, 7)
        self.assertIn('checked:wine-etersoft\n', result.stderr)
        result = self.shell('check_reqs', harness.replace('return 7;', 'return 0;'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('checked:wine-etersoft-full', result.stderr)

    def test_install_and_simulation_use_selected_artifacts(self):
        for module, call, simulate in [('install', 'install_built_packages', False),
                                      ('check_reqs', 'test_package_files_requirements', True)]:
            with self.subTest(call=call):
                result = self.shell(module, '''
run_in_chroot() { echo "$*"; cat >/dev/null; return 7; }
BOOTSTRAP_EXCLUDE=wine-etersoft-full
PKGFORMAT=rpm INTBUILT=/built dist=test
EXPMAINFILES='wine.rpm full.rpm' EXPEXTRAFILES=devel.rpm
'''+call+'\n')
                self.assertEqual(result.returncode, 7, result.stderr)
                self.assertIn("'wine-etersoft-full' wine.rpm full.rpm devel.rpm", result.stdout)
                self.assertEqual('--simulate' in result.stdout, simulate)


if __name__ == '__main__':
    unittest.main()
