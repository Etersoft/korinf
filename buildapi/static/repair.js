(function () {
  'use strict';
  const selects = Array.from(document.querySelectorAll('.repair-engine'));
  let preferred = 'mimo';
  try { preferred = localStorage.getItem('korinf-repair-engine') || preferred; } catch (_) {}
  if (!['mimo', 'codex'].includes(preferred)) preferred = 'mimo';
  selects.forEach(function (select) {
    select.value = preferred;
    select.addEventListener('change', function () {
      selects.forEach(other => { other.value = select.value; });
      try { localStorage.setItem('korinf-repair-engine', select.value); } catch (_) {}
    });
    select.form.addEventListener('submit', function () {
      const button = select.form.querySelector('button[type="submit"]');
      button.disabled = true;
      button.textContent = 'Запуск ремонта…';
    });
  });

  const panel = document.getElementById('repair');
  if (!panel) return;
  const log = document.getElementById('repair-log');
  const follow = document.getElementById('repair-follow');
  const connection = document.getElementById('repair-connection');
  const report = document.getElementById('repair-report');
  let timer;
  async function update() {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    let active = true;
    try {
      const response = await fetch(panel.dataset.logUrl, {cache: 'no-store', signal: controller.signal});
      if (!response.ok) throw new Error('HTTP ' + response.status);
      const data = await response.json();
      active = ['starting', 'running'].includes(data.status);
      const scroll = log.scrollTop;
      log.textContent = data.log;
      log.scrollTop = follow.checked ? log.scrollHeight : scroll;
      document.getElementById('repair-status').textContent = data.message;
      document.getElementById('repair-engine-name').textContent = data.engine_label;
      report.textContent = data.report || '';
      report.hidden = !data.report;
      document.getElementById('repair-report-heading').hidden = !data.report;
      document.getElementById('repair-patch').textContent = data.patch || '';
      document.getElementById('repair-patch-details').hidden = !data.patch;
      document.getElementById('repair-patch-title').textContent =
        data.applied && data.applied.length ? 'Применённые изменения' : 'Изменения (не применены)';
      document.querySelectorAll('.btn-repair').forEach(button => {
        button.disabled = active;
        button.textContent = active ? 'Ремонт выполняется…' : 'Починить сборку';
      });
      connection.textContent = (active ? 'Журнал обновлён: ' : 'Ремонт завершён. Журнал сохранён: ') +
        new Date().toLocaleTimeString();
    } catch (error) {
      connection.textContent = 'Не удалось обновить журнал (' + error.message + '). Повтор через 2с.';
    } finally {
      clearTimeout(timeout);
      if (active) timer = setTimeout(update, 2000);
    }
  }
  window.addEventListener('pagehide', () => clearTimeout(timer));
  update();
}());
