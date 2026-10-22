/**
 * GOOGLE AUTH — rezolvarea unica a credentialelor Google.
 *
 * Ordinea (prima care exista castiga):
 *   1. ENV din secret manager (Cloud):
 *        GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET / GOOGLE_REFRESH_TOKEN
 *   2. FISIERE locale (Local):
 *        ~/.google-mcp/credentials.json  -> installed.client_id / installed.client_secret
 *        ~/.google-mcp/tokens/mavis.json  -> refresh_token
 *
 * REGULA: nu afiseaza NICIO secret. describe() intoarce doar DE UNDE a venit.
 *          niciun secret nu ajunge in repo, in chat, sau in log.
 */

const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || '/root';
const CREDS_FILE = path.join(HOME, '.google-mcp', 'credentials.json');
const TOKENS_FILE = path.join(HOME, '.google-mcp', 'tokens', 'mavis.json');

// POPY a adaugat cheile in secret manager cu sufixul _MAVIS_CLOUD, ca sa nu se
// confunde cu cele locale. Acceptam ambele forme — prima care exista castiga.
const ENV_KEYS = {
  client_id: ['GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_ID_MAVIS_CLOUD'],
  client_secret: ['GOOGLE_CLIENT_SECRET', 'GOOGLE_CLIENT_SECRET_MAVIS_CLOUD'],
  refresh_token: ['GOOGLE_REFRESH_TOKEN', 'GOOGLE_REFRESH_TOKEN_MAVIS_CLOUD'],
  email: ['GOOGLE_EMAIL'],
  maps: ['GOOGLE_MAPS_API_KEY'],
};

function envVal(kind) {
  for (const n of (ENV_KEYS[kind] || [])) {
    if (process.env[n]) return { value: process.env[n], name: n };
  }
  return null;
}

function readJson(p) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return null; }
}

/**
 * JSON tolerant la erori de copiere manuala.
 * Caz real: fisierul avea un `"` la inceput si `}}` la final ->
 * JSON.parse arunca, iar credentialele dispareau silent.
 * Recuperam primul `{` ... ultimul `}` si re incercam.
 */
function readJsonTolerant(p) {
  const raw = (() => { try { return fs.readFileSync(p, 'utf8'); } catch { return null; } })();
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { /* mai jos */ }
  // Extragem primul obiect JSON BALANSAT: de la primul '{' pana la paranteza
  // care ii corespunde. Asta repara si gunoi ramas dupa (ex: '}}' la final).
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

function fromEnv() {
  const id = envVal('client_id');
  const sec = envVal('client_secret');
  const tok = envVal('refresh_token');
  if (!id || !sec || !tok) return null;
  return {
    client_id: id.value,
    client_secret: sec.value,
    refresh_token: tok.value,
    source: 'env',
    source_detail: [id.name, sec.name, tok.name],
  };
}

function fromFiles() {
  const c = readJsonTolerant(CREDS_FILE);
  const t = readJsonTolerant(TOKENS_FILE);
  if (!c || !t) return null;
  const inst = c.installed || c.web || c; // desktop client = installed, web = web
  const client_id = inst.client_id;
  const client_secret = inst.client_secret;
  const refresh_token = t.refresh_token;
  if (!client_id || !client_secret || !refresh_token) return null;
  return {
    client_id,
    client_secret,
    refresh_token,
    source: 'files',
    source_detail: [CREDS_FILE, TOKENS_FILE],
  };
}

/** Credentialele active, sau null daca nu exista niciun set complet. */
function resolve() {
  return fromEnv() || fromFiles() || null;
}

/** Diagnostic fara secreti. Spune EXACT ce lipseste. */
function describe() {
  const env = {
    client_id: envVal('client_id')?.name || null,
    client_secret: envVal('client_secret')?.name || null,
    refresh_token: envVal('refresh_token')?.name || null,
    email: envVal('email')?.name || null,
    maps_api_key: envVal('maps')?.name || null,
  };
  const files = {
    credentials_json: fs.existsSync(CREDS_FILE),
    tokens_mavis_json: fs.existsSync(TOKENS_FILE),
  };
  const r = resolve();
  const missing = [];
  if (!env.client_id && !files.credentials_json) missing.push('GOOGLE_CLIENT_ID');
  if (!env.client_secret && !files.credentials_json) missing.push('GOOGLE_CLIENT_SECRET');
  if (!env.refresh_token && !files.tokens_mavis_json) missing.push('GOOGLE_REFRESH_TOKEN');
  return {
    resolved: !!r,
    source: r ? r.source : null,
    source_detail: r ? r.source_detail : null,
    env,
    files,
    missing,
    paths: { CREDS_FILE, TOKENS_FILE },
  };
}

/** Scope-urile pentru care se cere consimtamant. Un set complet, o singura cerere. */
const SCOPES = {
  drive: 'https://www.googleapis.com/auth/drive',
  gmail: 'https://www.googleapis.com/auth/gmail.modify',
  gmailReadonly: 'https://www.googleapis.com/auth/gmail.readonly',
  calendar: 'https://www.googleapis.com/auth/calendar',
  docs: 'https://www.googleapis.com/auth/documents',
  spreadsheets: 'https://www.googleapis.com/auth/spreadsheets',
  slides: 'https://www.googleapis.com/auth/presentations',
  photosReadonly: 'https://www.googleapis.com/auth/photoslibrary.readonly',
  photosReadwrite: 'https://www.googleapis.com/auth/photoslibrary.readwrite',
  driveFile: 'https://www.googleapis.com/auth/drive.file',
};

/**
 * Setul implicit (6 scope-uri) — cele care functioneaza fara API-uri suplimentare
 * activate in proiectul Cloud.
 *
 * DE CE NU PENTRU PHOTOS: scope-ul photoslibrary.* este respins de Google cu
 * `invalid_scope` daca Photos Library API nu e activata in proiect. Google
 * raporteaza scope-urile pentru API-uri neactivate drept "invalid" — vezi
 * raportul de eroare: valid=[...], invalid=[photoslibrary.readwrite].
 *
 * In plus, masurat 2026-10-21: `photoslibrary.googleapis.com` este blocat de
 * egress-ul sandboxului de cloud (0/6 conexiuni). Deci Photos se face de la
 * Local, oricum. Nu blocam restul setup-ului pentru el.
 */
const FULL_SCOPES = [
  SCOPES.drive,
  SCOPES.gmail,
  SCOPES.calendar,
  SCOPES.docs,
  SCOPES.spreadsheets,
  SCOPES.slides,
];

/** Scope-uri pentru Google Photos — doar daca Photos Library API e activata in proiect. */
const PHOTOS_SCOPES = [SCOPES.photosReadwrite];

/** Setul minim: ce trebuie ca Drive + Gmail sa mearga in cloud. */
const CORE_SCOPES = [SCOPES.drive, SCOPES.gmail, SCOPES.calendar];

module.exports = {
  resolve,
  describe,
  fromEnv,
  fromFiles,
  readJson,
  readJsonTolerant,
  SCOPES,
  FULL_SCOPES,
  PHOTOS_SCOPES,
  CORE_SCOPES,
  CREDS_FILE,
  TOKENS_FILE,
};
