"""Pin input bytes and the generator export independently from the host checkout."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'buildapi'))
import epm_installer as ei


class Installer(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.snapshot = self.root / 'snapshot'
        self.snapshot.mkdir()
        rows = []
        for name in ei.REQUIRED:
            p = self.snapshot / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('fixture\n')
            rows.append({'path': name, 'sha256': ei.digest(p)})
        (self.snapshot / 'SNAPSHOT.json').write_text(json.dumps({
            'repo': 'https://example.invalid/generator', 'commit': 'a' * 40, 'exported_files': rows}))
        self.source = self.root / 'eepm-3.64.69-alt1.src.rpm'
        self.source.write_bytes(b'exact selected source')

    def build(self, version='3.64.69'):
        def run(args, **kw):
            if args[0] == 'rpm':
                return subprocess.CompletedProcess(args, 0, 'eepm|3.64.69|1', '')
            if args[0] == 'sh':
                self.assertEqual(Path(args[2]).read_bytes(), self.source.read_bytes())
                self.assertEqual(args[3], '11-testing')
                self.assertNotEqual(Path(args[2]), self.source)
                out = Path(kw['cwd']) / 'wine-etersoft-install.sh'
                out.write_text(f'#!/bin/bash\nexport EPMVERSION="{version}"\n')
            return subprocess.CompletedProcess(args, 0, '', '')
        with patch.object(ei.subprocess, 'run', side_effect=run):
            return ei.build_installer(self.source, ei.digest(self.source), '11-testing',
                snapshot_dir=self.snapshot, work_root=self.root)

    def test_exact_input_and_provenance_are_retained(self):
        result = self.build()
        self.assertEqual(result['source_sha256'], ei.digest(self.source))
        self.assertEqual(result['sha256'], ei.digest(result['path']))
        self.assertTrue((Path(result['work_dir']) / 'provenance.json').exists())
        self.assertEqual(self.source.read_bytes(), b'exact selected source')

    def test_wrong_embedded_epm_version_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'EPMVERSION'):
            self.build('3.64.68')

    def test_source_changed_after_preview_is_rejected_before_execution(self):
        with patch.object(ei.subprocess, 'run') as run, self.assertRaisesRegex(ValueError, 'SHA256'):
            ei.build_installer(self.source, '0' * 64, '11-testing', snapshot_dir=self.snapshot)
        run.assert_not_called()

    def test_tampered_snapshot_fails(self):
        (self.snapshot / ei.REQUIRED[0]).write_text('changed')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            ei.snapshot_info(self.snapshot)

    def test_stable_branch_rejected(self):
        with self.assertRaises(ValueError):
            ei.build_installer(self.source, ei.digest(self.source), '11.6.13', snapshot_dir=self.snapshot)


if __name__ == '__main__':
    unittest.main()
