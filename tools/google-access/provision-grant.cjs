// provision-grant.cjs - host side.
//
// Two jobs:
//   1. default: find a LIVE Google grant on this machine (same mechanism as
//      google-layer/google-grant.js) and publish it into the Google_Access
//      container's persistent volume.
//   2. --from-code <code> [--client live|secrets]: exchange a widening
//      consent code for tokens and publish them. This is the ONE click that
//      widens the credential to every Google API scope.
//
// It NEVER prints a token: only labels, lengths and HTTP statuses.
"use strict";
const fs = require("node:fs");
const path = require("node:path");

const GL = "C:\\Users\\apviz\\.minimax-agent\\projects\\google-layer";
const grant = require(path.join(GL, "google-grant.js"));

const DATA_DIR = "C:\\Users\\apviz\\.minimax\\google-access\\data";
const OUT = path.join(DATA_DIR, "credentials.json");
const SECRETS_DIR = "E:\\--- System Secrets";
const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";

function readJson(p) {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}

function secretClient() {
  let files = [];
  try {
    files = fs.readdirSync(SECRETS_DIR);
  } catch {
    return null;
  }
  for (const f of files) {
    if (!/client_secret.*\.json$/i.test(f)) continue;
    const j = readJson(path.join(SECRETS_DIR, f));
    if (!j) continue;
    const sec = j.web || j.installed || {};
    if (sec.client_id && sec.client_secret) {
      return { file: f, client_id: sec.client_id, client_secret: sec.client_secret };
    }
  }
  return null;
}

function publish(obj) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify(obj, null, 2), "utf8");
  console.log("WROTE=" + OUT + " bytes=" + fs.statSync(OUT).size);
}

async function exchangeCode(code, clientId, clientSecret, redirectUri) {
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    code,
    grant_type: "authorization_code",
    redirect_uri: redirectUri,
  });
  const res = await fetch(OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, json };
}

(async () => {
  const argv = process.argv.slice(2);
  const codeIdx = argv.indexOf("--from-code");
  const clientIdx = argv.indexOf("--client");
  const redirectUri = "urn:ietf:wg:oauth:2.0:oob";

  if (codeIdx !== -1) {
    const code = argv[codeIdx + 1];
    const which = clientIdx !== -1 ? argv[clientIdx + 1] : "secrets";
    if (!code) {
      console.log("ERROR=missing code after --from-code");
      process.exit(2);
    }
    let clientId, clientSecret, label;
    if (which === "secrets") {
      const sc = secretClient();
      if (!sc) {
        console.log("ERROR=no client secret found under " + SECRETS_DIR);
        process.exit(3);
      }
      clientId = sc.client_id;
      clientSecret = sc.client_secret;
      label = "secrets:" + sc.file;
    } else {
      const live = await grant.findLiveGrant(null);
      if (!live) {
        console.log("ERROR=no live grant on this machine");
        process.exit(3);
      }
      clientId = live.clientId;
      clientSecret = live.clientSecret;
      label = "live:" + live.label;
    }
    const ex = await exchangeCode(code, clientId, clientSecret, redirectUri);
    console.log("TOKEN_ENDPOINT_HTTP=" + ex.status);
    if (ex.status !== 200 || !ex.json.access_token) {
      console.log("ERROR=" + (ex.json.error || "unknown") + " " + (ex.json.error_description || ""));
      console.log("NO_CHANGE=1 (the stored credential is untouched)");
      process.exit(4);
    }
    const refresh = ex.json.refresh_token;
    if (!refresh) {
      console.log("ERROR=no refresh_token returned - the code was probably already used");
      process.exit(5);
    }
    // verify the new refresh token against the endpoint
    const probe = await grant.exchange(clientId, clientSecret, refresh);
    console.log("REFRESH_PROBE_HTTP=" + probe.status + " expires_in=" + (probe.json.expires_in || "-"));
    publish({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refresh,
      scope: probe.json.scope || "",
      provisioned_at: new Date().toISOString(),
      source: label + " (widened consent)",
    });
    console.log("SCOPES=" + (probe.json.scope || ""));
    console.log("PERMANENT=1 (refresh token persists in the mounted volume; no consent needed again)");
    return;
  }

  console.log("=== candidates ===");
  const cands = grant.findCandidates();
  for (const c of cands) {
    const ex = await grant.exchange(c.clientId, c.clientSecret, c.refreshToken);
    const ok = ex.status === 200 && !!ex.json.access_token;
    console.log(
      (ok ? "LIVE " : "DEAD ") +
        c.label +
        " | client_id=" + c.clientId.slice(0, 28) +
        " | http=" + ex.status +
        " | " + (ex.json.error || "expires_in=" + ex.json.expires_in)
    );
  }

  const live = await grant.findLiveGrant((l) => console.log("  " + l));
  if (!live) {
    console.log("NO_LIVE_GRANT=1 -> re-consent is required (ACCESS)");
    process.exit(3);
  }
  console.log("LIVE_GRANT=1 client_id=" + live.clientId);
  console.log("LIVE_SCOPE=" + (live.scope || "(none reported)"));

  const sc = secretClient();
  if (sc) {
    console.log("SECRETS_CLIENT=" + sc.file + " client_id=" + sc.client_id + " MATCHES_LIVE=" + (sc.client_id === live.clientId));
  }

  publish({
    client_id: live.clientId,
    client_secret: live.clientSecret,
    refresh_token: live.refreshToken,
    scope: live.scope || "",
    provisioned_at: new Date().toISOString(),
    source: live.label,
  });
  console.log("SECRETS_IN_IMAGE=none (credential lives in the mounted volume only)");
})().catch((e) => {
  console.log("ERROR=" + (e && e.message ? e.message : String(e)));
  process.exit(4);
});
