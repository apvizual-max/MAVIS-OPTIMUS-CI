# WORKFLOWS — cum se lucrează în CI

> **Complementul lui `CI-POLICY.md`.** Politica spune *ce* e permis; aici
> spune *cum se execută*, cu comenzi, porți și coduri de ieșire.
>
> **Măsurat 2026-10-27.** Fiecare flux are o poartă care **poate eșua**.

---

## W0 — Deschiderea sesiunii

```powershell
node C:\Users\apviz\QWEN_BACKUP\core\kernel.js --intent "<ce urmează să fac>"
powershell -NoProfile -File scripts\mavis-drive-bridge-selfcheck.ps1
powershell -NoProfile -File scripts\scan-staged-secrets-selfcheck.ps1
git status --short
```

**Citește, în ordine:** `README.md` → `DOCTRINA-CI.md` → `MAPARE-SISTEM.md` →
`docs/MAPARE-FOLDERE.md` → acest document.

**Nu declara nimic înainte de măsurat.** La început se citește; la final se
raportează.

---

## W1 — Schimbare în proiect → commit

**Automat, pe `main`, fără R0.** Popy nu aprobă comituri.

```
1. editezi (write/edit)
2. git add -A
3. poarta de secrete rulează AUTOMAT prin hook-ul pre-commit
4. git commit
```

| Cod al porții | Ce înseamnă | Ce faci |
|---|---|---|
| `0` | `BLOCKS=0 WARNS=0 SCAN_OK` | comitezi |
| `1` | cel puțin un `BLOCK` — **commit refuzat** | vezi `BLOCK <pattern> @ <fișier>:<linie>` |
| `2` | scanarea **nu a putut rula** — commit refuzat | e o eroare, nu un bloc. Nu rescrie secretul; repară scannerul |

> **Regula:** `2` ≠ `1`. O poartă care *acuză* trebuie să dovedească
> imputabilitatea; o aruncare nu e o dovadă.

**Proba porții, la schimbarea ei:**
```powershell
powershell -NoProfile -File scripts\scan-staged-secrets-selfcheck.ps1
```
7 probe, în ambele sensuri: o cheie plantată e **blocată**, un placeholder
**nu** e blocat, o cheie privată e blocată, liniile goale **nu** aruncă
excepție, scannerul **nu** se blochează pe propriul cod, indexul real e curat.

---

## W2 — Publicarea către Cloud

```powershell
powershell -NoProfile -File scripts\mavis-drive-bridge.ps1 -Publish -Title "<subiect>" -Body "<text>"
```

**Ce se întâmplă:** se scrie **același `TASK_ID`** în ambele canale —
`BRIDGE-DRIVE/TASKURI-PENTRU-CLOUD.md` (Drive, primar) și
`QUEUE/TASKS-FOR-CLOUD.md` (GitHub, secundar) — și se emite un receipt în
`state/drive-bridge-last-publish.json`.

| Cod | Ce înseamnă |
|---|---|
| `0` | `SYNCED` — confirmat în indexul de cloud |
| `2` | input lipsă (fără `-Title`, fără python) |
| `3` | ținta nu a fost găsită în Drive |
| `4` | **scris, neconfirmat** — onestul „unknown" |
| `5` | transportul Drive e jos — canalul activ trece pe GitHub |

**Regula:** `UNVERIFIED` **nu e succes**. Nu raporta „am publicat" pe baza
scrierii — raportează pe baza măsurătorii.

**De ce ambele canale, la aceeași publicare:** o cădere de transport nu
trebuie să coste timp.

---

## W3 — Push pe GitHub

**Singurul lucru care cere R0.**

```
1. Popy dă R0 explicit
2. scripts\git-autopush.ps1 -Acord          # singura cale de push
3. git ls-remote origin main               # verificarea, NICIODATĂ prin exit code
```

| Cod | Ce înseamnă |
|---|---|
| `0` | hash-ul server **==** hash-ul HEAD local |
| `1` | **poarta a refuzat** push-ul: `POARTA: acest repo nu se impinge fara acordul lui Popy` |

> `git push` scris cu mâna **ocolesc** poarta? Nu — poarta e un hook
> `pre-push`, nu un switch. Dar și așa, calea corectă e `git-autopush.ps1
> -Acord`: un `-Acord` = o singură împungere.

**Divergența se documentează, nu se rezolvă cu forță.** Măsurat 2026-10-27:
**17 commituri local / 5 remote** (cele 5 remote sunt lucrarea CD).

---

## W4 — Sincronizarea zilnică

Rulează singură, la **08:30**, prin taskul `MavisSyncBridge`.

```powershell
powershell -NoProfile -File scripts\run-sync-logged.ps1 -DryRun
```

| Ce | Măsurat |
|---|---|
| Log zilnic | `exit_pull=0`, `local_dupa == remote`, `impingere=NEEXECUTATA|poarta_R0=ramane_la_Popy` |
| Consecvență | 12 loguri consecutive (12→23 oct), fără gol |
| Auto-verificare | `mavis-sync.ps1 -SelfTest` → `POARTA|TRECUT` (EXIT 0) |

**Sincronizarea nu împinge.** Citește, și lasă push-ul porții.

---

## W5 — Verificarea a ce vede Cloud

```powershell
powershell -NoProfile -File scripts\mavis-drive-bridge.ps1 -Status
python scripts\drivefs_probe.py --staleness "MAPARE-SISTEM.md" --folder "Optimus_CI (by Mavis)" --local "<rădăcină>"
```

| Câmp | Ce înseamnă |
|---|---|
| `TRANSPORT=UP` | rădăcina mirrorului e **conectată** |
| `PROPAGATION=OK` / `STALE` | scrierea locală e / nu e **confirmată** |
| `CLOUD_CHANNEL_FILE_PRESENT` | fișierul canalului e / nu e în indexul de cloud |
| `CLOUD_TRACKED_AGE_DAYS` | **cât de veche e copia** pe care Cloud ar citi-o |
| `ACTIVE_CHANNEL` | `DRIVE` doar dacă propagarea e `OK`; altfel `GITHUB` |

> **O rădăcină conectată nu e un transport care încarcă.** Măsurat: rădăcina
> `connected=true`, coada `PENDING_OPERATIONS=0`, dar motorul de sync al
> DriveFS raporta `change_ids_up_to_date: true` — nu vedea scrierile locale.

---

## W6 — Transport degradat

**Nu blochează sistemul.** Regula: poarta cere ca **raportul să fie
concordant cu măsurătoarea**, nu ca transportul să fie UP.

```
1. mavis-drive-bridge.ps1 -Status  →  PROPAGATION=STALE, ACTIVE_CHANNEL=GITHUB
2. conținutul NOU merge pe canalul secundar (push cu R0)
3. conținutul VECHI rămâne în cloud, și poate fi citit - dar e vechi
4. raportezi: ce e nou, unde, și cât de veche e ce vede Cloud
```

**Nu** re-autentifici DriveFS și **nu** reconsentezi tokenul unilateral:
act ACCESS, pe mașina lui Popy.

---

## W7 — Cerință nouă de la Popy

```
1. Popy scrie ce vrea în BRIDGE-DRIVE/INTENTII.md (liber, cu cuvintele lui)
   sau cererea e structurată și intră în TASKURI-PENTRU-CLOUD.md
2. Local: citește, măsoară, execută
3. Cloud: citește la pull, livrează în INTRARI-CLOUD/, marchează, mută în ISTORIC/
```

**Regula de numire:** `MAVIS-LOCAL-…` / `MAVIS-CLOUD-…` în ambele canale.
**Nu se suprascrie nimic.** Corecția = fișier nou.

---

## W8 — Verificarea pe server, peste conținutul aterizat

> **Aditiv.** Măsurat 2026-10-27.

```
.github/workflows/ci-verify.yml
  on: push (main) · workflow_dispatch · schedule '30 3 * * *'
  runs-on: windows-latest · permissions: contents: read
  → actions/checkout@v4
  → scannerul de secrete pe index
  → auto-proba
```

**Ce e diferit de W1:** W1 rulează **înainte** de commit, pe mașina lui Popy,
prin hook. W8 rulează **după** push, pe server, peste ce s-a aterizat.

| | W1 (hook) | W8 (server) |
|---|---|---|
| Când | înainte de commit | după push |
| Unde | calculatorul lui Popy | runner GitHub |
| Efect | **blochează** commitul | **raportează** (nu blochează) |
| Ce acoperă | indexul local | conținutul **public**, deja împins |

**De ce raportează, nu blochează:** acest repo e lucrat acum de alt AI. Un
workflow care blochează push-ul altcuia ar fi o poartă fără imputabilitate —
ar acuza conținut pe care eu nu l-am scris și pe care nu l-am măsurat. Regula
din `CI-POLICY.md` §5: *un verdict care acuză trebuie să dovedească
imputabilitatea.*

**Proba:** falsificat în ambele sensuri într-o clonă curată (runner simulat) —
`SCANNED=50 BLOCKS=0 SCAN_OK` exit 0 → cheie plantată → `BLOCKS=1` exit 1
(workflow roșu) → scosă → `SCAN_OK` exit 0.

**Starea reală:** pe remote `.github/workflows/` dă **404**. Workflow-ul
există doar în copia locală, între cele 17 commituri neîmpinse — **serverul
nu rulează încă nimic pentru acest repo.** Se activează la push, cu R0.

---

## Fluxuri pe care CI **nu** le atinge

| Flux | Unde trăiește |
|---|---|
| Triaj Jules, adaptări, Daily Loop | **CD** — `Optimus_CD (by Jules)\JULES - Optimus CD\` |
| Live Review, merge-uri de PR | **CD** |
| `JULES_API_KEY` în repo-uri | **CD** (R0 deschis) |

**Din CI se ating doar dacă e strict necesar** — și atunci se documentează.

---

*2026-10-27 · Mavis Local · măsurat · aditiv*
