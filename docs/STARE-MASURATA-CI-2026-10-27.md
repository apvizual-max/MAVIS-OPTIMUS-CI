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
| DriveFS | rulează, `version 132.0.0.0`, startup 2026-10-26 **22:43** | `Get-Process`, `drive_fs_507.txt` |
| Rădăcina mirrorului My Drive | `Google\GDrive`, `root_id=23`, `sync_type=MIRROR`, **connected=true** | `MirrorRoots`, anunțul cel mai recent, în toate logurile |
| Cache-ul de conținut | `E:\Google\Cache\100488352004104984848\content_cache` | `content_cache_path` |

**Atenție la o capcană de citire:** la același startup (22:43:01.70x) există
trei dump-uri de rădăcini. Primul spune `connected=false` pentru rădăcina
GDrive, ultimul spune `connected=true`. **Proba citește ultima apariție** —
starea finală. Citirea manuală a primului dump ar da diagnosticul greșit.

**A doua capcană, măsurată mai târziu în aceeași zi:** DriveFS **rotește
logurile**. Sesiunea activă scria în `drive_fs_507.txt`, iar `drive_fs.txt`
nou conținea doar urma unei **lansări eșuate** (`CANNOT_START_IPC`). Un
instrument care citește un nume de fișier fix citește un log mort. Detalii:
§7.

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
| `scripts/drivefs_probe.py` | ✅ | `--title`, `--newest`, `--root-state`, `--pending`, `--staleness` |
| `scripts/mavis-drive-bridge.ps1` | ✅ | `-Status`, `-Publish`, `-Verify` |
| `scripts/mavis-drive-bridge-selfcheck.ps1` | ✅ | **16 probe**, `BRIDGE_PROBLEMS=0 UNKNOWN=0`, **EXIT 0** |
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
| Propagare Drive | **`PROPAGATION=STALE`** — lag **611,7 min**, `BRIDGE-DRIVE` `FOUND=0` în indice |
| **Vârsta copiei din cloud** | **`CLOUD_TRACKED_AGE_DAYS=2.91`** pentru `MAPARE-SISTEM.md`; localul e cu **4158,7 min** mai nou |
| Fișierul canalului primar în cloud | **`CLOUD_CHANNEL_FILE_PRESENT=false`** — `TASKURI-PENTRU-CLOUD.md` nu e în cloud |
| Conținutul arborelui CI în cloud | **dinainte de mutarea din 26 oct** (`DOCTRINA-CI.md` — 12 oct, `MAPARE-SISTEM.md` — 24 oct). Mutarea a fost la nivel de metadată, cu `cloud_id`-uri păstrate |
| Motor sync DriveFS | `operation_queue_size: 0` · `change_ids_up_to_date: true` · `largest_local_change_id: 9281302` — **nu vede scrierile locale** |
| Canal activ | **`GITHUB`** (pentru conținut nou) — `TRANSPORT=UP`, dar propagarea nu e confirmată |
| Cod de ieșire `-Status` | **4** când propagarea e `STALE` (nu 0) |
| Eroare IPC DriveFS | `ipc_socket_win.cc:272` „The pipe has been ended", repetată la 60s, activă la măsurare |

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
| 13 | Instrumentul reparat: `TRANSPORT` separat de `PROPAGATION`, `state/` exclus din măsurătoarea de lag, canalul activ urmează propagarea | ✅ |
| 14 | Poarta extinsă: 5 probe de falsificare a concordanței raport–măsurătoare | ✅ |
| 15 | Măsurătoare directă a vârstei copiei din cloud (`drivefs_probe.py --staleness`) + invariantul „fișierul canalului absent ⇒ propagarea nu poate fi OK" (6 probe de concordanță) | ✅ |

**Nepropus, intenționat:** push-ul celor 12 commituri locale (R0, plus
divergența cu remote-ul avansat).

---

## 7. Două defecte de măsurătoare, găsite și reparate

> **Aditiv.** Măsurat 2026-10-27, în jurul orei 02:00. Nimic de mai sus nu
> se rescrie.

### 7.1 Defectul 1 — sonda citea un log mort

**Simptom:** poarta raporta `UNKNOWN proba-transport — starea rădăcinii
mirrorului nu s-a putut citi`, cu `BRIDGE_PROBLEMS=0 UNKNOWN=1`. Era
`UNKNOWN=0` cu câteva ore înainte. Sistemul nu se schimbase — **se schimbase
instrumentul**.

**Cauza, măsurată:** DriveFS **rotește logurile**. Sesiunea activă scria în
`drive_fs_507.txt` (mtime în continuă actualizare), iar `drive_fs.txt` —
fișierul cu nume fix, pe care îl citea sonda — conținea doar urma unei
**lansări eșuate**:

```
drive_fs.cc:818:RunDriveFS Return code: CANNOT_START_IPC
base_ipc_server.h:61:StartInternal There is already an IPC server at \\.\Pipe\GoogleDriveFSPipe_apviz
```

Sonda citea `drive_fs.txt` → **0 linii `MirrorRoots`** → `ROOT_STATE=UNKNOWN`.

**Consecința reală:** un transport **funcțional** era raportat ca
necunoscut. E fals negativ — ascunde o punte care merge.

**Reparația:** sonda scanează acum **toate** logurile `drive_fs*.txt`, în
ordinea descrescătoare a mtime-ului, și ia **anunțul cel mai recent despre
rădăcina GDrive**, ordonat după **amprenta de timp din interiorul liniei**
(UTC, ISO-8601) — nu după numele fișierului, nu după mtime. Un fișier al
cărui mtime e mai vechi decât anunțul găsit nu poate conține unul mai nou,
deci scanarea se oprește acolo.

**Defect ascuns, găsit în aceeași reparare:** codul vechi lua primul
`title=` și primul `connected=` din **linia** — dar o linie `MirrorRoots`
conține **mai multe rădăcini**. Putea raporta starea rădăcinii GDrive de la
**altă rădăcină**. Acum fiecare rădăcină e împărțită și asociată cu
`connected=` ei.

### 7.2 Defectul 2 — instrumentul spunea `TRANSPORT=UP` pe baza unei măsurători nereușite

Codul vechi avea:

```powershell
if ($root.State -eq 'false') { ...TRANSPORT=DOWN...; return 5 }
Write-Out 'TRANSPORT=UP'      # <- prinde si UNKNOWN
```

`UNKNOWN` trecea pe ramura `UP`. **Un instrument care afirmă ceva ce n-a
măsurat.** Iar poarta n-o vedea: regula de concordanță verifica doar
`false→DOWN` și `true→UP`, și pentru `UNKNOWN` poarta scria `UNKNOWN` în loc
să verifice.

**Reparația:** `UNKNOWN` are ramura ei — `TRANSPORT=UNKNOWN`, canal activ
GitHub, ieșire **4**. Noul `TRANSPORT=UNKNOWN` se propagă și în poartă: o
raportare cu rădăcina `UNKNOWN` și transport `UP` e **respinsă**.

### 7.3 Falsificarea — în ambele sensuri

| Probă | Așteptare | Măsurat |
|---|---|---|
| Log nou spune `connected=false`, log vechi spune `connected=true` | câștigă anunțul **nou** | `ROOT_STATE=false`, `LOG=drive_fs_901.txt` ✅ |
| GDrive **al doilea** root într-o linie cu `Documents` primul | cuplare **per-rădăcină** | `ROOT_STATE=true` (GDrive), nu starea lui Documents ✅ |
| Niciun anunț despre GDrive | `UNKNOWN` + ieșire **3** | `ROOT_STATE=UNKNOWN`, exit 3 ✅ |
| Poarta cu raport falsificat (rădăcină `UNKNOWN` + transport `UP`) | **respins** | `proba-concordanta` OK — falsul e respins ✅ |
| Raport adevarat (rădăcină `UNKNOWN` + transport `UNKNOWN`) | **acceptat** | `proba-concordanta` OK ✅ |
| Sonda citește `drive_fs.txt` neatins de >30 min | **FAIL** | `proba-log` — regula e în poartă ✅ |

**Starea după reparație:**

```
BRIDGE_PROBLEMS=0 UNKNOWN=0     EXIT 0     (16 probe)
SECRET_PROBLEMS=0  UNKNOWN=0     EXIT 0     (7 probe)
TRANSPORT=UP   PROPAGATION=STALE   ACTIVE_CHANNEL=GITHUB   exit 4
CLOUD_TRACKED_AGE_DAYS=2.93   CLOUD_CHANNEL_FILE_PRESENT=false
```

**Rădăcina e conectată** (`ROOT_STATE=true`, anunț `2026-10-26T22:43:24`,
citit din `drive_fs_507.txt`). **Propagarea e tot STALE** — asta e măsurătoarea
separată, și nu s-a schimbat prin repararea instrumentului.

### 7.4 Regula, pentru totdeauna

**Un nume de fișier fix nu e o măsurătoare.** Când un producător rotește
fișierele sale, instrumentul care citește `cei_mai_recenti.txt` citește, de
fapt, *ce a fost* recent — nu *ce e* recent.

**Și:** o stare **necunoscută** nu se traduce niciodată într-o stare
favorabilă. `UNKNOWN` → `UNKNOWN`. Un instrument care nu a măsurat nu are
dreptul să spună „merge".

---

*2026-10-27 · Mavis Local · măsurat*
