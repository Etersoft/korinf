"""converts/common: the deb depends of a package without an ALT Sisyphus build come from its rpm."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

# rpm -qp --requires of postgresql-mchar built for Debian 12 (spec converted by rpmbph)
REQUIRES = '''libc.so.6()(64bit)
libicui18n.so.72()(64bit)
libicuuc.so.72()(64bit)
postgresql
postgresql-contrib
/bin/sh
rpmlib(CompressedFileNames) <= 3.0.4-1
rpmlib(PayloadFilesHavePrefix) <= 4.0-1
'''


class RpmDeplist(unittest.TestCase):
    def run_func(self, call, sisyphus_depends=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            log = root / 'x86_64/ALTLinux/Sisyphus/log'
            log.mkdir(parents=True)
            if sisyphus_depends is not None:
                (log / 'pkg.rpm.depends').write_text(sisyphus_depends)
            (root / 'requires').write_text(REQUIRES)
            script = '''
assert_var() { :; }; warning() { echo "warning: $*" >&2; }
filter_deb_pkgnames() { cat; }
convert_pkgreqs_to_target() { for i in "$@" ; do echo "deb-$i" ; done; }
rpm() { [ "$1 $2" = "-qp --requires" ] && [ "$3" = pkg.rpm ] && cat "$TESTROOT/requires"; }
''' + (ROOT / 'share/eterbuild/korinf/converts/common').read_text() + '\n' + call + '\n'
            return subprocess.run(['bash'], input=script, text=True, capture_output=True, cwd=root,
                                  env=dict(os.environ, TESTROOT=str(root), TARGETPATH=str(root), TARGETARCH='x86_64'))

    def test_package_names_only(self):
        r = self.run_func('get_rpm_deplist pkg.rpm')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.split(), ['postgresql', 'postgresql-contrib'])

    def test_fallback_when_no_sisyphus_build(self):
        call = 'get_target_deplist pkg > out || get_rpm_deplist pkg.rpm > out; cat out'
        r = self.run_func(call)
        self.assertEqual(r.stdout.split(), ['postgresql', 'postgresql-contrib'])
        self.assertIn('Cannot locate', r.stderr)
        # with the Sisyphus build its depends are used
        r = self.run_func(call, sisyphus_depends='util-linux\n')
        self.assertEqual(r.stdout.split(), ['deb-util-linux'])


if __name__ == '__main__':
    unittest.main()
