# STARE — platforma Jules

**Măsurat:** 2026-10-22 · **Metodă:** `gh api` / `gh pr list` / rularea
scripturilor pe această mașină.

## 1. Ceea ce s-a măsurat, nu ce s-a presupus

| Repo | Ramură | Privat | Etichetă `jules` | `jules.yml` | `JULES_API_KEY` | PR-uri Jules deschise |
|---|---|---|---|---|---|---|
| MAVIS-CLOUD | main | nu | ✅ | ✅ | ✅ | **34** |
| pkms-vault-automation | **master** | nu | ❌ | ❌ | ❌ | **25** |
| OPTIMUS-Backbone | main | nu | ❌ | ❌ | ❌ | **37** |
| SENTINEL_PRIME | main | **da** | ❌ | ❌ | ❌ | **3** |
| MAVIS-OPTIMUS-CI | main | nu | ❌ | ❌ | ❌ | 0 |
| Optimus-Mavis-Skills | main | nu | ❌ | ❌ | ❌ | 0 |
| hermes-doctor | main | nu | ❌ | ❌ | ❌ | 0 |
| Qwen-Ecosystem-Dashboard | main | da | ❌ | ❌ | ❌ | 0 |

**Total PR-uri Jules deschise: 99**, în 4 repo-uri, toate de la
`app/google-labs-jules`.

### Concluzia care schimbă modelul

**Jules lucrează în repo-uri fără plumbing-ul GitHub.** 62 dintre cele 99 de
PR-uri stau în repo-uri care n-au eticheta `jules`, n-au workflow și n-au
secret. Așa că Jules are **două căi**:

1. **Calea automată** — issue cu etichetă `jules` → `jules.yml` → Jules.
   Necesită etichetă + workflow + secret. Funcționează doar în MAVIS-CLOUD.
2. **Calea interfeței web** — „Run and snapshot" din `jules.google.com`, cu
   repo-ul conectat acolo. Nu necesită nimic pe partea GitHub. Funcționează
   peste tot unde Popy a configurat Jules.

**Platforma construită azi folosește calea automată**, pentru că este
programabilă și trasabilă. Calea web rămâne deschisă și produce PR-uri pe
care triajul le prinde oricum — de aceea registre 99 de PR-uri, nu 34.

## 2. Defectul care explica „Jules nu știe regulile proiectului"

`11-JULES/RAPORT-DE-STARE.md` scria că Jules nu are regulile în memorie.

**Nu era o limitare a lui Jules. Era un pointer rupt, făcut de mine.**

`MAVIS-CLOUD/.github/workflows/jules.yml` trimitea promptul:

```
Citește AGENTS.md și docs/HANDOFF-COMPLET.md înainte de orice lucru.
```

`docs/HANDOFF-COMPLET.md` **nu există** — a fost mutat cu `git mv` în
`docs/arhiva/handoffs-vechi/HANDOFF-COMPLET.md` (6.780 B) când s-a aplicat
regula de arhivare. Deci fiecare task Jules primea instrucțiunea de a citi
un fișier inexistent.

Reparația nu e „adaugă memoria în interfața Jules" (astea cere un click
uman, și e o singură repo-uri). Reparația e **structurală**: contextul
călătorește în corpul issue-ului, pe care workflow-ul îl transmite deja în
prompt. `config/jules-context.md` e sursa unică și se injectează automat.

## 3. Ce e construit și probat

| Piesă | Stare | Probă |
|---|---|---|
| `jules-dispatch.ps1` | ✅ | dry-run real: ținta aleasă din arborele repo-ului (`SITE/build-hub.py`, 32.574 B), corp de 5.766 caractere |
| `jules-verify.ps1` | ✅ | clone reală + `node --test ALEX-KIT/cv-mutator.test.js` → **EXIT 0** |
| `jules-triage.ps1` | ✅ | scanare reală a 99 de PR-uri, verdict cu motiv, buget 5 verificări/repo |
| `jules-daily.ps1` | ✅ | bucla completă, ledger de cotă, raport zilnic |
| `jules-install.ps1` | ✅ | mod PLAN rulat pe MAVIS-OPTIMUS-CI: a detectat eticheta lipsă și secretul lipsă |
| `jules-lib.ps1` | ✅ | bibliotecă comună, ASCII pur |
| `run-jules-daily-logged.ps1` | ✅ | rulat cu `-DryRun` → log datat scris, EXIT 0 |
| Task Windows `JulesDailyLoop` | ✅ | înregistrat, `Ready`, zilnic **09:00**, `RunLevel Limited` |

### Porțile, cu contra-proba

| Poartă | Ce blochează | Contra-probă |
|---|---|---|
| Politică (secrete + căi interzise) | `ghp_…`, `sk-…`, chei PEM, `node_modules/`, `vendor/`, `dist/` | diff curat → **0** încălcare; diff contaminat → **2** (cale + secret) |
| Buget de verificare | verifică mai mult de 5 PR-uri/repo | PR #14 → marcat `not verified - budget reached`, **nu** ACCEPT |
| Instrument lipsă | `pytest`/`node` absent | clasificat `TOOL MISSING` → **NO_MEASUREMENT**, nu FAIL |

## 4. Defecte găsite și reparate în această sesiune

1. **`Path.GetTempFileName()`** aruncă „The file exists" pe această mașină →
   înlocuit cu `state/tmp/` + GUID.
2. **`$ErrorActionPreference='Stop'` + program nativ care scrie pe stderr** →
   `gh repo clone` oprea scriptul înainte de citirea codului de ieșire.
   `Invoke-Native` coboară preferința și o restaurează.
3. **Liniile de log contaminau codul de ieșire** → loguri pe `stderr`,
   rezultate pe `stdout`.
4. **`return ,@()`** produce o colecție de 1 element care conține un gol →
   `.Count` = 1 → **poarta respingea 100% din 96 de PR-uri**. Măsurat, reparat,
   reconfirmat: curat → 0, gol → 0.
5. **`)` de pris** la capătul unei linii în `jules-install.ps1` → 3 erori de
   parse.
6. **6 octeți non-ASCII** în `jules-triage.ps1` (`·`) → parserul PS 5.1 ar
   fi rupt șirurile.
7. **Pointer rupt** către `docs/HANDOFF-COMPLET.md` (vezi §2).

## 5. Starea git-ului

**`MAVIS-OPTIMUS-CI` este PUBLIC** și conținea **292 de fișiere cu date
personale** (CV-uri, telefon, nume de clienți) comise la rădăcină, în
`MAVIS-CLOUD-main repo - local/`. Copia de pe disc (`cloud-ingest/MAVIS-CLOUD`,
348 de fișiere) conține **toate cele 292** — zero pierdere la ștergere
(verificat fișier cu fișier).

`.gitignore` interzice acum `_GitHub-Main_Repos-Local/`, `work/`, `logs/`,
`state/tmp/`.

**Atenție:** ștergerea din arborele curent nu șterge din istoricul public.
Redresarea istoricului cere force-push → **interzis** fără R0 explicit, și e
o decizie a lui Popy, nu una a mea.

## 6. Ce rămâne și cine decide

| # | Decizie | Cine |
|---|---|---|
| 1 | `JULES_API_KEY` în cele 4 repo-uri fără el — **secretul nu poate fi citit de pe GitHub** | Popy |
| 2 | R0 pe merge-urile cu verdict ACCEPT | Popy |
| 3 | Al 5-lea repo cu Jules activ: `OPTIMUS-Backbone` e propunerea mea | Popy |
| 4 | Redresarea istoricului public al repo-ului (date personale) | Popy |
| 5 | R0 pe push-ul platformei în `MAVIS-OPTIMUS-CI` | Popy |
