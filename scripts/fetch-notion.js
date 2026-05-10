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
      type:    getSelect(props, '類型'),
      name:    getTitle(props, '名稱'),
      content: getRichText(props, '內容'),
      date:    getDate(props, '日期'),
      phone:   getPhone(props, '電話'),
      link:    getUrl(props, '連結'),
      notes:   getRichText(props, '備註'),
    };
  });

  // Read existing trip.json and merge overview rows into it
  const tripPath = path.join('data', tripId, 'trip.json');
  const existing = JSON.parse(fs.readFileSync(tripPath, 'utf-8'));

  const flights = rows
    .filter(r => r.type === '航班')
    .map(r => ({
      type:      r.name,
      airline:   r.content,
      date:      r.date,
      departure: (r.notes || '').split('→')[0]?.trim() || '',
      arrival:   (r.notes || '').split('→')[1]?.trim() || '',
    }));

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

function write(tripId, filename, data) {
  const dir = path.join('data', tripId);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, filename), JSON.stringify(data, null, 2));
}

async function main() {
  const trips = config.trips;
  const target = process.argv[2]; // optional: run only one trip

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

main().catch(err => { console.error(err); process.exit(1); });
