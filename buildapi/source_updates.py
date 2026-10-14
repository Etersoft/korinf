"""Publish unchanged eepm source RPMs to explicitly selected development branches."""
import argparse
import functools
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import epm_installer

LOCK_FILE = Path(__file__).with_name('source-update.lock')
SOURCE_ROOT = Path('/var/ftp/pub/Korinf/sources')
WINE_ROOT = Path('/var/ftp/pub/Etersoft/WINE@Etersoft')
PRIVATE_ROOT = Path('/var/ftp/pvt/Etersoft/WINE@Etersoft')
DEFAULT_BRANCHES = ('10-testing', '10-unstable', '11-testing', '11-unstable')
BRANCH = re.compile(r'^(?:[A-Za-z0-9][A-Za-z0-9.-]*-)?(?:testing|unstable)$')
PACKAGE = re.compile(r'^eepm-[0-9][A-Za-z0-9.+~^_-]*\.src\.rpm$')


class SourceUpdateError(Exception):
    def __init__(self, status, message):
        self.status = status
        super().__init__(message)


def digest(path):
    with path.open('rb') as stream:
        value = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
        return value.hexdigest()


def packages(directory):
    paths = sorted(p for p in directory.glob('eepm-*.src.rpm') if PACKAGE.fullmatch(p.name))
    if not paths:
        return []
    if any(p.is_symlink() or not p.is_file() for p in paths):
        raise SourceUpdateError(409, f'Ожидался обычный файл SRPM: {directory}')
    query = subprocess.run(['rpm', '-qp', '--queryformat',
        '%{NAME}|%{EPOCH}|%{VERSION}|%{RELEASE}|%{SOURCEPACKAGE}\n', *map(str, paths)],
        capture_output=True, text=True, timeout=30)
    lines = query.stdout.splitlines()
    if query.returncode or len(lines) != len(paths):
        raise SourceUpdateError(409, f'Не удалось проверить RPM в {directory}')
    result = []
    for path, line in zip(paths, lines):
        fields = line.split('|')
        if len(fields) != 5 or fields[0] != 'eepm' or fields[4] != '1':
            raise SourceUpdateError(409, f'Это не исходный пакет eepm: {path}')
        epoch = 0 if fields[1] == '(none)' else int(fields[1])
        result.append({'path': path, 'evr': (epoch, fields[2], fields[3])})
    return result


def compare(a, b):
    for left, right in zip(a['evr'], b['evr']):
        if left == right:
            continue
        if isinstance(left, int):
            return (left > right) - (left < right)
        run = subprocess.run(['rpmvercmp', left, right], capture_output=True, text=True, timeout=10)
        try:
            result = int(run.stdout.strip())
        except ValueError:
            raise SourceUpdateError(500, 'Не удалось сравнить версии через rpmvercmp')
        if result:
            return result
    return 0


def newest(rows):
    return max(rows, key=functools.cmp_to_key(compare)) if rows else None


def branch_names():
    return sorted(p.name for p in WINE_ROOT.iterdir() if BRANCH.fullmatch(p.name) and p.is_dir())


def destination(name):
    if not BRANCH.fullmatch(name):
        raise SourceUpdateError(400, f'Обновление стабильной или неизвестной ветки запрещено: {name}')
    root = WINE_ROOT.resolve()
    folder = WINE_ROOT / name
    path = folder / 'sources'
    if not path.is_dir():
        raise SourceUpdateError(404, f'Нет каталога sources у ветки {name}')
    real = path.resolve()
    if not real.is_relative_to(root):
        raise SourceUpdateError(409, f'Каталог ветки выходит за WINE: {name}')
    # A development alias must not lead to a stable release, nor share its sources.
    for other in WINE_ROOT.iterdir():
        if BRANCH.fullmatch(other.name) or not other.is_dir():
            continue
        # 'last' tracks the development channel on builder; it is not a fixed release.
        if other.name == 'last' and other.is_symlink() and BRANCH.fullmatch(other.resolve().name):
            continue
        stable = other / 'sources'
        if stable.is_dir() and (stable.resolve() == real or other.resolve() == folder.resolve()):
            raise SourceUpdateError(409, f'{name} разделяет sources со стабильной веткой {other.name}')
    return real


def installer_destination(name):
    if not BRANCH.fullmatch(name):
        raise SourceUpdateError(400, 'Installer destination must be testing/unstable')
    folder = PRIVATE_ROOT / name
    docs = folder / 'docs'
    if not docs.is_dir():
        raise SourceUpdateError(404, f'Нет каталога docs у ветки {name}')
    real = docs.resolve()
    if not real.is_relative_to(PRIVATE_ROOT.resolve()):
        raise SourceUpdateError(409, 'Каталог docs выходит за WINE')
    for other in PRIVATE_ROOT.iterdir():
        if BRANCH.fullmatch(other.name) or not other.is_dir():
            continue
        if other.name == 'last' and other.is_symlink() and BRANCH.fullmatch(other.resolve().name):
            continue
        stable = other / 'docs'
        if stable.is_dir() and (stable.resolve() == real or other.resolve() == folder.resolve()):
            raise SourceUpdateError(409, f'{name} разделяет docs со стабильной веткой {other.name}')
    target = real / 'wine-etersoft-install.sh'
    if target.is_symlink() or (target.exists() and not target.is_file()):
        raise SourceUpdateError(409, 'Installer должен быть обычным файлом: ' + str(target))
    return target


def installer_preview(name, version):
    target = installer_destination(name)
    try:
        snapshot = epm_installer.snapshot_info()
    except ValueError as error:
        raise SourceUpdateError(409, str(error)) from error
    db = {}
    for name in (epm_installer.IPFS_DB, epm_installer.IPFS_MANIFEST):
        path = target.parent / name
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise SourceUpdateError(409, 'IPFS DB должна быть обычным файлом: ' + str(path))
        db[name] = digest(path) if path.exists() else None
    return {'destination': str(target), 'epm_version': version,
            'current_sha256': digest(target) if target.exists() else None,
            'ipfs_db': {'current_sha256': db, 'winetricks_current': ipfs_db_current(target.parent)},
            'generator_commit': snapshot['commit'], 'generator_files': snapshot['files'],
            'action': 'build-and-replace'}


def ipfs_db_current(docs):
    """Whether the published IPFS DB was made for the winetricks package it names
    (then the generation is skipped); None without a manifest."""
    try:
        rows = dict(line.split('=', 1) for line in
                    (docs / epm_installer.IPFS_MANIFEST).read_text().splitlines() if '=' in line)
    except OSError:
        return None
    rpm = Path(rows.get('winetricks_rpm', ''))
    return (rows.get('manifest_complete') == '1' and rpm.is_file()
            and digest(rpm) == rows.get('winetricks_rpm_sha256'))


def _replace_file(source, target, sha256, mode):
    """Atomically replace the directory entry (a hard link to stable stays)."""
    if target.exists() and digest(target) == sha256:
        return 'unchanged'
    fd, temporary = tempfile.mkstemp(prefix='.installer-update-', dir=target.parent)
    try:
        with os.fdopen(fd, 'wb') as output, Path(source).open('rb') as input_file:
            shutil.copyfileobj(input_file, output)
            output.flush()
            os.fsync(output.fileno())
        if digest(Path(temporary)) != sha256:
            raise SourceUpdateError(409, 'Файл изменился после генерации: ' + target.name)
        os.chmod(temporary, mode)
        os.replace(temporary, target)
        temporary = None
        return 'updated'
    finally:
        if temporary:
            Path(temporary).unlink(missing_ok=True)


def preview(branches=None):
    names = branch_names()
    chosen = list(DEFAULT_BRANCHES) if branches is None else list(branches)
    if branches is None:
        chosen = [name for name in chosen if name in names]
    if len(chosen) != len(set(chosen)) or any(name not in names for name in chosen):
        raise SourceUpdateError(400, 'Допустимы только существующие testing/unstable без повторов')
    candidates = packages(SOURCE_ROOT)
    source = newest(candidates)
    if source is None:
        raise SourceUpdateError(404, 'В Korinf/sources нет исходного пакета eepm')
    path = source['path']
    sha = digest(path)
    info = {'name': path.name, 'path': str(path), 'sha256': sha, 'version': source['evr'][1]}
    rows = []
    for name in names:
        row = {'name': name, 'selected': name in chosen, 'destination': str(WINE_ROOT / name / 'sources'),
               'current': [], 'action': 'blocked', 'message': ''}
        try:
            dest = destination(name)
            row['destination'] = str(dest)
            row['installer'] = installer_preview(name, source['evr'][1])
            current = packages(dest)
            row['current'] = [entry['path'].name for entry in current]
            latest = newest(current)
            row['current_latest'] = latest['path'].name if latest else None
            target = dest / path.name
            if latest and compare(latest, source) > 0:
                raise SourceUpdateError(409, 'В ветке уже есть более новая версия; понижение installer запрещено')
            if target.exists() or target.is_symlink():
                if target.is_symlink() or not target.is_file() or digest(target) != sha:
                    raise SourceUpdateError(409, f'Файл с тем же именем отличается: {target}')
                row['action'] = 'unchanged'
                row['message'] = 'Уже опубликован'
            elif latest and compare(latest, source) >= 0:
                raise SourceUpdateError(409, 'В ветке уже есть такая же или более новая версия; понижение запрещено')
            else:
                row['action'] = 'copy'
                row['message'] = 'Скопировать исходный RPM'
        except SourceUpdateError as error:
            row['message'] = str(error)
        rows.append(row)
    selected = [row for row in rows if row['selected']]
    token_data = {'source': info, 'branches': selected}
    token = hashlib.sha256(json.dumps(token_data, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    return {'source': info, 'branches': rows, 'preview_token': token}


def apply(branches, preview_token):
    with LOCK_FILE.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SourceUpdateError(409, 'Обновление epm уже выполняется') from error
        return _apply_locked(branches, preview_token)


def _apply_locked(branches, preview_token):
    if not branches:
        raise SourceUpdateError(400, 'Выберите хотя бы одну ветку')
    plan = preview(branches)
    if not isinstance(preview_token, str) or plan['preview_token'] != preview_token:
        raise SourceUpdateError(409, 'План изменился; обновите предварительный просмотр')
    selected = [row for row in plan['branches'] if row['selected']]
    blocked = [row for row in selected if row['action'] == 'blocked']
    if blocked:
        raise SourceUpdateError(409, '; '.join(row['name'] + ': ' + row['message'] for row in blocked))
    source = Path(plan['source']['path'])
    staged = {}
    try:
        return _apply_staged(branches, preview_token, plan, selected, source, staged)
    finally:
        for built in staged.values():
            if built.get('work_dir'):
                shutil.rmtree(built['work_dir'], ignore_errors=True)


def _apply_staged(branches, preview_token, plan, selected, source, staged):
    # Generate every selected installer before publishing any SRPM.
    for row in selected:
        try:
            built = epm_installer.build_installer(source, plan['source']['sha256'], row['name'],
                                                  we_path=str(WINE_ROOT),
                                                  docs_dir=installer_destination(row['name']).parent)
            staged[row['name']] = built
            expected = row['installer']
            if (built['epm_version'] != plan['source']['version'] or
                built['generator_commit'] != expected['generator_commit'] or
                built['generator_files'] != expected['generator_files']):
                raise SourceUpdateError(409, 'Installer inputs changed after preview')
            staged[row['name']] = built
        except (ValueError, OSError, subprocess.SubprocessError) as error:
            raise SourceUpdateError(409, 'Installer не собран; ничего не опубликовано: ' + str(error)) from error
    if preview(branches)['preview_token'] != preview_token:
        raise SourceUpdateError(409, 'План изменился во время сборки installer; ничего не опубликовано')
    results = []
    for row in selected:
        result = {key: row[key] for key in ('name', 'destination', 'message')}
        result['status'] = row['action']
        temporary = None
        installer_temp = None
        published_source = None
        built = staged[row['name']]
        result['installer'] = built.copy()
        try:
            target_installer = installer_destination(row['name'])
            if str(target_installer) != row['installer']['destination']:
                raise SourceUpdateError(409, 'Путь installer изменился')
            fd, installer_temp = tempfile.mkstemp(prefix='.installer-update-', dir=target_installer.parent)
            with os.fdopen(fd, 'wb') as output, Path(built['path']).open('rb') as input_file:
                shutil.copyfileobj(input_file, output)
                output.flush()
                os.fsync(output.fileno())
            if digest(Path(installer_temp)) != built['sha256']:
                raise SourceUpdateError(409, 'Installer изменился после генерации')
            os.chmod(installer_temp, 0o755)
            if row['action'] == 'copy':
                dest = destination(row['name'])
                if str(dest) != row['destination']:
                    raise SourceUpdateError(409, 'Путь ветки изменился после просмотра')
                fd, temporary = tempfile.mkstemp(prefix='.eepm-update-', dir=dest)
                with os.fdopen(fd, 'wb') as output, source.open('rb') as input_file:
                    shutil.copyfileobj(input_file, output)
                    output.flush()
                    os.fsync(output.fileno())
                if digest(Path(temporary)) != plan['source']['sha256']:
                    raise SourceUpdateError(409, 'Исходный RPM изменился во время копирования')
                os.chmod(temporary, 0o664)
                # Atomic publication, refusing to overwrite a concurrently created file.
                try:
                    os.link(temporary, dest / source.name)
                    published_source = dest / source.name
                except FileExistsError:
                    target = dest / source.name
                    if target.is_symlink() or digest(target) != plan['source']['sha256']:
                        raise SourceUpdateError(409, 'Конфликт файла при публикации')
                result['status'] = 'copied'
                result['message'] = 'Скопирован без изменения содержимого; SHA256 проверен'
            # The database first: it fits the winetricks package, old or new installer.
            result['installer']['ipfs_db'] = {}
            for name, item in built.get('ipfs_db', {}).items():
                result['installer']['ipfs_db'][name] = _replace_file(
                    item['path'], target_installer.parent / name, item['sha256'], 0o664)
            # Replace directory entry, never truncate a file hard-linked to stable.
            if target_installer.exists() and digest(target_installer) == built['sha256']:
                result['installer']['status'] = 'unchanged'
            else:
                os.replace(installer_temp, target_installer)
                installer_temp = None
                result['installer']['status'] = 'updated'
            result['installer']['destination'] = str(target_installer)
            result['message'] += '; installer ' + result['installer']['status']
        except (OSError, SourceUpdateError) as error:
            if published_source is not None and temporary is not None:
                try:
                    if os.path.samefile(published_source, temporary):
                        published_source.unlink()
                except OSError as rollback_error:
                    result['rollback_error'] = str(rollback_error)
            result['status'] = 'failed'
            result['message'] = str(error)
        finally:
            if temporary:
                Path(temporary).unlink(missing_ok=True)
            if installer_temp:
                Path(installer_temp).unlink(missing_ok=True)
        results.append(result)
    return {'source': plan['source'], 'results': results}


def main():
    parser = argparse.ArgumentParser(description='Копировать готовый eepm.src.rpm из Korinf в testing/unstable WINE')
    parser.add_argument('branches', nargs='*', help='Например: 11-testing 11-unstable')
    parser.add_argument('--apply', action='store_true', help='Выполнить копирование; без флага только просмотр')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    try:
        plan = preview(args.branches or None)
        selected = [r for r in plan['branches'] if r['selected']]
        result = apply([r['name'] for r in selected], plan['preview_token']) if args.apply else plan
        if args.json:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            print('Korinf: ' + result['source']['name'])
            print('SHA256: ' + result['source']['sha256'])
            for row in result.get('results', selected):
                print(f"{row['name']}: {row.get('status', row.get('action'))} — {row['message']}")
                print('  ' + row['destination'])
                if 'current_latest' in row:
                    print('  Сейчас: ' + str(row['current_latest'] or 'нет'))
                if 'installer' in row:
                    installer = row['installer']
                    print(f"  Installer epm {installer['epm_version']}: {installer.get('status', installer.get('action', 'не опубликован'))}")
                    print('  ' + installer.get('destination', installer.get('path', '')))
                    if installer.get('sha256'):
                        print('  Installer SHA256: ' + installer['sha256'])
        return int(any(row.get('status') == 'failed' or row.get('action') == 'blocked'
                       for row in result.get('results', selected)))
    except (SourceUpdateError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, str(error) + '\n')
