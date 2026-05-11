const { Client } = require('@notionhq/client');

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const databaseId = '48936aece5304d1b8866c922b704688d';

const rows = [
  {
    date: '2027-01-25',
    theme: '接機・Tomamu 移動日',
    time: '下午',
    category: '🚗 交通',
    title: '前往新千歲機場接女朋友',
    location: '新千歲機場',
    transport: '一般轎車',
    notes: '接機後前往 Tomamu 附近住宿。',
  },
  {
    date: '2027-01-25',
    theme: '接機・Tomamu 移動日',
    time: '傍晚',
    category: '🏨 住宿',
    title: 'Tomamu 附近旅館入住',
    location: 'Tomamu 周邊',
    transport: '一般轎車',
    notes: '暫定 1/25–1/28 入住，可能延到 1/29 離開 Tomamu。',
  },
  {
    date: '2027-01-26',
    theme: 'Tomamu 滑雪',
    time: '全天',
    category: '⛷️ 滑雪',
    title: 'Tomamu 滑雪場滑雪',
    location: 'Tomamu Ski Resort',
    transport: '一般轎車／接駁待確認',
    notes: '住宿與雪場交通待旅館確認。',
  },
  {
    date: '2027-01-27',
    theme: 'Tomamu 滑雪',
    time: '全天',
    category: '⛷️ 滑雪',
    title: 'Tomamu 滑雪場滑雪',
    location: 'Tomamu Ski Resort',
    transport: '一般轎車／接駁待確認',
    notes: '住宿與雪場交通待旅館確認。',
  },
  {
    date: '2027-01-28',
    theme: 'Tomamu / 札幌彈性日',
    time: 'TBD',
    category: '🚗 交通',
    title: 'Tomamu → 札幌（暫定）',
    location: 'Tomamu / 札幌',
    transport: '一般轎車',
    notes: '尚未決定 1/28 或 1/29 離開 Tomamu；離開後回札幌晃晃並住札幌。',
  },
  {
    date: '2027-01-29',
    theme: 'TBD',
    time: 'TBD',
    category: '📍 景點',
    title: 'Tomamu 或札幌彈性安排',
    location: 'Tomamu / 札幌',
    transport: '一般轎車',
    notes: '若 1/29 才離開 Tomamu，上午保留 Tomamu；若已回札幌，安排札幌市區或近郊。',
  },
  {
    date: '2027-01-30',
    theme: 'TBD',
    time: 'TBD',
    category: '📍 景點',
    title: '札幌 / 近郊 TBD',
    location: '札幌 / 近郊',
    transport: '一般轎車',
    notes: '行程待定。',
  },
  {
    date: '2027-01-31',
    theme: '還車・回程',
    time: 'TBD',
    category: '🚗 交通',
    title: '還車',
    location: '新千歲 / 租車公司',
    transport: '一般轎車',
    notes: '回程航班前完成還車。',
  },
];

function title(value) {
  return { title: [{ text: { content: value } }] };
}

function richText(value) {
  return value ? { rich_text: [{ text: { content: value } }] } : { rich_text: [] };
}

function select(value) {
  return { select: { name: value } };
}

function date(value) {
  return { date: { start: value } };
}

async function existingPage(row) {
  const res = await notion.databases.query({
    database_id: databaseId,
    filter: {
      and: [
        { property: '日期', date: { equals: row.date } },
        { property: '名稱', title: { equals: row.title } },
      ],
    },
    page_size: 1,
  });

  return res.results[0];
}

async function createPage(row) {
  await notion.pages.create({
    parent: { database_id: databaseId },
    properties: {
      日期: date(row.date),
      當日主題: richText(row.theme),
      時間: richText(row.time),
      分類: select(row.category),
      名稱: title(row.title),
      地點: richText(row.location),
      交通方式: richText(row.transport),
      備註: richText(row.notes),
    },
  });
}

async function main() {
  if (!process.env.NOTION_TOKEN) {
    throw new Error('NOTION_TOKEN is required');
  }

  for (const row of rows) {
    const existing = await existingPage(row);
    if (existing) {
      console.log(`skip existing: ${row.date} ${row.title}`);
      continue;
    }

    await createPage(row);
    console.log(`created: ${row.date} ${row.title}`);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
