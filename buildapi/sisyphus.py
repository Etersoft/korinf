"""Daily forced Sisyphus builds, submitted to the normal robot queue."""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import secrets
import string

import products
import systembuild


def plan():
    result, seen = [], set()
    for product in products.names():
        root = systembuild.ETERSOFT_PUB / product
        # version.list is the published selection, not historical FTP directories.
        for line in (root / 'version.list').read_text().splitlines():
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            fields = re.split(r'\t+| {2,}', line.strip())
            if len(fields) < 2 or not systembuild.RE_VERSION.fullmatch(fields[1]):
                raise ValueError(f'Invalid version.list entry for {product}: {line}')
            version = (root / fields[1]).resolve().name
            available = systembuild.systems(version, product)
            targets = [s for s in ('x86_64/ALTLinux/Sisyphus', 'ALTLinux/Sisyphus') if s in available]
            if 'x86_64/ALTLinux/Sisyphus' in targets:
                if products.get(product)['i586']:
                    targets = ['x86_64/ALTLinux/Sisyphus']
                elif 'ALTLinux/Sisyphus' not in targets:
                    targets.append('ALTLinux/Sisyphus')
            if not targets:
                raise ValueError(f'No Sisyphus target for {product} {version}')
            for target in targets:
                key = (product, version, target)
                if key not in seen:
                    seen.add(key)
                    result.append(dict(product=product, version=version, dist=target))
    return result


def submit(sales, today=None):
    today = today or dt.datetime.now().date().isoformat()
    sales = Path(sales)
    if not (sales / 'SALESDIR').is_file():
        raise ValueError(f'Not a robot queue: {sales}')
    jobs = plan()  # Validate the entire plan before publishing any tasks.
    with (sales / '.sisyphus-daily.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = sales / '.sisyphus-daily.json'
        previous = json.loads(state.read_text()) if state.exists() else {}
        completed = previous.get('jobs', []) if previous.get('date') == today else []
        for job in jobs:
            key = [job['product'], job['version'], job['dist']]
            if key in completed:
                print('Already submitted today:', *key)
                continue
            taskid = dt.datetime.now().strftime('%Y%m%d%H%M%S') + '.B01D-0000.' + ''.join(
                secrets.choice(string.ascii_lowercase + string.digits) for _ in range(10))
            result = systembuild.enqueue(job['version'], job['dist'], True, str(sales), taskid,
                                         job['product'], sisyphus_companion=True, skip_failed=True)
            completed.append(key)
            temporary = state.with_suffix('.tmp')
            temporary.write_text(json.dumps(dict(date=today, jobs=completed)) + '\n')
            temporary.replace(state)
            print('Existing:' if result['existing'] else 'Queued:', result['taskid'], *key, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sales-dir', default=os.environ.get('SALES_DIR', str(Path.home() / 'sales')))
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    if args.dry_run:
        for job in plan():
            print(job['product'], job['version'], job['dist'], 'FORCE=1')
    else:
        submit(args.sales_dir)
    return 0
