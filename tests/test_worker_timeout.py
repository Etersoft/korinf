"""Robot worker time limit per task, with a fake build task script."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TASKID = '20261007120000.B01D-0000.abcdefghij'


class WorkerTimeout(unittest.TestCase):
    def run_worker(self, body):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            sales = tmp / 'sales'
            sales.mkdir()
            (sales / 'SALESDIR').touch()
            task = sales / (TASKID + '.task')
            task.write_text('TASKTYPE=winebuild\n')
            fake = tmp / 'buildtask.sh'
            fake.write_text('#!/bin/sh\n' + body)
            fake.chmod(0o755)
            env = dict(os.environ, KORINF_TASK_TIMEOUT='1', KORINF_BUILDTASK=str(fake))
            result = subprocess.run(['sh', str(ROOT / 'robot/hands/worker.sh'), str(sales)],
                                    env=env, capture_output=True, text=True, timeout=60)
            files = sorted(p.name for p in sales.iterdir() if p.name != 'SALESDIR')
            failed = sales / (TASKID + '.task.failed')
            return result, files, failed.read_text() if failed.exists() else ''

    def test_task_over_limit_fails(self):
        result, files, failed = self.run_worker('sleep 30\n')
        self.assertEqual(files, [TASKID + '.task.failed'], result.stdout + result.stderr)
        self.assertIn('(Error: timeout 1)', failed)

    def test_task_in_time_is_left_to_the_task(self):
        result, files, _ = self.run_worker('exit 0\n')
        self.assertEqual(files, [TASKID + '.task'], result.stdout + result.stderr)

    def test_failed_task_is_not_touched(self):
        result, files, failed = self.run_worker('mv "$2" "$2.failed"\nexit 1\n')
        self.assertEqual(files, [TASKID + '.task.failed'], result.stdout + result.stderr)
        self.assertNotIn('timeout', failed)


if __name__ == '__main__':
    unittest.main()
