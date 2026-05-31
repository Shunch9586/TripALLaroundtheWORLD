const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

function read(file) {
  return fs.readFileSync(file, 'utf8');
}

function writeJSON(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}

function clean(value) {
  return String(value || '')
    .replace(/\*\*/g, '')
    .replace(/\r/g, '')
    .trim();
}

function dateFromSlash(value) {
  const match = String(value || '').match(/(\d{4})\/(\d{2})\/(\d{2})/);
  return match ? `${match[1]}-${match[2]}-${match[3]}` : '';
}

function dateFromMonthDay(value, year = '2026') {
  const match = String(value || '').match(/(\d{2})\/(\d{2})/);
  return match ? `${year}-${match[1]}-${match[2]}` : '';
}

function firstTime(lines = []) {
  for (const line of lines) {
    const match = String(line).match(/(\d{1,2}:\d{2})/);
    if (match) return match[1];
  }
  return '';
}

function normalizeTime(value) {
  const match = String(value || '').match(/(\d{1,2}:\d{2})/);
  return match ? match[1].padStart(5, '0') : '';
}

function stripLine(value) {
  return clean(value)
    .replace(/^[*\-\s]+/, '')
    .replace(/^[-–—]+\s*/, '')
    .replace(/^\d+[.、]\s*/, '')
    .replace(/^📍\s*/, '')
    .trim();
}

function itineraryItem({ date, theme, time = '', category, title, location = '', mapsUrl = '', transport = '', notes = '' }) {
  return {
    date,
    theme: clean(theme),
    time: normalizeTime(time),
    category,
    title: clean(title),
    location: clean(location),
    mapsUrl,
    transport: clean(transport),
    estimatedCost: 0,
    notes: clean(notes),
  };
}

function categoryFromJapan(icon, title) {
  const text = `${title || ''}`;
  if (/航班|航空|起飛|抵達.*機場|返台|回國|JX\d+|BR\d+|AC\d+/.test(text)) return '✈️ 航班';
  if (/滑雪|雪場|🏂|⛷/.test(text)) return '⛷️ 滑雪';
  if (/住宿|民宿|飯店|Check-in|入住|退房/.test(text)) return '🏨 住宿';
  if (/餐|咖啡|便當|晚餐|午餐|早餐/.test(text)) return '🍜 餐廳';
  if (/取車|還車|自駕|交通|Narita Express|N'EX|搭乘|車站|轉車|🚗|🛣/.test(text)) return '🚗 交通';
  if (/✈/.test(icon || '') && !text) return '✈️ 航班';
  return '📍 景點';
}

function categoryFromCanada(type, text) {
  if (type === 'flight' || /✈|起飛|航班/.test(text)) return '✈️ 航班';
  if (type === 'ski' || /滑雪|雪具|Whistler|Blackcomb|Lake Louise Ski/.test(text)) return '⛷️ 滑雪';
  if (/取車|還車|開車|Drive|車程|km|駕/.test(text)) return '🚗 交通';
  if (/午餐|晚餐|餐廳|Lounge|Restaurant/.test(text)) return '🍜 餐廳';
  if (/入住|Hostel|Hotel|Airbnb|住宿/.test(text)) return '🏨 住宿';
  if (/溫泉|纜車|Gondola|Monument|Lake|Canyon|公園|酒莊|極光|雪橇|摩托車|採購|Outlet|遊客中心/.test(text)) return '📍 景點';
  return '📍 景點';
}

function detailTitle(line) {
  const cleaned = stripLine(line);
  const parts = cleaned.split('|').map(part => part.trim()).filter(Boolean);
  const primary = /^\d{1,2}:\d{2}\s*(?:[-–—]\s*\d{1,2}:\d{2})?$/.test(parts[0] || '')
    ? parts[1]
    : parts[0];
  if (/出發\s*[-–—>]+.*返回/.test(primary || '') && parts[1]) {
    return parts[1];
  }
  const title = (primary || cleaned)
    .replace(/^\d{1,2}:\d{2}\s*(?:[-–—]\s*\d{1,2}:\d{2})?\s*/, '')
    .replace(/^(上午|下午|晚上|中午|早上)[：:]\s*/, '$1：')
    .replace(/^⚠️\s*/, '')
    .trim();
  return title || parts[1] || cleaned;
}

function detailNotes(line) {
  const parts = stripLine(line).split('|').map(part => part.trim()).filter(Boolean);
  return parts.length > 1 ? parts.slice(1).join('\n') : '';
}

function mapURL(query) {
  return query ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}` : '';
}

function extractJSONScript(html) {
  const match = html.match(/<script id="itinerary-data" type="application\/json">\s*([\s\S]*?)\s*<\/script>/);
  if (!match) throw new Error('Cannot find itinerary-data script');
  return JSON.parse(match[1]);
}

function extractLiteral(html, startMarker, endMarker) {
  const start = html.indexOf(startMarker);
  if (start === -1) throw new Error(`Cannot find ${startMarker}`);
  const literalStart = html.indexOf('=', start) + 1;
  const end = html.indexOf(endMarker, literalStart);
  if (end === -1) throw new Error(`Cannot find ${endMarker}`);
  return html.slice(literalStart, end).trim().replace(/;\s*$/, '');
}

function evalLiteral(literal) {
  return Function(`"use strict"; return (${literal});`)();
}

function importJapan() {
  const source = extractJSONScript(read('/private/tmp/gemini-travel-app-host.html'));
  const tripId = 'nagano-tokyo-2025';
  const items = [];

  source.forEach((day, index) => {
    const date = dateFromSlash(day.date);
    items.push(itineraryItem({
      date,
      theme: clean(day.title),
      category: '📍 景點',
      title: `Day ${index + 1} · ${clean(day.title)}`,
      location: clean(day.location),
      notes: clean(day.description.split('\n\n')[0] || day.description),
    }));

    clean(day.description)
      .split('\n')
      .map(stripLine)
      .filter(line => line && !/^(交通與入住|下午與晚間行程)$/.test(line))
      .filter(line => /\d{1,2}:\d{2}|搭乘|前往|Check-in|採購|理髮|退房|滑雪|纜車|返台/.test(line))
      .forEach(line => {
        items.push(itineraryItem({
          date,
          theme: clean(day.title),
          time: firstTime([line]),
          category: categoryFromJapan(day.icon, line),
          title: detailTitle(line),
          location: clean(day.location),
          transport: /搭乘|交通|車|N'EX|Narita Express/.test(line) ? '依原行程安排' : '',
          notes: detailNotes(line),
        }));
      });

    (day.sub_stops || []).forEach(stop => {
      items.push(itineraryItem({
        date,
        theme: clean(day.title),
        time: stop.time === '彈性' ? '' : clean(stop.time),
        category: categoryFromJapan('', stop.name),
        title: clean(stop.name),
        location: clean(stop.name),
        mapsUrl: mapURL(stop.map_query || stop.name),
        transport: stop.time === '彈性' ? '彈性停留點' : '',
        notes: '由舊版 WebApp 的彈性停留點匯入。',
      }));
    });
  });

  const trip = {
    title: '長野白馬滑雪・東京文化探索',
    dateRange: { start: '2025-12-30', end: '2026-01-05' },
    regions: ['東京', '長野', '白馬', '栂池高原'],
    flights: [
      {
        type: '去程',
        direction: 'outbound',
        airline: '星宇航空',
        flightNumber: 'JX800',
        ticketInfo: '08:25 TPE → 12:35 NRT',
        date: '2025-12-30',
        departure: 'TPE',
        arrival: 'NRT',
        aircraft: '',
        bookingCode: '',
        ticketNumber: '',
        link: '',
        notes: '',
      },
      {
        type: '回程',
        direction: 'inbound',
        airline: '星宇航空',
        flightNumber: 'JX803',
        ticketInfo: '15:40 NRT → TPE',
        date: '2026-01-05',
        departure: 'NRT',
        arrival: 'TPE',
        aircraft: '',
        bookingCode: '',
        ticketNumber: '',
        link: '',
        notes: '',
      },
    ],
    vehicle: {
      type: '租車',
      company: 'Nippon Rent-A-Car 秋葉原店',
      pickupDate: '2025-12-31',
      pickupTime: '08:00',
      returnDate: '2026-01-03',
      returnTime: '22:00',
      rentalCode: 'K95873',
      phone: '050-1712-2625',
      notes: '4WD。取還車皆為秋葉原店。',
    },
  };

  const info = [
    {
      category: '住宿',
      name: '相鐵Fresa Inn 御茶之水神保町',
      content: '12/30 入住。御茶水/神保町地區。',
      phone: '',
      address: 'Sotetsu Fresa Inn Ochanomizu-Jimbocho',
      notes: '',
      link: mapURL('Sotetsu Fresa Inn Ochanomizu-Jimbocho'),
    },
    {
      category: '住宿',
      name: '松之亭（栂池高原）',
      content: '12/31 - 1/2 入住。',
      phone: '',
      address: 'Matsunotei Tsugaike Kogen',
      notes: '舊版 WebApp 備註：通常沒有電梯，大件行李搬運需注意。',
      link: mapURL('Matsunotei Tsugaike Kogen'),
    },
    {
      category: '住宿',
      name: '相鐵 Fresa Inn 上野御徒町',
      content: '1/3 與 1/4 入住。',
      phone: '',
      address: 'Sotetsu Fresa Inn Ueno-Okachimachi',
      notes: '',
      link: mapURL('Sotetsu Fresa Inn Ueno-Okachimachi'),
    },
    {
      category: '提醒',
      name: '飲食禁忌',
      content: '全程請避開牛肉、菇類與茄子。',
      phone: '',
      address: '',
      notes: '',
      link: '',
    },
    ...source.map((day, index) => ({
      category: 'Vlog 拍攝建議',
      name: `Day ${index + 1} · ${clean(day.title)}`,
      content: clean(day.vlog_suggestion),
      phone: '',
      address: '',
      notes: '',
      link: '',
    })),
  ];

  writeJSON(path.join(root, 'data', tripId, 'trip.json'), trip);
  writeJSON(path.join(root, 'data', tripId, 'itinerary.json'), items);
  writeJSON(path.join(root, 'data', tripId, 'info.json'), info);
  return { id: tripId, name: '🎿 202512 長野東京', source: 'static' };
}

function importCanada() {
  const html = read('/private/tmp/canada-feb-2026.html');
  const schedule = evalLiteral(extractLiteral(html, 'const schedule =', 'const skiResorts ='));
  const logistics = evalLiteral(extractLiteral(html, 'const logistics =', '// --- 渲染內容 ---'));
  const tripId = 'canada-2026';

  const items = [];

  schedule.forEach(day => {
    const date = dateFromMonthDay(day.date, '2026');
    (day.details || [])
      .map(stripLine)
      .filter(line => line && !/^[-]+$/.test(line) && !/^建議補給站/.test(line))
      .forEach(line => {
        const title = detailTitle(line);
        const category = categoryFromCanada(day.type, `${title}\n${line}`);
        items.push(itineraryItem({
          date,
          theme: clean(day.highlight),
          time: firstTime([line]),
          category,
          title,
          location: clean(day.location),
          transport: /開車|Drive|車程|km|出發|抵達|取車|還車/.test(line) ? '依原行程安排' : '',
          notes: detailNotes(line),
        }));
      });

    (day.links || []).forEach(link => {
      items.push(itineraryItem({
        date,
        theme: clean(day.highlight),
        category: '📍 景點',
        title: clean(link.label),
        location: clean(day.location),
        mapsUrl: link.url || '',
        notes: '由舊版 WebApp 連結匯入。',
      }));
    });
  });

  (logistics.dining || []).forEach(item => {
    items.push(itineraryItem({
      date: dateFromMonthDay(item.date, '2026'),
      theme: '餐廳訂位',
      time: clean(item.time),
      category: '🍜 餐廳',
      title: clean(item.name),
      location: clean(item.address),
      mapsUrl: mapURL(item.address || item.name),
      notes: clean(item.note),
    }));
  });

  (logistics.tickets || []).forEach(item => {
    items.push(itineraryItem({
      date: dateFromMonthDay(item.date, '2026'),
      theme: '門票與活動',
      time: clean(item.time),
      category: '📍 景點',
      title: clean(item.name),
      location: clean(item.location),
      mapsUrl: mapURL(item.location || item.name),
      notes: clean(item.note),
    }));
  });

  const flights = (logistics.flights || []).map((flight, index, all) => {
    const isInbound = index === all.length - 1;
    return {
      type: isInbound ? '回程' : '航班',
      direction: isInbound ? 'inbound' : 'outbound',
      airline: /BR/.test(flight.code) ? '長榮航空' : 'Air Canada',
      flightNumber: flight.code,
      ticketInfo: `${flight.time} ${flight.dep} ${flight.depTerm || ''} → ${flight.arr} ${flight.arrTerm || ''}`,
      date: dateFromMonthDay(flight.time, '2026'),
      departure: flight.dep,
      arrival: flight.arr,
      aircraft: '',
      bookingCode: '',
      ticketNumber: '',
      link: '',
      notes: '',
    };
  });

  const rental = (logistics.rentals || [])[0] || {};
  const trip = {
    title: 'Canada 2026｜極光、滑雪與洛磯山脈',
    dateRange: { start: '2026-02-13', end: '2026-02-28' },
    regions: ['Yellowknife', 'Whistler', 'Banff', 'Kelowna', 'Vancouver'],
    flights,
    vehicle: {
      type: '租車',
      company: [rental.company, rental.loc].filter(Boolean).join(' / '),
      pickupDate: '2026-02-14',
      pickupTime: '10:00',
      returnDate: '2026-02-27',
      returnTime: '21:00',
      rentalCode: [rental.id, (logistics.rentals || [])[1]?.id].filter(Boolean).join(' / '),
      phone: '',
      notes: (logistics.rentals || []).map(r => `${r.company}｜${r.loc}｜${r.range}｜${r.id}`).join('\n'),
    },
  };

  const info = [];
  (logistics.hotels || []).forEach(hotel => {
    info.push({
      category: '住宿',
      name: clean(hotel.name),
      content: `${hotel.type || '住宿'}｜${hotel.status || ''}`,
      phone: '',
      address: clean(hotel.address),
      notes: '',
      link: mapURL(hotel.address || hotel.name),
    });
  });
  (logistics.rentals || []).forEach(rentalItem => {
    info.push({
      category: '租車',
      name: clean(rentalItem.company),
      content: clean(rentalItem.range),
      phone: '',
      address: clean(rentalItem.loc),
      notes: clean(`預約/憑證：${rentalItem.id}`),
      link: mapURL(rentalItem.loc),
    });
  });
  (logistics.skiRentals || []).forEach(item => {
    info.push({
      category: '滑雪裝備',
      name: clean(item.vendor),
      content: clean(`${item.range}｜${item.details}`),
      phone: '',
      address: '',
      notes: clean(`${item.note}\n${item.id}`),
      link: item.link || '',
    });
  });
  (logistics.dining || []).forEach(item => {
    info.push({
      category: '餐廳訂位',
      name: clean(item.name),
      content: clean(`${item.date} ${item.time}`),
      phone: '',
      address: clean(item.address),
      notes: clean(item.note),
      link: mapURL(item.address || item.name),
    });
  });
  (logistics.tickets || []).forEach(item => {
    info.push({
      category: '門票與活動',
      name: clean(item.name),
      content: clean(`${item.date} ${item.time}`),
      phone: '',
      address: clean(item.location),
      notes: clean(item.note),
      link: mapURL(item.location || item.name),
    });
  });

  writeJSON(path.join(root, 'data', tripId, 'trip.json'), trip);
  writeJSON(path.join(root, 'data', tripId, 'itinerary.json'), items.sort((a, b) => a.date.localeCompare(b.date) || a.time.localeCompare(b.time)));
  writeJSON(path.join(root, 'data', tripId, 'info.json'), info);
  return { id: tripId, name: '🇨🇦 202602 加拿大', source: 'static' };
}

function updateConfig(staticTrips) {
  const configPath = path.join(root, 'data', 'config.json');
  const config = JSON.parse(read(configPath));
  const existingById = new Map(config.trips.map(trip => [trip.id, trip]));
  for (const trip of staticTrips) {
    existingById.set(trip.id, { ...existingById.get(trip.id), ...trip });
  }
  config.trips = Array.from(existingById.values());
  writeJSON(configPath, config);
}

function main() {
  const trips = [importJapan(), importCanada()];
  updateConfig(trips);
  console.log(`Imported ${trips.length} legacy trips: ${trips.map(trip => trip.id).join(', ')}`);
}

main();
