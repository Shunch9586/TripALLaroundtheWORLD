const { Client } = require('@notionhq/client');
const fs = require('fs');

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const config = JSON.parse(fs.readFileSync('data/config.json', 'utf-8'));

const [tripId, date, title, location, notes] = process.argv.slice(2);

if (!process.env.NOTION_TOKEN) {
  console.error('Missing NOTION_TOKEN');
  process.exit(1);
}

if (!tripId || !date || !title || !location || !notes) {
  console.error('Usage: node scripts/upsert-notion-itinerary.js <tripId> <date> <title> <location> <notes>');
  process.exit(1);
}

const trip = config.trips.find(item => item.id === tripId);

if (!trip?.notionDbs?.itinerary) {
  console.error(`Unknown trip or missing itinerary DB: ${tripId}`);
  process.exit(1);
}

function richText(value) {
  return {
    rich_text: [
      {
        text: {
          content: value,
        },
      },
    ],
  };
}

function titleText(value) {
  return {
    title: [
      {
        text: {
          content: value,
        },
      },
    ],
  };
}

function select(name) {
  return { select: { name } };
}

async function findExistingPage(databaseId) {
  const res = await notion.databases.query({
    database_id: databaseId,
    filter: {
      property: '日期',
      date: {
        equals: date,
      },
    },
    page_size: 100,
  });

  return res.results.find(page => {
    const props = page.properties;
    const pageTitle = props['名稱']?.title?.map(item => item.plain_text).join('') || '';
    const category = props['分類']?.select?.name || '';
    return /露營車.*(停車|住宿)|停車地點/.test(pageTitle) || /注意事項|住宿/.test(category);
  });
}

async function main() {
  const databaseId = trip.notionDbs.itinerary;
  const properties = {
    '日期': { date: { start: date } },
    '當日主題': richText('留壽都滑雪・洞爺湖湖畔車宿'),
    '時間': richText('夜間'),
    '分類': select('🏨 住宿'),
    '名稱': titleText(title),
    '地點': richText(location),
    '地圖連結': { url: null },
    '交通方式': richText('露營車'),
    '預估費用': { number: 0 },
    '備註': richText(notes),
  };

  const existingPage = await findExistingPage(databaseId);

  if (existingPage) {
    await notion.pages.update({
      page_id: existingPage.id,
      properties,
    });
    console.log(`Updated Notion itinerary page: ${existingPage.id}`);
    return;
  }

  const created = await notion.pages.create({
    parent: { database_id: databaseId },
    properties,
  });
  console.log(`Created Notion itinerary page: ${created.id}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
