(() => {
  'use strict';
  const rows = [...document.querySelectorAll('.feature-table tbody tr')];
  const filters = [...document.querySelectorAll('.feature-filter')];
  const detail = document.querySelector('#feature-detail');
  const count = category => category === 'all' ? rows.length : rows.filter(row => row.dataset.category === category).length;
  filters.forEach(button => {
    const category = button.dataset.category;
    const number = button.querySelector('span');
    if (number && category !== 'all') number.textContent = String(count(category));
    button.addEventListener('click', () => {
      filters.forEach(item => {
        const selected = item === button;
        item.classList.toggle('active', selected);
        item.setAttribute('aria-pressed', String(selected));
      });
      rows.forEach(row => { row.hidden = category !== 'all' && row.dataset.category !== category; });
    });
  });
  rows.forEach(row => row.addEventListener('click', () => {
    rows.forEach(item => item.classList.toggle('selected', item === row));
    const name = row.querySelector('th').textContent.replace(/^\S+/, '').trim();
    const status = row.querySelector('.support-pill').textContent.trim();
    const description = row.querySelector('td:nth-child(3)').textContent.trim();
    const evidence = row.querySelector('td:nth-child(4) a');
    detail.querySelector('.feature-detail-index').textContent = row.querySelector('.feature-index').textContent;
    detail.querySelector('strong').textContent = `${name} · ${status}`;
    detail.querySelector('p').innerHTML = `${description} <a href="${evidence.href}"${evidence.target === '_blank' ? ' target="_blank" rel="noopener noreferrer"' : ''}>继续查看证据 ↗</a>`;
  }));
})();
