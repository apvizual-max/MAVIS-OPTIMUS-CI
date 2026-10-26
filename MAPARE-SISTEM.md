# MAPARE — unde stă tot

> Nu se mută nimic din alte proiecte. Totul e **prin referință**, ca
> nimic să nu se piardă dacă o cale se schimbă.

## Proiectul ăsta

```
E:\Google\GDrive\GDrive-Second_Brain_PKMS\02_Areas\02-2-AI-SOT\CASA\OPTIMUS - Prime\Optimus_CI (by Mavis)\
├── README.md                    punct de intrare, cold-boot
├── DOCTRINA-CI.md               cum lucrez
├── MAPARE-SISTEM.md             acest fișier
├── docs\
│   ├── MAPARE-FOLDERE.md        ce e în fiecare folder, măsurat
│   ├── WORKFLOWS.md             fluxurile, porțile, codurile de ieșire
│   ├── CONFLICTE-DOZTRINA.md    7 conflicte găsite + hotărâri  ← CITESTE
│   ├── CI-POLICY.md             politica CI: puntea, guvernanța, porțile
│   ├── BRIDGE-LOCAL-CLOUD.md    puntea, adaptată la R0
│   ├── PUNTE-DRIVE-PRIMARA.md   canalul primar Drive, cu măsurătorile
│   ├── GIT-GITHUB-PROCEDURI.md  procedurile Git/GitHub, cu mecanism și probe
│   ├── ARHITECTURA-CI-CD.md     convenția care separă CI de CD
│   ├── PROTOCOL-DENUMIRE-LOCAL-CLOUD.md  protocolul de denumire
│   ├── INVENTAR-REPO-URI.md     toate repo-urile
│   ├── RECUPERARE-GIT.md        starea măsurată a mașinii
│   └── arhiva\handoffs-vechi\   handoff-uri consumate — **mutate, nu șterse**
├── BRIDGE-DRIVE\                canalul primar (Google Drive)
├── QUEUE\                       canalul secundar (GitHub)
├── scripts\                     instrumentele
├── blueprint\
│   └── BLUEPRINT-PLAN-CI.md     planul de execuție           ← CITESTE
└── cloud-ingest\
    └── MAVIS-CLOUD\             clonă locală, **NEATINGEĂ**
```

## Doctina de bază — în afara proiectului

| Ce | Unde |
|---|---|
| Doctrina completă | `C:\Users\apviz\.minimax-agent\projects\SENTINEL_OPERATIONAL_DOCTRINE.md` |
| Substratul SENTINEL | `C:\Users\apviz\.minimax-agent\projects\SENTINEL_PRIME\01_FOUNDATION\doctrine\A_FI_DOCTRINE.md` |
| **§20 — doctrina operațională** | în fișierul de sus, secțiunea 20 |

## Skillurile vii — în afara proiectului

| Skill | Rol |
|---|---|
| `mavis-autonomous-operator-skill` | **se încarcă primul** — gândire, trei piloni |
| `mavis-git-install-skill` | ridicarea unui repo nou |
| `mavis-git-autonom-skill` | lucru zilnic cu Git |
| `mavis-optimus-continuous-integration-skill` | **scopul acestui proiect** |

Toate în `C:\Users\apviz\.minimax\agents\mavis\skills\`.

## Scriptele de Git — în afara proiectului

| Script | Ce face |
|---|---|
| `projects\scripts\git-autopush.ps1` | **singura poartă de push** — cere `-Acord` |
| `projects\scripts\push-status.ps1` | peretele: câte comituri neîmpinse, per repo |
| `projects\scripts\git-hooks\pre-push` | poarta reală, per repo, în istorie |

## Repo-urile GitHub ale lui Popy

| Repo | Rol | Acces |
|---|---|---|
| `Optimus-Mavis-Skills` | skillurile mele | privat |
| `OPTIMUS-Backbone` | consola OPTIMUS, scripturi | privat |
| `SENTINEL_PRIME` | substratul SENTINEL | privat |
| **`MAVIS-CLOUD`** | **fostul cartier Cloud** | **public** |
| **`MAVIS-OPTIMUS-CI`** | **acest proiect — de creat** | de creat |
| `Qwen-Ecosystem-Dashboard` | sistem Qwen | privat |
| `hermes-doctor` | plasa lui Hermes | privat |
| `pkms-vault-automation` | menținerea vaultului | privat |

Lista completă și măsurată: `docs/INVENTAR-REPO-URI.md`.

## Regula Triadei

```
1 conversație  =  1 folder local  =  1 repo GitHub
```

Fiecare proiect are conversația, folderul și repo-ul lui. **Proiectele nu
se ating între ele.** Când alt proiect are nevoie de ceva, eu dau un
prompt, Popy îl duce în sesiunea aceea, care are contextul complet.

**Aceasta e și motivul pentru care nu ating repo-urile altor proiecte:** nu
am contextul lor, și un agent fără context într-un repo străin e exact
defectul pe care îl reparăm.

---

## Celălalt cartier — CD

Sesiunea CD e **paralelă**, cu folderul, repo-ul și bugetul lui:

```
C:\Users\apviz\.minimax-agent\projects\Mavis-Optimus-Continuous-Development\
├── README.md · DOCTRINA-CD.md · HANDOFF-CD.md · PRIMING-CD.md
├── docs\                       ARHITECTURA · SPEC · MAPARE · WORKFLOWS · PROTOCOALE
└── JULES - Optimus CD\         platforma Jules (10 scripturi, config, workflows)
```

| | CI (aici) | CD (acolo) |
|---|---|---|
| Puntea Local↔Cloud | ✅ | — |
| Ingest read-only din Cloud | ✅ | — |
| Canalul `QUEUE/` | ✅ | — |
| Platforma Jules | — | ✅ |
| Live Review | — | ✅ |
| Cota 100 taskuri/zi | — | ✅ |

**Nu ne atingem.** CD nu scrie în `MAVIS-CLOUD`; CI nu rulează triajul.

---

## Topologia măsurată — 2026-10-27

> **Aditiv.** Nimic din arborele de mai sus nu se mută și nu se șterge.
> Secțiunea de jos reflectă **unde stă tot ACUM**.

### Sursa fizică

```
E:\Google\GDrive\GDrive-Second_Brain_PKMS\02_Areas\02-2-AI-SOT\CASA\OPTIMUS - Prime\Optimus_CI (by Mavis)\
├── .git                          ← FIȘIER (worktree link) → E:\Google\GitData-Optimus-CI
├── README.md · DOCTRINA-CI.md · MAPARE-SISTEM.md
├── BRIDGE-DRIVE\                ← PUNTEA PRIMARĂ (Google Drive)
│   ├── README-BRIDGE-DRIVE.md   protocolul
│   ├── TASKURI-PENTRU-CLOUD.md  Local → Cloud, structurat
│   ├── INTENTII.md              Popy → Cloud, liber
│   ├── INTRARI-CLOUD\           Cloud → Local
│   └── ISTORIC\                 consumate: se mută, nu se șterg
├── QUEUE\                        ← canalul SECUNDAR (GitHub)
│   └── TASKS-FOR-CLOUD.md
├── docs\        documentația de proiect
├── scripts\     mavis-sync.ps1 · run-sync-logged.ps1 · meta-prompt.ps1
│                notebooklm-cdp.mjs · snapshot-vault.ps1
│                drivefs_probe.py · mavis-drive-bridge.ps1
│                mavis-drive-bridge-selfcheck.ps1
├── blueprint\ · cloud-ingest\ (read-only) · logs\ · state\ (ignorat de git)
```

### Joncțiunile

| Acces rapid | Sursa fizică |
|---|---|
| `C:\Users\apviz\.minimax-agent\projects\Optimus_CI (by Mavis)` | folderul de pe `E:` de mai sus |
| `C:\Users\apviz\.minimax-agent\projects\Optimus_CD (by Jules)` | `E:\…\CASA\OPTIMUS - Prime\Optimus_CD (by Jules)` |

**Calea veche** `…\projects\Mavis-Optimus-Continuous-Integration\` **nu mai
există** — mutată pe `E:` la consolidarea din 2026-10-25, cu joncțiune în
loc. Nimic nu s-a pierdut: istoricul e în `E:\Google\GitData-Optimus-CI`.

### Ce e nou în CI (2026-10-27)

| Ce | Unde | De ce |
|---|---|---|
| Puntea Drive (primară) | `BRIDGE-DRIVE\` | ambele instanțe au acces la Drive |
| Canal secundar | `QUEUE\TASKS-FOR-CLOUD.md` | rezervă, scris simultan |
| Măsurătorul Drive | `scripts\drivefs_probe.py` | singura sursă de adevăr, API-ul e rupt |
| Orquestratorul punții | `scripts\mavis-drive-bridge.ps1` | scrie **și** măsoară |
| Poarta punții | `scripts\mavis-drive-bridge-selfcheck.ps1` | 6 probe, poate eșua |
| Starea de azi | `docs\STARE-MASURATA-CI-2026-10-27.md` | cifre + metode |
| Snapshot remote | `docs\STARE-MAVIS-OPTIMUS-CI-REMOTE.md` | alt AI lucrează acolo |
| Specificația punții | `docs\PUNTE-DRIVE-PRIMARA.md` | arhitectura + latența |

### Topologia Drive, corectată

| Ce | Stare măsurată |
|---|---|
| Mirrorul | `E:\Google\GDrive\` (rădăcină `Google\GDrive`, `root_id=23`, MIRROR) |
| **`G:`** | **nu** e mount virtual — volum fix, cu scurtătură `My Drive.lnk` → `E:\Google\GDrive` |
| DriveFS | rulează; startup 2026-10-26 22:43 |
| Folderul CI în Drive | `cloud_id 1V87h9Pbw52chSVNkxQ_NNuMh-CLfZeuI` |

Conventția care explică tot: `docs/ARHITECTURA-CI-CD.md`.