// Trecere completa pe tot inbox-ul, cu paginare
const k = require('./kit.js');
const fs = require('fs');

const LABELS = {
  joburi: 'MAVIS/Joburi', ai: 'MAVIS/AI si comunitati', social: 'MAVIS/Social',
  news: 'MAVIS/Newsletter', finante: 'MAVIS/Finante', personal: 'MAVIS/Personal',
  actiune: 'MAVIS/Actiune - de raspuns', facturi: 'MAVIS/Facturi si conturi',
};
const FIN   = /\b(kraken|tradingview|crypto|bitunix|coinbase|binance|factur|digi|raiffeisen|bnr|banca|invest|trading|broker|conturi|taxe)\b/i;
const JOB   = /\b(jooble|bestjobs|hipo|indeed|jobleads|recruit|job|jobs|career|careers|hiring|vacanta|angaj|aplicare|interviu|oportunitate)\b/i;
const AI    = /\b(ai|openai|anthropic|comfy|comfyui|automation|midjourney|prompt|llm|chatgpt|substack|goatacademy|twine|beehiiv|sadguru|isha|aiautomationsociety|comfy\.org)\b/i;
const SOCIAL= /\b(linkedin|skool|facebook|instagram|twitter|discord|pinterest|tiktok|politi)\b/i;

function classify(m) {
  const f = m.from || '', s = m.subj || '';
  if (/(happyadv|iqads)/i.test(f)) return /follow-up|aplicare/i.test(s) ? 'actiune' : 'personal';
  if (/\b(factur|facturi|facture|invoice)\b/i.test(s)) return 'facturi';
  if (FIN.test(f) || FIN.test(s)) return 'finante';
  if (JOB.test(f) || JOB.test(s)) return 'joburi';
  if (SOCIAL.test(f)) return 'social';
  if (AI.test(f) || AI.test(s)) return 'ai';
  return 'news';
}

async function fetchAll(q) {
  const all = [];
  let page = null;
  do {
    const url = 'https://gmail.googleapis.com/gmail/v1/users/me/messages?q=' + encodeURIComponent(q) +
      '&maxResults=500' + (page ? '&pageToken=' + page : '');
    const r = await k.req('GET', url);
    all.push(...(r.messages || []));
    page = r.nextPageToken || null;
  } while (page);
  return all;
}

(async () => {
  const list = await fetchAll('in:inbox');
  console.log('MESAJE IN INBOX:', list.length, '\n');

  const existing = await k.gmail.labels();
  const byName = new Map(existing.labels.map(l => [l.name, l.id]));
  const ids = {}; for (const [kk, n] of Object.entries(LABELS)) ids[kk] = byName.get(n);
  const allMavisIds = Object.values(ids);

  const counts = {}; const kept = [];
  let done = 0;
  for (let i = 0; i < list.length; i += 20) {
    const batch = list.slice(i, i + 20);
    const ds = await Promise.all(batch.map(m =>
      k.req('GET', `https://gmail.googleapis.com/gmail/v1/users/me/messages/${m.id}?format=metadata&metadataHeaders=Subject&metadataHeaders=From`)
        .catch(() => null)));
    for (let j = 0; j < batch.length; j++) {
      const d = ds[j]; if (!d || !d.payload) continue;
      const h = {}; (d.payload.headers || []).forEach(x => h[x.name] = x.value);
      const m = { subj: h.Subject || '', from: h.From || '' };
      const p = classify(m);
      counts[p] = (counts[p] || 0) + 1;
      await k.gmail.removeLabel(batch[j].id, allMavisIds);
      await k.gmail.addLabel(batch[j].id, [ids[p]]);
      await k.gmail.removeLabel(batch[j].id, ['UNREAD']);
      if (p === 'actiune' || p === 'personal' || p === 'facturi') {
        await k.gmail.addLabel(batch[j].id, ['INBOX']);
        kept.push({ eticheta: LABELS[p], subj: m.subj.slice(0, 70), from: m.from });
      } else {
        await k.gmail.removeLabel(batch[j].id, ['INBOX']);
      }
      done++;
      if (done % 100 === 0) console.log('  ...', done, '/', list.length);
    }
  }

  console.log('\n=== REZULTAT COMPLET ===');
  for (const [c, n] of Object.entries(counts).sort((a,b)=>b[1]-a[1]))
    console.log(`  ${String(n).padStart(4)}  ${LABELS[c]}`);
  console.log('\nRAMASE IN INBOX:', kept.length);
  kept.forEach(x => console.log(`  [${x.eticheta}] ${x.subj}  <${x.from}>`));
  fs.writeFileSync('/workspace/mavis-tools/kept_full.json', JSON.stringify(kept, null, 1));
})().catch(e => console.error('E:', e.message));
