# STARE MĂSURATĂ — CI — 2026-10-27

> **Aditiv.** Nu rescrie `docs/STARE-MASURATA-CI.md` (care rămâne istoricul
> din 2026-10-24). Acesta e măsurătoarea de **azi**, cu metodele.
>
> Măsurat pe mașina lui Popy, 2026-10-27, între 00:05 și 01:20.

---

## 1. Topologia — măsurată

| Ce | Valoare | Metodă |
|---|---|---|
| Sursa fizică a proiectului CI | `E:\Google\GDrive\GDrive-Second_Brain_PKMS\02_Areas\02-2-AI-SOT\CASA\OPTIMUS - Prime\Optimus_CI (by Mavis)` | `Get-Item` + joncțiune |
| Joncțiunea de pe C: | `C:\Users\apviz\.minimax-agent\projects\Optimus_CI (by Mavis)` → `E:\…\Optimus_CI (by Mavis)` | `LinkType=Junction`, `Target` |
| `.git` | **fișier**, nu director → `gitdir: E:/Google/GitData-Optimus-CI` | citire conținut |
| **G: NU e mount virtual** | volum fix; `G:\My Drive.lnk` → target `E:\Google\GDrive` | `WScript.Shell.CreateShortcut` + `fsutil fsinfo drivetype` |
| DriveFS | rulează, `version 132.0.0.0`, startup 2026-10-26 **22:43** | `Get-Process`, `drive_fs.txt` |
| Rădăcina mirrorului My Drive | `Google\GDrive`, `root_id=23`, `sync_type=MIRROR`, **connected=true** | `ReceiveMirrorRoots` (al 3-lea dump) |
| Cache-ul de conținut | `E:\Google\Cache\100488352004104984848\content_cache` | `content_cache_path` |

**Atenție la o capcană de citire:** cele trei dump-uri de `ReceiveMirrorRoots`
sunt **la același startup** (22:43:01.70x). Primul spune
`connected=false` pentru rădăcina GDrive, ultimul spune `connected=true`.
**Proba citește ultima apariție** — starea finală. Citirea manuală a
primului dump ar da diagnosticul greșit.

---

## 2. Puntea Drive — măsurată

| Ce | Valoare | Metodă |
|---|---|---|
| cloud_id al folderului CI | `1V87h9Pbw52chSVNkxQ_NNuMh-CLfZeuI` | `items` din `metadata_sqlite_db` |
| Calea în Drive | `My Drive > GDrive-Second_Brain_PKMS > 02_Areas > 02-2-AI-SOT > CASA > OPTIMUS - Prime > Optimus_CI (by Mavis)` | lanț `stable_parents` |
| Fișiere locale ajunse în Drive (create 24 oct, niciodată pe GitHub) | `STARE-MASURATA-CI.md` → `1yg2iC1kboRgZjhYeXhu-SqDBqkKKdGlY` | idem |
| Lag de propagare | **≈ 80 min** (22:11 → 23:31, 26 oct) | `modified` vs mtime |
| Coadă de operațiuni | `PENDING_OPERATIONS=0` | `operations` |
| Fișiere noi (create 00:35) în indice, la 01:05 | **nu încă** | idem — lag încă în desfășurare |

**Prin urmare:** puntea funcționează, **dar nu e instantă**. Nu se promează
latență sub o oră fără măsurătoare.

### Rutele de API — măsurate ca rupte

| Rută | Rezultat |
|---|---|
| `gdrive-mcp` (namespace minimax) | `invalid_grant` |
| `verify-drive.js` (același token) | `DRIVE v3 files.list FAILED`, **EXIT 2** |
| `gcloud` ADC (`authorized_user`) | Drive API → **HTTP 403** (fără scope de Drive) |

---

## 3. Instrumentele — măsurate

| Instrument | Stare | Notă |
|---|---|---|
| `scripts/drivefs_probe.py` | ✅ | `--title`, `--newest`, `--root-state`, `--pending` |
| `scripts/mavis-drive-bridge.ps1` | ✅ | `-Status`, `-Publish`, `-Verify` |
| `scripts/mavis-drive-bridge-selfcheck.ps1` | ✅ | 6 probe, `BRIDGE_PROBLEMS=0 UNKNOWN=0`, **EXIT 0** |
| `metadata_sqlite_db` | ✅ lizibil read-only | 422 932 480 B |
| `mirror_metadata_sqlite_db` | ❌ blocat de DriveFS | 2 278 027 264 B; `immutable=1` refuzat |

**Python 3.14.6** prezent. **`gh`** funcțional.

---

## 4. Repo-urile — măsurat

### `apvizual-max/MAVIS-OPTIMUS-CI` (remote)

| Ce | Valoare |
|---|---|
| Vizibilitate | **public** |
| `pushed_at` | **2026-10-24T23:55:56Z** (înainte: 14:35:06Z) |
| Dimensiune | 99 KB |
| Workflow-uri | **niciunul** (404 pe `.github/workflows`) |
| Secrete | **niciun** |
| `main` remote | `3da55ff56249f9ec7d299c88e10e27de039be6f` |

### Local vs remote — divergență

| | |
|---|---|
| Local `main` | `83b61398a4d255b57cddc9ec7096c21403abd095` |
| Remote `main` | `3da55fff56249f9ec7d299c88e10e27de039be6f` |
| **Înainte / înapoi** | **12 / 5** |

Cele 5 commituri remote sunt **lucrarea celeilalte sesiuni** (CD): două
merge-uri de PR-uri Jules (`meta-prompt.ps1` path traversal, `mavis-sync`
pipeline) + `docs(cd)` + cele două merge-uri.

**Decizie:** nu împingem fără R0 **și** nu rebazăm cu forța. Divergența se
documentează; sincronizarea e o operație cu R0, într-un rând cu restul.

### `apvizual-max/MAVIS-CLOUD` — neschimbat

Canalul **secundar** al punții. Nu e atins de acest rând.

### CD — în paralel

| Ce | Valoare |
|---|---|
| Sursa fizică | `E:\…\CASA\OPTIMUS - Prime\Optimus_CD (by Jules)` |
| HEAD | `5efc70b` — „CD: masuratoarea fals-zero reparata + gard Jules + poarta invariant ramuri" |
| Remote | **neconfigurat** |

---

## 5. Poarta de push și guvernanța

| Ce | Stare |
|---|---|
| `core.hooksPath` per repo | instalat în CI și CD |
| `core.hooksPath` **CI** | `E:/Google/GitData-Optimus-CI/hooks` — **director propriu**, cu `pre-commit` + `pre-push` **delegat** |
| `core.hooksPath` **CD** | `C:/Users/apviz/.minimax-agent/projects/scripts/git-hooks` — **neafectat** (poarta comună) |
| Poarta de push, fără martor | **EXIT 1** (măsurat) |
| Delegarea `pre-push` în repo-ul real | **EXIT 1** + mesajul porții comune (măsurat) |
| Scanare secrete pre-commit | `BLOCKS=0 WARNS=0 SCAN_OK` — **scanner propriu CI**: `scripts\scan-staged-secrets.ps1` |
| Auto-proba scannerului | `SECRET_PROBLEMS=0 UNKNOWN=0`, **EXIT 0** — 7 probe |
| Falsificarea lanțului de porți | `GATE_PROBLEMS=0`, **EXIT 0** — commit curat permis · commit cu secret **refuzat** · secret **absent** din istoric · push fără acord **refuzat** · push cu acord permis |
| Puntea `mavis-sync -SelfTest` | `POARTA|TRECUT`, EXIT 0 |
| Puntea `run-sync-logged -DryRun` | EXIT 0 |

---

## 6. Ce s-a schimbat în acest rând

| # | Ce | Stare |
|---|---|---|
| 1 | Structura `BRIDGE-DRIVE/` cu 4 canale + protocol | ✅ |
| 2 | Canalul secundar `QUEUE/TASKS-FOR-CLOUD.md` | ✅ |
| 3 | `drivefs_probe.py` — măsurătorul | ✅ |
| 4 | `mavis-drive-bridge.ps1` — publicare + măsurătoare | ✅ |
| 5 | `mavis-drive-bridge-selfcheck.ps1` — poarta, 6 probe | ✅ |
| 6 | Documentație: acest fișier + `docs/PUNTE-DRIVE-PRIMARA.md` + actualizări aditive | ✅ |
| 7 | Scanner de secrete **propriu CI** + auto-proba (7 probe, ambele sensuri) | ✅ |
| 8 | Hook `pre-commit` în directorul per-repo al CI | ✅ |
| 9 | `pre-push` delegat către poarta comună (CD neatins) | ✅ |
| 10 | Falsificarea lanțului de porți, în repo izolat, GitHub neatins | ✅ |
| 11 | Primul handoff publicat pe **ambele** canale | ⚠️ `TASK-2026-10-27-0103-…` · `SYNC_STATE=UNVERIFIED` (scris, neconfirmat în indice) |
| 12 | Folderul fantomă `…\projects\Mavis-Optimus-Continuous-Integration` | ✅ eliminat prin Trash recuperabil, 3 niveluri, EXIT 0 |

**Nepropus, intenționat:** push-ul celor 12 commituri locale (R0, plus
divergența cu remote-ul avansat).

---

*2026-10-27 · Mavis Local · măsurat*
