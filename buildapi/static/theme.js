(function () {
  'use strict';
  const key = 'korinf-theme';
  let theme = 'system';
  try { theme = localStorage.getItem(key) || 'system'; } catch (_) {}
  if (!['system', 'light', 'dark'].includes(theme)) theme = 'system';
  function apply(value) {
    if (value === 'system') delete document.documentElement.dataset.theme;
    else document.documentElement.dataset.theme = value;
  }
  apply(theme);
  document.addEventListener('DOMContentLoaded', function () {
    const select = document.getElementById('theme-select');
    if (!select) return;
    select.value = theme;
    select.addEventListener('change', function () {
      apply(select.value);
      try { localStorage.setItem(key, select.value); } catch (_) {}
    });
  });
}());
