"""Persistent review comments, independent of queue file renames."""
import json
import os
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent / 'comment-state'


def read(taskid):
    path = ROOT / (taskid + '.json')
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding='utf-8'))


def write(taskid, text, log_at=None):
    ROOT.mkdir(parents=True, exist_ok=True)
    path = ROOT / (taskid + '.json')
    if not text.strip():
        path.unlink(missing_ok=True)
        return None
    data = {'text': text.strip(), 'updated_at': time.time(), 'log_at': log_at}
    fd, temporary = tempfile.mkstemp(dir=ROOT, suffix='.tmp')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, ensure_ascii=False)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return data
