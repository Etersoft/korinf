from pathlib import Path
import os
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ProductDependencyDirectories(unittest.TestCase):
    def test_passes_only_current_architecture_directories(self):
        for arch in ('i586','x86_64'):
            with self.subTest(arch=arch), tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp); target=root/arch/'ALTLinux/Sisyphus';target.mkdir(parents=True)
                binary=root/'rpmreqs'
                binary.write_text('#!/bin/sh\nprintf "%s" "$RPMREQS_PACKAGE_DIRS" > "$CAPTURE"\necho nxssh\n')
                binary.chmod(0o755)
                script='''
load_mod() { :; }; kormod() { :; }; hostname() { echo builder; }
make_temp_file() { mktemp; }
set_destlogdir() { DESTLOGDIR="$DESTDIR/log"; mkdir -p "$DESTLOGDIR"; }
get_pkgname_from_filename() { echo rxclient; }
filter_deb_pkgnames() { cat; }
'''+(ROOT/'share/eterbuild/korinf/writedeps').read_text()+'''\nmake_alt_depends_list rxclient.rpm\n'''
                result=subprocess.run(['bash'],input=script,text=True,capture_output=True,
                                      env=dict(os.environ,DESTDIR=str(target),TARGETARCH=arch,
                                               ETERBUILDBIN=str(root),CAPTURE=str(root/'capture')))
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertEqual((root/'capture').read_text().splitlines(),[str(target),str(target/'extra')])
                self.assertEqual((target/'log/rxclient.rpm.depends').read_text(),'nxssh\n')

if __name__=='__main__': unittest.main()
