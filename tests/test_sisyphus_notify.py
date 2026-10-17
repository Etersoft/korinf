import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('notify', str(ROOT / 'share/eterbuild/korinf/notify-sisyphus-failure'))
spec = importlib.util.spec_from_loader(loader.name, loader)
notify = importlib.util.module_from_spec(spec)
loader.exec_module(notify)


class Notifications(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'test-1-alt1.src.rpm'
        self.source.write_text('source')
        self.log = self.root / 'test.log'
        self.log.write_text('STEP  * build in hasher Sisyphus ...\nerror: test failure\n[FAILED]\n')
        self.calls = []
        self.author = 'Newest Author <newest@example.org> 1-alt1'
        def run(args, **kwargs):
            self.calls.append((args, kwargs))
            return subprocess.CompletedProcess(args, 0, self.author if args[0] == 'rpm' else '')
        self.mock = patch.object(notify.subprocess, 'run', side_effect=run)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def send(self, dist, **kwargs):
        return notify.notify(dist, self.source, self.log, state=self.root / 'state', **kwargs)

    def test_both_architectures_once_and_i586_alias(self):
        self.send('x86_64/ALTLinux/Sisyphus')
        self.send('ALTLinux/Sisyphus')
        self.send('i586/ALTLinux/Sisyphus')
        self.send('x86_64/ALTLinux/Sisyphus')
        mail = [call for call in self.calls if call[0][0] == 'mutt']
        self.assertEqual(len(mail), 2)
        for args, _ in mail:
            self.assertIn('set from="lav+builder@etersoft.ru" use_from=yes envelope_from=yes', args)
            self.assertIn('my_hdr Reply-To: lav+builder@etersoft.ru', args)
        self.assertTrue(all(call[0][3:5] == ['-c', 'lav@etersoft.ru'] for call in mail))
        self.assertTrue(all(call[0][-2:] == ['--', 'newest@example.org'] for call in mail))
        self.assertIn('Архитектура: x86_64', mail[0][1]['input'])
        self.assertIn('Архитектура: i586', mail[1][1]['input'])
        self.assertIn('error: test failure', mail[0][1]['input'])
        self.assertTrue(all(call[0][3] == '%{CHANGELOGNAME}' for call in self.calls if call[0][0] == 'rpm'))

    def test_other_targets_never_query_author_or_send(self):
        for dist in ['x86_64/ALTLinux/p11', 'ALTLinux/p10', 'x86_64/Ubuntu/24.04']:
            self.send(dist)
        self.assertEqual(self.calls, [])

    def test_missing_author_does_not_fall_back_to_packager(self):
        self.author = 'Author without email'
        with self.assertRaises(ValueError):
            self.send('ALTLinux/Sisyphus')
        self.assertFalse(any(call[0][0] == 'mutt' for call in self.calls))

    def test_failed_delivery_can_be_retried(self):
        original = notify.subprocess.run.side_effect
        def fail(args, **kwargs):
            if args[0] == 'mutt':
                raise subprocess.CalledProcessError(1, args)
            return original(args, **kwargs)
        notify.subprocess.run.side_effect = fail
        with self.assertRaises(subprocess.CalledProcessError):
            self.send('ALTLinux/Sisyphus')
        notify.subprocess.run.side_effect = original
        self.assertIn('submitted', self.send('ALTLinux/Sisyphus'))

    def test_dry_run_does_not_send_or_mark(self):
        self.send('ALTLinux/Sisyphus', dry_run=True)
        self.assertFalse((self.root / 'state').exists())
        self.assertFalse(any(call[0][0] == 'mutt' for call in self.calls))


if __name__ == '__main__':
    unittest.main()
