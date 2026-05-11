const { Client } = require('@notionhq/client');
const fs = require('fs');
const path = require('path');

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const config = JSON.parse(fs.readFileSync('data/config.json', 'utf-8'));

/* ── Property extractors ── */
const getTitle    = (p, k) => p[k]?.title?.map(t => t.plain_text).join('') || '';
const getRichText = (p, k) => p[k]?.rich_text?.map(t => t.plain_text).join('') || '';
const getSelect   = (p, k) => p[k]?.select?.name || '';
const getDate     = (p, k) => p[k]?.date?.start || '';
const getNumber   = (p, k) => p[k]?.number ?? 0;
const getUrl      = (p, k) => p[k]?.url || '';
const getPhone    = (p, k) => p[k]?.phone_number || '';

async function queryAll(dbId) {
  const pages = [];
  let cursor;
  do {
    const res = await notion.databases.query({
      database_id: dbId,
      start_cursor: cursor,
      page_size: 100,
    });
    pages.push(...res.results);
    cursor = res.has_more ? res.next_cursor : null;
  } while (cursor);
  return pages;
}

async function fetchTripRegistry(dbId) {
  const pages = await queryAll(dbId);
  const trips = pages
    .map(page => {
      const props = page.properties;
      return {
        id: getRichText(props, '行程ID'),
        name: getTitle(props, '名稱'),
        notionPageId: normalizeNotionId(getRichText(props, '行程頁面ID')),
        sort: getNumber(props, '排序'),
        status: getSelect(props, '狀態') || '啟用',
        notionDbs: {
          overview: normalizeNotionId(getRichText(props, '總覽DB')),
          itinerary: normalizeNotionId(getRichText(props, '每日行程DB')),
          info: normalizeNotionId(getRichText(props, '重要資訊DB')),
        },
      };
    })
    .filter(trip =>
      trip.status !== '停用' &&
      trip.id &&
      trip.name &&
      trip.notionDbs.overview &&
      trip.notionDbs.itinerary &&
      trip.notionDbs.info
    )
    .sort((a, b) => (a.sort || 999) - (b.sort || 999) || a.name.localeCompare(b.name));

  return trips.map(({ sort, status, ...trip }) => trip);
}

function writeConfig(trips) {
  const next = { ...config, trips };
  fs.writeFileSync('data/config.json', `${JSON.stringify(next, null, 2)}\n`);
  console.log(`✅ data/config.json — ${trips.length} trips`);
}

async function fetchItinerary(tripId, dbId) {
  const pages = await queryAll(dbId);
  const items = pages
    .map(p => {
      const props = p.properties;
      return {
        date:          getDate(props, '日期'),
        theme:         getRichText(props, '當日主題'),
        time:          getRichText(props, '時間'),
        category:      getSelect(props, '分類'),
        title:         getTitle(props, '名稱'),
        location:      getRichText(props, '地點'),
        mapsUrl:       getUrl(props, '地圖連結'),
        transport:     getRichText(props, '交通方式'),
        estimatedCost: getNumber(props, '預估費用'),
        notes:         getRichText(props, '備註'),
      };
    })
    .filter(i => i.date)
    .sort((a, b) => {
      const byDate = a.date.localeCompare(b.date);
      return byDate !== 0 ? byDate : (a.time || '').localeCompare(b.time || '');
    });

  write(tripId, 'itinerary.json', items);
  console.log(`✅ ${tripId}/itinerary.json — ${items.length} 筆`);
}

async function fetchInfo(tripId, dbId) {
  const pages = await queryAll(dbId);
  const items = pages.map(p => {
    const props = p.properties;
    return {
      category: getSelect(props, '分類'),
      name:     getTitle(props, '名稱'),
      content:  getRichText(props, '內容'),
      phone:    getPhone(props, '電話'),
      address:  getRichText(props, '地址'),
      notes:    getRichText(props, '備註'),
      link:     getUrl(props, '連結'),
    };
  });

  write(tripId, 'info.json', items);
  console.log(`✅ ${tripId}/info.json — ${items.length} 筆`);
}

async function fetchOverview(tripId, dbId) {
  const pages = await queryAll(dbId);
  const rows = pages.map(p => {
    const props = p.properties;
    return {
      type:       getSelect(props, '類型'),
      name:       getTitle(props, '名稱'),
      content:    getRichText(props, '內容'),
      flightInfo: getRichText(props, '機票航班資訊') || getRichText(props, '航班資訊'),
      date:       getDate(props, '日期'),
      phone:      getPhone(props, '電話'),
      link:       getUrl(props, '連結'),
      notes:      getRichText(props, '備註'),
    };
  });

  // Read existing trip.json and merge overview rows into it
  const tripPath = path.join('data', tripId, 'trip.json');
  const existing = JSON.parse(fs.readFileSync(tripPath, 'utf-8'));

  const flights = rows
    .filter(isFlightRow)
    .map(toFlight)
    .sort((a, b) => {
      const rank = { outbound: 0, unknown: 1, inbound: 2 };
      const byDirection = rank[flightDirection(a)] - rank[flightDirection(b)];
      return byDirection || (a.date || '').localeCompare(b.date || '');
    });

  const dateRow = rows.find(r => r.type === '日期範圍');
  const vehicleRow = rows.find(r => r.type === '租車/露營車');
  const regionRow = rows.find(r => r.type === '主要區域');

  const merged = {
    ...existing,
    ...(dateRow?.date && { dateRange: { start: dateRow.date, end: dateRow.notes || dateRow.date } }),
    ...(regionRow && { regions: regionRow.content.split('・').map(s => s.trim()).filter(Boolean) }),
    ...(flights.length && { flights }),
    ...(vehicleRow && {
      vehicle: {
        ...existing.vehicle,
        company: vehicleRow.content || existing.vehicle?.company || '',
        phone:   vehicleRow.phone  || existing.vehicle?.phone   || '',
      },
    }),
  };

  write(tripId, 'trip.json', merged);
  console.log(`✅ ${tripId}/trip.json — updated`);
}

function isFlightRow(row) {
  return /航班|機票/.test(`${row.type || ''} ${row.name || ''}`) || Boolean(row.flightInfo);
}

function toFlight(row) {
  const route = parseFlightRoute(row.notes || row.flightInfo || '');
  return {
    type:       row.name || row.type,
    airline:    row.content,
    ticketInfo: row.flightInfo || row.content,
    date:       row.date,
    departure:  route.departure,
    arrival:    route.arrival,
    link:       row.link,
    notes:      row.notes,
  };
}

function parseFlightRoute(text) {
  const [departure = '', arrival = ''] = (text || '').split(/→|->/).map(s => s.trim());
  return { departure, arrival };
}

function flightDirection(flight) {
  const text = `${flight.type || ''} ${flight.departure || ''} ${flight.arrival || ''}`;
  if (/回程|返程|return|inbound/i.test(text)) return 'inbound';
  if (/去程|outbound/i.test(text)) return 'outbound';
  if (/^TPE\b/.test(flight.departure || '')) return 'outbound';
  if (/^TPE\b/.test(flight.arrival || '')) return 'inbound';
  return 'unknown';
}

function write(tripId, filename, data) {
  const dir = path.join('data', tripId);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, filename), JSON.stringify(data, null, 2));
}

async function main() {
  const trips = config.tripRegistryDb
    ? await fetchTripRegistry(config.tripRegistryDb)
    : config.trips;
  const target = process.argv[2]; // optional: run only one trip

  if (!target && config.tripRegistryDb) writeConfig(trips);

  for (const trip of trips) {
    if (target && trip.id !== target) continue;
    console.log(`\n🔄 Syncing: ${trip.name}`);
    const { overview, itinerary, info } = trip.notionDbs;
    await fetchItinerary(trip.id, itinerary);
    await fetchInfo(trip.id, info);
    await fetchOverview(trip.id, overview);
  }

  console.log('\n✅ 同步完成');
}

function normalizeNotionId(value) {
  return (value || '').replace(/-/g, '').trim();
}

main().catch(err => { console.error(err); process.exit(1); });
