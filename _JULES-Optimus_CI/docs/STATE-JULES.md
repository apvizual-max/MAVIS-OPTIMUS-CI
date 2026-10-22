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
| `jules-selfcheck.ps1` | ✅ | `FILES=10 PROBLEMS=0`; **proba-idiom**: payload pe stdout ȘI cod de ieșire 3; **proba-checkout**: poarta respinge director neclona, ramură greșită, fișier lipsă, commit greșit |
| `jules-adapt.ps1` | ✅ | 12/12 PR-uri adaptate, toate cu **EXIT 0** real, checkout verificat pe ramură + SHA + fișiere proprii |
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

## 3.3 A doua clasă de defecte: măsurătorile care măsurau altceva (2026-10-22, 11:30–12:10)

**Defectul de rădăcină: `gh pr checkout` acționează asupra repo-ului din
directorul CURENT și iese cu cod 0 chiar când acel repo nu e cel cerut.**

Măsurat, cu probă de falsificare într-un director de probă:

```
CWD = repo strain (MAVIS-OPTIMUS-CI)
gh pr checkout 9 -R apvizual-max/MAVIS-CLOUD
EXIT=0
BRANCH_AFTER=jules-detect-pain-coverage-2559261305742346084   # creată ÎN REPO-UL STRAIN
```

**Consecința, măsurată pe disc:** comanda a fugit în
`C:\Users\apviz\.minimax-agent\projects` — care e repo-ul **backbone-ului
OPTIMUS**, nu o simplă zonă de lucru. Acolo au rămas **9 ramuri Jules
străine**, repo-ul a fost lăsat **în afara `main`**, iar arborele de lucru i-a
fost înlocuit cu conținut MAVIS-CLOUD: `OPTIMUS_INDEX.md`, `00_INDEX/`,
`10_BRIDGES/`, `40_REGISTRIES/` au dispărut de pe disc.

Restaurat cu `git checkout main` — fișierele au revenit, ramura rătăcită a
rămas păstrată (recuperabilă), conținutul nu s-a pierdut.

Aceasta e cauza **FAIL-ului fals** de pe PR #9: clona a rămas pe ramura PR #18,
fișierul `ALEX-KIT/letter-engine.test.js` nu exista acolo, `node --test` a ieșit
1, iar raportul a numit propunerea spartă. După reparare: `RESULT=ADAPT`,
`node --test "ALEX-KIT/letter-engine.test.js"` → **EXIT 0**.

**Al doilea defect: `@($x | ConvertFrom-Json)` colapează un array JSON la un singur
element în PowerShell 5.1.** Măsurat pe payload-ul real de la GitHub:

```
34 de PR-uri în payload -> 1 element în @(...)-> fiecare element pică testul de tip
-> scanarea de conflicte raporta "0 open PR examined" în timp ce API-ul mergea
```

Reparat cu `ConvertFrom-JulesJson` (atribuie mai întâi, învelește după):
**34 elemente, 34 cu câmpul `number`**.

**Reparațiile aplicate:**
1. `Invoke-Native` / `Invoke-Gh` au primit `-WorkingDirectory`. Dacă
   directorul nu există, ieșirea e **127**, nu o rulare tăcută în altă parte.
2. `Test-CheckoutTarget` — poartă care poate eșua: director neclona, ramură
   greșită, SHA greșit sau fișier de test lipsă → toate respingute.
3. `jules-adapt.ps1` verifică checkout-ul pe **ramură + SHA + existența
   fișierelor proprii**, și cere ca `origin` să fie repo-ul potrivit.
4. Clona murdară e restaurată la HEAD înainte de măsurare (măsurat: două
   `decisions.jsonl` modificate de rularea testelor repo-ului).
5. **Lanț de runner-e**: `pytest` nu e instalat pe această mașină (măsurat:
   `No module named pytest`), dar testul PR #11 e `unittest` standard cu
   `unittest.main()`. Primul runner care pornește măsoară — așa PR #11 a
   devenit măsurabil fără pip: `python "mavis-tools/test_log.py"` → **EXIT 0**.
6. **Baseline detectat** când registrul nu declară comenzi: OPTIMUS-Backbone
   avea **0 comenzi** rulate (raport fără măsurătoare, verdict inconsistent);
   acum **2** comenzi detectate din repo → EXIT 0.
7. Verdictul distinge `ADAPT` de `ADAPT_NO_MEASUREMENT` — un PR fără măsurătoare
   nu e ACCEPT, dar nici REJECT.

**Rezultatul măsurat, toate 12 cu o singură versiune de script:**

| PR | Comenzi rulate | Toate EXIT 0 | Conflicte măsurate |
|---|---|---|---|
| MAVIS-CLOUD #9 | 2 | ✅ | 1 (PR #10, același fișier) |
| MAVIS-CLOUD #10 | 2 | ✅ | 1 (PR #9, același fișier) |
| MAVIS-CLOUD #11 | 2 | ✅ | 1 |
| MAVIS-CLOUD #12 | 1 | ✅ | 0 |
| MAVIS-CLOUD #13 | 1 | ✅ | **5** |
| MAVIS-CLOUD #14 | 1 | ✅ | 1 |
| MAVIS-CLOUD #15 | 1 | ✅ | **5** |
| MAVIS-CLOUD #16 | 2 | ✅ | 2 |
| MAVIS-CLOUD #17 | 2 | ✅ | 0 |
| MAVIS-CLOUD #18 | 2 | ✅ | 0 |
| OPTIMUS-Backbone #2 | 2 | ✅ | 0 |
| OPTIMUS-Backbone #9 | 2 | ✅ | 0 |

**Limită de mediu, măsurată, apoi rezolvată — și ce a rămas în urmă:** clona
`pkms-vault-automation` se materializa incomplet pe Windows: gitul eșua cu
*„Filename too long"* (MAX_PATH 260) și doar **14** din cele 701 de fișiere
urmărite ajungeau pe disc. O măsurătoare făcută în acel arbore ar fi descris
14 fișiere pretinzând că descrie 701.

Reparat cu `core.longpaths=true` propagat prin `GIT_CONFIG_*` — deci și la
apelurile `git` pe care le face `gh` intern. Măsurat **prin calea platformei**:
`Invoke-Gh` → `gh repo clone` → `CLONE_EXIT=0`, `ON_DISK=701`,
`TRACKED=701`, `INTEGRITY_OK=True`. Clona existentă a fost restaurată:
701/701, arbore curat, iar `jules-verify` pe PR #1 a ieșit pe ramura
`perf-lint-array-opt-3718015018285384704`, **verificată** contra API-ului.

**Ce a rămas, măsurat:** repo-ul pkms nu are runner de teste detectabil, deci
verdictul de acolo rămâne UNVERIFIED — instrument lipsă, nu test picat.
Politica e deja scanată de triaj pe diff (violație → REJECT). Pe GitHub,
PR-urile pkms au și ele conflicte de fișiere între ele.

## 3.4 Poarta de integritate a clonei

`Test-CloneIntegrity` compară fișierele urmărite de `HEAD` cu fișierele de
pe disc. Incomplet → `INCOMPLETE_CLONE`, cu numărul exact, și **nicio
măsurătoare nu se rulează** într-un arbore trunchiat. E o poartă care poate
eșua: raportează `701 de 701` pe clonele complete și ar raporta `14 de 701`
pe cea trunchiată.

### 3.4.1 Măsurătoarea trebuie să reproducă mediul sistemului pe care îl măsoară

Măsurând starea clonei `pkms-vault-automation` cu un `git status` obișnuit
din shell, ieșirea a fost: **1227 de fișiere șterse** (` D`), plus 100+
avertismente „could not open directory … Filename too long". Un verdict
dramatic: jumătate din clonă ar fi dispărută.

Repetând aceeași măsurătoare **cu `core.longpaths=true`** — configurația
pe care platforma o propagă prin `GIT_CONFIG_*` la fiecare apel git:

```
STATUS_WITH_LONGPATHS=0    TRACKED=4524    branch=jules-6988632761374277197-50cee8b5
```

Clona e **curată**. Cele 1227 de intrări erau un artefact al **măsurătorii**,
nu al sistemului măsurat: gitul fără long paths nu poate deschide
directoarele cu nume peste 260 de caractere, deci le raportează ca
șterse.

**Regula:** o măsurătoare care nu reproduce mediul sistemului pe care îl
măsoară produce defecte imaginare. `git status` gol într-un shell, și
`git status` gol în `Invoke-Native` cu long paths, sunt două lucruri
diferite — și doar al doilea îl descrie pe cel real.

## 3.5 A treia clasă de defecte: motivul fals care se repeta pe toate rândurile (2026-10-22, după `e76eb4d`)

Triajul complet s-a terminat cu `FINDINGS=99`, `TRIAGE_EXIT=0`, iar
distribuția verdicturilor a fost **50 ADAPT/PASS · 48 UNVERIFIED · 1 REJECT/FAIL**.
Pe prima vedere, un tabel sănătos. Nu era.

**Măsurătorul a fost interogat în locul artefactului.** La
`jules-triage.ps1:90`, poarta P2 căuta cele trei secțiuni canonice în
**body-ul pull request-ului de GitHub**:

```powershell
$reportCheck = Test-ReportComplete -Body ([string]$view.body)
```

Dar acele secțiuni — *Ce am schimbat / De ce / Cum am verificat* — sunt
**scrise de Mavis Local**, în raportul de adaptare
`docs/adaptari/adapt-<repo>-pr<n>.md`. Jules nu le scrie niciodată. Un PR
de Jules nu le poate conține. Deci poarta raporta, corect pentru ea însăși
și fals pentru lume:

> toate cele **99** de rânduri aveau motivul `report incomplete, missing
> sections: Ce am schimbat, De ce, Cum am verificat`

inclusiv cele **12** care au raportul complet pe disc. Verificat: header-ele
din `adapt-MAVIS-CLOUD-pr9.md` conțin toate cele trei secțiuni, iar triajul
totuși spunea că nu le conține. Nu era o divergență de formulare — era
citirea altui fișier.

Consecința nu era cosmetică. Verdictul era forțat pe `ADAPT` de un motiv
fals, deci **raportul pe care Popy îl citește conținea o afirmație
neadevărată despre 99 de propuneri**.

**Reparare, cu o singură sursă de cale:**

- `Get-AdaptReportPath` (în `jules-lib.ps1`) — scriitorul `jules-adapt.ps1`
  și cititorul `jules-triage.ps1` nu mai pot diverge; înainte, fiecare își
  construia calea separat.
- `Get-AdaptReportState` — distinge trei stări pe care verificarea le
  confunda:
  - `Exists = $false` → nu există raport local → motivul onest este
    `no local adaptation report yet (not yet adapted)`, iar propunerea
    **nu poate fi ACCEPT** niciodată, fiindcă nu a fost adaptată.
  - `Exists = $true, Complete = $false` → raportul e pe disc dar îi lipsește
    o secțiune → motivul devine `adaptation report incomplete, missing
    sections: ...` — același diagnostic, acum adevărat.
  - `Exists = $true, Complete = $true` → raport complet → **niciun motiv
    fals**.

**Proba de falsificare, cuplată în poarta permanentă.** `proba-raport` din
`jules-selfcheck.ps1` cere patru cazuri: raportul existent complet să fie
recunoscut, raportul absent să **nu fie inventat**, scriitorul și cititorul
să coincidă pe cale, iar un raport parțial să-și declare secțiunea lipsă.
Măsurat: `4/4`, `PROBE_ADAPTSTATE_OK`, `EXIT=0`.

### 3.5.1 A patra clasă: poarta blochează pe un defect scris de mine

În timpul aceleiași sesiuni, mesajul de succes al probei runner a primit
diacritice (`acceptă doar fișierele`). Într-un script care trebuie să fie
ASCII pur, **6 octeți peste `0x7F`**. `jules-selfcheck.ps1` a raportat
`FILES=10 PROBLEMS=1` și a ieșit cu `EXIT=1`.

Aceasta a fost **defectul real, prins corect** — poarta a funcționat. Dar
a fost prins de o poartă statică, nu de o probă de falsificare: nu exista
niciun caz în care poarta să fie demonstrată capabilă să blocheze un
octet non-ASCII introdus *ad hoc*. Repararea a fost simplă (fără
diacritice în mesaj), rezultatul măsurat: `FILES=10 PROBLEMS=0`, `EXIT=0`,
`nonascii=0` pe toate cele 10 scripturi.

**Regula pe care o produce:** o poartă care blochează o dată, accidental, nu
e o poartă — e o coincidență. O poartă se cuplă cu o **contra-probă**: îi
spui „arată că știi să detectezi asta" și verifici că răspunde corect.

## 3.6 A cincea clasă: poarta care blama propunerea pentru ceea ce nu îi aparține (2026-10-22, după `e76eb4d`)

Singurul REJECT din triaj era `SENTINEL_PRIME#3`. Un verdict REJECT înseamnă
„închidem propunerea cu motiv scris" — deci trebuie să fie **imediat**.

**Măsurătorul era nedrept în două moduri, simultan.**

**Modul 1 — eșecul nu era reproductibil.** Aceeași comită, același SHA
`6f0a391b`, două arbori:

| Arbor | Rezultat | Cod |
|---|---|---|
| `work/SENTINEL_PRIME` | 62 passed / **1 failed** / 1 not-run (64) | EXIT 1 |
| clonă curată, același SHA | 63 passed / **0 failed** / 1 not-run (64) | EXIT 0 |

Așadar: **același cod, două verdicturi diferite**. `test_deployment.py`
verifică un container Docker (`mavis-sentinel-hub`), porturi 8910/8912,
sondare HTTP live, deținerea portului și o pornire la rece — verificări
dependentă de mediu și de moment. Poarta măsura **mediul**, nu propunerea.

**Modul 2 — eșecurile precedeau propunerea.** Al doilea command,
`test_suite.py`, raportează:

| Ramură | Rezultat |
|---|---|
| `main` (baza) | **479 passed, 6 failed, 0 skipped** |
| capul PR #3 | **479 passed, 6 failed, 0 skipped** |

Identic. Cele 6 eșecuri **existasă înainte** de propunere. Poarta le
taxa propunerii — și, prin regula „orice eșec = REJECT", ar fi respins
**orice propunere viitoare** pe acel repo, la nesfârșit, pentru eșecuri
care nu-i aparțin.

Direcția e cea periculoasă: poarta eșua **în direcția greșită** — bloca
lucru bun, în loc să-l lase să treacă.

### Repararea: o propunere poate fi blamată doar pentru un eșec propriu

În `jules-verify.ps1`, după un eșec, două măsurători în plus — **doar pe
calea de eșec**, deci calea comună nu costă nimic:

1. **Reproductibilitate** — aceleași comenzi, în același arbore, a doua
   oară. Dacă a doua rundă trece → `FLAKY`. Un eșec care nu se repetă nu
   poate fi imputat propunerii.
2. **Baza** — aceleași comenzi pe `origin/main`. Dacă baza trece →
   `ATTRIBUTABLE`. Dacă baza pică cu **aceeași semnătură de eșec** →
   `PREEXISTING`. Dacă baza pică doar parțial → `MIXED`.

`Get-JulesFailureSignature` extrage **identitatea** verificării căzute
(`=== Secțiune ===` → `Status: FAIL` → liniile din `Errors:`), ca cele
două runuri să poată fi comparate ca mulțimi, nu ca „a picat / nu a picat".
`Compare-JulesFailureSets` decide: `ATTRIBUTABLE` / `PREEXISTING` / `MIXED`.

**Contractul nou al codurilor de ieșire:**

| Cod | Înțeles |
|---|---|
| 0 | totul a trecut |
| 1 | un command a picat, **reproductibil**, și **nu exista în bază** → REJECT |
| 2 | nu s-a putut măsura (instrument lipsă) → UNVERIFIED |
| **3** | eșec măsurat dar **neatribuibil** (FLAKY / PREEXISTING / MIXED) → UNVERIFIED |

Codul 3 este **noul**: un eșec măsurat, raportat, dar **nu blamat** pe
propunere. În triaj, el produce `UNVERIFIED`, nu `REJECT` — cu motivul
scris, ca Popy să vadă ce s-a măsurat.

**Proba de falsificare, cuplată în poarta permanentă.** `proba-atribuire`
din `jules-selfcheck.ps1` cere patru cazuri, pe date reale: baza trece →
`ATTRIBUTABLE`; baza pică identic → `PREEXISTING`; baza pică parțial →
`MIXED`; toate eșecurile sunt noi → `ATTRIBUTABLE`; plus extragerea
numelui verificării căzute dintr-un ieșire reală. Măsurat: `5/5`.

## 3.7 Tabelul final, măsurat cu codul definitiv (2026-10-22, 13:47–14:22)

Rulare completă pe toate cele **99** de PR-uri deschise, cu poarta de
atribuire activă. `TRIAGE_EXIT=0`.

| Verdict | Verificare | Număr | Ce înseamnă |
|---|---|---|---|
| **ACCEPT** | PASS | **12** | adaptat local, verificat fizic aici, raport complet |
| **ADAPT** | PASS | **40** | trece testele, dar nu are încă raport de adaptare local |
| **UNVERIFIED** | UNVERIFIED | **46** | nu s-a putut măsura (instrument lipsă) |
| **UNVERIFIED** | NOT_ATTRIBUTABLE | **1** | eșec măsurat, dar **nu al propunerii** |
| **REJECT** | FAIL | **0** | niciun verdict de respingere nu mai poate fi emis fără dovadă de imputabilitate |

Pe repo-uri:

| Repo | Total | ACCEPT | ADAPT | UNVERIFIED | REJECT |
|---|---|---|---|---|---|
| MAVIS-CLOUD | 34 | 10 | 23 | 1 | 0 |
| OPTIMUS-Backbone | 37 | 2 | 17 | 18 | 0 |
| pkms-vault-automation | 25 | 0 | 0 | 25 | 0 |
| SENTINEL_PRIME | 3 | 0 | 0 | 3 | 0 |

**Singurul REJECT din sesiune a devenit `UNVERIFIED / NOT_ATTRIBUTABLE`**, cu
`ATTRIBUTION=PREEXISTING` — adică toate cele 10 eșecuri identificate există și
pe ramura de bază:

```
FAIL ecosystem_snapshot_fresh: snapshot is #s old (bound #s) - the server is NOT refreshing it
BrainAndMonitor  :: MCP tools report OK only on a measured handshake: expected OK, got STALE
EcosystemCollector :: design_cloud_auth / design_cloud_hosts / design_cloud_reach / design_route_loader is present
McpHandshakeMeasure :: the real record is restored and the check returns OK: expected OK, got STALE
```

Normalizarea cifrelor (`\d+` → `#`) în semnătură a făcut clasificarea
**exactă**: înaintea ei, „snapshot is 10774s old" și „snapshot is 12374s old"
erau două eșecuri diferite, deci verdictul era `MIXED`. Acum e `PREEXISTING`.

**Ce nu s-a schimbat:** cele 46 UNVERIFIED rămân măsurate ca atare — 25 în
`pkms` (fără runner de teste), 18 în `OPTIMUS-Backbone` (teste pytest-style,
`pytest` absent) și 1 în `MAVIS-CLOUD`. Nu e deficit de măsurătoare, e
**instrument lipsă**, și se raportează onest.

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
12. **Poarta P2 a triajului interoga body-ul PR-ului, nu raportul local** →
    motiv fals `report incomplete` pe toate cele **99** de rânduri, inclusiv
    pe cele 12 cu raport complet. Reparat cu `Get-AdaptReportState`; proba
    `proba-raport` cuplată în poarta permanentă (4/4). Vezi §3.5.
13. **6 octeți non-ASCII** (diacritice) în mesajul probei runner →
    `jules-selfcheck.ps1` a raportat `PROBLEMS=1`, `EXIT=1`. Poarta a
    funcționat corect; defectul era al meu, nu al ei. Vezi §3.5.1.
14. **Poarta P3 blama propunerea pentru eșecuri care nu-i aparțineau** →
    `REJECT` pe `SENTINEL_PRIME#3` fără ca vreo măsurătoare să stabilească
    că eșecul e al propunerii. Reparată cu reproducție + bază + semnătură
    de eșec; cod nou de ieșire **3 = neatribuibil**. Vezi §3.6.

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
comparativă, scanner pre-commit), `7518567` (starea + triajul re-rulat),
`025f09c` (repararea măsurătorilor: checkout verificat, conflict scan
reparat, 12 adaptări), `e76eb4d` (deblocare pkms: long paths + poarta de
integritate a clonei), `8abca4b` (raport + imputabilitate: cele trei
porți măsurau altceva) și commitul de tabel final.
`origin/main` e la `d9a186e`.

**Contaminare reparată, în afara acestui repo:** repo-ul backbone-ului
(`C:\Users\apviz\.minimax-agent\projects`) a fost lăsat pe o ramură străină de
`gh pr checkout`, cu fișierele lui șterse de pe disc. Restaurat pe `main`;
fișierele (`OPTIMUS_INDEX.md`, `00_INDEX/`, `10_BRIDGES/`, `40_REGISTRIES/`)
sunt înapoi. Cele **9 ramuri străine** rămân ca referințe recuperabile — nu
conțin nimic ce nu există în PR-urile de pe GitHub.

## 6. Ce rămâne și cine decide

| # | Decizie | Cine |
|---|---|---|
| 1 | `JULES_API_KEY` în cele 4 repo-uri fără el — **secretul nu poate fi citit de pe GitHub** | Popy |
| 2 | R0 pe merge-ul celor **12 PR-uri ADAPT** (toate cu EXIT 0 măsurat) | Popy |
| 3 | R0 pe rezolvarea conflictului **#9 ↔ #10** (ambele adaugă `ALEX-KIT/letter-engine.test.js`) | Popy |
| 4 | R0 pe **push-ul** platformei în `MAVIS-OPTIMUS-CI` (singura operație externă) | Popy |
| 5 | Corectarea adresei necanonice în cele **9** fișiere din MAVIS-CLOUD (material read-only pentru conținut → scriere cerută) | Popy |
| 6 | Redresarea istoricului public al repo-ului (date personale) — cere force-push | Popy |
| 7 | Al 5-lea repo cu Jules activ: `OPTIMUS-Backbone` e propunerea mea | Popy |
| 8 | PR-urile **pkms** (25): clonarea e reparată (701/701), dar repo-ul **nu are runner de teste** detectabil → rămân UNVERIFIED prin lipsă de instrument. Ca să devină măsurabile, Jules trebuie să primească acolo un harness de test — și asta e o scriere externă | Popy |
| 9 | Instalarea lui `pytest` — **20** de PR-uri din `OPTIMUS-Backbone` folosesc teste pytest-style, iar `pytest` nu e instalat. Standard library refuză corect acele fișiere (ar fi PASS fals). Instalarea lui e decizie cu R0 | Popy |
| 10 | `SENTINEL_PRIME` are **6 eșecuri pre-existente** în `test_suite.py` (479 passed / 6 failed, identic pe `main`) și `test_deployment.py` depinde de Docker + porturi 8910/8912 + sondare live → verdictul nu e reproductibil fără mediu stabil. Poarta acum raportează asta ca UNVERIFIED, nu REJECT | Popy |
