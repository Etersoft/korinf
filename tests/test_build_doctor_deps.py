import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'buildapi'))
import doctor_deps as deps
import taskreader as tr


class DependencyTests(unittest.TestCase):
    def test_missing_formats_and_untrusted_names(self):
        text = ('No match for argument: libavcodec62\nE: Unable to locate package libfoo\n'
                'nothing provides libbar\nPackage libbaz has no installation candidate\n'
                'No match for argument: $(touch/tmp/x)\n')
        self.assertEqual(deps.missing_packages(text), ['libavcodec62', 'libbar', 'libbaz', 'libfoo'])

    def test_source_exact_package_and_architecture(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            directory = root / 'x86_64/ALTLinux/Sisyphus/log'
            directory.mkdir(parents=True)
            exact = directory / 'wine-etersoft.rpm.depends'
            exact.touch()
            (directory / 'wine-etersoft-gecko.rpm.depends').touch()
            records = [dict(path=str(root / 'x86_64/RedOS/7.3/log/wine-etersoft.log.xz'))]
            self.assertEqual(deps.source_files(records, 'x86_64/RedOS/7.3', 'wine-etersoft'), [exact])
            self.assertEqual(deps.source_files(records, 'RedOS/7.3', 'wine32-etersoft'), [])

    def test_source_symlink_alias_retains_logical_target(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            directory = root / 'x86_64/ALTLinux/Sisyphus/log'
            directory.mkdir(parents=True)
            exact = directory / 'wine-etersoft.rpm.depends'
            exact.touch()
            log = root / 'x86_64/Ubuntu/22.04/log/wine-etersoft.log'
            log.parent.mkdir(parents=True)
            log.touch()
            alias = root / 'x86_64/LinuxMint/21'
            alias.parent.mkdir()
            alias.symlink_to('../Ubuntu/22.04', target_is_directory=True)
            records = [dict(path=str((alias / 'log/wine-etersoft.log').resolve()),
                            target='WINE/x86_64/LinuxMint/21')]
            self.assertEqual(deps.source_files(records, 'x86_64/LinuxMint/21', 'wine-etersoft'), [exact])
            self.assertEqual(deps.source_files(records, 'LinuxMint/21', 'wine32-etersoft'), [])

    def test_report_missing_source_and_failed_stage_only(self):
        task = tr.Task('id', 'failed', '', fields=dict(DIST='x86_64/RedOS/7.3'),
                       failures=[('unknown', "Can't rebuild wine-etersoft component")])
        records = [dict(path='/not/a/log', mtime=0)]
        text = ('STEP * old\nNo match for argument: old\n[ DONE ]\n'
                'STEP * test requirements\nNo match for argument: libavcodec62\n[ FAILED ]\n'
                'STEP * cleanup\nNo match for argument: ignored\n')
        with patch('doctor.discover_logs', return_value=records), \
             patch('doctor.read_log', return_value=(text, False)), \
             patch.object(deps, 'source_files', return_value=[]), \
             patch.object(deps, 'convert', return_value=([], [])) as convert:
            report = deps.report(task)
        self.assertEqual(report['missing'], ['libavcodec62'])
        self.assertIn('source_warning', report)
        self.assertEqual(report['logs'][0]['time_relation'], 'unknown')
        convert.assert_called_once_with('x86_64/RedOS/7.3', 'wine-etersoft', ['libavcodec62'])

    def test_probe_requires_explicit_module_before_work(self):
        with self.assertRaisesRegex(ValueError, '--module'):
            deps.report(None, query=True)


if __name__ == '__main__':
    unittest.main()
