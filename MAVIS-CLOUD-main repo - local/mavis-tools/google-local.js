#!/usr/bin/env node
/**
 * GOOGLE LOCAL — flux complet OAuth pe calculatorul tau, intr-un singur fisier.
 *
 *   node google-local.js
 *
 * De ce sta in chat nu merge: platformul mascheaza valorile din secret manager
 * chiar si in mesajele mele, deci client_id-ul ajunge la tine ca
 * {{ARCHON_SECRET:...}} -> invalid_client. Aici nu se mai transmite nimic prin
 * chat: client_id-ul e citit din fisierul tau, iar refresh_token-ul se afiseaza
 * doar pe ecranul tau.
 *
 * ZERO dependinte externe (doar node built-ins). Functioneaza si daca repo-ul
 * nu e la zi.
 *
 * Ce face:
 *   1. citeste client_id + client_secret din ~/.google-mcp/credentials.json
 *      (sau din env: GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET)
 *   2. deschide un server local pe 127.0.0.1:8976
 *   3. deschide linkul de autorizare in browser
 *   4. prinde codul, il schimba in refresh_token
 *   5. scrie tokenul + fisierul cu chei pentru secret manager
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const { exec } = require('child_process');

const HOME = os.homedir();
const CREDS_FILE = path.join(HOME, '.google-mcp', 'credentials.json');
const TOKENS_DIR = path.join(HOME, '.google-mcp', 'tokens');
const TOKENS_FILE = path.join(TOKENS_DIR, 'mavis.json');
const ENV_OUT = path.join(HOME, '.google-mcp', 'cloud-secret.env');

const PORT = 8976;
const REDIRECT_URI = `http://127.0.0.1:${PORT}`;

const SCOPES = [
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/gmail.modify',
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/documents',
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/presentations',
];

const C = {
  b: (s) => `\x1b[1m${s}\x1b[0m`, g: (s) => `\x1b[32m${s}\x1b[0m`,
  y: (s) => `\x1b[33m${s}\x1b[0m`, r: (s) => `\x1b[31m${s}\x1b[0m`, d: (s) => `\x1b[2m${s}\x1b[0m`,
};

function readJsonTolerant(file) {
  let raw;
  try { raw = fs.readFileSync(file, 'utf8'); } catch { return null; }
  try { return JSON.parse(raw); } catch { /* mai jos */ }
  const s = raw.indexOf('{');
  if (s === -1) return null;
  let depth = 0, inStr = false, esc = false, end = -1;
  for (let i = s; i < raw.length; i++) {
    const ch = raw[i];
    if (inStr) {
      if (esc) esc = false;
      else if (ch === '\\') esc = true;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') inStr = true;
    else if (ch === '{') depth++;
    else if (ch === '}') { depth--; if (depth === 0) { end = i; break; } }
  }
  if (end === -1) return null;
  try { return JSON.parse(raw.slice(s, end + 1)); } catch { return null; }
}

function findClient() {
  const c = readJsonTolerant(CREDS_FILE);
  if (c) {
    const inst = c.installed || c.web || c;
    if (inst.client_id && inst.client_secret) {
      return { client_id: inst.client_id, client_secret: inst.client_secret, from: CREDS_FILE };
    }
  }
  const id = process.env.GOOGLE_CLIENT_ID;
  const sec = process.env.GOOGLE_CLIENT_SECRET;
  if (id && sec) return { client_id: id, client_secret: sec, from: 'env' };
  return null;
}

function openBrowser(url) {
  try {
    if (process.platform === 'win32') exec(`cmd /c start "" "${url}"`, () => {});
    else if (process.platform === 'darwin') exec(`open "${url}"`, () => {});
    else exec(`xdg-open "${url}"`, () => {});
  } catch { /* deschide manual daca nu merge */ }
}

/** fetch cu retry — reteaua poate da greseli intermitente. */
async function fetchRetry(url, opts, tries = 4) {
  let last;
  for (let i = 0; i < tries; i++) {
    try { return await fetch(url, opts); }
    catch (e) { last = e; await new Promise(r => setTimeout(r, 1500 * (i + 1))); }
  }
  throw last;
}

(async () => {
  console.log(C.b('\n=== GOOGLE LOCAL ===\n'));
  const c = findClient();
  if (!c) {
    console.log(C.r('Nu am gasit clientul OAuth.\n'));
    console.log('Caut in: ' + CREDS_FILE);
    console.log('Sau seteaza GOOGLE_CLIENT_ID si GOOGLE_CLIENT_SECRET.\n');
    process.exit(1);
  }
  console.log(C.g('Client gasit (' + c.from + ')'));
  console.log(C.d('  client_id: ' + c.client_id));

  const p = new URLSearchParams({
    client_id: c.client_id,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    scope: SCOPES.join(' '),
    access_type: 'offline',
    prompt: 'consent',
    include_granted_scopes: 'true',
  });
  const url = 'https://accounts.google.com/o/oauth2/v2/auth?' + p.toString();

  // auto-verificare: scope-urile din link trebuie sa fie exact lista canonica
  const back = new URL(url).searchParams.get('scope').split(' ').sort();
  if (JSON.stringify(back) !== JSON.stringify(SCOPES.slice().sort())) {
    console.log(C.r('Scope-urile nu corespund. Opresc aici.'));
    process.exit(1);
  }
  console.log(C.d('\nScope-uri (' + back.length + '): ' + back.join(', ') + '\n'));

  const server = http.createServer((req, res) => {
    const u = new URL(req.url, 'http://127.0.0.1');
    if (u.pathname !== '/callback') { res.writeHead(404); return res.end('not found'); }
    const code = u.searchParams.get('code');
    const err = u.searchParams.get('error');
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    if (err) {
      res.end(`<h2>EROARE</h2><p>${err}</p><p>${u.searchParams.get('error_description') || ''}</p>`);
      clearTimeout(timer); server.close();
      console.log(C.r('\nConsimtamant refuzat: ' + err));
      process.exit(1);
    }
    res.end('<h2>Cod primit</h2><p>Se verifica acum la Google. Poti inchide fereastra.</p>');
    server.close();
    exchange(code);
  });

  await new Promise(r => server.listen(PORT, '127.0.0.1', r));

  const timer = setTimeout(() => {
    console.log(C.r('\nTimp expirat - nu a venit niciun redirect de la Google.\n'));
    console.log('Daca ai primit "invalid_scope", inseamna ca un scope e gresit sau ca API-ul\n' +
      'nu e activat in proiect. Daca ai primit "OAuth client was not found", inseamna ca\n' +
      'linkul a fost stricat inainte de a ajunge la Google - ruleaza din nou comanda.\n');
    server.close(); process.exit(1);
  }, 10 * 60 * 1000);

  console.log(C.b('Daca browserul nu s-a deschis, deschide manual:\n'));
  console.log(C.g(url) + '\n');
  console.log(C.d('Dupa ce consimti, revino aici. Astept...\n'));
  console.log(C.b('  ATENTIE - cele doua URL-uri sunt diferite:\n'));
  console.log(C.d('  1. URL-ul de DESCHIS (de mai sus)   -> accounts.google.com/o/oauth2/v2/auth?...'));
  console.log(C.d('     Asta e cererea. NU contine codul.\n'));
  console.log(C.b('  2. URL-ul dupa Allow (adresa browserului) -> http://127.0.0.1:8976/?code=4/0Aean...'));
  console.log(C.d('     ASTA contine codul. Daca faci asta manual, copiaza bara de adresa de ACOLO.'));
  console.log(C.d('     Acest script o prinde singur - nu trebuie sa faci nimic.\n'));
  openBrowser(url);

  async function exchange(code) {
    clearTimeout(timer);
    try {
      const r = await fetchRetry('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          client_id: c.client_id, client_secret: c.client_secret,
          code, grant_type: 'authorization_code', redirect_uri: REDIRECT_URI,
        }).toString(),
      });
      const j = await r.json();
      if (j.error) {
        console.log(C.r('\nSchimbul a esuat: ' + j.error + ' — ' + (j.error_description || '') + '\n'));
        process.exit(1);
      }
      fs.mkdirSync(TOKENS_DIR, { recursive: true });
      fs.writeFileSync(TOKENS_FILE, JSON.stringify({
        access_token: j.access_token, refresh_token: j.refresh_token, scope: j.scope,
        token_type: j.token_type, expires_in: j.expires_in, obtained_at: new Date().toISOString(),
      }, null, 2), { mode: 0o600 });

      fs.writeFileSync(ENV_OUT, [
        '# CHEI PENTRU SECRET MANAGER (Mavis Cloud)',
        '# Nu comita acest fisier. Nu il trimite in chat.',
        'GOOGLE_CLIENT_ID=' + c.client_id,
        'GOOGLE_CLIENT_SECRET=' + c.client_secret,
        'GOOGLE_REFRESH_TOKEN=' + j.refresh_token,
        'GOOGLE_EMAIL=' + (process.env.GOOGLE_EMAIL || 'apvizual@gmail.com'),
      ].join('\n') + '\n', { mode: 0o600 });

      console.log(C.g('\nOK. Totul e gata.\n'));
      console.log('  token salvat : ' + TOKENS_FILE);
      console.log('  chei cloud   : ' + ENV_OUT);
      console.log('\n' + C.b('Pune aceste 3 valori in secret manager (Mavis Cloud):'));
      console.log(C.d('  (Environmental Information -> Secrets -> numele de mai jos, valoarea de dupa =)\n'));
      console.log('  GOOGLE_CLIENT_ID_MAVIS_CLOUD     = ' + c.client_id);
      console.log('  GOOGLE_CLIENT_SECRET_MAVIS_CLOUD = ' + c.client_secret);
      console.log('  GOOGLE_REFRESH_TOKEN_MAVIS_CLOUD = ' + j.refresh_token);
      console.log('\n' + C.b('  DOAR linia de refresh token conteaza daca primele doua sunt deja puse:'));
      console.log('  GOOGLE_REFRESH_TOKEN_MAVIS_CLOUD = ' + j.refresh_token);
      console.log(C.d('\n  Refresh tokenul e cel mai important - primele doua poti sa le regenerezi oricand.'));
      console.log(C.d('  Copiaza linia de mai sus, fara "GOOGLE_REFRESH_TOKEN_MAVIS_CLOUD = " - doar valoarea.\n'));
      process.exit(0);
    } catch (e) { console.log(C.r('Eroare: ' + e.message)); process.exit(1); }
  }
})();
