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
| `jules-triage.ps1` | ✅ | scanare reală a **99 de PR-uri**, verdict cu motiv, buget 5 verificări/repo |
| `jules-daily.ps1` | ✅ | bucla completă, ledger de cotă, raport zilnic |
| `jules-install.ps1` | ✅ | mod PLAN rulat pe MAVIS-OPTIMUS-CI: a detectat eticheta lipsă și secretul lipsă |
| `jules-lib.ps1` | ✅ | bibliotecă comună, ASCII pur, `Write-JulesOut` (stdout direct) |
| `run-jules-daily-logged.ps1` | ✅ | rulat cu `-DryRun` → log datat scris, EXIT 0 |
| `jules-scan-staged.ps1` | ✅ | poartă pre-commit: `STAGED=13 SCANNED=13 BLOCKS=0 SCAN_OK`; control falsificare → **BLOCKS=3, SCAN_BLOCKED, EXIT=1** |
| `jules-selfcheck.ps1` | ✅ | `FILES=9 PROBLEMS=0`; **proba-idiom**: payload pe stdout ȘI cod de ieșire 3 |
| Task Windows `JulesDailyLoop` | ✅ | înregistrat, `Ready`, zilnic **09:00**, `RunLevel Limited` |

### Porțile, cu contra-proba

| Poartă | Ce blochează | Contra-probă |
|---|---|---|
| Politică (secrete + căi interzise) | `ghp_…`, `sk-…`, chei PEM, `node_modules/`, `vendor/`, `dist/` | diff curat → **0** încălcare; diff contaminat → **2** (cale + secret) |
| Buget de verificare | verifică mai mult de 5 PR-uri/repo | PR #14 → marcat `not verified - budget reached`, **nu** ACCEPT |
| Instrument lipsă | `pytest`/`node` absent | clasificat `TOOL MISSING` → **NO_MEASUREMENT**, nu FAIL |

## 3.1 Rezultatul primului triaj complet (2026-10-22, 10:29–10:33)

**99 de PR-uri scanate** — toate cele deschise, în 4 repo-uri.

| Verdict | Număr | Ce înseamnă |
|---|---|---|
| **ADAPT** | **12** | verificate **VERDE** local, dar raportul lipsește cele 3 secțiuni → le refac eu |
| **UNVERIFIED** | **81** | buget de verificare atins (5/repo). **Nu e ACCEPT.** |
| **UNVERIFIED** | **6** | instrumentul de verificare nu există în acel repo → fără măsurătoare |
| **REJECT** | **0** | nicio încălcare reală de politică |
| **ACCEPT** | **0** | toate cele 12 verificate au raportul incomplet |

Cele 12 ADAPT: 5 în MAVIS-CLOUD, 5 în OPTIMUS-Backbone, 2 în SENTINEL_PRIME.

**Observația care contează:** cele 12 au trecut testele reale pe această
mașină. Substanța e bună. Ce lipsește e **forma raportului** — Jules nu știa
formatul, pentru că nu i-a fost spus. De aici vine valoarea contextului
canonic: de acum înainte îl primește în corpul issue-ului.

Un PR gol (0 fișiere) a fost prins: `pkms-vault-automation` #24.

## 3.2 Defectul care făca toate porțile de nefolosit (măsurat 2026-10-22, după primul commit)

**Orice poartă care scria o linie înainte de a întoarce un cod de eșec
returna SUCCES.** Probe măsurat pe această mașină:

```
function F { Write-Output 'X'; return 3 }
$c = F        ->  $c = @('X', 3)      # Write-Output intră în valoarea returnată
exit $c       ->  EXIT 0              # exit ia ultimul element; codul 3 se pierde
```

Controlul: `function F { return 3 }` → `exit 3` → **EXIT 3**, corect.

Cauza: 6 scripturi apelează `$code = Main`, iar `Main` scria payload-ul cu
`Write-Output`. `Write-Output` scrie în **stream-ul de succes**, deci ajunge
în valoarea atribuită. Consecința: `jules-verify` (care trebuia să dea
distincția FAIL vs NO_MEASUREMENT), `jules-triage`, `jules-dispatch`,
`jules-daily`, `jules-install` și scannerul pre-commit **nu puteau eșua**.
O poartă care nu poate eșua nu e o poartă.

Reparație: `Write-JulesOut` în `jules-lib.ps1` — `[Console]::Out.WriteLine`,
scrie direct pe stdout, nu e capturată de atribuire și lasă codul de ieșire
intact. Măsurat: pe arbore `GATE_EXIT=0`, pe control cu adresă necanonică
`PROBE_EXIT=1`.

**Poarta de email din `verify.yml` se autotrigea.** Căuta adresa necanonică
prin literal, dar literalul se afla în `config/jules-context.md` — fișierul
care *numea* adresa ca s-o interzică. Gate = literal greșit:
1. nu poate prinde următoarea adresă greșită, fiindcă o caută pe una cunoscută;
2. se declanșează pe propria declarație de regulă.

Înlocuită cu o poartă de **comparație**: orice adresă găsită trebuie să fie
canonică. Setul scanat e cel **tracked** (`git ls-files`), deci rulează
identic în CI și local. Control falsificare: `PROBE_EXIT=1` pe un repo cu
o adresă necanonică, `GATE_EXIT=0` pe arborele real.

**Măsurătoare corectată:** adresa necanonică nu e într-un singur fișier din
materialul MAVIS-CLOUD, ci în **9**:
`PROGRES.md`, `07-SITEURI-NIVEL1/SPECIFICATIE.md`,
`11-JULES/RAPORT-DE-STARE.md`, `14-LINKEDIN/CATALOG.md`,
`ALEX-KIT/08-CVURI-NOTARE.md`, `docs/LOG-SISTEM.json`, `docs/NEXT-MAXHERMES.md`,
`docs/TODO.json`, `docs/arhiva/handoffs-vechi/HANDOFF-COMPLET.md`.
Într-un al 10-lea (`docs/git-install.md`) apare `alex@ap-id.ro` — adresă
diferită, pe domeniul lui; poarta o tratează ca permisă.

**Consecință pentru instalare:** poarta de email va fi ROȘIE în MAVIS-CLOUD
până când cele 9 fișiere sunt corectate. De aceea `jules-install.ps1` trebuie
să raporteze violările preexistente ca prerechizit, nu să instaleze tăcut o
poartă roșie. MAVIS-CLOUD rămâne read-only pentru conținut → repararea cere
R0.

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
8. **`Write-Output` contamină codul de ieșire** în 6 scripturi: orice poartă
   care scria o linie înainte de `return 3` returna **0**. Probe măsurat în
   §3.2. Reparat cu `Write-JulesOut`; verificat de o probă care eșuează
   intenționat, ca poarta să fie demonstrată ca poate eșua.
9. **Poarta de email din `verify.yml` se autotrigea** pe fișierul care
   declara regula. Înlocuită cu o poartă de comparație (vezi §3.2).
10. **Ledgerul de cotă era citit o singură dată**, înainte de bucla zilnică;
    subprocessul de dispatch îl actualizează, deci verificarea plafonului
    mintea. Recitit la fiecare iterare.
11. **Nu exista poartă pre-commit**: scanarea de secrete se făcuse o singură
    dată, manual, la comitarea lui `d0f04d6`. Acum `jules-scan-staged.ps1`
    scanează **index-ul** (ce va fi comis, nu ce sta pe disc) și e
    demonstrat capabil să blocheze.

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

Commituri locale, **nimic împins**: `d0f04d6` (platforma, 311 fișiere),
`c613236` (repararea porților: exit code real, poartă de email
comparativă, scanner pre-commit). `origin/main` e la `d9a186e`.

## 6. Ce rămâne și cine decide

| # | Decizie | Cine |
|---|---|---|
| 1 | `JULES_API_KEY` în cele 4 repo-uri fără el — **secretul nu poate fi citit de pe GitHub** | Popy |
| 2 | R0 pe merge-urile cu verdict ACCEPT | Popy |
| 3 | Al 5-lea repo cu Jules activ: `OPTIMUS-Backbone` e propunerea mea | Popy |
| 4 | Redresarea istoricului public al repo-ului (date personale) | Popy |
| 5 | R0 pe push-ul platformei în `MAVIS-OPTIMUS-CI` | Popy |
| 6 | Corectarea adresei necanonice în cele **9** fișiere din MAVIS-CLOUD (material read-only pentru conținut → scriere cerută) | Popy |
