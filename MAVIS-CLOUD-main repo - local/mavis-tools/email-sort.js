/**
 * 0.8f — Sortarea thread-urilor 1-3 ani pe cele 8 categorii MAVIS
 * METODA IEFTINA: cautari cu filtre de expeditor -> thread-uri direct, fara messages.get
 * Cost: ~5 unitati per pagina de 500. Zero apeluri scumpe.
 */
const k = require('./kit.js');
const q = require('./quota.js');

const L = {
  social:   'MAVIS/Social',
  joburi:   'MAVIS/Joburi',
  ai:       'MAVIS/AI si comunitati',
  finante:  'MAVIS/Finante',
  newsletter:'MAVIS/Newsletter',
  personal: 'MAVIS/Personal',
  facturi:  'MAVIS/Facturi si conturi',
  actiune:  'MAVIS/De raspuns',
};

const WINDOW = 'older_than:1y newer_than:3y';
// categoriile zilnice nu pot folosi fereastra de 1-3 ani
const NO_WINDOW = new Set(['ai', 'actiune', 'facturi']);

const CATS = [
  ['social',    `{from:skool from:facebook from:instagram from:tiktok from:pinterest from:polibrawl from:youtube}`],
  ['joburi',    `{from:jooble from:bestjobs from:hipo from:indeed from:jobleads from:recruit from:linkedin from:iqads from:designproject}`],
  // AI si newsletter-urile vin ZILNIC: fereastra 'mai vechi de 1 an' le arunca pe TOATE.
  ['ai',        `{from:substack from:goatacademy from:aiautomationsociety from:beehiiv from:twine from:comfy from:deepmind from:openai from:anthropic subject:AI subject:"artificial intelligence"}`],
  // etichete care NU aveau nicio regula - create goale
  ['facturi',   `{subject:factura subject:factură subject:invoice subject:facturi}`],
  ['actiune',   `{is:starred} {is:important is:unread}`],
  ['finante',   `{from:kraken from:tradingview from:bitunix from:coinbase from:binance subject:factura subject:investitie}`],
  ['newsletter',`{from:noreply from:no-reply from:newsletter from:digest from:promotions from:offers from:deals from:notificari from:notificări}`],
  ['personal',  `{from:happyadv from:alexfiloti from:family from:parinti}`],
];

async function threadIds(query) {
  const out = []; let page = null;
  do {
    const r = await k.req('GET',
      'https://gmail.googleapis.com/gmail/v1/users/me/threads?q=' + encodeURIComponent(query) +
      '&maxResults=500' + (page ? '&pageToken=' + page : ''));
    out.push(...(r.threads || []).map(t => t.id));
    page = r.nextPageToken || null;
  } while (page);
  return out;
}

(async () => {
  const ex = await k.gmail.labels();
  const byName = new Map(ex.labels.map(l => [l.name, l.id]));
  for (const [k2, n] of Object.entries(L)) if (!byName.has(n)) await k.gmail.createLabel(n);
  const labels = await k.gmail.labels();
  const M = new Map((labels.labels||[]).map(l => [l.name, l.id]));

  const total = new Map();
  for (const [cat, flt] of CATS) {
    const w = NO_WINDOW.has(cat) ? '' : WINDOW + ' ';
    // GHILIMELE OBLIGATORII: etichetele cu spatiu sau linie sunt stricate de Gmail.
    // Liniuta din nume face eticheta DE NEINDEXABILA - nicio forma de cautare
    // nu o gaseste. De aceea s-a renumit 'MAVIS/De raspuns'.
    // 'actiune' prinde si ce a fost deja sortat in alta categorie si scos din
    // inbox. Cu 'in:inbox' ar da 0, pentru ca mailurile cu stea nu mai sunt acolo.
    const inbox = (cat === 'actiune') ? '' : ' in:inbox';
    const query = w + flt + inbox + ' -label:"' + L[cat] + '"';
    let ids = [];
    try { ids = await threadIds(query); } catch (e) { console.log('cautare blocata', cat, e.message.slice(0,40)); continue; }
    console.log('\n' + cat.toUpperCase() + ': ' + ids.length + ' thread-uri  (cota ' + q.state.used + ')');
    if (!ids.length) continue;
    // aplica eticheta + scoate din inbox + marcheaza citit
    const lab = M.get(L[cat]);
    for (let i = 0; i < ids.length; i += 100) {
      try {
        await k.req('POST',
          `https://gmail.googleapis.com/gmail/v1/users/me/threads/${ids[i]}/modify`,
          { addLabelIds: [lab], removeLabelIds: ['INBOX', 'UNREAD'] });
        const rest = ids.slice(i + 1, i + 101);
        for (const t of rest) {
          await k.req('POST', `https://gmail.googleapis.com/gmail/v1/users/me/threads/${t}/modify`,
            { addLabelIds: [lab], removeLabelIds: ['INBOX', 'UNREAD'] });
        }
      } catch (e) { console.log('  blocat la', i, e.message.slice(0, 50)); break; }
      if (i % 1000 === 0) console.log('   ...', i, '/', ids.length);
    }
    total.set(cat, ids.length);
  }

  console.log('\n=== REZULTAT 0.8f ===');
  for (const [c, n] of total) console.log('  ' + String(n).padStart(6) + '  ' + L[c]);
  console.log('\ncota totala consumata:', q.state.used, 'unitati');
  console.log('GATA');
})().catch(e => console.error('E:', e.message));