const CAT_STYLE = {
  '✈️ 航班':       { color: '#2563EB', tone: '#DBEAFE' },
  '🏨 住宿':       { color: '#7C3AED', tone: '#EDE9FE' },
  '⛷️ 滑雪':       { color: '#DB2777', tone: '#FCE7F3' },
  '📍 景點':       { color: '#059669', tone: '#D1FAE5' },
  '🍜 餐廳':       { color: '#EA580C', tone: '#FFEDD5' },
  '🚗 交通':       { color: '#B45309', tone: '#FEF3C7' },
  '🅿️ 露營車停車': { color: '#854D0E', tone: '#FEF3C7' },
  '⚠️ 注意事項':   { color: '#DC2626', tone: '#FEE2E2' },
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
  document.body.dataset.trip = id;

  activeFilter = 'all';
  renderOverview();
  renderFilterBar();
  renderDateJump();
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
  if (currentDesign() === 'option3') {
    renderOverviewConsole();
    return;
  }

  const t = tripData;
  const status = tripStatus();
  const next = nextItem();
  const flights = sortedFlights().map(f => `
    <div class="ov-row">
      <span class="ov-icon">✈️</span>
      <div>
        <div class="ov-label">${f.type}</div>
        <div class="ov-value">${f.date} &nbsp;${f.airline}<br>${f.departure} → ${f.arrival}</div>
      </div>
    </div>`).join('');

  document.getElementById('overview-card').innerHTML = `
    <div class="ov-header">
      <div class="ov-kicker">${status.label}</div>
      <div class="ov-title">${t.title}</div>
      <div class="ov-dates">${formatDate(t.dateRange.start)} → ${formatDate(t.dateRange.end)}</div>
      ${next ? `
        <div class="next-card">
          <div class="next-label">下一個行程</div>
          <div class="next-title">${next.time || '時間未定'} · ${next.title}</div>
          <div class="next-meta">${formatDate(next.date)} ${next.location ? ` · ${next.location}` : ''}</div>
        </div>` : ''}
    </div>
    <div class="ov-grid">
      <div class="ov-stat">
        <span>天數</span>
        <strong>${tripDays()}</strong>
      </div>
      <div class="ov-stat">
        <span>行程</span>
        <strong>${itinerary.length}</strong>
      </div>
      <div class="ov-stat">
        <span>狀態</span>
        <strong>${status.short}</strong>
      </div>
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
          取車 ${formatDate(t.vehicle.pickupDate)} ${t.vehicle.pickupTime || ''} ／ 還車 ${formatDate(t.vehicle.returnDate)} ${t.vehicle.returnTime || ''}
          ${t.vehicle.rentalCode ? `<br>代號 ${t.vehicle.rentalCode}` : ''}
        </div>
      </div>
    </div>`;
}

function renderOverviewConsole() {
  const t = tripData;
  const status = tripStatus();
  const next = nextItem();
  const flights = sortedFlights();
  const outbound = flights.find(f => flightDirection(f) === 'outbound') || flights[0];
  const inbound = flights.find(f => flightDirection(f) === 'inbound') || flights[flights.length - 1];

  document.getElementById('overview-card').innerHTML = `
    <div class="console-hero">
      <div class="console-route">
        <span>${airportCode(outbound?.departure) || 'TPE'}</span>
        <i></i>
        <span>${airportCode(outbound?.arrival) || 'CTS'}</span>
      </div>
      <div class="console-title">${t.title}</div>
      <div class="console-meta">${formatDate(t.dateRange.start)} - ${formatDate(t.dateRange.end)} · ${status.label}</div>
    </div>
    <div class="console-strip">
      <div><span>Days</span><strong>${tripDays()}</strong></div>
      <div><span>Stops</span><strong>${(t.regions || []).length}</strong></div>
      <div><span>Plans</span><strong>${itinerary.length}</strong></div>
      <div><span>Mode</span><strong>${t.vehicle?.type || 'Trip'}</strong></div>
    </div>
    <div class="console-grid">
      <div class="console-panel">
        <span>Regions</span>
        <strong>${(t.regions || []).join(' / ')}</strong>
      </div>
      <div class="console-panel">
        <span>Next</span>
        <strong>${next ? `${formatDate(next.date)} ${next.time || ''} · ${next.title}` : '尚未排定'}</strong>
      </div>
      <div class="console-panel">
        <span>Vehicle</span>
        <strong>${t.vehicle?.rentalCode || t.vehicle?.company || '未設定'}${t.vehicle?.phone ? ` · ${t.vehicle.phone}` : ''}</strong>
      </div>
      <div class="console-panel">
        <span>Return</span>
        <strong>${inbound ? `${formatDate(inbound.date)} · ${inbound.departure} → ${inbound.arrival}` : '未設定'}</strong>
      </div>
    </div>
    ${flights.length ? `
      <div class="console-flights">
        ${flights.map(flightCard).join('')}
      </div>` : ''}`;
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
      renderDateJump();
      renderItinerary();
    });
  });
}

/* ── Date jump ── */
function renderDateJump() {
  const dates = itineraryDates();
  const el = document.getElementById('date-jump');
  if (!el) return;

  if (!dates.length) {
    el.innerHTML = '';
    return;
  }

  el.innerHTML = dates.map((date, index) => {
    const d = new Date(date + 'T12:00:00');
    return `
      <button class="date-chip" data-date="${date}">
        <span>DAY ${String(index + 1).padStart(2, '0')}</span>
        <strong>${date.slice(5)}</strong>
        <em>${DAYS[d.getDay()]}</em>
      </button>`;
  }).join('');

  el.querySelectorAll('.date-chip').forEach(button => {
    button.addEventListener('click', () => {
      const target = document.getElementById(dayElementId(button.dataset.date));
      if (!target) return;
      el.querySelectorAll('.date-chip').forEach(chip => chip.classList.remove('active'));
      button.classList.add('active');
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });
}

/* ── Itinerary ── */
function renderItinerary() {
  if (currentDesign() === 'option3') {
    renderItineraryTickets();
    return;
  }

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
        <div class="day-section" id="${dayElementId(date)}">
          <div class="day-header">
            <span class="day-date${isToday ? ' is-today' : ''}">${date.slice(5)} (${DAYS[d.getDay()]})</span>
            ${isToday ? '<span class="today-pill">今日</span>' : ''}
            <span class="day-theme">${theme || ''}</span>
          </div>
          ${items.map(itemCard).join('')}
        </div>`;
    }).join('');
}

function renderItineraryTickets() {
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
    `<div class="ticket-board">` +
    Object.entries(byDate).sort(([a],[b]) => a.localeCompare(b)).map(([date, { theme, items }], index) => {
      const d = new Date(date + 'T12:00:00');
      const isToday = date === today;
      return `
        <section class="ticket-day${isToday ? ' is-today' : ''}" id="${dayElementId(date)}">
          <aside class="ticket-date">
            <span>DAY ${String(index + 1).padStart(2, '0')}</span>
            <strong>${date.slice(5)}</strong>
            <em>${DAYS[d.getDay()]}</em>
          </aside>
          <div class="ticket-stack">
            <div class="ticket-day-title">
              <span>${theme || '自由行程'}</span>
              ${isToday ? '<b>今日</b>' : ''}
            </div>
            ${items.map(ticketCard).join('')}
          </div>
        </section>`;
    }).join('') +
    `</div>`;
}

/* ── Today ── */
function renderToday() {
  const today = todayStr();
  const items = itinerary.filter(i => i.date === today);
  const el = document.getElementById('today-content');
  const status = tripStatus();

  if (!items.length) {
    const { start, end } = tripData.dateRange || {};
    const msg = today < start ? '旅程尚未開始' : today > end ? '旅程已結束' : '今天沒有排定行程';
    const next = nextItem();
    el.innerHTML = `
      <div class="today-hero">
        <div>
          <div class="today-label">${status.label}</div>
          <div class="today-heading">${msg}</div>
          <div class="today-sub">${formatDate(start)} → ${formatDate(end)}</div>
        </div>
      </div>
      ${next ? `
        <div class="dashboard-card">
          <div class="dashboard-label">下一個行程</div>
          ${itemCard(next)}
        </div>` : ''}
      ${quickActions()}`;
    return;
  }

  const d = new Date(today + 'T12:00:00');
  const theme = items[0]?.theme || '';
  el.innerHTML = `
    <div class="today-hero">
      <div>
        <div class="today-label">今日行程</div>
        <div class="today-heading">${today.slice(5)} (${DAYS[d.getDay()]})</div>
        ${theme ? `<div class="today-sub">${theme}</div>` : ''}
      </div>
      <span class="today-count">${items.length} 項</span>
    </div>
    ${quickActions()}
    <div class="dashboard-card">
      <div class="dashboard-label">時間表</div>
      ${items.map(itemCard).join('')}
    </div>`;
}

/* ── Info ── */
function renderInfo() {
  const groups = {};
  infoData.forEach(item => {
    if (!groups[item.category]) groups[item.category] = [];
    groups[item.category].push(item);
  });

  if (!Object.keys(groups).length) {
    document.getElementById('info-list').innerHTML = `
      ${quickActions()}
      <div class="empty"><div class="empty-icon">ℹ️</div><div class="empty-title">尚未同步重要資訊</div><div class="empty-sub">Notion 重要資訊資料庫目前沒有可顯示的資料</div></div>`;
    return;
  }

  document.getElementById('info-list').innerHTML =
    quickActions() +
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
  const style = CAT_STYLE[item.category] || { color: '#64748B', tone: '#F1F5F9' };
  const maps = item.mapsUrl
    ? `<a class="maps-btn" href="${item.mapsUrl}" target="_blank" rel="noreferrer">地圖</a>` : '';
  const hasFooter = item.transport || item.estimatedCost || item.notes;

  return `
    <div class="item-card" style="--cat:${style.color}; --cat-tone:${style.tone}">
      <div class="item-head">
        <div class="item-time">${item.time || '—'}</div>
        <div class="item-body">
          <span class="item-cat">${item.category}</span>
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

function ticketCard(item) {
  const style = CAT_STYLE[item.category] || { color: '#64748B', tone: '#F1F5F9' };
  const maps = item.mapsUrl
    ? `<a class="ticket-map" href="${item.mapsUrl}" target="_blank" rel="noreferrer">MAP</a>` : '';
  const details = [
    item.location ? `<span>LOC · ${item.location}</span>` : '',
    item.transport ? `<span>MOVE · ${item.transport}</span>` : '',
    item.estimatedCost ? `<span>COST · ¥${item.estimatedCost.toLocaleString()}</span>` : '',
    item.notes ? `<span>NOTE · ${item.notes}</span>` : '',
  ].filter(Boolean).join('');

  return `
    <article class="ticket-card" style="--cat:${style.color}; --cat-tone:${style.tone}">
      <div class="ticket-time">${item.time || '--:--'}</div>
      <div class="ticket-main">
        <div class="ticket-cat">${item.category || '行程'}</div>
        <h3>${item.title}</h3>
        ${details ? `<div class="ticket-details">${details}</div>` : ''}
      </div>
      ${maps}
    </article>`;
}

function flightCard(flight) {
  const direction = flightDirection(flight);
  const label = direction === 'inbound' ? 'RETURN' : 'OUTBOUND';
  return `
    <div class="flight-card">
      <div class="flight-label">${label}</div>
      <div class="flight-code">${flight.airline || flight.type}</div>
      <div class="flight-route">
        <strong>${flight.departure || '未定'}</strong>
        <span>→</span>
        <strong>${flight.arrival || '未定'}</strong>
      </div>
      <div class="flight-date">${formatDate(flight.date)} · ${flight.type || ''}</div>
    </div>`;
}

function row(key, val) {
  if (!val) return '';
  return `<div class="info-row"><span class="info-row-key">${key}</span><span>${val}</span></div>`;
}

function itineraryDates() {
  const filtered = activeFilter === 'all' ? itinerary : itinerary.filter(i => i.category === activeFilter);
  return [...new Set(filtered.map(item => item.date).filter(Boolean))].sort((a, b) => a.localeCompare(b));
}

function todayStr() {
  return new Date().toISOString().split('T')[0];
}

function formatDate(date) {
  if (!date) return '';
  return date.replace(/^(\d{4})-(\d{2})-(\d{2})$/, '$1/$2/$3');
}

function tripDays() {
  const { start, end } = tripData.dateRange || {};
  if (!start || !end) return '—';
  const startDate = new Date(start + 'T12:00:00');
  const endDate = new Date(end + 'T12:00:00');
  return Math.round((endDate - startDate) / 86400000) + 1;
}

function tripStatus() {
  const today = todayStr();
  const { start, end } = tripData.dateRange || {};
  if (!start || !end) return { label: '旅程', short: '未定' };
  if (today < start) return { label: '即將出發', short: '未開始' };
  if (today > end) return { label: '旅程已結束', short: '完成' };
  return { label: '旅途中', short: '進行中' };
}

function nextItem() {
  const today = todayStr();
  return itinerary.find(item => item.date >= today) || itinerary[0];
}

function quickActions() {
  const phone = tripData.vehicle?.phone;
  const code = tripData.vehicle?.rentalCode;
  const nav = tripData.vehicle?.notes;

  if (!phone && !code && !nav) return '';

  return `
    <div class="quick-grid">
      ${phone ? `<a class="quick-card" href="tel:${phone}"><span>租車電話</span><strong>${phone}</strong></a>` : ''}
      ${code ? `<div class="quick-card"><span>租車代號</span><strong>${code}</strong></div>` : ''}
      ${nav ? `<div class="quick-card quick-wide"><span>提醒</span><strong>${nav}</strong></div>` : ''}
    </div>`;
}

function currentDesign() {
  return document.documentElement.dataset.design || 'option1';
}

function dayElementId(date) {
  return `day-${date}`;
}

function sortedFlights() {
  return [...(tripData.flights || [])].sort((a, b) => {
    const rank = { outbound: 0, unknown: 1, inbound: 2 };
    const byDirection = rank[flightDirection(a)] - rank[flightDirection(b)];
    if (byDirection !== 0) return byDirection;
    return (a.date || '').localeCompare(b.date || '');
  });
}

function flightDirection(flight) {
  const text = `${flight?.type || ''} ${flight?.departure || ''} ${flight?.arrival || ''}`;
  if (/回程|返程|return|inbound/i.test(text)) return 'inbound';
  if (/去程|outbound/i.test(text)) return 'outbound';
  if (/^TPE\b/.test(flight?.departure || '')) return 'outbound';
  if (/^TPE\b/.test(flight?.arrival || '')) return 'inbound';
  return 'unknown';
}

function airportCode(value) {
  return (value || '').match(/[A-Z]{3}/)?.[0] || '';
}

init().catch(console.error);
