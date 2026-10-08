"""Products of the system builds and personal orders: robot/products.list.

Everything product specific (the build script, the i586 companion, the
delivery files and URL) is there, not in the code: a new product is a line.
"""
from pathlib import Path

LIST = Path(__file__).resolve().parent.parent / 'robot' / 'products.list'
DEFAULT_DOWNLOAD_URL = 'https://download.etersoft.ru/pub/download/{product}/'
LISTS = ('required',)
FLAGS = ('init', 'i586', 'license_types', 'downloaddir')


def parse(text):
    """{product: {'bootstrap', 'init', 'i586', 'log_alias', 'download_url', 'required', 'install',
    'license_types', 'downloaddir'}} of a products.list text, in its order."""
    result = {}
    for raw in text.splitlines():
        line = raw.split('#', 1)[0].split()
        if not line:
            continue
        product, values = line[0], dict(item.split('=', 1) for item in line[1:] if '=' in item)
        entry = {'bootstrap': values.get('bootstrap', ''), 'log_alias': None, 'install': values.get('install') or None,
                 'download_url': (values.get('download_url') or DEFAULT_DOWNLOAD_URL)}
        if values.get('log_alias') and ':' in values['log_alias']:
            entry['log_alias'] = tuple(values['log_alias'].split(':', 1))
        for key in LISTS:
            entry[key] = [v for v in values.get(key, '').split(',') if v]
        for key in FLAGS:
            entry[key] = values.get(key) == '1'
        result[product] = entry
    return result


def load(path=LIST):
    try:
        return parse(Path(path).read_text(encoding='utf-8'))
    except OSError:
        return {}


PRODUCTS = load()


def names():
    return tuple(PRODUCTS)


def get(product):
    """The settings of a product, None for an unknown one."""
    return PRODUCTS.get(product)
