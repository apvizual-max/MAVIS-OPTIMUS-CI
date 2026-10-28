# MAVIS-OPTIMUS-CI — Stare Măsurată Jules (2026-10-28)

> Document generat de **Jules** în urma invocării manuale.
> Măsurătorile sunt executate din mediul CI (Linux), fără acces la host-ul Windows, DriveFS, sau PowerShell.

## 1. Contextul Măsurătorii

Mediul de execuție curent **nu este** host-ul Windows al lui Popy. Este un container/sandbox separat. Din această cauză, instrumentele PowerShell (`.ps1`) și comenzile care depind de monturile locale (ex. `/workspace/gitdata`, `/secrets`, `E:\Google\GDrive`) nu pot fi executate sau raportează lipsa resurselor.

Nu s-au efectuat modificări de cod, conform cerinței de a nu construi nimic fără o sarcină concretă. Raportul prezintă exclusiv starea actuală măsurabilă.

## 2. Verificări Existente și Rezultatele Lor

Am rulat verificările disponibile pentru serverul CI (`ci-server`). Deoarece portile scrise în PowerShell depind de mediul Windows, testarea s-a concentrat pe motorul Node.js.

### 2.1. CLI Doctor (`node ci-server/engine/cli.mjs doctor`)

Măsurătoarea raportează **lipsa monturilor esențiale**, deoarece sandbox-ul actual nu reflectă topologia mașinii host descrisă în `MAVIS-LOCAL-ONBOARDING-2026-10-27.md` și `CI-SERVER.md`.

*   **Rezultat General:** `green: false`, `anomalyCount: 6`
*   **Verificări care ar pica (Lipsă resursă):**
    *   Monturi: `mount:project`, `mount:gitdata`, `mount:secrets`, `mount:ga-data`, `mount:gate` raportează `ok: false`.
    *   Utilitare lipsă: `powershell` raportează `MISSING`.
    *   Date de conectare: `token:github` lipsă, `google:consent-file` lipsă.
    *   Porți: `gate:pre-push` și `gate:mirror-equal` lipsesc sau nu pot fi verificate.
    *   Stare Repo-uri (`repo:ci`, `repo:cloud`, `repo:ciclone`): `HEAD=n/a inSync=false` (din cauza lipsei `gitdata`).

*   **Anomalii (Configurație Git):**
    Sistemul a detectat anomalii legate de igiena `gitconfig` (care trebuie reparate conform procedurilor de siguranță, vezi incidentul din 27 oct):
    *   `GITDIR_FILEMODE_NOT_FALSE`: Pentru repo-urile `ci`, `cloud`, și `ciclone`, opțiunea `core.filemode` nu este setată pe fals (`(unset)`). Aceasta încalcă una dintre cele 4 gărzi de securitate împotriva contaminării din sistemul Windows (`core.filemode=false` + `safe.directory=*`).
    *   `GITDIR_IDENTITY_SET`: Identitatea este setată pe `google-labs-jules[bot]`, ceea ce generează o atenționare, întrucât motorul verifică autorii pe commit-urile nepublicate.

### 2.2. CLI Selftest (`node ci-server/engine/cli.mjs selftest`)

*   **Rezultat:** `FAIL SETUP`
*   **Cauză:** Permisiuni insuficiente (`Permission denied`) la crearea directorului pentru fixture-uri în `/workspace/gitdata/scratch/selftest/`. Similar cu problema de mai sus, mediul actual nu are montat sistemul de fișiere pentru `gitdata` în locația așteptată de server, ducând la un eșec de configurare înainte de rularea testelor efective (T1-T7).

## 3. Îmbunătățiri Care Merită Făcute

Având în vedere măsurătorile de mai sus și arhitectura proiectului, iată îmbunătățirile sistemice necesare:

1.  **Rezolvarea anomaliilor `core.filemode`:** Anomalia `GITDIR_FILEMODE_NOT_FALSE` trebuie remediată. Deși configurația sistemului (`ci-server/gitconfig`) ar trebui să aplice `core.filemode=false`, instrumentul de validare (`doctor`) semnalează lipsa ei. Acest lucru trebuie investigat pentru a asigura funcționarea primei "gărzi" împotriva modificărilor nedorite ale permisiunilor de fișiere (chmod).
2.  **Abordarea lipsurilor cross-platform:** Porturile și testele depind puternic de topologia de sistem a lui Popy. Dacă acest cod (incluzând `jules.yml`) intenționează să ruleze autonom prin GitHub Actions sau agenți separați pe mașini Linux, verificările PowerShell (`scripts/*.ps1`) și căile absolute (`E:\Google\...`) vor bloca invariabil execuția. O îmbunătățire utilă ar fi implementarea unor wrapper-uri OS-agnostice sau izolarea strictă a codului care rulează în CI/CD cloud față de cel care trebuie să ruleze local.
3.  **Corectarea mediului de Selftest:** Testele `selftest.mjs` încearcă să acceseze `/workspace/gitdata/scratch/`. Dacă rulează pe host și containerul Docker nu a montat volumul corect, sau dacă e rulat de un agent care nu respectă structura din container, va eșua (cum am măsurat aici).

**Verdict final:** S-au măsurat sistemele existente. Din cauza izolării mediului, verificările care depind de topologia sistemului de fișiere pică imediat, iar anomaliile vizibile se referă la configurațiile Git de bază (`filemode`). Nu s-au efectuat modificări de cod.
