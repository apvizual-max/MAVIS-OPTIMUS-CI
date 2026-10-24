# Mavis Optimus Continuous Integration — HQ

**Proiect:** OPTIMUS CI · **Rol:** Mavis Local · **Conv:** această conversație
**Început:** 2026-10-11 · **Doctrine:** `DOCTRINA-CI.md`

---

## Citește asta primul, agent nou, cu zero memorie

Ai ajuns în cartierul general. **Trei rânduri și știi tot:**

1. citește `DOCTRINA-CI.md` — cum lucrez
2. citește `docs/CONFLICTE-DOZTRINA.md` — ce s-a hotărât și de ce
3. citește `docs/ARHITECTURA-CI-CD.md` — cine ține ce, și unde e CD

Apoi citește `MAPARE-SISTEM.md` — unde stă tot.
Pentru cifrele de azi: `docs/STARE-MASURATA-CI.md`.

---

## Ce este acest proiect, într-un rând

**Inginerul de sistem al integrării continue a lui Popy.** Nu lucrez la
conținut — lucrez la **sistem**: Git, GitHub, poarta R0, puntea
Local↔Cloud.

## Ce NU este acest proiect

Nu e CD. **Bucla Jules și Live Review sunt în folderul CD**, cu
sesiunea și repo-ul lor: `MAVIS-OPTIMUS-CD`.
Nu sunt producție, nu sunt site, nu sunt CV-uri, nu sunt vault. **Acelea au
fiecare conversația și folderul lor propriu.** Regula Triadei:
`1 conversație = 1 folder = 1 repo`.

---

## Cele trei piloni — modul prin care răspund

```
RUCSAC     — ce e adevărat și măsurat
LOGICĂ     — de ce se leagă, sau de ce nu se leagă
STRATEGIE  — ce e optim în ansamblu, și decizia luată
```

Fiecare propunere, fiecare raport, fiecare nealiniere — pe acești trei.
Nu sunt rapoarte de situație. **Predau rezultatul gândit, nu problema.**

---

## Guvernanța Git — permanentă

| | |
|---|---|
| **COMMIT** | automat, mereu, pe `main`. **Fără R0, niciodată.** |
| **FORK** | doar cerut explicit, ca GOAL + CRITERIA |
| **PUSH spre GitHub** | **singurul** lucru care cere R0 |
| **≥50 neîmpinse** | îl reamintesc la fiecare răspuns, până dă R0 |
| **Changes** | gol, permanent, la toate proiectele de pe mașină |
| **Instanța Cloud** | singura care împinge fără R0 — container volatil |

Mecanismul complet, cu măsurătorile și proba falsificare:
`docs/GIT-GITHUB-PROCEDURI.md`.

---

## Cele trei reguli pe care nu le încalc niciodată

1. **Utilizatorul nu se va îmbunătăți niciodată.** Proiectez pentru un om
   fără cunoștințe de Git, cu zero memorie între sesiuni. Raportul e
   întotdeauna complet în sine.
2. **Prezența lui într-o buclă e o eroare de sistem.** Scoaterea lui din
   buclă e sarcina mea, nu un favor. Cererea de aprobare necerută **e**
   corupția.
3. **O poartă care stă în prohă, sau într-un flag pe care eu îl pot pasa,
   nu e o poartă.** Mecanismul trebuie să mă oprească și când vreau să
   trec.

---

## Cele două repo-uri, și cine ține fiecare

| Repo | Vizibilitate | Rol | Cine îl administrează |
|---|---|---|---|
| `apvizual-max/MAVIS-CLOUD` | **public** | **puntea** Local↔Cloud. Canal `QUEUE/TASKS-FOR-CLOUD.md`. | Instanța Cloud împinge automat; **CI** face ingest-ul și guvernanța |
| `apvizual-max/MAVIS-OPTIMUS-CI` | **public** | **acest proiect** — SOT pentru proceduri, punte, guvernanță | **CI**, cu commit automat + R0 push |
| `apvizual-max/MAVIS-OPTIMUS-CD` | **public** | SOT pentru bucla Jules + Live Review | **CD**, cu commit automat + R0 push |

Inventarul complet, măsurat: `docs/INVENTAR-REPO-URI.md`.

---

## Surse

| Sursă | Rol |
|---|---|
| `cloud-ingest/MAVIS-CLOUD/` | clonă locală a repo-ului Cloud — **NU se modifică** |
| `C:\Users\apviz\.minimax-agent\projects\SENTINEL_OPERATIONAL_DOCTRINE.md` | doctrina de bază, §20 |
| `C:\Users\apviz\.minimax\agents\mavis\skills\` | skillurile vii |
| `C:\Users\apviz\.minimax-agent\projects\scripts\git-autopush.ps1` | **singura poartă de push** |
| `C:\Users\apviz\.minimax-agent\projects\scripts\push-status.ps1` | peretele: comituri neîmpinse, per repo |
| `C:\Users\apviz\.minimax-agent\projects\scripts\git-hooks\pre-push` | poarta reală, per repo, în istorie |

---

## Mapă

| Folder / fișier | Ce e |
|---|---|
| `README.md` | acest fișier — punct de intrare, cold-boot |
| `DOCTRINA-CI.md` | cum lucrez |
| `MAPARE-SISTEM.md` | unde stă tot |
| `docs/` | documentația de proiect |
| `docs/CONFLICTE-DOZTRINA.md` | **cele conflicte găsite, și hotărâra** |
| `docs/ARHITECTURA-CI-CD.md` | **convenția care separă CI de CD** |
| `docs/GIT-GITHUB-PROCEDURI.md` | **procedurile Git/GitHub, cu mecanism și probe** |
| `docs/CI-POLICY.md` | politica CI: puntea, guvernanța, verificarea |
| `docs/STARE-MASURATA-CI.md` | **starea măsurată azi, cu cifre și metode** |
| `docs/INVENTAR-REPO-URI.md` | toate repo-urile, locale și GitHub |
| `docs/BRIDGE-LOCAL-CLOUD.md` | puntea, în detaliu |
| `docs/PROTOCOL-DENUMIRE-LOCAL-CLOUD.md` | protocolul de denumire |
| `docs/META-PROMPT.md` | generarea meta-promptului |
| `docs/RECUPERARE-GIT.md` | starea măsurată a mașinii, cu cifre |
| `docs/STATUS-LOCAL-TO-CLOUD-2026-10-12.md` | raport de status |
| `docs/arhiva/handoffs-vechi/` | handoff-uri consumate — **mutate, nu șterse** |
| `blueprint/` | planul de execuție al proiectului |
| `cloud-ingest/` | sursa clonată, neatinsă |
| `scripts/` | puntea: `mavis-sync.ps1`, wrapper, snapshot, meta-prompt |
| `logs/` | logul datat al fiecărei rulări a punții |

---

## Starea acum

Repo: **public**, ramura `main`, HEAD `f5fb3f3`, **10 commituri neîmpinse**
peste `origin/main` (`d9a186e`). **Nimic împins** — corect, push-ul e
blocat de poarta R0.

**Puntea e vie:** `MavisSyncBridge` 08:30, `LastTaskResult=0`,
`exit_pull=0`, `local_dupa == remote`, `impingere=NEEXECUTATA`.

Cifrele complete: `docs/STARE-MASURATA-CI.md`.
