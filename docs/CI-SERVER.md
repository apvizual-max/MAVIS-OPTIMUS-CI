# CI-SERVER — serverul Mavis-Optimus-CI

> Document scris pentru orice agent care vine nou si nu are memorie intre
> sesiuni. Tot ce e mai jos e **masurat**, nu povestit.

## 1. De ce exista

Peste acelasi repo lucreaza, simultan, mai multi agenti: **Mavis Cloud**
(instanta din cloud), **Jules** (prin Optimus CD) si **Antigravity**. Popy a
cerut explicit ca, dupa fiecare impingere, sa existe o **sincronizare cu ce
e deja pe GitHub si lucrat de ceilalti**, si ca totul sa ramana pe **un singur
branch** (`main`).

Fara asta, istoricul se rupe si conflictul apare la cel mai prost moment: in
plin flux de lucru al altui agent.

## 2. Cele patru reguli (nucleul sistemului)

1. **Pre-flight.** Inainte de orice proces, GitHub trebuie sa fie **curat si
   unitar**: exact o ramura (`main`), **zero** pull request-uri deschise.
2. **Daca nu e curat, nu se face nimic.** Motorul raporteaza `BLOCKED` cu
   motivele exacte si astepta. Nu curata nimic in ascuns, nu taie nimic.
3. **Localul e autonom.** Fetch, integrare (`--ff-only` sau `--no-ff`), commit
   automat, totul pe `main`. Ramurile locale ale altor agenti se **integreaza**
   in `main`, nu se sterg.
4. **Push-ul cere R0.** Un singur acord, un singur push. Poarta e refuzanta
   prin design: `$(git rev-parse --git-dir)/PUSH-ACORD`.

## 3. Topologia (masurat 2026-10-27)

```
E:\Google\GDrive\...\Optimus_CI (by Mavis)     proiectul  -> /workspace/project
E:\Google\GitData-Optimus-CI                   data git   -> /workspace/gitdata
  ├── repo\                  gitdir MAVIS-OPTIMUS-CI
  ├── clone-MAVIS-CLOUD\     gitdir clonei Cloud
  ├── clone-MAVIS-OPTIMUS-CI\gitdir clonei CI
  ├── scratch\               laboratorul portilor
  └── evidence\              jurnalul evenimentelor (ci-ledger.jsonl / .log)

C:\Users\apviz\.minimax-agent\projects\scripts\git-hooks
                          poarta comuna de push   -> /workspace/gate (read-only)
E:\--- System Secrets\github-token-apvizual-max.txt
                          tokenul               -> /secrets/ (read-only)

Container: Mavis-Optimus-CI   imagine: mavis/optimus-ci:1.0.0
API: http://127.0.0.1:8790 (doar loopback)
```

## 4. O singura poarta, doua medii

Portile sunt **aceleasi** in host si in container — nu doua implementari:

| Poarta | Unde ruleaza | Cum se rezolva calea |
|---|---|---|
| scanner de secrete (`scripts\scan-staged-secrets.ps1`) | host + container | `MAVIS_SECRET_SCANNER`, altfel `$top/scripts/...` |
| poarta de push (`git-hooks/pre-push`) | host + container | `MAVIS_PUSH_GATE`, altfel calea Windows de pe host |

Hook-urile sunt **versionate** in `ci-server/hooks/`, iar containerul le
instaleaza singur in gitdir-uri la pornire (idempotent). Dupa un an, sursa
canonica e tot in repo, nu in gitdir-ul consumabil.

`scan-staged-secrets.ps1` a primit parametrul `-GitDir`: in container,
pointerul `.git` contine o cale Windows (`E:/...`) pe care git linux nu o
poate rezolva, deci gitdir-ul se paseaza explicit.

## 5. Containerul

| Ce | Detaliu |
|---|---|
| Nume | `Mavis-Optimus-CI` |
| Imagine | `mavis/optimus-ci:1.0.0` (node:22-slim + git + PowerShell 7) |
| Restart | `--restart unless-stopped` |
| API | `127.0.0.1:8790` (host) -> `8790` (container) |
| Volume | proiect (rw), gitdata (rw), poarta (ro), token (ro), consent (ro) |
| Fara dependinte | motorul e Node stdlib. `npm install` nu exista, deci nu se strica |

### Comenzi

```powershell
# pornire completa (dupa un an: asta e tot ce trebuie)
powershell -NoProfile -ExecutionPolicy Bypass -File "<CI>\ci-server\bootstrap.ps1"

# diagnostic
docker exec Mavis-Optimus-CI node /opt/optimus-ci/engine/cli.mjs doctor

# stare repo-uri
docker exec Mavis-Optimus-CI node /opt/optimus-ci/engine/cli.mjs status

# pre-flight
docker exec Mavis-Optimus-CI node /opt/optimus-ci/engine/cli.mjs plan

# jurnal
docker exec Mavis-Optimus-CI node /opt/optimus-ci/engine/cli.mjs evidence 50
```

## 6. Pluginul (interfata pentru orice AI)

`optimus-ci-server` (in `~/.minimax/skills/optimus-ci-server/`) expune 7
unelte MCP: `ci_status`, `ci_plan`, `ci_sync`, `ci_arm_push`, `ci_push`,
`ci_doctor`, `ci_evidence`.

Serverul MCP e stdio, **fara SDK** (JSON-RPC scris manual). Motivul: un SDK
aduce un arbore de dependinte care dispare intr-o zi; protocolul are ~200 de
linii si tine peste ani.

## 7. Re-autentificare minima

| Ce | Cum se reface | Cand cere omul |
|---|---|---|
| Token GitHub | `gh auth token` -> fisierul din volumul de secrete (bootstrapul face asta automat) | doar daca `gh` nu mai e logat |
| Grant Google | se citeste din `consent-result.json`; daca **nu exista grant viu**, atunci consent | doar daca nu exista niciun grant viu |
| Docker | trebuie sa porneasca | — |

Rezultat: dupa un an, pornirea e `bootstrap.ps1` + un `gh auth login` (daca a expirat sesiunea) — sub 5 minute.

## 8. Ce NU e aici

- **CD / PKMS**: proiecte surori. Nu se ating, nu se discuta fara motiv empiric.
- **LiveReview**: evaluarea cu cheie proprie (BYOK) e in fluxul CD.
- **Starea pe Drive**: o dauneaza bridge-ul (`mavis-cloud-bridge-skill`), nu
  serverul de git.

## 9. Relatii

- `docs\MAVIS-LOCAL-ONBOARDING-2026-10-27.md` — onboardingul proiectului
- `docs\GIT-GITHUB-PROCEDURI.md` — procedurile de git pe host
- `docs\BRIDGE-LOCAL-CLOUD.md` — canalul primar (Google Drive)
- `docs\CONTRACT-CLOUD-QUEUE.md` — contractul cozii (canal secundar)
- skill: `mavis-optimus-ci-server-skill`
