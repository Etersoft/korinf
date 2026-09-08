"""Isolated restart tests: no real queue, build or HTTP service is touched."""
import ast
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'buildapi'))
import taskreader as tr


class HTTPException(Exception):
    def __init__(self, status_code, detail):
        self.status_code = status_code
        super().__init__(detail)


class RestartTests(unittest.TestCase):
    def test_restart_requests_cleanup_before_requeue(self):
        import os
        tree = ast.parse((ROOT / 'buildapi/main.py').read_text())
        func = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == '_do_restart')
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os=os, tr=tr, SALES=tmp, HTTPException=HTTPException)
            exec(compile(ast.Module(body=[func], type_ignores=[]), '<restart>', 'exec'), env)
            taskid = '20260908120000.ABCD-1234.abcdefghij'
            failed = pathlib.Path(tmp) / (taskid + '.task.failed')
            queued = pathlib.Path(tmp) / (taskid + '.task')
            failed.write_text('PACKAGE="wine-etersoft"\n# build FAILED at today\n')
            original = failed.read_text()
            real_rename = os.rename

            def rename(src, dst):
                self.assertEqual(tr.parse_file(src)[0]['CLEAR_FAILED_ON_RESTART'], '1')
                real_rename(src, dst)

            with patch.object(os, 'rename', side_effect=rename):
                self.assertTrue(env['_do_restart'](taskid)['restarted'])
            self.assertFalse(failed.exists())
            self.assertTrue(queued.read_text().startswith(original))
            queued.rename(failed)
            env['_do_restart'](taskid)
            self.assertEqual(queued.read_text().count('CLEAR_FAILED_ON_RESTART=1'), 1)
            with self.assertRaises(HTTPException) as caught:
                env['_do_restart'](taskid)
            self.assertEqual(caught.exception.status_code, 404)
            with self.assertRaises(HTTPException) as caught:
                env['_do_restart']('../invalid')
            self.assertEqual(caught.exception.status_code, 400)
            queued.rename(failed)
            with patch.object(os, 'rename', side_effect=OSError('denied')):
                with self.assertRaises(HTTPException) as caught:
                    env['_do_restart'](taskid)
            self.assertEqual(caught.exception.status_code, 500)
            self.assertTrue(failed.exists())
            self.assertFalse(queued.exists())

    def test_worker_clears_only_requested_package_and_fails_on_error(self):
        script = r'''
set -eu
. "$1/share/eterbuild/korinf/status"
set_destlogdir() { DESTLOGDIR="$DESTDIR/log"; mkdir -p "$DESTLOGDIR"; }
fatal() { echo "$*" >&2; exit 1; }
DESTDIR="$2/distro"
BUILDNAME=wine-etersoft
set_destlogdir
touch "$DESTLOGDIR/$BUILDNAME.build.failed" "$DESTLOGDIR/$BUILDNAME.autobuild.failed" "$DESTLOGDIR/other.build.failed" "$DESTLOGDIR/$BUILDNAME.log"
CLEAR_FAILED_ON_RESTART=
clear_restart_build_status
test -f "$DESTLOGDIR/$BUILDNAME.build.failed"
test -f "$DESTLOGDIR/$BUILDNAME.autobuild.failed"
CLEAR_FAILED_ON_RESTART=1
clear_restart_build_status
test ! -e "$DESTLOGDIR/$BUILDNAME.build.failed"
test ! -e "$DESTLOGDIR/$BUILDNAME.autobuild.failed"
test -f "$DESTLOGDIR/other.build.failed"
test -f "$DESTLOGDIR/$BUILDNAME.log"
clear_restart_build_status
mkdir "$DESTLOGDIR/$BUILDNAME.build.failed"
if (clear_restart_build_status); then exit 1; fi
'''
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(['bash', '-c', script, 'test', str(ROOT), tmp], check=True)


if __name__ == '__main__':
    unittest.main()
