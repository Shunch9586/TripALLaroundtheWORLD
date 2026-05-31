const { Client } = require('@notionhq/client');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const tripId = args[0];
const flags = new Set(args.filter(arg => arg.startsWith('--')));
const dryRun = flags.has('--dry-run');

if (!tripId) {
  console.error('Usage: node scripts/setup-static-trip-notion.js <tripId|all> [--dry-run]');
  process.exit(1);
}

if (!dryRun && !process.env.NOTION_TOKEN) {
  console.error('Missing NOTION_TOKEN');
  process.exit(1);
}

const root = path.resolve(__dirname, '..');
const configPath = path.join(root, 'data/config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const notion = dryRun ? null : new Client({ auth: process.env.NOTION_TOKEN });

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJSON(file, data) {
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}

function normalizeId(id) {
  return String(id || '').replace(/-/g, '');
}

function richText(value) {
  const text = String(value || '');
  if (!text) return { rich_text: [] };
  return {
    rich_text: (text.match(/[\s\S]{1,1900}/g) || []).slice(0, 20).map(content => ({
      text: { content },
    })),
  };
}

function titleText(value) {
  return {
    title: [
      {
        text: {
          content: String(value || '未命名').slice(0, 1900),
        },
      },
    ],
  };
}

function select(name) {
  return name ? { select: { name } } : { select: null };
}

function url(value) {
  return { url: value || null };
}

function phone(value) {
  return { phone_number: value || null };
}

function number(value) {
  return { number: Number(value || 0) };
}

function registryProperties(trip, notionPageId = '', notionDbs = {}) {
  return {
    '名稱': titleText(trip.name),
    '行程ID': richText(trip.id),
    '行程頁面ID': richText(normalizeId(notionPageId)),
    '排序': number(trip.sort || 900),
    '狀態': select('啟用'),
    '總覽DB': richText(normalizeId(notionDbs.overview)),
    '每日行程DB': richText(normalizeId(notionDbs.itinerary)),
    '重要資訊DB': richText(normalizeId(notionDbs.info)),
  };
}

function itineraryProperties(item) {
  return {
    '日期': { date: item.date ? { start: item.date } : null },
    '當日主題': richText(item.theme),
    '時間': richText(item.time),
    '分類': select(item.category || '📍 景點'),
    '名稱': titleText(item.title),
    '地點': richText(item.location),
    '地圖連結': url(item.mapsUrl),
    '交通方式': richText(item.transport),
    '預估費用': number(item.estimatedCost),
    '備註': richText(item.notes),
  };
}

function infoProperties(item) {
  return {
    '分類': select(item.category || '重要資訊'),
    '名稱': titleText(item.name),
    '內容': richText(item.content),
    '電話': phone(item.phone),
    '地址': richText(item.address),
    '備註': richText(item.notes),
    '連結': url(item.link),
  };
}

function overviewProperties(row) {
  return {
    '類型': select(row.type),
    '名稱': titleText(row.name),
    '內容': richText(row.content),
    '航班方向': select(row.flightDirection),
    '航班編號': richText(row.flightNumber),
    '出發': richText(row.departure),
    '抵達': richText(row.arrival),
    '機型': richText(row.aircraft),
    '訂位代號': richText(row.bookingCode),
    '機票號碼': richText(row.ticketNumber),
    '機票航班資訊': richText(row.flightInfo),
    '日期': { date: row.date ? { start: row.date } : null },
    '電話': phone(row.phone),
    '連結': url(row.link),
    '備註': richText(row.notes),
  };
}

function titleOf(page) {
  return page.properties?.['名稱']?.title?.map(item => item.plain_text).join('') || '';
}

async function queryExistingRegistryPage(tripId) {
  const response = await notion.databases.query({
    database_id: config.tripRegistryDb,
    filter: {
      property: '行程ID',
      rich_text: { equals: tripId },
    },
    page_size: 1,
  });
  return response.results[0] || null;
}

async function createDatabase(parentPageId, title, properties) {
  const database = await notion.databases.create({
    parent: { page_id: parentPageId },
    title: [{ text: { content: title } }],
    properties,
  });
  return database.id;
}

async function ensureTripPage(trip) {
  const existing = await queryExistingRegistryPage(trip.id);
  if (existing) return existing.id;

  const created = await notion.pages.create({
    parent: { database_id: config.tripRegistryDb },
    properties: registryProperties(trip),
  });
  return created.id;
}

async function ensureDatabases(trip, pageId) {
  if (trip.notionDbs?.overview && trip.notionDbs?.itinerary && trip.notionDbs?.info) {
    return trip.notionDbs;
  }

  const overview = await createDatabase(pageId, '總覽', {
    '名稱': { title: {} },
    '類型': { select: {} },
    '內容': { rich_text: {} },
    '航班方向': { select: {} },
    '航班編號': { rich_text: {} },
    '出發': { rich_text: {} },
    '抵達': { rich_text: {} },
    '機型': { rich_text: {} },
    '訂位代號': { rich_text: {} },
    '機票號碼': { rich_text: {} },
    '機票航班資訊': { rich_text: {} },
    '日期': { date: {} },
    '電話': { phone_number: {} },
    '連結': { url: {} },
    '備註': { rich_text: {} },
  });

  const itinerary = await createDatabase(pageId, '每日行程', {
    '名稱': { title: {} },
    '日期': { date: {} },
    '當日主題': { rich_text: {} },
    '時間': { rich_text: {} },
    '分類': { select: {} },
    '地點': { rich_text: {} },
    '地圖連結': { url: {} },
    '交通方式': { rich_text: {} },
    '預估費用': { number: { format: 'number' } },
    '備註': { rich_text: {} },
  });

  const info = await createDatabase(pageId, '重要資訊', {
    '名稱': { title: {} },
    '分類': { select: {} },
    '內容': { rich_text: {} },
    '電話': { phone_number: {} },
    '地址': { rich_text: {} },
    '備註': { rich_text: {} },
    '連結': { url: {} },
  });

  return {
    overview: normalizeId(overview),
    itinerary: normalizeId(itinerary),
    info: normalizeId(info),
  };
}

async function clearDatabase(databaseId) {
  let cursor;
  do {
    const response = await notion.databases.query({
      database_id: databaseId,
      start_cursor: cursor,
      page_size: 100,
    });
    for (const page of response.results) {
      await notion.pages.update({ page_id: page.id, archived: true });
      await sleep(120);
    }
    cursor = response.has_more ? response.next_cursor : null;
  } while (cursor);
}

async function createRows(databaseId, rows, toProperties) {
  for (const row of rows) {
    await notion.pages.create({
      parent: { database_id: databaseId },
      properties: toProperties(row),
    });
    await sleep(180);
  }
}

function overviewRows(tripData) {
  return [
    {
      type: '日期範圍',
      name: tripData.title,
      content: '',
      date: tripData.dateRange.start,
      notes: tripData.dateRange.end,
    },
    {
      type: '主要區域',
      name: '主要區域',
      content: (tripData.regions || []).join('・'),
    },
    ...((tripData.flights || []).map(flight => ({
      type: '航班',
      name: flight.type,
      content: flight.airline,
      flightDirection: flight.direction,
      flightNumber: flight.flightNumber,
      departure: flight.departure,
      arrival: flight.arrival,
      aircraft: flight.aircraft,
      bookingCode: flight.bookingCode,
      ticketNumber: flight.ticketNumber,
      flightInfo: flight.ticketInfo,
      date: flight.date,
      link: flight.link,
      notes: flight.notes,
    }))),
    {
      type: '租車/露營車',
      name: tripData.vehicle?.type || '租車',
      content: tripData.vehicle?.company || '',
      phone: tripData.vehicle?.phone || '',
      notes: [
        tripData.vehicle?.pickupDate && `取車 ${tripData.vehicle.pickupDate} ${tripData.vehicle.pickupTime || ''}`,
        tripData.vehicle?.returnDate && `還車 ${tripData.vehicle.returnDate} ${tripData.vehicle.returnTime || ''}`,
        tripData.vehicle?.rentalCode && `預約代號 ${tripData.vehicle.rentalCode}`,
        tripData.vehicle?.notes,
      ].filter(Boolean).join('\n'),
    },
  ];
}

function localTripFiles(tripId) {
  const dir = path.join(root, 'data', tripId);
  return {
    trip: readJSON(path.join(dir, 'trip.json')),
    itinerary: readJSON(path.join(dir, 'itinerary.json')).filter(item => item.date && item.title),
    info: readJSON(path.join(dir, 'info.json')).filter(item => item.name),
  };
}

function updateLocalConfig(trip, pageId, notionDbs) {
  const index = config.trips.findIndex(item => item.id === trip.id);
  const nextTrip = {
    id: trip.id,
    name: trip.name,
    notionPageId: normalizeId(pageId),
    notionDbs: {
      overview: normalizeId(notionDbs.overview),
      itinerary: normalizeId(notionDbs.itinerary),
      info: normalizeId(notionDbs.info),
    },
  };

  if (index >= 0) {
    config.trips[index] = nextTrip;
  } else {
    config.trips.push(nextTrip);
  }
  writeJSON(configPath, config);
}

async function sleep(ms) {
  await new Promise(resolve => setTimeout(resolve, ms));
}

async function setupTrip(trip) {
  const files = localTripFiles(trip.id);
  if (dryRun) {
    console.log(`[dry-run] ${trip.id}: overview=${overviewRows(files.trip).length}, itinerary=${files.itinerary.length}, info=${files.info.length}`);
    return;
  }

  console.log(`Setting up Notion trip: ${trip.name}`);
  const pageId = await ensureTripPage(trip);
  const notionDbs = await ensureDatabases(trip, pageId);

  await notion.pages.update({
    page_id: pageId,
    properties: registryProperties(trip, pageId, notionDbs),
  });

  await clearDatabase(notionDbs.overview);
  await clearDatabase(notionDbs.itinerary);
  await clearDatabase(notionDbs.info);

  await createRows(notionDbs.overview, overviewRows(files.trip), overviewProperties);
  await createRows(notionDbs.itinerary, files.itinerary, itineraryProperties);
  await createRows(notionDbs.info, files.info, infoProperties);

  updateLocalConfig(trip, pageId, notionDbs);
  console.log(`Done: ${trip.id}`);
}

async function main() {
  const trips = config.trips.filter(trip => {
    if (tripId === 'all') return trip.source === 'static';
    return trip.id === tripId;
  });

  if (!trips.length) {
    console.error(`No matching static trip: ${tripId}`);
    process.exit(1);
  }

  for (const trip of trips) {
    await setupTrip(trip);
  }
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
