# ARHITECTURA CI ↔ CD — latura CI

> Oglinda documentului cu același nume din folderul CD
> (`…\Mavis-Optimus-Continuous-Development\docs\ARHITECTURA-CI-CD.md`).
> **Convenția e aceeași, privită din CI.**
>
> Decizie măsurată 2026-10-24. Pentru motivul separării și pentru ce s-a
> mutat efectiv, vezi latura CD.

---

## 1. Separarea e definitivă

| | **CI — Continuous Integration** | **CD — Continuous Development** |
|---|---|---|
| **Sesiune** | aceasta | sesiunea CD paralelă |
| **Folder** | `…\Mavis-Optimus-Continuous-Integration\` | `…\Mavis-Optimus-Continuous-Development\` |
| **Repo** | `apvizual-max/MAVIS-OPTIMUS-CI` | `apvizual-max/MAVIS-OPTIMUS-CD` |
| **Puntea** | Local ↔ Cloud, prin `MAVIS-CLOUD` | — |
| **Bucla de dezvoltare** | — | Jules + Live Review |
| **Task zilnic** | `MavisSyncBridge` 08:30 | `JulesDailyLoop` 09:00 |
| **Cota Jules** | nu e bugetul CI | 100 taskuri/zi, bugetul CD |

---

## 2. Ce ține CI

- **Puntea Local ↔ Cloud** și scriptul `scripts/mavis-sync.ps1`
- **Ingest-ul read-only** din `MAVIS-CLOUD` (`cloud-ingest/`)
- **Canalul `QUEUE/TASKS-FOR-CLOUD.md`** — rămâne canalul Cloud
- **Procedurile Git/GitHub** pentru repo-ul Cloud
- **Guvernanța Git/GitHub** a repo-ului CI
- **Inventarul repo-urilor** de pe mașină

## 3. Ce ține CD

- **Platforma Jules**: `dispatch`, `verify`, `triage`, `adapt`, `daily`,
  `install`, `selfcheck`, `scan-staged`
- **Registrul repo-urilor** pentru Jules, contextul canonic, cardurile de task
- **Politica Live Review** și workflow-urile `jules.yml` / `verify.yml`
- **Verdicturile de triaj** și rapoartele de adaptare
- **Guvernanța Git/GitHub** a repo-ului CD

---

## 4. Punctul de contact

**`MAVIS-CLOUD` e comun, dar nu e al nimănui.**

- CD îl folosește ca **țintă** de lucru pentru Jules (triaj, adaptare).
- CI îl folosește ca **punte** (ingest read-only, cereri de la Cloud).

**CD nu scrie în `MAVIS-CLOUD`.** Regula rămâne: `MAVIS-CLOUD` e **sursă
read-only pentru conținut**, cu excepțiile autorizate explicit.

**Instanța Cloud nu are rol în CD.** Nu triază, nu propune, nu
merge-uiește. Singura ei interacțiune cu CD e canalul `QUEUE/`.

---

## 5. Mișcarea efectivă — măsurată

| | |
|---|---|
| Subfolderul platformei | `Mavis-Optimus-Continuous-Integration\_JULES-Optimus_CI\` → `Mavis-Optimus-Continuous-Development\JULES - Optimus CD\` |
| Ștergeri în arborele CI la mutare | **33** (`git status --porcelain`) |
| Fișiere în folderul CD | **9 810** · **89 729 822 octeți** |
| Modificări de cale necesare în platformă | **2**, ambele reparate (§6) |

---

## 6. Cele două referințe la calea veche, reparate

Amândouă erau defecte latente: **nu se vedeau până când platforma se muta.**

### 6.1 `jules-scan-staged.ps1` — prefix hardcodat

Lista prefixelor platformei era
`_JULES-Optimus_CI/scripts/` și `_JULES-Optimus_CI/config/`.
După mutare, poarta ar fi aplicat regula brand-ului **chiar pe fișierele
care declară regula** — un fals pozitiv produs de o constantă veche.

Reparat: prefixul se **derivează** din numele folderului platformei.

### 6.2 `jules-install.ps1` — cale în mesaj

Mesajul sursei de context scria calea veche în `JULES-CONTEXT.md`, într-un
repo **public**. Reparat: se scrie calea **relativă, derivată**.

### 6.3 Verificarea reparărilor

Nu prin citire — prin rulare:

| Verificare | Rezultat |
|---|---|
| `jules-selfcheck.ps1` din locația CD | `FILES=10 PROBLEMS=0`, **EXIT 0**, 5 probe verzi |
| `jules-scan-staged.ps1 -RepoPath <CD>` | `STAGED=56 SCANNED=56 BLOCKS=0 WARNS=0 SCAN_OK`, **EXIT 0** |
| Scurgerile raportate de poartă | `JULES - Optimus CD/scripts/...` — prefixul derivat, corect |

Platforma e **independentă de cale** prin construcție:
`jules-lib.ps1:12` → `$script:JulesRoot = Split-Path -Parent $PSScriptRoot`.

---

## 7. Regula Triadei, reținută

```
1 conversație  =  1 folder local  =  1 repo GitHub
```

Proiectele nu se ating între ele. Când celălalt are nevoie de ceva, îi
dau un prompt, Popy îl duce în sesiunea respectivă, care are contextul
complet.

**Aceasta e și motivul pentru care nu ating repo-urile altor proiecte:**
nu am contextul lor, și un agent fără context într-un repo străin e exact
defectul pe care îl reparăm.
