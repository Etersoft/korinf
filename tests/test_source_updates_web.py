"""Source update HTTP contract tests; no production source files are modified.

The web page is in the Release Manager (Kerberos); buildapi keeps the API."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'buildapi'))
from fastapi.testclient import TestClient
import main
import source_updates


class SourceUpdateWebTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)
        self.headers = {'X-API-Key': 'source-test-key'}
        key = patch.dict(main.CFG, {'API_KEY': 'source-test-key'})
        key.start()
        self.addCleanup(key.stop)
        self.plan = dict(source=dict(name='eepm-4.0-alt1.src.rpm', path='/source/eepm-4.0-alt1.src.rpm', sha256='a' * 64),
                         branches=[dict(name='10-testing', destination='/wine/10-testing/sources',
                                        current=['eepm-3.0-alt1.src.rpm'], current_latest='eepm-3.0-alt1.src.rpm',
                                        action='copy', message='Копировать', selected=True)],
                         preview_token='b' * 64)
        preview = patch.object(source_updates, 'preview', return_value=self.plan)
        self.preview = preview.start()
        self.addCleanup(preview.stop)
        apply = patch.object(source_updates, 'apply', return_value=dict(source=self.plan['source'], results=[
            dict(name='10-testing', destination='/wine/10-testing/sources', status='copied', message='Готово',
                 installer=dict(epm_version='4.0', status='updated', sha256='e' * 64))]))
        self.apply = apply.start()
        self.addCleanup(apply.stop)

    def test_no_unauthenticated_web_form(self):
        self.assertEqual(self.client.get('/source-updates/epm').status_code, 404)
        self.assertIn(self.client.post('/source-updates/epm', data=dict(branch='10-testing', preview_token='b' * 64)).status_code,
                      (404, 405))
        self.apply.assert_not_called()
        html = self.client.get('/').text
        self.assertIn(':5502/epm-update', html)

    def test_api_requires_key_for_read_and_write(self):
        url = '/api/source-updates/epm'
        self.assertEqual(self.client.get(url).status_code, 401)
        self.assertEqual(self.client.post(url, json=dict(branches=['10-testing'], preview_token='x')).status_code, 401)
        self.apply.assert_not_called()
        self.preview.assert_not_called()
        response = self.client.get(url + '?branch=10-testing', headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertIn('no-store', response.headers['cache-control'])
        self.preview.assert_called_once_with(['10-testing'])

    def test_api_post_forwards_exact_selection_and_token(self):
        response = self.client.post('/api/source-updates/epm', headers=self.headers,
                                    json=dict(branches=['10-testing'], preview_token='b' * 64))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['results'][0]['status'], 'copied')
        self.apply.assert_called_once_with(['10-testing'], 'b' * 64)
        self.preview.assert_not_called()

    def test_same_origin_enforced_for_api_post(self):
        for extra in ({'Origin': 'http://evil.invalid'}, {'Origin': 'https://testserver'},
                      {'Referer': 'http://evil.invalid/form'}, {'Sec-Fetch-Site': 'cross-site'},
                      {'Sec-Fetch-Site': 'same-site'}, {'Origin': 'null'}, {'Origin': 'http://[bad'}):
            with self.subTest(headers=extra):
                api = self.client.post('/api/source-updates/epm', headers={**self.headers, **extra},
                                       json=dict(branches=['10-testing'], preview_token='b' * 64))
                self.assertEqual(api.status_code, 403)
        self.apply.assert_not_called()

    def test_conflict_is_returned_without_retry(self):
        self.apply.side_effect = source_updates.SourceUpdateError(409, 'План изменился')
        response = self.client.post('/api/source-updates/epm', headers=self.headers,
                                    json=dict(branches=['10-testing'], preview_token='old'))
        self.assertEqual(response.status_code, 409)
        self.assertEqual(self.apply.call_count, 1)
        self.preview.assert_not_called()

    def test_backend_rejects_stable_request_with_no_fallback(self):
        self.apply.side_effect = source_updates.SourceUpdateError(422, 'Стабильная ветка запрещена')
        response = self.client.post('/api/source-updates/epm', headers=self.headers,
                                    json=dict(branches=['10.10'], preview_token='token'))
        self.assertEqual(response.status_code, 422)
        self.apply.assert_called_once_with(['10.10'], 'token')
        self.preview.assert_not_called()


if __name__ == '__main__':
    unittest.main()
