# MAPARE — unde stă tot

> Nu se mută nimic din alte proiecte. Totul e **prin referință**, ca
> nimic să nu se piardă dacă o cale se schimbă.

## Proiectul ăsta

```
C:\Users\apviz\.minimax-agent\projects\Mavis-Optimus-Continuous-Integration\
├── README.md                    punct de intrare, cold-boot
├── DOCTRINA-CI.md               cum lucrez
├── MAPARE-SISTEM.md             acest fișier
├── docs\
│   ├── CONFLICTE-DOZTRINA.md    7 conflicte găsite + hotărâri  ← CITESTE
│   ├── STATE-CLOUD.md           ce am înglobat din MAVIS-CLOUD
│   ├── CI-POLICY.md             Live Review + Jules
│   ├── BRIDGE-LOCAL-CLOUD.md    puntea, adaptată la R0
│   ├── INVENTAR-REPO-URI.md     toate repo-urile
│   └── RECUPERARE-GIT.md        starea măsurată a mașinii
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

Conventția care explică tot: `docs/ARHITECTURA-CI-CD.md`.