"""Exercise the real scheduler with small builds, without containers or mail."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / 'robot/hands/worker.sh'
spec = importlib.util.spec_from_file_location('worker', ROOT / 'robot/hands/worker.py')
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class ParallelWorker(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sales = self.root / 'sales'
        self.sales.mkdir()
        (self.sales / 'SALESDIR').touch()
        self.fake = self.root / 'build.py'
        self.fake.write_text('''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
p = Path(sys.argv[2])
start = time.monotonic()
time.sleep(0.7)
p.with_suffix('.result').write_text(json.dumps([start, time.monotonic(), os.environ['KORINF_TASK_WORKDIR']]))
p.unlink()
''')
        self.fake.chmod(0o755)
        self.env = dict(os.environ, KORINF_BUILDTASK=str(self.fake), KORINF_TASK_JOBS='2',
                        KORINF_TASK_TIMEOUT='10', KORINF_WORK_ROOT=str(self.root / 'work'))

    def task(self, name, dist, extra=''):
        task = self.sales / (name + '.task')
        task.write_text('TASKTYPE=winebuild\nDIST="' + dist + '"\n' + extra)
        return task

    def start(self):
        proc = subprocess.Popen(['sh', str(WORKER), str(self.sales)], env=self.env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.addCleanup(lambda: proc.poll() is None and proc.kill())
        return proc

    def finish(self, proc):
        _, err = proc.communicate(timeout=15)
        self.assertEqual(proc.returncode, 0, err)

    def result(self, name):
        return json.loads((self.sales / (name + '.result')).read_text())

    def wait_started(self):
        deadline = time.monotonic() + 5
        while not list(self.sales.glob('*.run')):
            self.assertLess(time.monotonic(), deadline)
            time.sleep(.02)

    def test_independent_systems_overlap_and_have_separate_workdirs(self):
        self.task('z', 'x86_64/Ubuntu/22.04')
        self.task('y', 'x86_64/RedOS/8.0', 'COMPONENTNAME=RX@Etersoft\n')
        self.finish(self.start())
        a, b = self.result('z'), self.result('y')
        self.assertLess(max(a[0], b[0]), min(a[1], b[1]))
        self.assertNotEqual(a[2], b[2])

    def test_alias_architecture_and_product_share_system_lock(self):
        self.task('z', 'x86_64/LinuxMint/21')
        self.task('y', 'i586/Ubuntu/22.04', 'COMPONENTNAME=RX@Etersoft\n')
        self.task('x', 'x86_64/RedOS/8.0')
        self.finish(self.start())
        a, b, c = (self.result(n) for n in 'zyx')
        self.assertGreaterEqual(b[0], a[1])
        self.assertLess(c[0], a[1])  # A blocked task must not block other systems.

    def test_limit_one(self):
        self.env['KORINF_TASK_JOBS'] = '1'
        self.task('z', 'Ubuntu/22.04')
        self.task('y', 'RedOS/8.0')
        self.finish(self.start())
        self.assertGreaterEqual(self.result('y')[0], self.result('z')[1])

    def test_personal_task_is_exclusive(self):
        (self.sales / 'z.task').write_text('DIST=Ubuntu/22.04\n')
        self.task('y', 'RedOS/8.0')
        self.finish(self.start())
        self.assertGreaterEqual(self.result('y')[0], self.result('z')[1])

    def test_two_workers_do_not_claim_same_task(self):
        self.task('z', 'Ubuntu/22.04')
        first = self.start()
        self.wait_started()
        self.finish(self.start())
        self.finish(first)
        self.assertTrue((self.sales / 'z.result').exists())

    def test_surviving_build_keeps_queue_lock_after_scheduler_death(self):
        self.task('z', 'Ubuntu/22.04')
        first = self.start()
        self.wait_started()
        first.kill()
        first.wait()
        self.task('y', 'RedOS/8.0')
        self.finish(self.start())
        self.assertFalse((self.sales / 'y.result').exists())
        deadline = time.monotonic() + 5
        while not (self.sales / 'z.result').exists():
            self.assertLess(time.monotonic(), deadline)
            time.sleep(.05)
        time.sleep(.1)
        self.finish(self.start())
        self.assertTrue((self.sales / 'y.result').exists())
        first.stderr.close()

    def test_stop_drains_active_and_leaves_pending(self):
        self.env['KORINF_TASK_JOBS'] = '1'
        self.task('z', 'Ubuntu/22.04')
        self.task('y', 'RedOS/8.0')
        proc = self.start()
        self.wait_started()
        (self.sales / 'STOP').touch()
        self.finish(proc)
        self.assertTrue((self.sales / 'z.result').exists())
        self.assertTrue((self.sales / 'y.task').exists())

    def test_new_task_uses_free_slot(self):
        self.task('z', 'Ubuntu/22.04')
        proc = self.start()
        self.wait_started()
        self.task('y', 'RedOS/8.0')
        self.finish(proc)
        self.assertLess(self.result('y')[0], self.result('z')[1])

    def test_stale_marker_is_interrupted(self):
        task = self.task('z', 'Ubuntu/22.04')
        Path(str(task) + '.run').write_text('999999999\n')
        self.finish(self.start())
        self.assertTrue(Path(str(task) + '.interrupted').exists())
        self.assertFalse(Path(str(task) + '.run').exists())

    def test_invalid_selector_takes_exclusive_lock(self):
        self.assertIsNone(worker.resource(self.task('z', 'x86_64/all')))


if __name__ == '__main__':
    unittest.main()
