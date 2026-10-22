# STATUS — Google Workspace

**Creat:** 2026-10-12 · **Repo:** `https://github.com/apvizual-max/MAVIS-CLOUD.git` · **30 commituri**
**Actualizat:** 2026-10-22

## Stare

| Ce | Stare |
|---|---|
| Capitol documentat | ✅ |
| Priming KIT creat | ✅ |
| Skill de control | ✅ `.skills/google-cloud-auth/` |
| Predare completă | ✅ `HANDOFF.md` în acest folder |
| Prompt de start | ✅ `PROMPT-START.txt` |
| Client OAuth verificat | ✅ Desktop, proiect `gen-lang-client-0284509562` |
| Credentiale în secret manager | ✅ client_id + client_secret + email |
| **Refresh token** | ⛔ **LIPSA** — lipsește un singur consimțământ |
| Test de diagnostic | ✅ `mavis-tools/google-preflight.js` |

## Ce urmează

1. **Un consimțământ în browser** → `18-GOOGLE/AUTORIZARE-LINK.txt` (linkul e generat
   de `mavis-tools/google-link-file.js`).
2. **Tokenul în secret manager** → `GOOGLE_REFRESH_TOKEN_MAVIS_CLOUD`.
3. **Verificare live** → `node mavis-tools/google-verify.js` din cloud.
4. **In production** → `docs/GOOGLE-PRODUCTION-CHECKLIST.md`. Până atunci, tokenul
   moare în 7 zile de la consimțământ (appul e în modul Testing).

## Regula de naming

Fără notebook pentru acest capitol.
Notebook-urile create de Mavis Cloud se numesc obligatoriu
`MavisCloud-(subiect)`.

## Capcana de reținut (2026-10-22)

**Platforma maschează valorile din secret manager în mesajele de chat.**
Un link de autorizare trimis prin chat ajunge în browser cu
`{{ARCHON_SECRET:...}}` în loc de client_id real → *Error 401: invalid_client*.
Client ID e identificator public → stă în repo (`mavis-tools/google-client.json`),
iar linkul se livrează prin **fișier în repo**, nu prin chat.
