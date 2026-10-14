"""Dependency evidence using Korinf's own replacement functions."""
import os
import datetime as dt
from pathlib import Path
import re
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[1]
NAME = re.compile(r'[A-Za-z0-9_][A-Za-z0-9_.+-]*')


def missing_packages(text):
    patterns = (r'No match for argument: (\S+)', r'Unable to locate package (\S+)',
                r'nothing provides (\S+)', r'Package (\S+) has no installation candidate')
    return sorted({name for pattern in patterns for name in re.findall(pattern, text)
                   if NAME.fullmatch(name)})


def source_files(records, dist, component):
    """Mirror get_target_deplist's Sisyphus path for the selected package."""
    roots = set()
    parts = dist.removeprefix('i586/').split('/')
    for record in records:
        path = Path(record['path'])
        directory = path.parent
        if directory.name != 'log':
            continue
        target = directory.parent
        if list(target.parts[-len(parts):]) != parts:
            logical = record.get('target', '').split('/')
            # discover() resolves symlinks in path but retains the requested
            # target (e.g. WINE/x86_64/LinuxMint/21 -> Ubuntu/22.04).
            if logical[-len(parts):] != parts:
                continue
            if len(parts) == 3 and target.parts[-3] != parts[0]:
                continue
        root = target
        for _ in parts:
            root = root.parent
        if root.name in ('x86_64', 'i586', 'aarch64'):
            continue
        roots.add(root)
    arch = 'x86_64/' if dist.startswith('x86_64/') else ''
    package = component.replace('wine32-', 'wine-', 1)
    found = set()
    for root in roots:
        directory = root / (arch + 'ALTLinux/Sisyphus/log')
        path = directory / (package + '.rpm.depends')
        if path.is_file():
            found.add(path)
    return sorted(found)


def convert(dist, component, dependencies):
    # $0 must live in bin/: common resolves Korinf and sibling build-utils from it.
    script = r'''
. "$1/share/eterbuild/korinf/common" >/dev/null
load_mod repl
real_dist=$(get_real_target_dist "$2") || exit
parse_dist_name "$real_dist"
set_target_var >/dev/null
BUILDNAME="$3"
replacements=$(print_pkgrepl_list)
for rule in $replacements; do
    [ ! -f "$rule" ] || printf 'RULE\t%s\n' "$rule"
done
while IFS= read -r dep; do
    TARGETPKGNAME= USEDPKGREPL=
    if tolocal_anyrepl "$dep" $replacements; then
        printf 'DEP\t%s\t%s\t%s\n' "$dep" "$TARGETPKGNAME" "$USEDPKGREPL"
    else
        printf 'DEP\t%s\t%s\tunchanged\n' "$dep" "$dep"
    fi
done
'''
    result = subprocess.run(['bash', '-c', script, str(ROOT / 'bin/korexec'),
                             str(ROOT), dist, component], input='\n'.join(dependencies) + '\n',
                            text=True, capture_output=True, timeout=90, check=True)
    rules, mappings = [], []
    for line in result.stdout.splitlines():
        fields = line.split('\t')
        if fields[0] == 'RULE' and len(fields) == 2:
            rules.append(dict(path=fields[1], resolved=str(Path(fields[1]).resolve())))
        elif fields[0] == 'DEP' and len(fields) == 4:
            mappings.append(dict(source=fields[1], target=fields[2].split(), rule=fields[3]))
    if len(mappings) != len(dependencies):
        raise RuntimeError('Incomplete result from Korinf dependency converter')
    return rules, mappings


def report(task, component=None, query=False, module=None):
    import doctor
    if query and not module:
        raise ValueError('--query requires --module to select the build environment explicitly')
    names = [component] if component else doctor.components(task)
    if len(names) != 1 or names[0] == 'unknown':
        raise ValueError('Select one known component with --component')
    component = names[0]
    if not NAME.fullmatch(component):
        raise ValueError('Invalid component name')
    dist = task.fields.get('DIST', '')
    if component.startswith('wine32-'):
        dist = dist.removeprefix('x86_64/')
    if not re.fullmatch(r'(?:x86_64/|i586/|aarch64/)?[A-Za-z0-9_.+-]+/[A-Za-z0-9_.+-]+', dist):
        raise ValueError('A concrete distribution is required')
    records = doctor.discover_logs(task, names)
    logs, missing = [], set()
    for record in sorted(records, key=lambda row: -row['mtime'])[:6]:
        row = dict(path=record['path'], mtime=record['mtime'],
                   time_relation=doctor.log_time_relation(record['mtime'], doctor.failure_time(task)))
        try:
            text, row['truncated'] = doctor.read_log(record['path'])
            clean = doctor.ANSI.sub('', text)
            blocks = re.split(r'(?m)^(?=STEP\s+\*)', clean)
            failed = [block for block in blocks if re.search(r'\[\s*FAILED\s*\]', block)]
            row['missing'] = missing_packages(failed[-1] if failed else blocks[-1])
            missing.update(row['missing'])
        except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
            row['error'] = str(exc)
        logs.append(row)
    sources, dependencies = [], set()
    for path in source_files(records, dist, component):
        text = path.read_text()
        deps = text.split()
        dependencies.update(deps)
        sources.append(dict(path=str(path), mtime=path.stat().st_mtime, count=len(deps)))
    # Missing names are useful even when no source .depends file was discovered.
    rules, mappings = convert(dist, component, sorted(dependencies | missing))
    result = dict(task=doctor.task_summary(task), component=component, dist=dist,
                  sources=sources, rules=rules, mappings=mappings, missing=sorted(missing), logs=logs,
                  note='Source covers the selected package; missing names are log evidence, not a fresh install test.')
    if not sources:
        result['source_warning'] = 'No Sisyphus .rpm.depends found alongside discovered artifact logs'
    if query:
        if not module:
            raise ValueError('--query requires --module to select the build environment explicitly')
        candidates = []
        for name in sorted(missing):
            # Search the ABI-independent prefix; report suggestions without applying them.
            term = re.sub(r'\d+$', '', name)
            command = 'epm search ' + shlex.quote(term)
            proc = subprocess.run([str(ROOT / 'bin/korexec'), dist, command],
                                  env=dict(os.environ, KORINFMODULE=module),
                                  text=True, capture_output=True)
            output = proc.stdout + proc.stderr
            candidates.append(dict(package=name, command=command, returncode=proc.returncode,
                                   output=output[-12000:], truncated=len(output) > 12000))
        result['candidates'] = candidates
    return result


def print_report(result, verbose=False):
    print(f"{result['task']['taskid']}: {result['dist']} | {result['component']}")
    print('Missing in logs: ' + (', '.join(result['missing']) or 'not identified'))
    for source in result['sources']:
        print(f"Source: {source['path']} ({source['count']} dependencies)")
    if 'source_warning' in result:
        print('WARNING: ' + result['source_warning'])
    for row in result['mappings']:
        if verbose or row['source'] in result['missing']:
            print(f"{row['source']} => {' '.join(row['target']) or '(removed)'} [{row['rule']}]")
    for index, log in enumerate(result['logs']):
        if verbose or index == 0 or log.get('missing') or 'error' in log:
            stamp = dt.datetime.fromtimestamp(log['mtime']).astimezone().isoformat(timespec='seconds')
            print(f"Log: {log['path']} | {stamp} | {log['time_relation']}")
            if 'error' in log:
                print(log['error'])
    if verbose:
        for rule in result['rules']:
            print(f"Rule file: {rule['path']} -> {rule['resolved']}")
    for row in result.get('candidates', []):
        print(f"Candidates for {row['package']} (exit {row['returncode']}):\n{row['output']}")
    print(result['note'])
