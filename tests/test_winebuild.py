"""winebuild robot tasks with a fake bootstrap: no real build or queue is touched."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TASKID = '20261007120000.B01D-0000.abcdefghij'

SUCCESS = """\
> ./eepm.sh x86_64/ALTLinux/p10 11-testing -b
    * [22:33:53] eepm is up-to-date ... [ SKIP ]
> ./wine-etersoft.sh x86_64/ALTLinux/p10 11-testing -b
Build /var/ftp/pub/Etersoft/WINE@Etersoft/11-testing/sources/wine-etersoft-11.6.13-eter1.src.rpm package
    * [22:33:54] build in hasher p10 ...
hasher output
(568 secs) [ DONE ]
    * [22:43:22] copying to FTP dir ... (7 secs) [ DONE ]
> ./wine32-etersoft.sh i586/ALTLinux/p10 11-testing -b
    * [22:44:12] build in hasher p10 ... (535 secs) [ DONE ]
"""

FAILURE = """\
> ./wine-etersoft.sh x86_64/ALTLinux/p10 11-testing -b
    * [22:03:40] build in hasher p10 ... (89 secs) [FAILED]
> ./wine-etersoft-local.sh x86_64/ALTLinux/p10 11-testing -f
    * [22:04:00] wine-etersoft-local is up-to-date ... [ SKIP ]
"""


class WineBuild(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.sales = self.root / 'sales'
        self.sales.mkdir()
        self.home = self.root / 'home'
        self.home.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def run_task(self, task_text, output='', rc=0):
        task = self.sales / (TASKID + '.task')
        task.write_text(task_text)
        fake = self.root / 'bootstrap.sh'
        (self.root / 'output').write_text(output)
        fake.write_text(f'#!/bin/sh\necho "$@" > {self.root}/args\npwd > {self.root}/cwd\ncat {self.root}/output\nexit {rc}\n')
        fake.chmod(0o755)
        script = f"""
            AROBOTDIR={ROOT}/robot
            . {ROOT}/share/eterbuild/korinf/taskfield
            . {ROOT}/robot/funcs/genericbuild
            . {ROOT}/robot/funcs/winebuild
            run_wine_build_task {task}
        """
        env = dict(os.environ, HOME=str(self.home), WINEBUILD_BOOTSTRAP=str(fake))
        return subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True)

    def progress(self):
        lines = (self.sales / 'winebuild' / (TASKID + '.progress')).read_text().splitlines()
        return [line.split('\t') for line in lines]

    def task(self, version='11-testing', dist='x86_64/ALTLinux/p10', extra=''):
        return (f'TASKTYPE=winebuild\nCOMPONENTNAME="WINE@Etersoft"\n'
                f'PROJECTVERSION="{version}"\nDIST="{dist}"\n{extra}')

    def test_success(self):
        result = self.run_task(self.task(), SUCCESS)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / 'done' / (TASKID + '.done')).exists())
        self.assertEqual((self.root / 'args').read_text().split(), ['--nostop', '--init', 'x86_64/ALTLinux/p10', '11-testing'])
        events = self.progress()
        self.assertEqual(events[0][0], 'start')
        self.assertEqual([e[2:] for e in events if e[0] == 'stage'],
                         [['eepm', 'x86_64/ALTLinux/p10', 'build'], ['wine-etersoft', 'x86_64/ALTLinux/p10', 'build'],
                          ['wine32-etersoft', 'i586/ALTLinux/p10', 'build']])
        self.assertEqual([e[2:] for e in events if e[0] == 'result'],
                         [['eepm', 'skipped'], ['wine-etersoft', 'ok'], ['wine32-etersoft', 'ok']])
        # the source package of a stage follows its stage and command events
        index = [e[0] for e in events].index('source')
        self.assertEqual(events[index - 2][2], 'wine-etersoft')
        self.assertEqual(events[index][2:], ['wine-etersoft-11.6.13-eter1.src.rpm'])
        self.assertEqual(sum(e[0] == 'source' for e in events), 1)
        # the korinf command of each stage
        self.assertEqual([e[2:] for e in events if e[0] == 'command'],
                         [['./eepm.sh x86_64/ALTLinux/p10 11-testing -b'],
                          ['./wine-etersoft.sh x86_64/ALTLinux/p10 11-testing -b'],
                          ['./wine32-etersoft.sh i586/ALTLinux/p10 11-testing -b']])
        steps = [e[2:] for e in events if e[0] == 'step']
        self.assertIn(['DONE', 'build in hasher p10 (568 s)'], steps)
        self.assertEqual(events[-1][0], 'end')
        self.assertEqual(events[-1][2], '0')
        log = (self.sales / 'winebuild' / (TASKID + '.log')).read_text()
        self.assertIn('hasher output', log)

    def test_phases(self):
        # --init: each package first gets its build requirements (-i), then is built (-b)
        output = ('> ./eepm.sh x86_64/ALTLinux/p10 11-testing -i\n'
                  '    * [11:58:27] install build requires only ... (5 secs) [ DONE ]\n'
                  '> ./eepm.sh x86_64/ALTLinux/p10 11-testing -b\n'
                  '    * [11:58:28] eepm is up-to-date ... [ SKIP ]\n'
                  '> ./eepm.sh x86_64/ALTLinux/p10 11-testing\n')
        self.run_task(self.task(), output)
        self.assertEqual([e[2:] for e in self.progress() if e[0] == 'stage'],
                         [['eepm', 'x86_64/ALTLinux/p10', 'init'], ['eepm', 'x86_64/ALTLinux/p10', 'build'],
                          ['eepm', 'x86_64/ALTLinux/p10']])

    def test_failed_stage(self):
        result = self.run_task(self.task(), FAILURE)
        self.assertNotEqual(result.returncode, 0)
        failed = self.sales / (TASKID + '.task.failed')
        self.assertTrue(failed.exists())
        self.assertIn('(Error: build WINE@Etersoft 11-testing x86_64/ALTLinux/p10: failed wine-etersoft, exit 0)',
                      failed.read_text())
        self.assertEqual([e[2:] for e in self.progress() if e[0] == 'result'],
                         [['wine-etersoft', 'failed'], ['wine-etersoft-local', 'skipped']])

    def test_bootstrap_exit_code(self):
        result = self.run_task(self.task(), 'Error: unknown version\n', rc=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('exit 1)', (self.sales / (TASKID + '.task.failed')).read_text())
        self.assertEqual(self.progress()[-1][2], '1')

    def test_force(self):
        self.run_task(self.task(extra='FORCE=1\n'), SUCCESS)
        self.assertEqual((self.root / 'args').read_text().split()[:2], ['--nostop', '--force'])

    def test_restart_starts_progress_anew(self):
        self.run_task(self.task(), FAILURE)
        os.rename(self.sales / (TASKID + '.task.failed'), self.sales / (TASKID + '.task'))
        task = (self.sales / (TASKID + '.task')).read_text()
        self.run_task(task, SUCCESS)
        events = self.progress()
        self.assertEqual(sum(1 for e in events if e[0] == 'start'), 1)
        self.assertNotIn(['wine-etersoft', 'failed'], [e[2:] for e in events if e[0] == 'result'])

    def test_runs_in_the_script_directory(self):
        self.run_task(self.task(), SUCCESS)
        self.assertEqual((self.root / 'cwd').read_text().strip(), str(self.root))

    def test_product_bootstrap(self):
        for product, script in (('WINE@Etersoft', 'bin-wine/wine-etersoft-bootstrap-new.sh'),
                                ('RX@Etersoft', 'bin-rx/build-rx-bootstrap-new.sh'),
                                ('CRYPTO@Etersoft', 'bin-crypto/crypto-bootstrap-new.sh'),
                                ('SELTA@Etersoft', 'bin-selta/selta-bootstrap-new.sh')):
            with self.subTest(product=product):
                out = subprocess.run(['bash', '-c', f'AROBOTDIR={ROOT}/robot; . {ROOT}/robot/funcs/winebuild; '
                                      f'winebuild_bootstrap {product}'],
                                     env={k: v for k, v in os.environ.items() if k != 'WINEBUILD_BOOTSTRAP'},
                                     capture_output=True, text=True).stdout.strip()
                self.assertEqual(os.path.realpath(out), str(ROOT / script))
                self.assertTrue(os.access(out, os.X_OK))

    def test_unknown_product(self):
        task = self.task().replace('WINE@Etersoft', 'LINUX@Etersoft')
        env_free = self.run_task_env(task)
        self.assertNotEqual(env_free.returncode, 0)
        self.assertTrue((self.sales / (TASKID + '.task.broken')).exists())

    def run_task_env(self, task_text):
        """run_task without the WINEBUILD_BOOTSTRAP override"""
        task = self.sales / (TASKID + '.task')
        task.write_text(task_text)
        script = f"""
            AROBOTDIR={ROOT}/robot
            . {ROOT}/share/eterbuild/korinf/taskfield
            . {ROOT}/robot/funcs/genericbuild
            . {ROOT}/robot/funcs/winebuild
            run_wine_build_task {task}
        """
        env = {k: v for k, v in os.environ.items() if k != 'WINEBUILD_BOOTSTRAP'}
        env['HOME'] = str(self.home)
        return subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True)

    def test_product_versions(self):
        for version in ('1.10', 'unstable', '0.5-9'):
            with self.subTest(version=version):
                result = self.run_task(self.task(version=version), SUCCESS)
                self.assertEqual(result.returncode, 0, result.stderr)
                os.rename(self.home / 'done' / (TASKID + '.done'), self.home / 'done' / (version + '.done'))

    def test_invalid_fields(self):
        for version, dist in (('11-testing', 'all'), ('11-testing', '-x/y'), ('../x', 'x86_64/ALTLinux/p10')):
            with self.subTest(version=version, dist=dist):
                result = self.run_task(self.task(version, dist), SUCCESS)
                self.assertNotEqual(result.returncode, 0)
                broken = self.sales / (TASKID + '.task.broken')
                self.assertTrue(broken.exists())
                broken.unlink()
                self.assertFalse((self.root / 'args').exists())


if __name__ == '__main__':
    unittest.main()
