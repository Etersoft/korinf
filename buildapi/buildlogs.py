"""Discover only build logs below known artifact roots, never arbitrary paths."""
import bz2
import copy
import gzip
import hashlib
import lzma
from pathlib import Path
import re

import products
import systembuild

PUB = Path('/var/ftp/pub')
PVT = Path('/var/ftp/pvt')
LIVE = Path('/srv/builder/Projects/korinf/log')
NAME = re.compile(r'(.+?)(?:\.(?:config|install))?\.log(?:\.(?:xz|bz2|gz))?$')


def discover(task):
    records = _discover(task)
    # A system build of x86_64/<D>/<V> of a product with i586=1 (robot/products.list)
    # also builds the 32-bit packages of its i586 companion <D>/<V>.
    dist = task.fields.get('DIST', '')
    settings = products.get(task.fields.get('COMPONENTNAME') or systembuild.LEGACY_PRODUCT)
    if systembuild.is_system_build(task) and settings and settings['i586'] and dist.startswith('x86_64/'):
        companion = copy.copy(task)
        companion.fields = dict(task.fields, DIST=dist.removeprefix('x86_64/'))
        known = {r['id'] for r in records}
        records += [r for r in _discover(companion) if r['id'] not in known]
        records.sort(key=lambda r: (not r['failed'], -r['mtime']))
    return records[:200]


def _discover(task):
    package = task.fields.get('PACKAGE', '')
    roots = [(PUB / 'Korinf', bool(package))]
    product = task.fields.get('COMPONENTNAME', '').split(' ')[0]
    version = task.fields.get('PROJECTVERSION', '')
    if re.fullmatch(r'[A-Za-z0-9_@.+-]+', product) and re.fullmatch(r'[A-Za-z0-9_+.-]+', version) and version not in ('.', '..'):
        roots += [(base / 'Etersoft' / product / version, True) for base in (PUB, PVT)]
    if package:
        roots.append((LIVE, True))
    # Error messages can identify a failed shared component in a product task.
    failed_names = set(re.findall(r'(?:Package |for )([A-Za-z0-9_][A-Za-z0-9_.+-]*)',
                                 '\n'.join(err or '' for _, err in task.failures)))
    raw_dist = task.fields.get('DIST', 'all')
    dist = raw_dist.removeprefix('i586/')
    broad_dist = dist in ('all', 'ALL', 'build') or dist.endswith(('/build', '/ALL'))
    records = {}
    for root, all_components in roots:
        if not all_components and not failed_names:
            continue
        if not root.is_dir():
            continue
        real_root = root.resolve()
        # Select the task's literal target first: scanning entire product trees
        # on NFS can take seconds and traverses unrelated source archives.
        directories = []
        concrete = not broad_dist and len(dist.split('/')) >= 2 and re.fullmatch(r'[A-Za-z0-9_+.-]+(?:/[A-Za-z0-9_+.-]+)+', dist)
        if concrete:
            direct = root / dist / 'log'
            if direct.is_dir():
                directories.append(direct)
            directories.extend(root.glob('*/' + dist + '/log'))
        else:
            depths = (2, 3) if root == PUB / 'Korinf' else (2, 3, 4)
            for depth in depths:
                directories.extend(root.glob('*/' * depth + 'log'))
        if root == LIVE:
            if concrete:
                directories = [root / dist] if (root / dist).is_dir() else []
            else:
                directories = [p for depth in (2, 3) for p in root.glob('*/' * (depth - 1) + '*') if p.is_dir()]
        for directory in directories:
            relative = directory.relative_to(root).as_posix()
            target = relative.removesuffix('/log')
            if broad_dist:
                if raw_dist in ('x86_64/build', 'x86_64/ALL') and 'x86_64/' not in target:
                    continue
                if raw_dist in ('i586/build', 'i586/ALL') and 'x86_64/' in target:
                    continue
            elif not (target == dist or target.endswith('/' + dist) or target.startswith(dist + '/')):
                continue
            try:
                files = list(directory.iterdir())
            except OSError:
                continue
            for path in files:
                match = NAME.fullmatch(path.name)
                if not match:
                    continue
                component = match[1]
                if package and component != package:
                    continue
                if not package and not all_components and component not in failed_names:
                    continue
                try:
                    resolved = path.resolve()
                    if not resolved.is_relative_to(real_root) or not resolved.is_file():
                        continue
                    info = resolved.stat()
                except OSError:
                    continue
                failed = any((directory / (component + suffix)).exists()
                             for suffix in ('.build.failed', '.autobuild.failed')) or component in failed_names
                key = hashlib.sha256(str(resolved).encode()).hexdigest()[:24]
                records[key] = dict(id=key, component=component, target=target,
                                    failed=failed, mtime=info.st_mtime, size=info.st_size,
                                    path=str(resolved), filename=path.name)
    return sorted(records.values(), key=lambda r: (not r['failed'], -r['mtime']))[:200]


def read_tail(path, limit=256 * 1024):
    path = Path(path)
    opener = {'.xz': lzma.open, '.bz2': bz2.open, '.gz': gzip.open}.get(path.suffix)
    if opener is None:
        with path.open('rb') as stream:
            stream.seek(0, 2)
            size = stream.tell()
            stream.seek(max(0, size - limit))
            content = stream.read(limit)
        prefix = '[Показан конец лога]\n' if size > limit else ''
    else:
        # Bound decompression work and memory even for corrupt or oversized logs.
        content = b''
        total = 0
        with opener(path, 'rb') as stream:
            while total < 64 * 1024 * 1024:
                chunk = stream.read(65536)
                if not chunk:
                    break
                total += len(chunk)
                content = (content + chunk)[-limit:]
        prefix = '[Показан конец лога]\n' if total > limit else ''
        if total >= 64 * 1024 * 1024:
            prefix = '[Лог превышает лимит распаковки 64 МиБ; показан фрагмент]\n'
    text = content.decode('utf-8', errors='replace')
    return prefix + re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
