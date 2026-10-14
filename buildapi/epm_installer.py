"""Build with an unmodified pinned wine-base-bottle-scripts export; never publish."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

SCRIPT_DIR = 'installation script W@E'
REQUIRED = ('comp_list.txt', *(SCRIPT_DIR + '/' + name for name in (
    'make_wine_part.sh', 'common_func.sh', 'url-parser.sh', 'wine-etersoft-install-part.sh')))


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def snapshot_info(snapshot_dir=None):
    root = Path(snapshot_dir or os.environ.get('KORINF_INSTALLER_SNAPSHOT',
                '/srv/builder/Projects/wine-base-bottle-scripts'))
    try:
        info = json.loads((root / 'SNAPSHOT.json').read_text())
        if not re.fullmatch(r'[0-9a-f]{40}', info['commit']):
            raise ValueError('Invalid snapshot commit')
        files = {row['path']: row for row in info['exported_files']}
        for name in REQUIRED:
            path = root / name
            if path.is_symlink() or not path.is_file() or digest(path) != files[name]['sha256']:
                raise ValueError('Snapshot checksum mismatch: ' + name)
        return {'path': str(root.resolve()), 'repo': info['repo'], 'commit': info['commit'],
                'files': {name: files[name]['sha256'] for name in REQUIRED}}
    except (OSError, KeyError, TypeError, json.JSONDecodeError) as error:
        raise ValueError('Configure KORINF_INSTALLER_SNAPSHOT with a pinned export: ' + str(error)) from error


def build_installer(source_path, source_sha256, branch, *, snapshot_dir=None,
                    work_root=None, we_path='/var/ftp/pub/Etersoft/WINE@Etersoft', timeout=600):
    if not re.fullmatch(r'(?:[A-Za-z0-9][A-Za-z0-9.-]*-)?(?:testing|unstable)', branch):
        raise ValueError('Installer generation is limited to testing/unstable')
    source = Path(source_path).resolve()
    if digest(source) != source_sha256:
        raise ValueError('Selected eepm source SHA256 changed')
    meta = subprocess.run(['rpm', '-qp', '--queryformat', '%{NAME}|%{VERSION}|%{SOURCEPACKAGE}',
                           str(source)], capture_output=True, text=True, timeout=30, check=True)
    name, version, source_flag = meta.stdout.split('|')
    if name != 'eepm' or source_flag != '1':
        raise ValueError('Expected an eepm source RPM')
    snapshot = snapshot_info(snapshot_dir)
    work = Path(tempfile.mkdtemp(prefix='korinf-installer-', dir=work_root))
    # Freeze the exact selected input; upstream extracts it without altering it.
    pinned_source = work / source.name
    shutil.copyfile(source, pinned_source)
    if digest(pinned_source) != source_sha256:
        raise ValueError('Selected eepm source changed while staging')
    repo = work / 'generator'
    for relative, sha in snapshot['files'].items():
        dest = repo / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(Path(snapshot['path']) / relative, dest)
        if digest(dest) != sha:
            raise ValueError('Generator snapshot changed while staging')
    cwd = repo / SCRIPT_DIR
    log_path = work / 'build.log'
    env = os.environ.copy()
    # Prevent caller state from overriding explicit source/branch or component list.
    for key in ('ETERWINEVER', 'WINETRICKS_BUILD', 'EPM_VERSION', 'UPDATE_COMPS',
                'UPDATE_COMPS_FROM_WINE', 'COMP_LIST_FILE', 'SCRIPTS_PATH', 'TMP_DIR'):
        env.pop(key, None)
    env['WE_PATH'] = str(we_path)
    with log_path.open('w') as log:
        try:
            subprocess.run(['sh', './make_wine_part.sh', str(pinned_source), branch],
                           cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=timeout)
        except subprocess.SubprocessError as error:
            raise ValueError('Native installer generation failed; log: ' + str(log_path)) from error
    output = cwd / 'wine-etersoft-install.sh'
    if not output.is_file() or output.stat().st_size == 0:
        raise ValueError('Native generator did not create installer: ' + str(log_path))
    text = output.read_text()
    versions = re.findall(r'^export EPMVERSION="([^"\n]+)"$', text, re.M)
    if versions != [version]:
        raise ValueError('Installer EPMVERSION does not match the selected source RPM')
    subprocess.run(['bash', '-n', str(output)], capture_output=True, text=True, check=True, timeout=30)
    if digest(pinned_source) != source_sha256 or digest(source) != source_sha256:
        raise ValueError('Source changed during installer generation')
    result = {'path': str(output), 'sha256': digest(output), 'epm_version': version,
              'source_sha256': source_sha256, 'source_name': source.name, 'branch': branch,
              'generator_commit': snapshot['commit'], 'generator_repo': snapshot['repo'],
              'generator_files': snapshot['files'], 'work_dir': str(work), 'log_path': str(log_path)}
    (work / 'provenance.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    return result
