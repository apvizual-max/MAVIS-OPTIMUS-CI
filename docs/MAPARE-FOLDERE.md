# MAPARE-FOLDERE — unde stă tot, în CI

> Complementul lui `MAPARE-SISTEM.md`. Acolo e **unde stă sistemul** în
> relație cu restul mașinii. Aici e **ce e în fiecare folder al proiectului**
> și ce se atinge / nu se atinge.
>
> **Măsurat 2026-10-27.** Cifrele sunt de pe disc, nu din memorie.

---

## 1. Rădăcina

| | |
|---|---|
| **Sursa (SOT)** | `E:\Google\GDrive\GDrive-Second_Brain_PKMS\02_Areas\02-2-AI-SOT\CASA\OPTIMUS - Prime\Optimus_CI (by Mavis)` |
| **Joncțiune locală** | `C:\Users\apviz\.minimax-agent\projects\Optimus_CI (by Mavis)` → `E:` (`LinkType=Junction`) |
| **În Drive** | `My Drive > GDrive-Second_Brain_PKMS > 02_Areas > 02-2-AI-SOT > CASA > OPTIMUS - Prime > Optimus_CI (by Mavis)` |
| **`cloud_id`** | `1V87h9Pbw52chSVNkxQ_NNuMh-CLfZeuI` |
| **`.git`** | **fișier** (worktree link) → `gitdir: E:/Google/GitData-Optimus-CI` |
| **Gitdir CD (separat)** | `E:/Google/GitData-Optimus-CD` |
| **Volum** | **568 fișiere · 13,7 MB** (fără `state/`) |

> **Calea veche nu mai există:** `…\projects\Mavis-Optimus-Continuous-Integration\`
> a fost eliminată prin Trash recuperabil (3 niveluri, EXIT 0) pe 27 oct.

---

## 2. Rădăcina, fișier cu fișier

| Entitate | Ce e | Volum | Git? |
|---|---|---|---|
| `README.md` | Portul: ce e proiectul, cum se intră, ce porți există | 8.649 B | ✅ |
| `DOCTRINA-CI.md` | Doctrina CI: reguli, asimetria, ce nu se atinge | 9.544 B | ✅ |
| `MAPARE-SISTEM.md` | Unde stă sistemul față de restul mașinii | 7.811 B | ✅ |
| `Plan_Dezvoltare_CI_from_POPY (Gemini)-10-13-2026.md` | Planul original, 13 oct, **istoric** — nu e contract | 63.702 B | ✅ |
| `.gitignore` | Ce nu se comite | 1.360 B | ✅ |
| `.github/workflows/` | Workflow-ul de server: `ci-verify.yml` | 1 fișier · 1.589 B | ✅ |
| `docs/` | Documentația: 27 fișiere | 164.356 B | ✅ |
| `scripts/` | Instrumentele: 10 fișiere | 79.200 B | ✅ |
| `BRIDGE-DRIVE/` | **Canalul primar** (Google Drive) | 5 fișiere · 8.563 B | ✅ |
| `QUEUE/` | **Canalul secundar** (GitHub) | 1 fișier · 3.352 B | ✅ |
| `blueprint/` | Planul CI din faza de blueprint | 1 fișier · 11.255 B | ✅ |
| `mapari/` | **gol** — folder rămas de la o layout veche | 0 | — |
| `cloud-ingest/` | Clonă **read-only** a lui `MAVIS-CLOUD` | 502 fișiere · 13,98 MB | ❌ ignorat |
| `logs/` | Jurnalele punții zilnice | 14 fișiere · 44.015 B | ❌ ignorat |
| `desktop.ini` | Artefact Windows | 149 B | ❌ ignorat |
| `state/` | Scratch, măsurători, probe | — | ❌ ignorat |

**Volum total** (fără `state/`): **568 fișiere · 14.388.527 B** (13,7 MB).
**Git-tracked: 50 fișiere · 359.381 B.**

> **`mapari/` e gol.** L-am lăsat: e necomandat, și un folder gol nu strică
> nimic. Nu e un plan de șters — e o poziție fără conținut.

---

## 3. `BRIDGE-DRIVE/` — canalul primar

| Fișier | Cine scrie | Ce e |
|---|---|---|
| `README-BRIDGE-DRIVE.md` | Local | **Protocolul canalului**: reguli, formate, convenție |
| `TASKURI-PENTRU-CLOUD.md` | Local | Cerințe structurate spre Cloud (canal primar) |
| `INTENTII.md` | Popy | Cerințe libere, cu cuvintele lui |
| `INTRARI-CLOUD/README.md` | Cloud | Livrările Cloud intră aici |
| `ISTORIC/README.md` | Local | Ce a fost consumat — prin **mutare**, niciodată ștergere |

---

## 4. `scripts/` — instrumentele

| Script | Ce face | Notă |
|---|---|---|
| `mavis-drive-bridge.ps1` | Publicare pe ambele canale + măsurătoare de stare | `-Status` · `-Publish` · `-Verify` |
| `mavis-drive-bridge-selfcheck.ps1` | **Poarta punții** — 14 probe | `BRIDGE_PROBLEMS=0 UNKNOWN=0` |
| `drivefs_probe.py` | Sonda read-only în baza DriveFS | `--title` · `--newest` · `--root-state` · `--pending` · `--staleness` |
| `scan-staged-secrets.ps1` | **Poarta de secrete** pe index | `BLOCKS` / `WARNS` |
| `scan-staged-secrets-selfcheck.ps1` | **Poarta porții de secrete** — 7 probe | `SECRET_PROBLEMS=0 UNKNOWN=0` |
| `mavis-sync.ps1` | **Puntea zilnică** Local↔Cloud (task 08:30) | cale derivată din `$PSScriptRoot` · `exit` propriu |
| `mavis-sync-selfcheck.ps1` | **Poarta punții zilnice** — 9 probe | `SYNC_PROBLEMS=0 UNKNOWN=0 FALSIFIED=4` |
| `mavis-sync.ps1` | Sincronizarea zilnică Local↔Cloud | taskul `MavisSyncBridge`, 08:30 |
| `run-sync-logged.ps1` | Rulează sincronizarea cu log datat | `-DryRun` disponibil |
| `meta-prompt.ps1` | Generează meta-prompt-ul de pornire | — |
| `snapshot-vault.ps1` | Snapshot al vault-ului | — |
| `notebooklm-cdp.mjs` | Acces la NotebookLM prin CDP | — |

**Regula:** toate scripturile `.ps1` sunt **ASCII pur** (0 octeți peste
`0x7F`) — rulează în Windows PowerShell 5.1, unde `pwsh` nu e instalat.

---

## 5. `docs/` — documentația

**Nucleu:** `README` · `DOCTRINA-CI` · `MAPARE-SISTEM` · `MAPARE-FOLDERE` ·
`WORKFLOWS`

**Puntea și politici:** `PUNTE-DRIVE-PRIMARA` · `BRIDGE-LOCAL-CLOUD` ·
`PROTOCOL-DENUMIRE-LOCAL-CLOUD` · `CI-POLICY` · `GIT-GITHUB-PROCEDURI` ·
`CONFLICTE-DOZTRINA` · `ARHITECTURA-CI-CD`

**Stare:** `STARE-MASURATA-CI-2026-10-27` · `STARE-MAVIS-OPTIMUS-CI-REMOTE` ·
`STARE-MASURATA-CI` · `STATUS-LOCAL-TO-CLOUD-2026-10-12`

**Instrumente:** `INVENTAR-REPO-URI` · `META-PROMPT` · `RECUPERARE-GIT`

**Arhivă:** `docs/arhiva/handoffs-vechi/` — 11 fișiere, istoric **prin mutare**.

---

## 6. Ce stă **în afara** proiectului

| Ce | Unde | Regula |
|---|---|---|
| **Skillurile Mavis** | `C:\Users\apviz\.minimax\agents\mavis\skills\` | 4 skilluri extinse aditiv: `mavis-optimus-continuous-integration-skill`, `mavis-cloud-bridge-skill`, `mavis-local-to-cloud-reporting`, `mavis-google-workspace-skill` |
| **Poarta de push (definiția comună)** | `C:\Users\apviz\.minimax-agent\projects\scripts\git-hooks\pre-push` | **o singură definiție**, partajată cu CD. Hook-ul din CI **delegă**, nu copiază |
| **Hook-urile per-repo ale CI** | `E:\Google\GitData-Optimus-CI\hooks\` | `pre-commit` (scanner) + `pre-push` (delegat) |
| **Folderul CD** | `…\Optimus_CD (by Jules)\` | **neatins** din CI. Documentele CD trăiesc în folderul CD |
| **Bazele DriveFS** | `%LOCALAPPDATA%\Google\DriveFS\` | `metadata_sqlite_db` = index de cloud (citibil). `mirror_metadata_sqlite_db` = **blocat** de DriveFS |

---

## 7. Regula de așezare

**Un document trăiește în folderul sistemului pe care îl guvernează.**

- Document despre CI → în folderul CI. **CD neatins.**
- Document despre CD → în folderul CD. **Nu se rescrie din CI.**
- Corecția se face prin **fișier nou**, cu numele instanței care l-a scris.
- Actualizările sunt **aditive**. Nimic nu se trunchiază.

Concret, în acest rând: 15 documente CI extinse, 4 skilluri extinse, 4 scripturi
noi, 2 hook-uri, `.gitignore` completat — **zero** fișiere șterse, zero
rescrise, zero atinse în CD.

---

## 8. `.github/workflows/` — plasa de siguranță a serverului

> **Aditiv.** Măsurat 2026-10-27.

| Fișier | Ce face | Notă |
|---|---|---|
| `ci-verify.yml` | Rulează scannerul de secrete + auto-proba pe **ce a aterizat** în repo | `on: push` (main) + `workflow_dispatch` + `schedule: '30 3 * * *'` · `runs-on: windows-latest` |

**Unde rulează:** pe serverul GitHub. **Nu** rulează poarta punții — acolo nu
există DriveFS.

**Raportează, nu blochează.** Un workflow care blchează un push al altui AI
care lucrează pe același repo ar fi o poartă fără imputabilitate: verdictul
de „REJECT" al meu pe conținutul altcuia. El doar **spune** ce a aterizat.

**Falsificat în ambele sensuri** (clonă curată, simulare de runner):
`SCANNED=50 BLOCKS=0 SCAN_OK` exit 0 → cu cheie plantată `BLOCKS=1` exit 1
(workflow ar deveni roșu) → scosă → `SCAN_OK` exit 0.

**Starea reală:** pe remote, `.github/workflows/` dă **404** — workflow-ul
există doar în copia locală, între cele 17 commituri neîmpinse. **Serverul
nu rulează încă nimic pentru acest repo.**

---

*2026-10-27 · Mavis Local · măsurat · aditiv*
