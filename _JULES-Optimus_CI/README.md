# Platforma de integrare MAVIS LOCAL ↔ JULES

> Folderul de lucru creat de Popy pentru dezvoltarea integrării Jules.
> Tot ce se construiește aici ajunge în `MAVIS-OPTIMUS-CI` (repo public).

## Ce este

O platformă **autonomă** care face două lucruri, în buclă, zilnic:

1. **Trimite** taskuri de nivel de sistem către Google Jules, pe fiecare
   repo, pe trei axe: performanță, design, securitate.
2. **Triază** fiecare pull request pe care Jules îl deschide, verificându-l
   **fizic, pe această mașină**, și dând un verdict măsurat.

Mavis Local este autoritatea supremă. Jules propune. **Merge-ul cere R0.**

## Fluxul complet

```
  Mavis Local                          Jules (sandbox Google)             GitHub
       |                                       |                             |
       |  jules-dispatch.ps1                   |                             |
       |  -> gh issue create --label jules -----+---------------------------->|
       |                                       |                             |
       |                          citeste AGENTS.md + JULES-CONTEXT.md        |
       |                          + corpul issue-ului (contextul complet)      |
       |                                       |                             |
       |                                       |  lucreaza, deschide PR ---->|
       |                                       |                             |
       |  jules-triage.ps1                      |                             |
       |  -> gh pr diff + gh pr view <-----------+-----------------------------|
       |  -> Test-DiffPolicy (secrete, cai interzise)                        |
       |  -> jules-verify.ps1 (ruleaza testele REAL, aici, acum)              |
       |                                       |                             |
       |  verdict: ACCEPT | ADAPT | REJECT | UNVERIFIED                      |
       |  -> merge? DOAR cu R0 de la Popy                                      |
```

**De ce contează canalul „corpul issue-ului”:** Jules nu are memorie și nu
accesează interfața noastră. Workflow-ul `jules.yml` transmite corpul
issue-ului în prompt. Așa că **regulile și invariantele noastre călătoresc
în corpul task-ului**. Nu e nevoie de intervenție umană în interfața Jules.

## Fișierele

| Fișier | Ce face |
|---|---|
| `config/repos.json` | registrul repo-urilor: ramură, etichetă, workflow, secret, comenzi de verificare |
| `config/jules-context.md` | **contextul canonic** pe care îl primește Jules la fiecare task |
| `config/task-cards.md` | cardul de task pentru fiecare axă (performanță / design / securitate) |
| `scripts/jules-lib.ps1` | bibliotecă comună: `gh`, registru, arbore repo, ledger de cotă, poartă de secrete |
| `scripts/jules-dispatch.ps1` | trimite un task (issue + etichetă `jules`) |
| `scripts/jules-verify.ps1` | verifică fizic un PR: clonează, face checkout, rulează testele |
| `scripts/jules-triage.ps1` | triază toate PR-urile deschise și scrie verdictul |
| `scripts/jules-daily.ps1` | bucla zilnică: dispatch + triaj + raport |
| `scripts/jules-install.ps1` | instalează puntea Jules într-un repo (etichetă + workflow + context) |
| `workflows/jules.yml` | template-ul workflow-ului de declanșare |
| `workflows/verify.yml` | template-ul verificării nocturne |

## Rulare

```powershell
# plan, fără scrieri pe GitHub
powershell -NoProfile -File scripts\jules-install.ps1 -Repo MAVIS-OPTIMUS-CI

# o sarcină concretă către Jules
powershell -NoProfile -File scripts\jules-dispatch.ps1 -Repo MAVIS-CLOUD -Axis security

# triaj complet
powershell -NoProfile -File scripts\jules-triage.ps1

# bucla zilnică completă
powershell -NoProfile -File scripts\jules-daily.ps1
```

Toate scripturile sunt **ASCII pur** (Windows PowerShell 5.1 rupe șirurile cu
interpolare dacă apare un octet peste `0x7F` fără BOM) și se rulează cu
`powershell -NoProfile -File`. `pwsh` **nu** e instalat pe această mașină.

## Cota lui Jules

Cota e **100 de taskuri pe zi**. Platforma arde cel mult `maxTasksPerDay`
(15 = 5 repo-uri × 3 axe). Restul rămâne rezervă pentru refactorizări mari,
unde sandbox-ul lui Jules chiar contează.

Taskurile sunt **la nivel de sistem**, nu la nivel de virgulă: o țintă
măsurată, un test, un PR.

## Starea măsurată (2026-10-22)

| Repo | PR-uri Jules deschise | Etichetă `jules` | Workflow | Secret | Calea automată |
|---|---|---|---|---|---|
| MAVIS-CLOUD | **34** | ✅ | ✅ | ✅ | ✅ |
| OPTIMUS-Backbone | **37** | ❌ | ❌ | ❌ | ❌ |
| pkms-vault-automation | **25** | ❌ | ❌ | ❌ | ❌ |
| SENTINEL_PRIME | **3** | ❌ | ❌ | ❌ | ❌ |
| MAVIS-OPTIMUS-CI | 0 | ❌ | ❌ | ❌ | ❌ |
| Optimus-Mavis-Skills | 0 | ❌ | ❌ | ❌ | ❌ |

**99 de PR-uri Jules deschise în 4 repo-uri.** 62 dintre ele sunt în repo-uri
*fără* plumbing GitHub — deci Jules are și **calea interfeței web**, care
produce PR-uri fără etichetă, fără workflow și fără secret. Platforma de mai
jos folosește calea **automată**, pentru că e programabilă și trasabilă; calea
web rămâne deschisă, iar triajul prinde PR-urile ei oricum.

Doar MAVIS-CLOUD are calea automată completă. Restul primesc eticheta,
workflow-ul și contextul prin `jules-install.ps1`. **Secretul `JULES_API_KEY`
nu poate fi citit de pe GitHub** — e singurul pas care îl poate face doar
Popy:

```
gh secret set JULES_API_KEY -R apvizual-max/MAVIS-OPTIMUS-CI
```

## Reguli care nu se negociază

- **Merge = push = R0.** Triajul produce verdict, nu merge.
- **Jules propune.** Local evaluează, corectează, extinde și decide.
- **Niciodată ștergere definitivă.** Arhivare prin `git mv`.
- **Zero cifre nereproductibile.** Tot ce se raportează e măsurat acum.
