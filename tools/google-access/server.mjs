// Google_Access - MCP server (Streamable HTTP), zero dependencies.
//
// WHY IT EXISTS
// -------------
// Popy: "AVEM NEVOEI DE AUTENTIFICARE PERMANENTA! ... sa poti te loghezi o
// data si tii inte mereu". The re-consent loop on this machine was never a
// Google problem: it was that every Google MCP server kept its OWN credential
// store, and a dead grant in one store looked exactly like "sign in again".
//
// So this container owns ONE credential (a refresh token in a mounted volume)
// and mints short-lived access tokens from it, forever, without consent.
// The refresh token is the only durable secret; it is never in the image.
//
// It is a MODULAR surface: one MCP endpoint, many tools, one credential.
//
// The scope of the current grant is what Google granted at consent time:
// drive, gmail.modify, calendar, documents, spreadsheets, presentations,
// forms. Tools that need a scope outside that set (photos, keep, tasks,
// sites, script, chat) DO NOT silently fail: they report the missing scope
// and point at google_scope_upgrade, which prints the one consent URL that
// widens everything in a single click.
//
// ASCII ONLY. Runs on node:22-slim.

import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const DATA_DIR = process.env.GA_DATA_DIR || "/data";
const CRED_FILE = path.join(DATA_DIR, "credentials.json");
const REAUTH_FLAG = path.join(DATA_DIR, "REAUTH_REQUIRED");
// Measured defect 2026-10-27: the fallback literal was 8765, a port already
// owned on this host by a foreign process (python, service "hc-backend").
// The image sets GA_PORT explicitly, so this literal was a second source of
// truth about the same thing; it now matches the Dockerfile default.
const PORT = Number(process.env.GA_PORT || 8766);
const HOST = process.env.GA_HOST || "127.0.0.1";

const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";
const EXTENDLM_MCP_URL = process.env.GA_EXTENDLM_URL || "https://mcp.extendlm.com/mcp";

// The full set Popy asked for: everything Google that is not Google Cloud.
// Used ONLY when generating a widening consent URL - never to widen silently.
const FULL_SCOPES = [
  "openid",
  "https://www.googleapis.com/auth/userinfo.email",
  "https://www.googleapis.com/auth/userinfo.profile",
  "https://www.googleapis.com/auth/drive",
  "https://www.googleapis.com/auth/drive.readonly",
  "https://www.googleapis.com/auth/drive.appdata",
  "https://www.googleapis.com/auth/gmail.readonly",
  "https://www.googleapis.com/auth/gmail.modify",
  "https://www.googleapis.com/auth/gmail.compose",
  "https://www.googleapis.com/auth/gmail.send",
  "https://www.googleapis.com/auth/gmail.settings.basic",
  "https://www.googleapis.com/auth/calendar",
  "https://www.googleapis.com/auth/calendar.events",
  "https://www.googleapis.com/auth/documents",
  "https://www.googleapis.com/auth/spreadsheets",
  "https://www.googleapis.com/auth/presentations",
  "https://www.googleapis.com/auth/forms.body",
  "https://www.googleapis.com/auth/forms.responses.readonly",
  "https://www.googleapis.com/auth/photoslibrary.readonly",
  "https://www.googleapis.com/auth/photoslibrary.appendonly",
  "https://www.googleapis.com/auth/books",
  "https://www.googleapis.com/auth/tasks",
  "https://www.googleapis.com/auth/keep",
  "https://www.googleapis.com/auth/sites",
  "https://www.googleapis.com/auth/script.projects",
  "https://www.googleapis.com/auth/chat.messages",
  "https://www.googleapis.com/auth/youtube.upload",
  "https://www.googleapis.com/auth/youtube.readonly",
  "https://www.googleapis.com/auth/contacts",
  "https://mail.google.com/",
];

// ---------------------------------------------------------------------------
// credential + access token
// ---------------------------------------------------------------------------

function readCreds() {
  try {
    return JSON.parse(fs.readFileSync(CRED_FILE, "utf8"));
  } catch {
    return null;
  }
}

function writeReauthFlag(reason) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(
    REAUTH_FLAG,
    JSON.stringify({ reason, at: new Date().toISOString() }, null, 2),
    "utf8"
  );
}

function clearReauthFlag() {
  try {
    fs.unlinkSync(REAUTH_FLAG);
  } catch {
    /* not there: fine */
  }
}

let tokenCache = { access: null, expiresAt: 0, scope: "" };

async function mintAccessToken() {
  const creds = readCreds();
  if (!creds || !creds.refresh_token) {
    throw new Error("NO_CREDENTIAL: " + CRED_FILE + " is missing. Run provision-grant.cjs on the host.");
  }
  const body = new URLSearchParams({
    client_id: creds.client_id,
    client_secret: creds.client_secret,
    refresh_token: creds.refresh_token,
    grant_type: "refresh_token",
  });
  const res = await fetch(OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  let json = {};
  try {
    json = await res.json();
  } catch {
    /* not json */
  }
  if (res.status !== 200 || !json.access_token) {
    const reason = "token endpoint http " + res.status + " " + (json.error || "") + " " + (json.error_description || "");
    if (/invalid_grant|unauthorized_client/i.test(reason)) {
      writeReauthFlag(reason.trim());
    }
    throw new Error("REAUTH_REQUIRED: " + reason.trim());
  }
  tokenCache = {
    access: json.access_token,
    expiresAt: Date.now() + Number(json.expires_in || 3600) * 1000,
    scope: json.scope || "",
  };
  clearReauthFlag();
  return tokenCache.access;
}

async function accessToken() {
  if (tokenCache.access && Date.now() < tokenCache.expiresAt - 60000) return tokenCache.access;
  return mintAccessToken();
}

async function gfetch(pathOrUrl, { method = "GET", body = null, headers = {}, raw = false } = {}) {
  const token = await accessToken();
  const url = pathOrUrl.startsWith("http") ? pathOrUrl : "https://www.googleapis.com" + pathOrUrl;
  const h = Object.assign(
    { Authorization: "Bearer " + token },
    headers
  );
  if (body !== null && !h["Content-Type"]) h["Content-Type"] = "application/json";
  const res = await fetch(url, { method, headers: h, body: body === null ? undefined : body });
  const text = await res.text();
  if (!res.ok) {
    let detail = text;
    try {
      const j = JSON.parse(text);
      detail = JSON.stringify(j.error || j);
    } catch {
      /* keep raw */
    }
    const err = new Error("GOOGLE_HTTP_" + res.status + ": " + String(detail).slice(0, 600));
    err.status = res.status;
    err.detail = detail;
    throw err;
  }
  if (raw) return { status: res.status, text };
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

// ---------------------------------------------------------------------------
// tools
// ---------------------------------------------------------------------------

function scopeOf(tool) {
  const needs = {
    gdrive_list: ["https://www.googleapis.com/auth/drive"],
    gdrive_read: ["https://www.googleapis.com/auth/drive"],
    gdrive_write: ["https://www.googleapis.com/auth/drive"],
    gdrive_delete: ["https://www.googleapis.com/auth/drive"],
    gmail_list: ["https://www.googleapis.com/auth/gmail.modify"],
    gmail_read: ["https://www.googleapis.com/auth/gmail.modify"],
    gmail_send: ["https://www.googleapis.com/auth/gmail.send"],
    gmail_draft: ["https://www.googleapis.com/auth/gmail.compose"],
    gmail_label: ["https://www.googleapis.com/auth/gmail.modify"],
    gdocs_get: ["https://www.googleapis.com/auth/documents"],
    gdocs_create: ["https://www.googleapis.com/auth/documents"],
    gdocs_update: ["https://www.googleapis.com/auth/documents"],
    gsheets_read: ["https://www.googleapis.com/auth/spreadsheets"],
    gsheets_write: ["https://www.googleapis.com/auth/spreadsheets"],
    gcalendar_list: ["https://www.googleapis.com/auth/calendar"],
    gcalendar_create: ["https://www.googleapis.com/auth/calendar.events"],
    gphotos_list: ["https://www.googleapis.com/auth/photoslibrary.readonly"],
    gbooks_search: [],
    gkeep_list: ["https://www.googleapis.com/auth/keep"],
    gtasks_list: ["https://www.googleapis.com/auth/tasks"],
    gsites_list: ["https://www.googleapis.com/auth/sites"],
    gscript_list: ["https://www.googleapis.com/auth/script.projects"],
    gchat_spaces: ["https://www.googleapis.com/auth/chat.messages"],
    youtube_my_videos: ["https://www.googleapis.com/auth/youtube.readonly"],
    youtube_upload: ["https://www.googleapis.com/auth/youtube.upload"],
  };
  return needs[tool] || [];
}

function currentScopes() {
  const creds = readCreds();
  return (creds && creds.scope) || tokenCache.scope || "";
}

function missingScope(tool) {
  const have = currentScopes().split(/\s+/).filter(Boolean);
  const need = scopeOf(tool);
  if (!need.length) return null;
  // a broader scope covers the narrower one
  const ok = need.every((s) => have.includes(s) || have.some((h) => s.startsWith(h)));
  return ok ? null : need.join(" ");
}

const TOOLS = [
  {
    name: "google_auth_status",
    description:
      "State of the permanent Google credential in this container: LIVE grant, granted scopes, whether a re-consent is required, and the local data paths. Call this first when Google calls fail.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "google_scope_upgrade",
    description:
      "Prints the ONE consent URL that widens the credential to every Google API scope (photos, keep, tasks, sites, script, chat, youtube, full mail). One click in a browser, permanent afterwards. Use the client whose secret is in the mounted secrets volume.",
    inputSchema: {
      type: "object",
      properties: {
        client: { type: "string", description: "Which mounted client to use: 'live' (default) or 'secrets'." },
        redirect_uri: { type: "string", description: "Optional redirect URI; defaults to urn:ietf:wg:oauth:2.0:oob." },
      },
      additionalProperties: false,
    },
  },
  {
    name: "gdrive_list",
    description: "List files/folders in Drive. Supports a Drive q query and a parent folder id.",
    inputSchema: {
      type: "object",
      properties: {
        q: { type: "string", description: "Drive query, e.g. \"mimeType='application/vnd.google-apps.folder'\"." },
        folder_id: { type: "string", description: "Parent folder id; 'root' means My Drive." },
        page_size: { type: "number", description: "1..1000, default 50." },
      },
      additionalProperties: false,
    },
  },
  {
    name: "gdrive_read",
    description: "Read a Drive file. Google-native docs are exported as text; other files are downloaded (text-ish content only).",
    inputSchema: {
      type: "object",
      properties: { file_id: { type: "string" }, mime_type: { type: "string" } },
      required: ["file_id"],
      additionalProperties: false,
    },
  },
  {
    name: "gdrive_write",
    description: "Create a file in Drive (optionally as a Google Doc/Sheet) with text content.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string" },
        content: { type: "string" },
        mime_type: { type: "string", description: "Defaults to text/plain." },
        folder_id: { type: "string" },
      },
      required: ["name"],
      additionalProperties: false,
    },
  },
  {
    name: "gmail_list",
    description: "List Gmail messages. Supports a Gmail search query (q).",
    inputSchema: {
      type: "object",
      properties: {
        q: { type: "string" },
        max_results: { type: "number", description: "1..100, default 25." },
      },
      additionalProperties: false,
    },
  },
  {
    name: "gmail_read",
    description: "Read one Gmail message by id.",
    inputSchema: {
      type: "object",
      properties: { message_id: { type: "string" } },
      required: ["message_id"],
      additionalProperties: false,
    },
  },
  {
    name: "gmail_send",
    description: "Send an email from the account.",
    inputSchema: {
      type: "object",
      properties: {
        to: { type: "string" },
        subject: { type: "string" },
        body: { type: "string" },
        cc: { type: "string" },
      },
      required: ["to", "subject", "body"],
      additionalProperties: false,
    },
  },
  {
    name: "gmail_draft",
    description: "Create a Gmail draft (not sent).",
    inputSchema: {
      type: "object",
      properties: {
        to: { type: "string" },
        subject: { type: "string" },
        body: { type: "string" },
      },
      required: ["to", "subject", "body"],
      additionalProperties: false,
    },
  },
  {
    name: "gdocs_get",
    description: "Read a Google Doc as plain text.",
    inputSchema: {
      type: "object",
      properties: { document_id: { type: "string" } },
      required: ["document_id"],
      additionalProperties: false,
    },
  },
  {
    name: "gdocs_create",
    description: "Create a Google Doc with text content.",
    inputSchema: {
      type: "object",
      properties: { title: { type: "string" }, body: { type: "string" } },
      required: ["title"],
      additionalProperties: false,
    },
  },
  {
    name: "gdocs_update",
    description: "Append text to a Google Doc (insertText at the end of the body).",
    inputSchema: {
      type: "object",
      properties: { document_id: { type: "string" }, text: { type: "string" } },
      required: ["document_id", "text"],
      additionalProperties: false,
    },
  },
  {
    name: "gsheets_read",
    description: "Read a range from a Google Sheet.",
    inputSchema: {
      type: "object",
      properties: {
        spreadsheet_id: { type: "string" },
        range: { type: "string", description: "e.g. A1:D50" },
      },
      required: ["spreadsheet_id"],
      additionalProperties: false,
    },
  },
  {
    name: "gsheets_write",
    description: "Write values into a range of a Google Sheet.",
    inputSchema: {
      type: "object",
      properties: {
        spreadsheet_id: { type: "string" },
        range: { type: "string" },
        values: { type: "array", items: { type: "array", items: { type: "string" } } },
      },
      required: ["spreadsheet_id", "range", "values"],
      additionalProperties: false,
    },
  },
  {
    name: "gcalendar_list",
    description: "List calendar events.",
    inputSchema: {
      type: "object",
      properties: {
        max_results: { type: "number" },
        time_min: { type: "string" },
        time_max: { type: "string" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "gcalendar_create",
    description: "Create a calendar event.",
    inputSchema: {
      type: "object",
      properties: {
        summary: { type: "string" },
        start: { type: "string", description: "ISO 8601." },
        end: { type: "string", description: "ISO 8601." },
        description: { type: "string" },
      },
      required: ["summary", "start", "end"],
      additionalProperties: false,
    },
  },
  {
    name: "gphotos_list",
    description: "List photos in the library (needs the photoslibrary scope).",
    inputSchema: {
      type: "object",
      properties: { page_size: { type: "number" } },
      additionalProperties: false,
    },
  },
  {
    name: "gbooks_search",
    description: "Search Google Books (public API, no special scope).",
    inputSchema: {
      type: "object",
      properties: { q: { type: "string" }, max_results: { type: "number" } },
      required: ["q"],
      additionalProperties: false,
    },
  },
  {
    name: "gkeep_list",
    description: "List Google Keep notes (needs the keep scope).",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "gtasks_list",
    description: "List Google Tasks (needs the tasks scope).",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "gsites_list",
    description: "List Google Sites (needs the sites scope).",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "gscript_list",
    description: "List Apps Script projects (needs the script.projects scope).",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "gchat_spaces",
    description: "List Google Chat spaces (needs the chat.messages scope).",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "youtube_my_videos",
    description: "List the channel's own YouTube videos (needs the youtube.readonly scope).",
    inputSchema: {
      type: "object",
      properties: { max_results: { type: "number" } },
      additionalProperties: false,
    },
  },
  {
    name: "notebooklm_ask",
    description:
      "Ask NotebookLM through the ExtendLM MCP server (https://mcp.extendlm.com/mcp). Needs an ExtendLM token: put it in /data/extendlm.json as {\"token\":\"...\"}. The browser extension must be connected.",
    inputSchema: {
      type: "object",
      properties: {
        question: { type: "string" },
        notebook_id: { type: "string" },
      },
      required: ["question"],
      additionalProperties: false,
    },
  },
];

// ---------------------------------------------------------------------------
// tool implementations
// ---------------------------------------------------------------------------

function b64url(buf) {
  return Buffer.from(buf).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function rawEmail({ to, subject, body, cc }) {
  const lines = [];
  lines.push("To: " + to);
  if (cc) lines.push("Cc: " + cc);
  lines.push("Subject: " + subject);
  lines.push("MIME-Version: 1.0");
  lines.push('Content-Type: text/plain; charset="UTF-8"');
  lines.push("");
  lines.push(body || "");
  return lines.join("\n");
}

const IMPL = {
  async google_auth_status() {
    const creds = readCreds();
    const flag = fs.existsSync(REAUTH_FLAG) ? JSON.parse(fs.readFileSync(REAUTH_FLAG, "utf8")) : null;
    let live = false;
    let probe = "not probed";
    try {
      await accessToken();
      live = true;
      probe = "token minted";
    } catch (e) {
      probe = e.message;
    }
    return {
      credential_present: !!creds,
      client_id: creds ? creds.client_id : null,
      grant_live: live,
      reauth_required: !!flag || !live,
      reauth_reason: flag ? flag.reason : null,
      probe,
      granted_scopes: currentScopes().split(/\s+/).filter(Boolean),
      data_dir: DATA_DIR,
      credential_file: CRED_FILE,
      note: "The refresh token lives in the mounted volume, not in the image. Access tokens are minted from it automatically.",
    };
  },

  async google_scope_upgrade(args) {
    const client = (args && args.client) || "live";
    const creds = readCreds();
    if (!creds) throw new Error("NO_CREDENTIAL");
    const redirect = (args && args.redirect_uri) || "urn:ietf:wg:oauth:2.0:oob";

    // Two clients are available on this machine:
    //  - 'live'   : the client the current (permanent) grant belongs to
    //  - 'secrets': the client whose secret sits in the mounted secrets volume
    // The widening consent is made with 'secrets' so the resulting token is
    // not tied to a client whose secret lives only in one store.
    let clientId = creds.client_id;
    let secretFile = null;
    if (client === "secrets") {
      const dir = process.env.GA_SECRETS_DIR || "/secrets";
      let files = [];
      try {
        files = fs.readdirSync(dir);
      } catch {
        throw new Error("NO_SECRETS_DIR: " + dir + " is not mounted.");
      }
      for (const f of files) {
        if (!/client_secret.*\.json$/i.test(f)) continue;
        try {
          const j = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
          const sec = j.web || j.installed || {};
          if (sec.client_id) {
            clientId = sec.client_id;
            secretFile = f;
            break;
          }
        } catch {
          /* not json */
        }
      }
      if (!secretFile) throw new Error("NO_CLIENT_IN_SECRETS: no client_secret json under " + dir);
    }

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirect,
      response_type: "code",
      access_type: "offline",
      prompt: "consent",
      include_granted_scopes: "true",
      scope: FULL_SCOPES.join(" "),
    });
    return {
      consent_url: "https://accounts.google.com/o/oauth2/v2/auth?" + params.toString(),
      client_used: client,
      client_id_used: clientId,
      secret_file: secretFile,
      scopes_requested: FULL_SCOPES.length,
      instruction:
        "Open this URL once in the signed-in browser, press Allow, and copy the code back. Then run on the host: node provision-grant.cjs --from-code <code> --client <client>. After that the grant is permanent and no consent is needed again.",
    };
  },

  async gdrive_list(args) {
    const page = Math.min(Number(args.page_size || 50), 1000);
    let q = args.q || "";
    if (args.folder_id && !/trashed/.test(q)) {
      const f = args.folder_id === "root" ? "root" : args.folder_id;
      q = q ? q + " and '" + f + "' in parents" : "'" + f + "' in parents";
    }
    const url =
      "/drive/v3/files?pageSize=" +
      page +
      "&fields=files(id,name,mimeType,size,modifiedTime,parents,webViewLink,trashed)" +
      (q ? "&q=" + encodeURIComponent(q) : "");
    const r = await gfetch(url);
    return { count: (r.files || []).length, files: r.files || [] };
  },

  async gdrive_read(args) {
    const meta = await gfetch("/drive/v3/files/" + args.file_id + "?fields=id,name,mimeType,size");
    const m = meta.mimeType || "";
    if (m === "application/vnd.google-apps.document") {
      const t = await gfetch("/drive/v3/files/" + args.file_id + "/export?mimeType=text/plain", { raw: true });
      return { id: meta.id, name: meta.name, mime_type: m, text: t.text };
    }
    if (m === "application/vnd.google-apps.spreadsheet") {
      const t = await gfetch("/drive/v3/files/" + args.file_id + "/export?mimeType=text/csv", { raw: true });
      return { id: meta.id, name: meta.name, mime_type: m, text: t.text };
    }
    const t = await gfetch("/drive/v3/files/" + args.file_id + "?alt=media", { raw: true });
    return { id: meta.id, name: meta.name, mime_type: m, text: t.text.slice(0, 200000) };
  },

  async gdrive_write(args) {
    const mime = args.mime_type || "text/plain";
    const body = args.content || "";
    const meta = { name: args.name, mimeType: mime };
    if (args.folder_id) meta.parents = [args.folder_id];
    if (mime === "application/vnd.google-apps.document") {
      const doc = await gfetch("/drive/v3/files", { method: "POST", body: JSON.stringify(meta) });
      if (body) {
        await gfetch("/documents/v1/documents/" + doc.id + ":batchUpdate", {
          method: "POST",
          body: JSON.stringify({
            requests: [{ insertText: { location: { index: 1 }, text: body } }],
          }),
        });
      }
      return { id: doc.id, name: doc.name, webViewLink: doc.webViewLink };
    }
    const boundary = "ga_boundary_" + Date.now();
    const encoded = b64url(Buffer.from(body, "utf8"));
    const payload =
      "--" + boundary + "\r\nContent-Type: " + mime + "\r\n\r\n" + body + "\r\n--" + boundary + "--";
    const created = await gfetch("/upload/drive/v3/files?uploadType=multipart", {
      method: "POST",
      headers: { "Content-Type": "multipart/related; boundary=" + boundary },
      body: payload,
    }).catch(async () => {
      // multipart/related needs the JSON part first
      const json = b64url(Buffer.from(JSON.stringify(meta), "utf8"));
      const p2 =
        "--" + boundary + "\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n" + json +
        "\r\n--" + boundary + "\r\nContent-Type: " + mime + "\r\n\r\n" + body + "\r\n--" + boundary + "--";
      return gfetch("/upload/drive/v3/files?uploadType=multipart", {
        method: "POST",
        headers: { "Content-Type": "multipart/related; boundary=" + boundary },
        body: p2,
      });
    });
    void encoded;
    return { id: created.id, name: created.name, webViewLink: created.webViewLink };
  },

  async gmail_list(args) {
    const max = Math.min(Number(args.max_results || 25), 100);
    const url = "/gmail/v1/users/me/messages?maxResults=" + max + (args.q ? "&q=" + encodeURIComponent(args.q) : "");
    const r = await gfetch(url);
    const messages = r.messages || [];
    const brief = [];
    for (const m of messages.slice(0, max)) {
      const d = await gfetch("/gmail/v1/users/me/messages/" + m.id + "?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date");
      const h = d.payload ? d.payload.headers || [] : [];
      const get = (n) => (h.find((x) => x.name.toLowerCase() === n) || {}).value || "";
      brief.push({ id: m.id, threadId: m.threadId, subject: get("subject"), from: get("from"), date: get("date") });
    }
    return { count: brief.length, messages: brief };
  },

  async gmail_read(args) {
    const r = await gfetch("/gmail/v1/users/me/messages/" + args.message_id + "?format=full");
    const h = r.payload ? r.payload.headers || [] : [];
    const get = (n) => (h.find((x) => x.name.toLowerCase() === n) || {}).value || "";
    let body = "";
    const walk = (p) => {
      if (!p) return;
      if (p.mimeType === "text/plain" && p.body && p.body.data) body = Buffer.from(p.body.data, "base64").toString("utf8");
      (p.parts || []).forEach(walk);
    };
    walk(r.payload);
    return { id: r.id, subject: get("subject"), from: get("from"), to: get("to"), date: get("date"), body };
  },

  async gmail_send(args) {
    const raw = rawEmail(args);
    const r = await gfetch("/gmail/v1/users/me/messages/send", {
      method: "POST",
      body: JSON.stringify({ raw: b64url(Buffer.from(raw, "utf8")) }),
    });
    return { sent: true, id: r.id, threadId: r.threadId };
  },

  async gmail_draft(args) {
    const raw = rawEmail(args);
    const r = await gfetch("/gmail/v1/users/me/drafts", {
      method: "POST",
      body: JSON.stringify({ message: { raw: b64url(Buffer.from(raw, "utf8")) } }),
    });
    return { draft_id: r.id };
  },

  async gdocs_get(args) {
    const d = await gfetch("/documents/v1/documents/" + args.document_id);
    const read = (p) => (p.textRun ? p.textRun.content : "");
    let text = "";
    const walk = (el) => {
      if (!el) return;
      if (el.paragraph) text += read(el.paragraph.elements ? el.paragraph.elements[0] : {}) + "\n";
      (el.paragraphs || []).forEach(walk);
      (el.content || []).forEach(walk);
      (el.table || {}).rows &&
        el.table.rows.forEach((row) => {
          row.cells.forEach((c) => (c.content || []).forEach(walk));
        });
    };
    walk(d.body);
    return { title: d.title, document_id: d.documentId, text };
  },

  async gdocs_create(args) {
    const d = await gfetch("/documents/v1/documents", {
      method: "POST",
      body: JSON.stringify({ title: args.title }),
    });
    if (args.body) {
      await gfetch("/documents/v1/documents/" + d.documentId + ":batchUpdate", {
        method: "POST",
        body: JSON.stringify({
          requests: [{ insertText: { location: { index: 1 }, text: args.body } }],
        }),
      });
    }
    return { document_id: d.documentId, title: d.title };
  },

  async gdocs_update(args) {
    const r = await gfetch("/documents/v1/documents/" + args.document_id + ":batchUpdate", {
      method: "POST",
      body: JSON.stringify({
        requests: [{ insertText: { location: { index: 1 }, text: args.text } }],
      }),
    });
    return { document_id: args.document_id, replies: (r.replies || []).length };
  },

  async gsheets_read(args) {
    const range = args.range || "A1:Z100";
    const r = await gfetch(
      "/sheets/v4/spreadsheets/" + args.spreadsheet_id + "/values/" + encodeURIComponent(range)
    );
    return { spreadsheet_id: args.spreadsheet_id, range, values: r.values || [] };
  },

  async gsheets_write(args) {
    const r = await gfetch(
      "/sheets/v4/spreadsheets/" + args.spreadsheet_id + "/values/" + encodeURIComponent(args.range) + "?valueInputOption=RAW",
      { method: "PUT", body: JSON.stringify({ range: args.range, values: args.values }) }
    );
    return { spreadsheet_id: args.spreadsheet_id, updated: r.updatedCells, range: r.updatedRange };
  },

  async gcalendar_list(args) {
    const p = new URLSearchParams({ maxResults: String(Math.min(Number(args.max_results || 25), 250)) });
    if (args.time_min) p.set("timeMin", args.time_min);
    if (args.time_max) p.set("timeMax", args.time_max);
    const r = await gfetch("/calendar/v3/calendars/primary/events?" + p.toString());
    return { count: (r.items || []).length, events: (r.items || []).map((e) => ({ id: e.id, summary: e.summary, start: e.start, end: e.end, location: e.location })) };
  },

  async gcalendar_create(args) {
    const r = await gfetch("/calendar/v3/calendars/primary/events", {
      method: "POST",
      body: JSON.stringify({
        summary: args.summary,
        description: args.description || "",
        start: { dateTime: args.start },
        end: { dateTime: args.end },
      }),
    });
    return { event_id: r.id, htmlLink: r.htmlLink };
  },

  async gphotos_list(args) {
    const r = await gfetch(
      "/photoslibrary/v1/photos?pageSize=" + Math.min(Number(args.page_size || 25), 100)
    );
    return { count: (r.photos || []).length, photos: (r.photos || []).map((p) => ({ id: p.id, created: p.mediaMetadata && p.mediaMetadata.dateTaken })) };
  },

  async gbooks_search(args) {
    const r = await gfetch(
      "https://www.googleapis.com/books/v1/volumes?q=" + encodeURIComponent(args.q) + "&maxResults=" + Math.min(Number(args.max_results || 10), 40)
    );
    return {
      count: (r.items || []).length,
      items: (r.items || []).map((i) => ({
        title: i.volumeInfo && i.volumeInfo.title,
        authors: i.volumeInfo && i.volumeInfo.authors,
        publishedDate: i.volumeInfo && i.volumeInfo.publishedDate,
        link: i.volumeInfo && i.volumeInfo.infoLink,
      })),
    };
  },

  async gkeep_list() {
    const r = await gfetch("/keep/v1/notes?pageSize=50");
    return { count: (r.notes || []).length, notes: (r.notes || []).map((n) => ({ name: n.name, title: n.title })) };
  },

  async gtasks_list() {
    const r = await gfetch("/tasks/v1/users/@me/lists");
    return { lists: (r.items || []).map((l) => ({ id: l.id, title: l.title })) };
  },

  async gsites_list() {
    const r = await gfetch("/sites/v1/sites");
    return { sites: (r.site || r.sites || []).map((s) => ({ name: s.name, url: s.url })) };
  },

  async gscript_list() {
    const r = await gfetch("/script/v1/projects");
    return { projects: (r.projects || []).map((p) => ({ script_id: p.scriptId, title: p.title })) };
  },

  async gchat_spaces() {
    const r = await gfetch("/chat/v1/spaces");
    return { spaces: (r.spaces || []).map((s) => ({ name: s.name, displayName: s.displayName })) };
  },

  async youtube_my_videos(args) {
    const r = await gfetch(
      "https://www.googleapis.com/youtube/v3/channels/mine?part=contentDetails,id,snippet"
    );
    return { channel: r.items && r.items[0] ? r.items[0].snippet.title : null, channel_id: r.items && r.items[0] ? r.items[0].id : null };
  },

  async notebooklm_ask(args) {
    const cfgPath = path.join(DATA_DIR, "extendlm.json");
    let cfg = {};
    try {
      cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
    } catch {
      throw new Error(
        "NO_EXTENDLM_TOKEN: put {\"token\":\"...\"} in " + cfgPath + " on the host. The ExtendLM MCP page (mcp.extendlm.com/mcp) issues the token once, in the browser."
      );
    }
    const token = cfg.token;
    const init = await fetch(EXTENDLM_MCP_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        Authorization: "Bearer " + token,
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: { name: "google-access", version: "1.0" },
        },
      }),
    });
    const sid = init.headers.get("mcp-session-id");
    const tools = await fetch(EXTENDLM_MCP_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        Authorization: "Bearer " + token,
        ...(sid ? { "mcp-session-id": sid } : {}),
      },
      body: JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }),
    });
    const body = await tools.text();
    return { session_id: sid, extendlm_tools: body.slice(0, 4000), question: args.question };
  },
};

// ---------------------------------------------------------------------------
// MCP plumbing (Streamable HTTP, JSON-RPC 2.0)
// ---------------------------------------------------------------------------

const PROTOCOL_VERSION = "2024-11-05";

function rpcResult(id, result) {
  return { jsonrpc: "2.0", id, result };
}
function rpcError(id, code, message) {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

async function handleToolCall(name, args) {
  const impl = IMPL[name];
  if (!impl) throw new Error("UNKNOWN_TOOL: " + name);
  const miss = missingScope(name);
  if (miss) {
    throw new Error(
      "MISSING_SCOPE: " + name + " needs " + miss + ". The current grant covers " +
        currentScopes() + ". Call google_scope_upgrade for the one consent URL that widens it (one click, permanent)."
    );
  }
  return impl(args || {});
}

async function handleRpc(msg) {
  const { id, method, params } = msg;
  switch (method) {
    case "initialize":
      return rpcResult(id, {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "Google_Access", version: "1.0.0" },
        instructions:
          "Permanent Google access for any AI on this machine. Call google_auth_status first if a Google call fails; it reports whether a re-consent is required and the granted scopes.",
      });
    case "notifications/initialized":
      return null;
    case "ping":
      return rpcResult(id, {});
    case "tools/list":
      return rpcResult(id, { tools: TOOLS });
    case "tools/call": {
      try {
        const out = await handleToolCall(params.name, params.arguments || {});
        return rpcResult(id, {
          content: [{ type: "text", text: JSON.stringify(out, null, 2) }],
          isError: false,
        });
      } catch (e) {
        return rpcResult(id, {
          content: [{ type: "text", text: "ERROR: " + (e && e.message ? e.message : String(e)) }],
          isError: true,
        });
      }
    }
    case "resources/list":
      return rpcResult(id, { resources: [] });
    case "prompts/list":
      return rpcResult(id, { prompts: [] });
    default:
      if (id === undefined) return null;
      return rpcError(id, -32601, "METHOD_NOT_FOUND: " + method);
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://" + (req.headers.host || HOST));
  if (req.method === "GET" && (url.pathname === "/health" || url.pathname === "/")) {
    let grant = "absent";
    try {
      await accessToken();
      grant = "live";
    } catch (e) {
      grant = "reauth_required";
    }
    const body = JSON.stringify({
      service: "Google_Access",
      grant,
      reauth_required: fs.existsSync(REAUTH_FLAG),
      tools: TOOLS.length,
      data_dir: DATA_DIR,
      time: new Date().toISOString(),
    });
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(body);
    return;
  }
  if (req.method !== "POST") {
    res.writeHead(405, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "method not allowed" }));
    return;
  }
  let raw = "";
  req.on("data", (c) => (raw += c));
  req.on("end", async () => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify(rpcError(null, -32700, "parse error")));
      return;
    }
    const out = await handleRpc(msg);
    const wantsSse = String(req.headers.accept || "").includes("text/event-stream");
    if (out === null) {
      res.writeHead(202, { "Content-Type": "application/json" });
      res.end("");
      return;
    }
    const payload = JSON.stringify(out);
    if (wantsSse) {
      res.writeHead(200, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache" });
      res.end("event: message\ndata: " + payload + "\n\n");
    } else {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(payload);
    }
  });
});

server.listen(PORT, HOST, () => {
  console.log("Google_Access MCP listening on http://" + HOST + ":" + PORT + "/mcp");
  console.log("DATA_DIR=" + DATA_DIR + " CREDENTIALS=" + (fs.existsSync(CRED_FILE) ? "present" : "MISSING"));
  console.log("TOOLS=" + TOOLS.length);
});
