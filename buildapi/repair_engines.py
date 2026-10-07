"""Fixed repair runners. Model commands never come from HTTP input."""
import json
import os
from pathlib import Path
import re
import shutil

ENGINES = {'mimo': 'MiMo (xmimo)', 'codex': 'Codex'}
DEFAULT = 'mimo'


def executable(engine):
    if engine not in ENGINES:
        raise ValueError('Неизвестный исполнитель ремонта')
    path = shutil.which('xmimo' if engine == 'mimo' else 'codex')
    if not path:
        raise FileNotFoundError(f'{ENGINES[engine]} не установлен на сервере')
    if engine == 'mimo' and not shutil.which('bwrap'):
        raise FileNotFoundError('Для изолированного запуска MiMo требуется bwrap')
    return path


def selected_mimo_model():
    # A fresh isolated runtime has no recent model and otherwise selects the
    # retired free API. Reuse the account's explicit, most recent selection.
    if os.environ.get('MIMOCODE_HOME'):
        state = Path(os.environ['MIMOCODE_HOME']) / 'state'
    else:
        state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'mimocode'
    try:
        recent = json.loads((state / 'model.json').read_text()).get('recent', [])
        for entry in recent:
            provider, model = entry.get('providerID'), entry.get('modelID')
            if isinstance(provider, str) and isinstance(model, str) and provider and model:
                return provider + '/' + model
    except (OSError, ValueError, TypeError, AttributeError):
        pass
    return None


def mimo_command(executable, checkout, work):
    """Keep the host read-only; only the disposable checkout and runtime can change."""
    runtime = work / 'mimo-runtime'
    (runtime / 'tmp').mkdir(parents=True, exist_ok=True)
    (runtime / 'config').mkdir(exist_ok=True)
    config = {
        'autoupdate': False, 'share': 'disabled', 'snapshot': False,
        'dream': {'auto': False}, 'distill': {'auto': False},
        'permission': {
            '*': 'deny', 'read': {'*': 'allow', '**/.ssh/**': 'deny',
                '**/.codex/**': 'deny', '**/buildapi/config': 'deny',
                '/etc/opt/mimo/**': 'deny', '**/.config/mimo/**': 'deny'},
            'glob': 'allow', 'grep': 'allow', 'edit': 'allow', 'write': 'allow',
            'bash': {'*': 'allow', 'ssh *': 'deny', 'sudo *': 'deny',
                     'curl *': 'deny', 'wget *': 'deny', 'git push*': 'deny'},
            'external_directory': 'allow',
        },
    }
    (runtime / 'config/mimocode.json').write_text(json.dumps(config))
    command = [shutil.which('bwrap') or 'bwrap', '--die-with-parent', '--new-session',
               '--unshare-user', '--unshare-pid', '--ro-bind', '/', '/',
               '--proc', '/proc', '--dev', '/dev',
               '--bind', str(checkout), str(checkout),
               '--bind', str(runtime), str(runtime), '--chdir', str(checkout)]
    environment = {
        'MIMOCODE_HOME': str(runtime), 'TMPDIR': str(runtime / 'tmp'),
        'MIMOCODE_DISABLE_PROJECT_CONFIG': '1', 'MIMOCODE_DISABLE_CLAUDE_IMPORT': '1',
        'MIMOCODE_DISABLE_EXTERNAL_SKILLS': '1', 'MIMOCODE_DISABLE_CLAUDE_CODE_SKILLS': '1',
        'MIMOCODE_DISABLE_CODEX_SKILLS': '1', 'MIMOCODE_DISABLE_CRON': '1',
        'NO_COLOR': '1',
    }
    for key, value in environment.items():
        command.extend(['--setenv', key, value])
    command += [executable, 'run', '--pure', '--format', 'json', '--dir', str(checkout)]
    model = selected_mimo_model()
    if model:
        command += ['--model', model]
    return command


def events(text):
    for line in text.splitlines():
        try:
            event = json.loads(line)
        except (ValueError, TypeError):
            continue
        if isinstance(event, dict):
            yield event


def render_mimo_log(text):
    lines = []
    for line in text.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            lines.append(line)
            continue
        if not isinstance(event, dict):
            continue
        kind, part = event.get('type'), event.get('part', {})
        if kind == 'text':
            lines.append(part.get('text', ''))
        elif kind == 'tool_use':
            state = part.get('state', {})
            inputs = state.get('input', {})
            lines.append(f"[{part.get('tool', 'tool')}] " + json.dumps(inputs, ensure_ascii=False))
            lines.append(str(state.get('output') or state.get('error') or state.get('status', '')))
        elif kind == 'step_start':
            lines.append('MiMo проверяет следующий шаг…')
        elif kind == 'error':
            lines.append('Ошибка: ' + json.dumps(event.get('error'), ensure_ascii=False))
    return '\n'.join(lines)


def mimo_result(path):
    # A textual/non-JSON answer is still a useful report, but is never auto-applied.
    last = ''
    with path.open('rb') as stream:
        stream.seek(0, 2)
        stream.seek(max(0, stream.tell() - 2_000_000))
        for event in events(stream.read(2_000_000).decode('utf-8', errors='replace')):
            if event.get('type') == 'text':
                last = event.get('part', {}).get('text', '')
            if event.get('type') == 'error':
                raise RuntimeError('MiMo сообщил об ошибке; подробности в журнале')
    text = re.sub(r'^```(?:json)?\s*|\s*```$', '', last.strip())
    try:
        result = json.loads(text)
        if (isinstance(result, dict) and isinstance(result.get('summary'), str)
                and isinstance(result.get('checks'), list)
                and all(isinstance(check, str) for check in result['checks'])):
            return result
    except ValueError:
        pass
    if not last:
        raise RuntimeError('MiMo не вернул итоговый отчёт; подробности в журнале')
    return dict(outcome='needs_review', confidence='low', summary=last, checks=[])
