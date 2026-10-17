from pathlib import Path
import os
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ProductDependencyDirectories(unittest.TestCase):
    def test_passes_only_current_architecture_directories(self):
        for arch, host in (('i586', 'builder'), ('x86_64', 'builder'), ('i586', 'builder.office.etersoft.ru')):
            with self.subTest(arch=arch, host=host), tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp)/"path with 'quote"; root.mkdir(); target=root/arch/'ALTLinux/Sisyphus';target.mkdir(parents=True)
                binary=root/'rpmreqs'
                binary.write_text('#!/bin/sh\nprintf "%s" "$RPMREQS_PACKAGE_DIRS" > "$CAPTURE"\necho nxssh\n')
                binary.chmod(0o755)
                script='''
load_mod() { :; }; kormod() { :; }; hostname() { echo "$TEST_HOST"; }
ssh() { [ "$1" = builder@builder32 ] || return 99; shift; "$@"; }
make_temp_file() { mktemp; }
set_destlogdir() { DESTLOGDIR="$DESTDIR/log"; mkdir -p "$DESTLOGDIR"; }
get_pkgname_from_filename() { echo rxclient; }
filter_deb_pkgnames() { cat; }
'''+(ROOT/'share/eterbuild/korinf/writedeps').read_text()+'''\nmake_alt_depends_list rxclient.rpm\n'''
                result=subprocess.run(['bash'],input=script,text=True,capture_output=True,
                                      env=dict(os.environ,DESTDIR=str(target),TARGETARCH=arch,TEST_HOST=host,
                                               ETERBUILDBIN=str(root),CAPTURE=str(root/'capture')))
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertEqual((root/'capture').read_text().splitlines(),[str(target),str(target/'extra')])
                self.assertEqual((target/'log/rxclient.rpm.depends').read_text(),'nxssh\n')

if __name__=='__main__': unittest.main()
