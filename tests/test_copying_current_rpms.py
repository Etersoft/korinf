"""Publishing must not pick stale binaries from a shared hasher directory."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CurrentRpmCopying(unittest.TestCase):
    def run_copy(self, package_format='rpm', missing=False, missing_extra=False, missing_file=False, debug=False):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            built, dest = work / 'built', work / 'published'
            built.mkdir()
            dest.mkdir()
            (dest / 'keep.txt').write_text('keep')
            names = [f'wine32-etersoft{suffix}-{version}.i586.{package_format}'
                     for suffix in ('', '-devel') for version in ('10', '11')]
            for name in names:
                (built / name).write_text(name)
            current = [str(built / name) for name in names if '-10.' in name]
            if debug:
                for version in ('10', '11'):
                    name = f'wine32-etersoft-debuginfo-{version}.i586.rpm'
                    (built / name).write_text(name)
                    if version == '10':
                        current.append(str(built / name))
            if missing_extra:
                current = [p for p in current if '-devel-' not in p]
            if missing_file:
                Path(current[0]).unlink()
            if missing:
                current = []
            (dest / names[1]).write_text('previously published')
            harness = r'''
kormod() { :; }
error() { echo "$*" >&2; }
fatal() { echo "$*" >&2; exit 99; }
rhas() { [[ "$1" =~ $2 ]]; }
estrlist() { printf '%s\n' "$3"; }
copying_sources() { :; }
mark_build_done() { :; }
copying_packages
'''
            source = (ROOT / 'share/eterbuild/korinf/copying').read_text()
            import os
            env = dict(os.environ, BUILTRPM=str(built), DESTDIR=str(dest),
                       PKGFORMAT=package_format, PKGVENDOR='test',
                       BUILDNAME='wine-etersoft', TARGETSRPM='wine-etersoft-10.src.rpm',
                       BUILTBINPKGLIST=' '.join(current), ALLOWPUBLICDEBUG='1' if debug else '',
                       EXPMAINFILES=f'wine32-etersoft-[0-9]*.{package_format}',
                       EXPEXTRAFILES=f'wine32-etersoft-devel-*.{package_format}')
            result = subprocess.run(['bash'], input='kormod() { :; }\n'+source+'\n'+harness,
                                    text=True, capture_output=True, env=env)
            published = {str(p.relative_to(dest)) for p in dest.rglob('*') if p.is_file()}
            return result, published

    def test_only_current_renamed_binary_packages_are_published(self):
        result, published = self.run_copy()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(published, {'keep.txt', 'wine32-etersoft-10.i586.rpm',
                                    'extra/wine32-etersoft-devel-10.i586.rpm'})

    def test_missing_current_list_preserves_published_files(self):
        result, published = self.run_copy(missing=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('wine32-etersoft-11.i586.rpm', published)

    def test_missing_extra_match_preserves_published_files(self):
        result, published = self.run_copy(missing_extra=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('wine32-etersoft-11.i586.rpm', published)

    def test_missing_current_file_preserves_published_files(self):
        result, published = self.run_copy(missing_file=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('wine32-etersoft-11.i586.rpm', published)

    def test_debug_packages_are_scoped_to_current_source(self):
        result, published = self.run_copy(debug=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('extra/wine32-etersoft-debuginfo-10.i586.rpm', published)
        self.assertNotIn('extra/wine32-etersoft-debuginfo-11.i586.rpm', published)

    def test_non_rpm_conversion_keeps_existing_selection(self):
        result, published = self.run_copy(package_format='deb')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('wine32-etersoft-11.i586.deb', published)


if __name__ == '__main__':
    unittest.main()
