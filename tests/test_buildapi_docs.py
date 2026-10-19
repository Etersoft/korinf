"""The guide is served for people (/help) and programs (/help.md, /llms.txt)."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'buildapi'))
import main
from fastapi.testclient import TestClient


class Docs(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)

    def test_help_html(self):
        r = self.client.get('/help')
        self.assertEqual(r.status_code, 200)
        self.assertIn('<h2 id="getting-the-api-key">Getting the API key</h2>', r.text)
        self.assertIn('href=/llms.txt', r.text)

    def test_help_markdown(self):
        r = self.client.get('/help.md')
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.headers['content-type'].startswith('text/markdown'))
        self.assertEqual(r.text, (ROOT / 'buildapi' / 'README.md').read_text(encoding='utf-8'))

    def test_llms_txt(self):
        r = self.client.get('/llms.txt')
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.text.startswith('# korinf buildapi\n'))
        self.assertIn('tools/korinf-api-key', r.text)

    def test_docs_need_no_key_and_hide_from_schema(self):
        paths = self.client.get('/openapi.json').json()['paths']
        for path in ('/help', '/help.md', '/llms.txt'):
            self.assertNotIn(path, paths)

    def test_missing_doc(self):
        with patch.object(main, 'LLMS_TXT_PATH', Path('/nonexistent/llms.txt')):
            self.assertEqual(self.client.get('/llms.txt').status_code, 503)

    def test_api_key_file_overrides_config(self):
        with tempfile.TemporaryDirectory() as d:
            keyfile = Path(d) / 'api-key'
            keyfile.write_text('secret-from-file\n')
            with patch.object(main, 'API_KEY_PATH', keyfile):
                self.assertEqual(main.load_config()['API_KEY'], 'secret-from-file')
            with patch.object(main, 'API_KEY_PATH', Path(d) / 'absent'):
                self.assertNotEqual(main.load_config()['API_KEY'], 'secret-from-file')


if __name__ == '__main__':
    unittest.main()
