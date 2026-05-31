const { Client } = require('@notionhq/client');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const tripId = args[0];
const flags = args.filter(arg => arg.startsWith('--'));
const explicitDatabaseId = args.slice(1).find(arg => !arg.startsWith('--'));
const dryRun = flags.includes('--dry-run');
const forceCreate = flags.includes('--force-create');

if (!tripId) {
  console.error('Usage: node scripts/push-static-trip-to-notion.js <tripId> [itineraryDatabaseId] [--dry-run] [--force-create]');
  process.exit(1);
}

if (!dryRun && !process.env.NOTION_TOKEN) {
  console.error('Missing NOTION_TOKEN. Use --dry-run to preview without writing.');
  process.exit(1);
}

const root = path.resolve(__dirname, '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'data/config.json'), 'utf8'));
const trip = config.trips.find(item => item.id === tripId);
const databaseId = explicitDatabaseId || trip?.notionDbs?.itinerary;
const itineraryPath = path.join(root, 'data', tripId, 'itinerary.json');

if (!fs.existsSync(itineraryPath)) {
  console.error(`Missing itinerary JSON: ${itineraryPath}`);
  process.exit(1);
}

if (!dryRun && !databaseId) {
  console.error(`Missing Notion itinerary database id for ${tripId}`);
  process.exit(1);
}

const notion = dryRun ? null : new Client({ auth: process.env.NOTION_TOKEN });
const itinerary = JSON.parse(fs.readFileSync(itineraryPath, 'utf8'));

function richText(value) {
  const text = String(value || '');
  if (!text) return { rich_text: [] };
  const chunks = text.match(/[\s\S]{1,1900}/g) || [];
  return {
    rich_text: chunks.slice(0, 20).map(content => ({
      text: { content },
    })),
  };
}

function titleText(value) {
  return {
    title: [
      {
        text: {
          content: String(value || '未命名行程').slice(0, 1900),
        },
      },
    ],
  };
}

function select(name) {
  return name ? { select: { name } } : { select: null };
}

function number(value) {
  return { number: Number(value || 0) };
}

function url(value) {
  return { url: value || null };
}

function propertiesFor(item) {
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

function titleOf(page) {
  return page.properties?.['名稱']?.title?.map(item => item.plain_text).join('') || '';
}

async function queryExistingByDate(databaseId, date) {
  const pages = [];
  let cursor;
  do {
    const response = await notion.databases.query({
      database_id: databaseId,
      start_cursor: cursor,
      page_size: 100,
      filter: {
        property: '日期',
        date: { equals: date },
      },
    });
    pages.push(...response.results);
    cursor = response.has_more ? response.next_cursor : null;
  } while (cursor);
  return pages;
}

async function sleep(ms) {
  await new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  const usable = itinerary.filter(item => item.date && item.title);
  console.log(`${dryRun ? 'Preview' : 'Writing'} ${usable.length} itinerary rows for ${tripId}`);

  if (dryRun) {
    const grouped = usable.reduce((acc, item) => {
      acc[item.date] = (acc[item.date] || 0) + 1;
      return acc;
    }, {});
    console.table(grouped);
    console.log('Sample rows:');
    usable.slice(0, 12).forEach(item => {
      console.log(`${item.date} ${item.time || '--:--'} ${item.category} ${item.title}`);
    });
    return;
  }

  const existingByKey = new Map();
  if (!forceCreate) {
    for (const date of [...new Set(usable.map(item => item.date))]) {
      const pages = await queryExistingByDate(databaseId, date);
      pages.forEach(page => existingByKey.set(`${date}::${titleOf(page)}`, page.id));
      await sleep(350);
    }
  }

  let created = 0;
  let updated = 0;
  for (const item of usable) {
    const key = `${item.date}::${item.title}`;
    const existingPageId = existingByKey.get(key);
    if (existingPageId) {
      await notion.pages.update({
        page_id: existingPageId,
        properties: propertiesFor(item),
      });
      updated += 1;
    } else {
      await notion.pages.create({
        parent: { database_id: databaseId },
        properties: propertiesFor(item),
      });
      created += 1;
    }
    await sleep(350);
  }

  console.log(`Done. created=${created}, updated=${updated}`);
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
