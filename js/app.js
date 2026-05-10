const CAT_STYLE = {
  '✈️ 航班':       { color: '#3B82F6' },
  '🏨 住宿':       { color: '#8B5CF6' },
  '⛷️ 滑雪':       { color: '#EC4899' },
  '📍 景點':       { color: '#10B981' },
  '🍜 餐廳':       { color: '#F97316' },
  '🚗 交通':       { color: '#D97706' },
  '🅿️ 露營車停車': { color: '#92400E' },
  '⚠️ 注意事項':   { color: '#EF4444' },
};

const DAYS = ['日','一','二','三','四','五','六'];

let tripData = {}, itinerary = [], infoData = [];
let activeFilter = 'all';

async function loadJSON(path) {
  const r = await fetch(path);
  if (!r.ok) throw new Error(`Failed to load ${path}`);
  return r.json();
}

async function init() {
  const config = await loadJSON('data/config.json');
  const sel = document.getElementById('trip-select');

  config.trips.forEach(t => {
    const o = document.createElement('option');
    o.value = t.id;
    o.textContent = t.name;
    sel.appendChild(o);
  });

  const params = new URLSearchParams(location.search);
  const tripId = params.get('trip') || config.trips[0].id;
  sel.value = tripId;

  sel.addEventListener('change', () => switchTrip(sel.value));
  setupTabs();
  await switchTrip(tripId);
}

async function switchTrip(id) {
  try {
    [tripData, itinerary, infoData] = await Promise.all([
      loadJSON(`data/${id}/trip.json`),
      loadJSON(`data/${id}/itinerary.json`),
      loadJSON(`data/${id}/info.json`),
    ]);
  } catch {
    document.getElementById('itinerary-list').innerHTML =
      `<div class="empty"><div class="empty-icon">⚠️</div><div class="empty-title">無法載入資料</div><div class="empty-sub">請先執行 Notion 同步，或確認 JSON 檔案存在</div></div>`;
    return;
  }

  const url = new URL(location.href);
  url.searchParams.set('trip', id);
  history.replaceState({}, '', url);

  activeFilter = 'all';
  renderOverview();
  renderFilterBar();
  renderItinerary();
  renderToday();
  renderInfo();
}

function setupTabs() {
  document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
      tab.classList.add('active');
      document.getElementById(`section-${tab.dataset.tab}`).classList.add('active');
    });
  });
}

/* ── Overview ── */
function renderOverview() {
  const t = tripData;
  const flights = (t.flights || []).map(f => `
    <div class="ov-row">
      <span class="ov-icon">✈️</span>
      <div>
        <div class="ov-label">${f.type}</div>
        <div class="ov-value">${f.date} &nbsp;${f.airline}<br>${f.departure} → ${f.arrival}</div>
      </div>
    </div>`).join('');

  document.getElementById('overview-card').innerHTML = `
    <div class="ov-header">
      <div class="ov-title">${t.title}</div>
      <div class="ov-dates">${t.dateRange.start} → ${t.dateRange.end}</div>
    </div>
    <div class="ov-row">
      <span class="ov-icon">📍</span>
      <div>
        <div class="ov-label">主要區域</div>
        <div class="ov-value">${(t.regions || []).join(' ・ ')}</div>
      </div>
    </div>
    ${flights}
    <div class="ov-row">
      <span class="ov-icon">🚐</span>
      <div>
        <div class="ov-label">${t.vehicle.type}</div>
        <div class="ov-value">${t.vehicle.company}
          ${t.vehicle.phone ? `<a href="tel:${t.vehicle.phone}">${t.vehicle.phone}</a>` : ''}<br>
          取車 ${t.vehicle.pickupDate} ／ 還車 ${t.vehicle.returnDate}
        </div>
      </div>
    </div>`;
}

/* ── Filter bar ── */
function renderFilterBar() {
  const used = new Set(itinerary.map(i => i.category));
  const cats = ['all', ...Object.keys(CAT_STYLE).filter(c => used.has(c))];
  const bar = document.getElementById('filter-bar');

  bar.innerHTML = cats.map(c => {
    const label = c === 'all' ? '全部' : c;
    return `<button class="filter-chip${c === activeFilter ? ' active' : ''}" data-cat="${c}">${label}</button>`;
  }).join('');

  bar.querySelectorAll('.filter-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      activeFilter = chip.dataset.cat;
      bar.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      renderItinerary();
    });
  });
}

/* ── Itinerary ── */
function renderItinerary() {
  const today = todayStr();
  const filtered = activeFilter === 'all' ? itinerary : itinerary.filter(i => i.category === activeFilter);

  const byDate = {};
  filtered.forEach(item => {
    if (!byDate[item.date]) byDate[item.date] = { theme: item.theme, items: [] };
    byDate[item.date].items.push(item);
  });

  if (!Object.keys(byDate).length) {
    document.getElementById('itinerary-list').innerHTML =
      `<div class="empty"><div class="empty-icon">🔍</div><div class="empty-title">沒有符合的行程</div></div>`;
    return;
  }

  document.getElementById('itinerary-list').innerHTML =
    Object.entries(byDate).sort(([a],[b]) => a.localeCompare(b)).map(([date, {theme, items}]) => {
      const d = new Date(date + 'T12:00:00');
      const isToday = date === today;
      return `
        <div class="day-section">
          <div class="day-header">
            <span class="day-date${isToday ? ' is-today' : ''}">${date.slice(5)} (${DAYS[d.getDay()]})</span>
            ${isToday ? '<span class="today-pill">今日</span>' : ''}
            <span class="day-theme">${theme || ''}</span>
          </div>
          ${items.map(itemCard).join('')}
        </div>`;
    }).join('');
}

/* ── Today ── */
function renderToday() {
  const today = todayStr();
  const items = itinerary.filter(i => i.date === today);
  const el = document.getElementById('today-content');

  if (!items.length) {
    const { start, end } = tripData.dateRange || {};
    const msg = today < start ? '旅程尚未開始' : today > end ? '旅程已結束' : '今天沒有排定行程';
    el.innerHTML = `<div class="empty"><div class="empty-icon">📅</div><div class="empty-title">${msg}</div><div class="empty-sub">${start} → ${end}</div></div>`;
    return;
  }

  const d = new Date(today + 'T12:00:00');
  const theme = items[0]?.theme || '';
  el.innerHTML = `
    <div class="today-banner">
      <span class="today-pill">今日</span>
      <span class="today-date-text">${today.slice(5)} (${DAYS[d.getDay()]})</span>
    </div>
    ${theme ? `<div class="today-theme-text">${theme}</div>` : ''}
    ${items.map(itemCard).join('')}`;
}

/* ── Info ── */
function renderInfo() {
  const groups = {};
  infoData.forEach(item => {
    if (!groups[item.category]) groups[item.category] = [];
    groups[item.category].push(item);
  });

  document.getElementById('info-list').innerHTML =
    Object.entries(groups).map(([cat, items]) => `
      <div class="info-group">
        <div class="info-group-label">${cat}</div>
        ${items.map(i => `
          <div class="info-card">
            <div class="info-name">${i.name}</div>
            ${row('內容', i.content)}
            ${row('電話', i.phone ? `<a href="tel:${i.phone}">${i.phone}</a>` : '')}
            ${row('地址', i.address)}
            ${row('備註', i.notes)}
            ${row('連結', i.link ? `<a href="${i.link}" target="_blank">查看 →</a>` : '')}
          </div>`).join('')}
      </div>`).join('');
}

/* ── Helpers ── */
function itemCard(item) {
  const style = CAT_STYLE[item.category] || { color: '#64748B' };
  const maps = item.mapsUrl
    ? `<a class="maps-btn" href="${item.mapsUrl}" target="_blank">📍 地圖</a>` : '';
  const hasFooter = item.transport || item.estimatedCost || item.notes;

  return `
    <div class="item-card" style="border-left-color:${style.color}">
      <div class="item-head">
        <div class="item-time">${item.time || '—'}</div>
        <div class="item-body">
          <span class="item-cat" style="background:${style.color}">${item.category}</span>
          <div class="item-title">${item.title}</div>
          ${item.location ? `<div class="item-loc">📍 ${item.location}</div>` : ''}
        </div>
        ${maps}
      </div>
      ${hasFooter ? `
      <div class="item-foot">
        ${item.transport ? `<div class="item-transport">🚌 ${item.transport}</div>` : ''}
        ${item.estimatedCost ? `<span class="item-cost">¥${item.estimatedCost.toLocaleString()}</span>` : ''}
        ${item.notes ? `<div class="item-note">💡 ${item.notes}</div>` : ''}
      </div>` : ''}
    </div>`;
}

function row(key, val) {
  if (!val) return '';
  return `<div class="info-row"><span class="info-row-key">${key}</span><span>${val}</span></div>`;
}

function todayStr() {
  return new Date().toISOString().split('T')[0];
}

init().catch(console.error);
