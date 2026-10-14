"""Development-source publication must never write into stable releases."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'buildapi'))
import source_updates as su


class SourceUpdates(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.source = root / 'Korinf/sources'
        self.wine = root / 'WINE'
        self.private = root / 'PRIVATE'
        self.private.mkdir()
        self.generated = root / 'generated.sh'
        self.generated.write_text('#!/bin/bash\nexport EPMVERSION="3.64.69"\n')
        self.source.mkdir(parents=True)
        self.wine.mkdir()
        for branch in ('11-testing', '11-unstable', '11.6'):
            (self.wine / branch / 'sources').mkdir(parents=True)
            (self.private / branch / 'docs').mkdir(parents=True)
            (self.private / branch / 'docs/wine-etersoft-install.sh').write_text('old installer')
        self.pkg = self.source / 'eepm-3.64.69-alt1.src.rpm'
        self.pkg.write_bytes(b'unchanged source RPM fixture')
        self.old = 'eepm-3.64.9-alt1.src.rpm'
        (self.source / self.old).write_bytes(b'old source')
        for branch in ('11-testing', '11-unstable', '11.6'):
            (self.wine / branch / 'sources' / self.old).write_bytes(b'old source')
        def fixture_packages(directory):
            rows = []
            for path in sorted(directory.glob('eepm-*.src.rpm')):
                fields = path.name.split('-')
                rows.append({'path': path, 'evr': (0, fields[1], fields[2][:-8])})
            return rows
        def fixture_compare(a, b):
            # Native rpm metadata/comparison is tested separately; fixture versions are numeric.
            left = tuple(map(int, a['evr'][1].split('.')))
            right = tuple(map(int, b['evr'][1].split('.')))
            return (left > right) - (left < right)
        self.snapshot = {'commit': 'a' * 40, 'files': {'script': 'hash'}}
        self.work = root / 'work'
        self.db = self.work / 'eget-winetricks.db'
        self.manifest = self.work / 'eget-winetricks.db.manifest'

        def fixture_build(source_path, source_sha256, branch, **kwargs):
            self.docs_dir = kwargs.get('docs_dir')
            self.work.mkdir(exist_ok=True)
            self.db.write_text('new db\n')
            self.manifest.write_text('manifest_complete=1\n')
            return {'path': str(self.generated), 'sha256': su.digest(self.generated),
                    'epm_version': '3.64.69', 'generator_commit': self.snapshot['commit'],
                    'generator_files': self.snapshot['files'], 'branch': branch,
                    'source_sha256': source_sha256, 'work_dir': str(self.work),
                    'ipfs_db': {p.name: {'path': str(p), 'sha256': su.digest(p)}
                                for p in (self.db, self.manifest)}}
        for patcher in (patch.object(su, 'SOURCE_ROOT', self.source),
                        patch.object(su, 'PRIVATE_ROOT', self.private),
                        patch.object(su, 'LOCK_FILE', root / 'update.lock'),
                        patch.object(su.epm_installer, 'snapshot_info', return_value=self.snapshot),
                        patch.object(su.epm_installer, 'build_installer', side_effect=fixture_build),
                        patch.object(su, 'WINE_ROOT', self.wine),
                        patch.object(su, 'packages', side_effect=fixture_packages),
                        patch.object(su, 'compare', side_effect=fixture_compare)):
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_preview_selects_latest_and_does_not_write(self):
        plan = su.preview()
        self.assertEqual(plan['source']['name'], self.pkg.name)
        self.assertEqual({r['name'] for r in plan['branches']}, {'11-testing', '11-unstable'})
        self.assertFalse((self.wine / '11-testing/sources' / self.pkg.name).exists())

    def test_copy_is_identical_keeps_old_and_stable_and_is_idempotent(self):
        plan = su.preview(['11-testing'])
        result = su.apply(['11-testing'], plan['preview_token'])
        self.assertEqual(result['results'][0]['status'], 'copied')
        copied = self.wine / '11-testing/sources' / self.pkg.name
        self.assertEqual(copied.read_bytes(), self.pkg.read_bytes())
        self.assertEqual((self.wine / '11-testing/sources' / self.old).read_bytes(), b'old source')
        self.assertFalse((self.wine / '11.6/sources' / self.pkg.name).exists())
        self.assertFalse((self.wine / '11-unstable/sources' / self.pkg.name).exists())
        plan = su.preview(['11-testing'])
        self.assertEqual(su.apply(['11-testing'], plan['preview_token'])['results'][0]['status'], 'unchanged')

    def test_stable_and_traversal_are_rejected(self):
        for branch in ('11.6', '../11-testing', '/tmp', '11-testing/../../11.6'):
            with self.subTest(branch=branch), self.assertRaises(su.SourceUpdateError):
                su.preview([branch])

    def test_development_alias_to_stable_is_blocked(self):
        (self.wine / '12-testing').symlink_to(self.wine / '11.6', target_is_directory=True)
        plan = su.preview(['12-testing'])
        selected = [r for r in plan['branches'] if r['selected']][0]
        self.assertEqual(selected['action'], 'blocked')
        with self.assertRaises(su.SourceUpdateError):
            su.apply(['12-testing'], plan['preview_token'])
        self.assertFalse((self.wine / '11.6/sources' / self.pkg.name).exists())

    def test_shared_sources_with_stable_are_blocked(self):
        folder = self.wine / '12-testing'
        folder.mkdir()
        (folder / 'sources').symlink_to(self.wine / '11.6/sources', target_is_directory=True)
        plan = su.preview(['12-testing'])
        with self.assertRaises(su.SourceUpdateError):
            su.apply(['12-testing'], plan['preview_token'])

    def test_source_or_selection_change_invalidates_preview(self):
        plan = su.preview(['11-testing'])
        with self.assertRaises(su.SourceUpdateError):
            su.apply(['11-unstable'], plan['preview_token'])
        self.pkg.write_bytes(b'replaced source')
        with self.assertRaises(su.SourceUpdateError):
            su.apply(['11-testing'], plan['preview_token'])

    def test_conflicting_file_and_downgrade_block_entire_batch(self):
        target = self.wine / '11-unstable/sources' / self.pkg.name
        target.write_bytes(b'different payload')
        plan = su.preview(['11-testing', '11-unstable'])
        with self.assertRaises(su.SourceUpdateError):
            su.apply(['11-testing', '11-unstable'], plan['preview_token'])
        self.assertFalse((self.wine / '11-testing/sources' / self.pkg.name).exists())
        target.unlink()
        (target.parent / 'eepm-3.64.70-alt1.src.rpm').write_bytes(b'newer')
        plan = su.preview(['11-unstable'])
        self.assertEqual([r for r in plan['branches'] if r['selected']][0]['action'], 'blocked')

    def test_existing_selected_source_does_not_allow_installer_downgrade(self):
        dest = self.wine / '11-testing/sources'
        (dest / self.pkg.name).write_bytes(self.pkg.read_bytes())
        (dest / 'eepm-3.64.70-alt1.src.rpm').write_bytes(b'newer branch source')
        before = (self.private / '11-testing/docs/wine-etersoft-install.sh').read_bytes()
        plan = su.preview(['11-testing'])
        selected = next(row for row in plan['branches'] if row['selected'])
        self.assertEqual(selected['action'], 'blocked')
        with patch.object(su.epm_installer, 'build_installer') as build:
            with self.assertRaises(su.SourceUpdateError):
                su.apply(['11-testing'], plan['preview_token'])
        build.assert_not_called()
        self.assertEqual((self.private / '11-testing/docs/wine-etersoft-install.sh').read_bytes(), before)
        self.assertEqual((dest / self.pkg.name).read_bytes(), self.pkg.read_bytes())
        self.assertEqual((dest / 'eepm-3.64.70-alt1.src.rpm').read_bytes(), b'newer branch source')

    def test_empty_selection_is_preview_only(self):
        plan = su.preview([])
        self.assertFalse(any(r['selected'] for r in plan['branches']))
        with self.assertRaises(su.SourceUpdateError):
            su.apply([], plan['preview_token'])

    def test_installer_atomic_replace_preserves_stable_hardlink(self):
        target = self.private / '11-testing/docs/wine-etersoft-install.sh'
        stable = self.private / '11.6/docs/wine-etersoft-install.sh'
        target.unlink()
        os.link(stable, target)
        plan = su.preview(['11-testing'])
        result = su.apply(['11-testing'], plan['preview_token'])
        self.assertEqual(stable.read_text(), 'old installer')
        self.assertEqual(target.read_bytes(), self.generated.read_bytes())
        self.assertNotEqual(stable.stat().st_ino, target.stat().st_ino)
        self.assertEqual(result['results'][0]['installer']['status'], 'updated')

    def test_ipfs_db_is_published_beside_the_installer_and_work_is_removed(self):
        docs = self.private / '11-testing/docs'
        stable = self.private / '11.6/docs/eget-winetricks.db'
        stable.write_text('old db\n')
        os.link(stable, docs / 'eget-winetricks.db')
        plan = su.preview(['11-testing'])
        self.assertEqual(plan['branches'][0]['installer']['ipfs_db']['current_sha256'],
                         {'eget-winetricks.db': su.digest(stable), 'eget-winetricks.db.manifest': None})
        self.assertIsNone(plan['branches'][0]['installer']['ipfs_db']['winetricks_current'])
        result = su.apply(['11-testing'], plan['preview_token'])
        self.assertEqual(self.docs_dir, docs)
        self.assertEqual((docs / 'eget-winetricks.db').read_text(), 'new db\n')
        self.assertEqual((docs / 'eget-winetricks.db.manifest').read_text(), 'manifest_complete=1\n')
        self.assertEqual(stable.read_text(), 'old db\n')
        self.assertEqual(result['results'][0]['installer']['ipfs_db'],
                         {'eget-winetricks.db': 'updated', 'eget-winetricks.db.manifest': 'updated'})
        self.assertFalse(self.work.exists())

    def test_ipfs_db_current_for_its_winetricks_package(self):
        docs = self.private / '11-testing/docs'
        rpm = self.wine / 'winetricks.noarch.rpm'
        rpm.write_bytes(b'winetricks')
        manifest = docs / 'eget-winetricks.db.manifest'
        manifest.write_text(f'winetricks_rpm={rpm}\nwinetricks_rpm_sha256={su.digest(rpm)}\nmanifest_complete=1\n')
        self.assertTrue(su.ipfs_db_current(docs))
        rpm.write_bytes(b'new winetricks')
        self.assertFalse(su.ipfs_db_current(docs))

    def test_changed_ipfs_db_invalidates_preview(self):
        plan = su.preview(['11-testing'])
        (self.private / '11-testing/docs/eget-winetricks.db').write_text('concurrent db')
        with self.assertRaises(su.SourceUpdateError):
            su.apply(['11-testing'], plan['preview_token'])

    def test_generator_failure_does_not_publish_source(self):
        plan = su.preview(['11-testing'])
        with patch.object(su.epm_installer, 'build_installer', side_effect=ValueError('generator failed')):
            with self.assertRaises(su.SourceUpdateError):
                su.apply(['11-testing'], plan['preview_token'])
        self.assertFalse((self.wine / '11-testing/sources' / self.pkg.name).exists())
        self.assertEqual((self.private / '11-testing/docs/wine-etersoft-install.sh').read_text(), 'old installer')

    def test_stable_docs_alias_is_blocked(self):
        docs = self.private / '11-testing/docs'
        (docs / 'wine-etersoft-install.sh').unlink()
        docs.rmdir()
        docs.symlink_to(self.private / '11.6/docs', target_is_directory=True)
        plan = su.preview(['11-testing'])
        with self.assertRaises(su.SourceUpdateError):
            su.apply(['11-testing'], plan['preview_token'])

    def test_installer_publish_failure_rolls_back_new_source(self):
        plan = su.preview(['11-testing'])
        with patch.object(su.os, 'replace', side_effect=OSError('rename failed')):
            result = su.apply(['11-testing'], plan['preview_token'])
        self.assertEqual(result['results'][0]['status'], 'failed')
        self.assertFalse((self.wine / '11-testing/sources' / self.pkg.name).exists())
        self.assertEqual((self.private / '11-testing/docs/wine-etersoft-install.sh').read_text(), 'old installer')

    def test_changed_installer_invalidates_preview(self):
        plan = su.preview(['11-testing'])
        (self.private / '11-testing/docs/wine-etersoft-install.sh').write_text('concurrent update')
        with self.assertRaises(su.SourceUpdateError):
            su.apply(['11-testing'], plan['preview_token'])


class PackageMetadata(unittest.TestCase):
    def test_rejects_binary_or_wrong_name_and_ignores_subpackages(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'eepm-3.64.69-alt1.src.rpm').touch()
            (root / 'eepm-apt-1-alt1.src.rpm').touch()
            for line in ('eepm|0|3.64.69|alt1|0\n', 'other|0|3.64.69|alt1|1\n'):
                result = subprocess.CompletedProcess([], 0, line, '')
                with patch.object(su.subprocess, 'run', return_value=result), self.assertRaises(su.SourceUpdateError):
                    su.packages(root)
            result = subprocess.CompletedProcess([], 0, 'eepm|(none)|3.64.69|alt1|1\n', '')
            with patch.object(su.subprocess, 'run', return_value=result) as run:
                self.assertEqual(su.packages(root)[0]['evr'], (0, '3.64.69', 'alt1'))
                self.assertNotIn(str(root / 'eepm-apt-1-alt1.src.rpm'), run.call_args.args[0])

if __name__ == '__main__':
    unittest.main()
