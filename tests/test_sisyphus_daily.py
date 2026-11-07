import concurrent.futures
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'buildapi'))
import products
import sisyphus
import systembuild


class DailySisyphus(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sales = self.root / 'sales'
        self.sales.mkdir()
        (self.sales / 'SALESDIR').touch()
        self.patch = patch.object(systembuild, 'ETERSOFT_PUB', self.root / 'pub')
        self.patch.start()
        self.addCleanup(self.patch.stop)
        for product in products.names():
            root = systembuild.ETERSOFT_PUB / product
            (root / '1.2').mkdir(parents=True)
            (root / 'stable').symlink_to('1.2')
            (root / 'version.list').write_text('Stable:\tstable\nAlias:\t1.2\n')
            (root / '1.2' / 'distro.list').write_text('x86_64/ALTLinux/Sisyphus\n')

    def test_all_products_aliases_and_companions(self):
        jobs = sisyphus.plan()
        self.assertEqual(len(jobs), 5)
        self.assertEqual({j['version'] for j in jobs}, {'1.2'})
        self.assertEqual([j['dist'] for j in jobs if j['product'] == 'RX@Etersoft'],
                         ['x86_64/ALTLinux/Sisyphus', 'ALTLinux/Sisyphus'])
        # noarch packages: no separate i586 build
        self.assertEqual([j['dist'] for j in jobs if j['product'] == 'SELTA@Etersoft'],
                         ['x86_64/ALTLinux/Sisyphus'])

    def test_force_once_per_day_and_active_next_day(self):
        sisyphus.submit(self.sales, '2026-10-17')
        tasks = list(self.sales.glob('*.task'))
        self.assertEqual(len(tasks), 5)
        self.assertTrue(all('FORCE=1\n' in p.read_text() for p in tasks))
        sisyphus.submit(self.sales, '2026-10-18')
        self.assertEqual(len(list(self.sales.glob('*.task'))), 5)
        for p in tasks:
            p.rename(str(p) + '.failed')
        sisyphus.submit(self.sales, '2026-10-18')
        self.assertEqual(len(list(self.sales.glob('*.task'))), 0)
        sisyphus.submit(self.sales, '2026-10-19')
        self.assertEqual(len(list(self.sales.glob('*.task'))), 0)
        self.assertEqual(len(list(self.sales.glob('*.task.failed'))), 5)
        for p in self.sales.glob('*.task.failed'):
            p.rename(p.with_suffix('.done'))
        sisyphus.submit(self.sales, '2026-10-20')
        self.assertEqual(len(list(self.sales.glob('*.task'))), 5)

    def test_forced_daily_task_follows_nonforced_active_task(self):
        existing = systembuild.enqueue('1.2', 'x86_64/ALTLinux/Sisyphus', False,
                                       str(self.sales), '20261017000000.B01D-0000.0000000000',
                                       'WINE@Etersoft')
        sisyphus.submit(self.sales, '2026-10-17')
        self.assertEqual(len(list(self.sales.glob('*.task'))), 6)
        self.assertNotIn('FORCE=1', Path(existing['new_path']).read_text())
        forced = systembuild.find_active(str(self.sales), '1.2', 'x86_64/ALTLinux/Sisyphus',
                                         'WINE@Etersoft', force=True)
        self.assertEqual(forced.fields['FORCE'], '1')
        self.assertNotEqual(forced.taskid, existing['taskid'])
        sisyphus.submit(self.sales, '2026-10-18')
        self.assertEqual(len(list(self.sales.glob('*.task'))), 6)

    def test_i586_system_alias_reuses_active_task(self):
        root = systembuild.ETERSOFT_PUB / 'RX@Etersoft' / '1.2'
        (root / 'distro.list').write_text('ALTLinux/Sisyphus\ni586/ALTLinux/Sisyphus\n')
        first = systembuild.enqueue('1.2', 'i586/ALTLinux/Sisyphus', True,
                                   str(self.sales), '20261017000000.B01D-0000.0000000000', 'RX@Etersoft')
        second = systembuild.enqueue('1.2', 'ALTLinux/Sisyphus', True,
                                    str(self.sales), '20261017000000.B01D-0000.0000000001', 'RX@Etersoft')
        self.assertTrue(second['existing'])
        self.assertEqual(second['taskid'], first['taskid'])

    def test_failed_alias_blocks_only_matching_daily_architecture(self):
        root = systembuild.ETERSOFT_PUB / 'RX@Etersoft' / '1.2'
        (root / 'distro.list').write_text('x86_64/ALTLinux/Sisyphus\ni586/ALTLinux/Sisyphus\n')
        first = systembuild.enqueue('stable', 'i586/ALTLinux/Sisyphus', False,
                                   str(self.sales), '20261017000000.B01D-0000.0000000000', 'RX@Etersoft')
        path = Path(first['new_path'])
        path.rename(str(path) + '.failed')
        sisyphus.submit(self.sales, '2026-10-18')
        tasks = [p.read_text() for p in self.sales.glob('*.task')]
        rx = [text for text in tasks if 'COMPONENTNAME="RX@Etersoft"' in text]
        self.assertEqual(len(rx), 1)
        self.assertIn('DIST="x86_64/ALTLinux/Sisyphus"', rx[0])
        self.assertEqual(len(list(self.sales.glob('*.task.failed'))), 1)
        # Manual requests remain an explicit retry, even for the failed alias.
        retry = systembuild.enqueue('1.2', 'i586/ALTLinux/Sisyphus', True,
                                   str(self.sales), '20261018000000.B01D-0000.0000000000', 'RX@Etersoft')
        self.assertFalse(retry['existing'])

    def test_concurrent_alias_submissions_are_deduplicated(self):
        def enqueue(i):
            return systembuild.enqueue('stable' if i % 2 else '1.2', 'x86_64/ALTLinux/Sisyphus',
                                       True, str(self.sales), f'20261017000000.B01D-0000.{i:010}', 'WINE@Etersoft')
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(enqueue, range(8)))
        self.assertEqual(sum(not r['existing'] for r in results), 1)
        self.assertEqual(len(list(self.sales.glob('*.task'))), 1)

    def test_all_sisyphus_tasks_share_worker_resource(self):
        import importlib.util
        path = Path(__file__).resolve().parents[1] / 'robot/hands/worker.py'
        spec = importlib.util.spec_from_file_location('worker', path)
        worker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(worker)
        keys = set()
        for i, job in enumerate(sisyphus.plan()):
            task = self.sales / f'{i}.task'
            task.write_text(f'TASKTYPE=winebuild\nCOMPONENTNAME="{job["product"]}"\n'
                            f'PROJECTVERSION="{job["version"]}"\nDIST="{job["dist"]}"\n')
            keys.add(worker.resource(task))
        self.assertEqual(keys, {'ALTLinux/Sisyphus'})

    def test_companion_exception_is_narrow(self):
        with self.assertRaises(systembuild.BuildError):
            systembuild.enqueue('1.2', 'ALTLinux/p10', True, str(self.sales),
                                '20261017000000.B01D-0000.0000000000', 'RX@Etersoft', sisyphus_companion=True)


if __name__ == '__main__':
    unittest.main()
