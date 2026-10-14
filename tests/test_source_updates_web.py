"""Source update HTTP contract tests; no production source files are modified."""
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
                                        current=['eepm-2.0-alt1.src.rpm', 'eepm-3.0-alt1.src.rpm'], current_latest='eepm-3.0-alt1.src.rpm', action='copy', message='Копировать', selected=True),
                                   dict(name='11-unstable', destination='/wine/11-unstable/sources',
                                        current=[], action='copy', message='Копировать', selected=False)],
                         preview_token='b' * 64)
        for row in self.plan['branches']:
            row['installer'] = dict(destination=f"/private/{row['name']}/docs/wine-etersoft-install.sh",
                                    epm_version='4.0', current_sha256='c' * 64,
                                    generator_commit='d' * 40, action='build-and-replace')
        preview = patch.object(source_updates, 'preview', return_value=self.plan)
        self.preview = preview.start()
        self.addCleanup(preview.stop)
        apply = patch.object(source_updates, 'apply', return_value=dict(source=self.plan['source'], results=[
            dict(name='10-testing', destination='/wine/10-testing/sources', status='copied', message='Готово',
                 installer=dict(destination='/private/10-testing/docs/wine-etersoft-install.sh',
                                epm_version='4.0', status='updated', sha256='e' * 64,
                                source_sha256='a' * 64, generator_commit='d' * 40,
                                log_path='/build/install.log'))]))
        self.apply = apply.start()
        self.addCleanup(apply.stop)

    def test_preview_is_read_only_and_displays_current_new_and_destination(self):
        result = self.client.get('/source-updates/epm')
        self.assertEqual(result.status_code, 200)
        for text in ('eepm-4.0-alt1.src.rpm', 'eepm-3.0-alt1.src.rpm', '/wine/10-testing/sources',
                     'Подтверждённый выбор', 'preview_token'):
            self.assertIn(text, result.text)
        self.assertIn('<strong><code>eepm-3.0-alt1.src.rpm</code></strong>', result.text)
        self.assertIn('<details><summary>Остальные пакеты (1)</summary>', result.text)
        self.assertIn('no-store', result.headers['cache-control'])
        self.preview.assert_called_once_with(None)
        self.apply.assert_not_called()
        self.assertIn("document.getElementById('apply-epm').disabled = true", result.text)

    def test_selection_get_is_explicit_including_empty_selection(self):
        self.client.get('/source-updates/epm?selection=1&branch=11-unstable')
        self.preview.assert_called_with(['11-unstable'])
        self.client.get('/source-updates/epm?selection=1')
        self.preview.assert_called_with([])
        self.apply.assert_not_called()

    def test_api_requires_key_for_read_and_write(self):
        url = '/api/source-updates/epm'
        self.assertEqual(self.client.get(url).status_code, 401)
        self.assertEqual(self.client.post(url, json=dict(branches=['10-testing'], preview_token='x')).status_code, 401)
        self.apply.assert_not_called()
        self.preview.assert_not_called()
        response = self.client.get(url + '?branch=10-testing', headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.preview.assert_called_once_with(['10-testing'])

    def test_same_origin_enforced_for_both_mutation_routes(self):
        for extra in ({'Origin': 'http://evil.invalid'}, {'Origin': 'https://testserver'},
                      {'Referer': 'http://evil.invalid/form'}, {'Sec-Fetch-Site': 'cross-site'},
                      {'Sec-Fetch-Site': 'same-site'}, {'Origin': 'null'}, {'Origin': 'http://[bad'}):
            with self.subTest(headers=extra):
                api = self.client.post('/api/source-updates/epm', headers={**self.headers, **extra},
                                       json=dict(branches=['10-testing'], preview_token='b' * 64))
                web = self.client.post('/source-updates/epm', headers=extra,
                                       data=dict(branch='10-testing', preview_token='b' * 64))
                self.assertEqual(api.status_code, 403)
                self.assertEqual(web.status_code, 403)
        self.apply.assert_not_called()

    def test_post_forwards_exact_selection_and_token_and_displays_result(self):
        response = self.client.post('/source-updates/epm', headers={'Origin': 'http://testserver'},
                                    data=dict(branch='10-testing', preview_token='b' * 64))
        self.assertEqual(response.status_code, 200)
        self.apply.assert_called_once_with(['10-testing'], 'b' * 64)
        self.assertIn('copied', response.text)
        self.assertIn('Обновлён', response.text)
        self.assertIn('epm 4.0', response.text)
        self.assertIn('/private/10-testing/docs/wine-etersoft-install.sh', response.text)
        self.assertIn('e' * 64, response.text)
        self.assertRegex(response.text, r'<details><summary>Контрольная сумма и происхождение</summary>[\s\S]*?' + 'e' * 64 + r'[\s\S]*?</details>')
        self.assertIn('/wine/10-testing/sources', response.text)
        self.assertNotIn('name="preview_token"', response.text)
        self.preview.assert_not_called()

    def test_conflict_does_not_retry_or_apply_another_preview(self):
        self.apply.side_effect = source_updates.SourceUpdateError(409, 'Источник изменился <script>bad</script>')
        response = self.client.post('/source-updates/epm', data=dict(branch='10-testing', preview_token='old'))
        self.assertEqual(response.status_code, 409)
        self.assertIn('Получить новый предпросмотр', response.text)
        self.assertNotIn('<script>bad</script>', response.text)
        self.assertIn('&lt;script&gt;', response.text)
        self.assertEqual(self.apply.call_count, 1)
        self.preview.assert_not_called()
        response = self.client.post('/api/source-updates/epm', headers=self.headers,
                                    json=dict(branches=['10-testing'], preview_token='old'))
        self.assertEqual(response.status_code, 409)

    def test_bad_forms_do_not_call_apply(self):
        for data in ({'branch': '10-testing'}, {'preview_token': 'b'},
                     {'branch': '10-testing', 'preview_token': ['one', 'two']},
                     {'branch': '10-testing', 'preview_token': 'b', 'path': '/stable'}):
            self.assertEqual(self.client.post('/source-updates/epm', data=data).status_code, 400)
        self.apply.assert_not_called()

    def test_blocked_or_empty_selection_disables_apply_and_escape_names(self):
        for mode in ('blocked', 'empty'):
            self.plan['branches'][0]['selected'] = mode != 'empty'
            self.plan['branches'][0]['action'] = 'blocked'
            self.plan['branches'][0]['current'] = ['<script>bad</script>']
            self.plan['branches'][0].pop('current_latest', None)
            response = self.client.get('/source-updates/epm')
            self.assertRegex(response.text, r'id="apply-epm"[^>]*disabled')
            self.assertIn('&lt;script&gt;bad&lt;/script&gt;', response.text)
            self.assertNotIn('<script>bad</script>', response.text)

    def test_installer_preview_and_source_unchanged_still_allow_update(self):
        row = self.plan['branches'][0]
        row['action'] = 'unchanged'
        row['message'] = 'Уже опубликован'
        response = self.client.get('/source-updates/epm')
        self.assertIn('Обновить epm и установщик', response.text)
        self.assertIn('Создать с epm 4.0', response.text)
        self.assertIn('/private/10-testing/docs/wine-etersoft-install.sh', response.text)
        self.assertNotRegex(response.text, r'id="apply-epm"[^>]*disabled')
        self.assertRegex(response.text, r'<details><summary>Сведения о генерации</summary>[\s\S]*?' + 'd' * 40 + r'[\s\S]*?</details>')
        self.apply.assert_not_called()

    def test_missing_installer_inputs_show_blocker_and_disable_action(self):
        row = self.plan['branches'][0]
        row.pop('installer')
        row['action'] = 'blocked'
        row['message'] = 'Настройте KORINF_INSTALLER_SNAPSHOT'
        response = self.client.get('/source-updates/epm')
        self.assertEqual(response.status_code, 200)
        self.assertIn('KORINF_INSTALLER_SNAPSHOT', response.text)
        self.assertIn('Генерация недоступна', response.text)
        self.assertRegex(response.text, r'id="apply-epm"[^>]*disabled')

    def test_failed_installer_result_is_not_presented_as_success(self):
        row = self.apply.return_value['results'][0]
        row['status'] = 'failed'
        row['message'] = 'Не удалось записать установщик'
        row['installer'].pop('status')
        response = self.client.post('/source-updates/epm', data=dict(branch='10-testing', preview_token='b' * 64))
        self.assertIn('Не завершено', response.text)
        self.assertIn('Не удалось записать установщик', response.text)
        self.assertNotIn('<strong>Обновлён</strong>', response.text)

    def test_backend_rejects_stable_request_with_no_fallback(self):
        self.apply.side_effect = source_updates.SourceUpdateError(422, 'Стабильная ветка запрещена')
        response = self.client.post('/api/source-updates/epm', headers=self.headers,
                                    json=dict(branches=['10.10'], preview_token='token'))
        self.assertEqual(response.status_code, 422)
        self.apply.assert_called_once_with(['10.10'], 'token')
        self.preview.assert_not_called()


if __name__ == '__main__':
    unittest.main()
