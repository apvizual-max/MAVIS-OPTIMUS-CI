# INVENTAR REPO-URI

> Măsurat **2026-10-24** prin `gh repo list apvizual-max --limit 60 --json
> name,visibility,pushedAt,defaultBranchRef` și `gh api
> repos/apvizual-max/<R>`.
> **Înlocuiește** inventarul din 2026-10-11/12, ale cărui vizibilități au
> devenit false.

---

## 1. Repo-urile GitHub ale lui Popy

**Toate cele 10, măsurate azi.**

| Repo | Vizibilitate | Ramură | Ultim push | Rol |
|---|---|---|---|---|
| `apvizual-max/MAVIS-CLOUD` | **PUBLIC** | `main` | 2026-10-24T01:14:10Z | **puntea** Local↔Cloud · ținta de lucru a lui Jules |
| `apvizual-max/MAVIS-OPTIMUS-CI` | **PUBLIC** | `main` | 2026-10-23T14:35:06Z | **SOT CI** — acest proiect |
| `apvizual-max/MAVIS-OPTIMUS-CD` | **nu există** | — | — | **SOT CD** — se creează la priming (R0) |
| `apvizual-max/OPTIMUS-Backbone` | **PUBLIC** | `main` | 2026-10-23T14:29:06Z | consola OPTIMUS + scripturi Git |
| `apvizual-max/Optimus-Mavis-Skills` | **PUBLIC** | `main` | 2026-10-24T00:17:22Z | skillurile agentului |
| `apvizual-max/pkms-vault-automation` | **PUBLIC** | **`master`** | 2026-10-24T00:19:25Z | menținerea vaultului |
| `apvizual-max/SENTINEL_PRIME` | **PRIVATE** | `main` | 2026-10-24T01:15:51Z | substratul doctrinei |
| `apvizual-max/Qwen-Ecosystem-Dashboard` | **PRIVATE** | `main` | 2026-10-24T00:30:08Z | sistem Qwen |
| `apvizual-max/hermes-doctor` | **PUBLIC** | `main` | 2026-10-23T14:31:44Z | plasa lui Hermes |
| `apvizual-max/hermes-local-backup` | **PUBLIC** | `main` | 2026-10-24T00:28:56Z | backup săptămânal Hermes |
| `apvizual-max/hermes-agent-temp` | **PRIVATE** | `main` | 2026-10-24T01:07:40Z | fork Hermes |

### Corectare față de inventarul din 2026-10-11/12

| Repo | Inventar vechi | **Măsurat azi** |
|---|---|---|
| `Optimus-Mavis-Skills` | privat | **public** |
| `OPTIMUS-Backbone` | privat | **public** |
| `hermes-doctor` | privat | **public** |
| `hermes-agent-temp` | public | **privat** |
| `pkms-vault-automation` | privat | **public** |

> **8 repo-uri din 10 sunt publice.** Conținutul lor e citibil de oricine.
> În `MAVIS-CLOUD` sunt și date personale ale lui Popy — decizia e a lui, dar
> se spune cu voce tare. **Nu se adaugă nimic nou cu date personale în
> repo-uri publice, fără R0.**

---

## 2. Starea canalelor GitHub, măsurată

| Repo | `.github/workflows/` | Secrete de repo | PR-uri Jules deschise |
|---|---|---|---|
| `MAVIS-CLOUD` | `jules.yml`, `verify.yml` | `JULES_API_KEY` | 34 |
| `MAVIS-OPTIMUS-CI` | **niciunul** (404) | **niciunul** | 0 |
| `MAVIS-OPTIMUS-CD` | — (nu există) | — | — |

**`JULES_API_KEY` e prezent doar în `MAVIS-CLOUD`.** Măsurat pe toate cele
6 repo-uri din registru. În celelalte calea automată nu se declanșează.

---

## 3. Cele mele, active

| Cale locală | Remote | Stare |
|---|---|---|
| `…\projects\Mavis-Optimus-Continuous-Integration\` | `MAVIS-OPTIMUS-CI` | **acest proiect** · 10 commituri neîmpinse |
| `…\projects\Mavis-Optimus-Continuous-Development\` | `MAVIS-OPTIMUS-CD` | **SOT CD** · repo GitHub de creat la priming |
| `…\projects\Mavis-Optimus-Continuous-Integration\cloud-ingest\MAVIS-CLOUD\` | `MAVIS-CLOUD` | clonă read-only, **nu se modifică** |
| `~/.minimax/agents/mavis/skills` | `Optimus-Mavis-Skills` | skillurile |
| `~/.minimax-agent/projects` | `OPTIMUS-Backbone` | consola OPTIMUS |

---

## 4. Repo-uri cu probleme, măsurate

| Cale | Problemă |
|---|---|
| `D:\Alex_Knowlege_Vault` | 36 urmărite din 52.933 |
| `E:\CLAUDE\...\OLD Work Files` | 58.237 șterse, remote greșit |
| `~/.minimax/vault-manifest/git-parked-2026-10-07` | 13.581 în index, 0 comituri |
| `E:\Ai_GDrive_Folder\X58 - PlayStation...` | `git init` în folder de joc, al altcuia |

## 5. Zgomot — nu atinge

31 de clone „GitHub backup 2026-10-08" pe `C:` și `D:`; 45 de repo-uri de
ritual în `Temp`; 24 de arhive `CLAUDE_BACKUP_*` pe `E:`.

**Nu sunt periculoase. Sunt zgomot.** Un inventar care le numără ca
probleme pierde semnalul.

## 6. Regula

**Orice repo care nu e al lui Popy — nu se atinge.** Nici măsurătoare
scriind în el, nici hook, nici config.

`lrc hooks disable` pe un repo străin e interzis de skill, și e corect:
un agent fără context într-un repo străin e exact defectul pe care îl
reparăm.
