# PUNTEA DRIVE — specificația completă

> **Aditiv.** Nu rescrie nimic existent. Completează `docs/CI-POLICY.md`
> §1 și `docs/BRIDGE-LOCAL-CLOUD.md`.
>
> Măsurat: **2026-10-27**. Metodă: `gh api`, baza de metadate DriveFS,
> logurile DriveFS, rularea scripturilor.

---

## 1. De ce s-a schimbat

| | Până acum | De acum |
|---|---|---|
| Canal primar | repo-ul `MAVIS-CLOUD` pe GitHub | **folder Google Drive** |
| Canal secundar | — | repo-ul, prin `QUEUE/TASKS-FOR-CLOUD.md` |
| De ce | Git e bun la istoric, diff, rollback | **ambele instance au acces la Drive**; Cloud-ul îl are deja |
| Ce pierde canalul Drive | — | **instantaneitatea** (≈ 80 min, măsurat) |

Regula lui Popy, 2026-10-27: *„You don't need to — you can both connect to
the Drive. If you work locally, Google Drive app will automatically sync
everything to Drive."* **Verificat și corectat unde trebuie**: automat
înseamnă *eventual*, nu *instant*. Diferența e măsurată mai jos.

---

## 2. Topologia, măsurată

```
Drive (server)
   │  contul Google al lui Popy, id 100488352004104984848
   ▼
E:\Google\GDrive\                 ← mirrorul (rădăcină: Google\GDrive, root_id=23, MIRROR)
   └── GDrive-Second_Brain_PKMS\02_Areas\02-2-AI-SOT\CASA\OPTIMUS - Prime\
       └── Optimus_CI (by Mavis)   ← folderul CI, cloud_id 1V87h9Pbw52chSVNkxQ_NNuMh-CLfZeuI
              ├── BRIDGE-DRIVE\   ← PUNTEA
              ├── QUEUE\          ← canal secundar (GitHub)
              └── docs\, scripts\ ← SOT-ul CI
```

**Joncțiune pentru acces rapid:**
`C:\Users\apviz\.minimax-agent\projects\Optimus_CI (by Mavis)` → sursa de
pe `E:`. **Nu e o copie** — e aceiași octeți. Editarea se face oriunde.

**Corectare a topologiei documentate:** `G:` **nu** e un mount virtual Google
Drive. E un volum fix, iar `G:\My Drive.lnk` e o scurtătură cu ținta
`E:\Google\GDrive`. Mirrorul real e pe `E:`.

**Date git:** `.git` e un **fișier** (worktree link) →
`gitdir: E:/Google/GitData-Optimus-CI`. Istoricul nu stă în folderul
sincronizat, ci pe `E:`, în afara mirrorului.

---

## 3. Ce se măsoară, și cu ce

| Întrebare | Instrument | Sursa de adevăr |
|---|---|---|
| Folderul există în Drive? | `drivefs_probe.py --title <nume>` | `items` din `metadata_sqlite_db` |
| Fișierul a ajuns în Drive? | `drivefs_probe.py --title <nume>` | id cloud + lanț de părinți |
| Rădăcina mirrorului e conectată? | `drivefs_probe.py --root-state` | `drive_fs.txt`, `ReceiveMirrorRoots` |
| Cât a durat propagarea? | `--newest <folder>` vs mtime local | `modified` din indice |
| Coada de upload | `--pending` | `operations` |

**De ce nu prin API-ul Drive?** Pentru că ruta de API e ** ruptă** pe această
mașină, măsurat:

| Rută | Rezultat |
|---|---|
| `gdrive-mcp` (namespace minimax) | `invalid_grant` la `files.list` — tokenul de reîmprospătare e revocat |
| `verify-drive.js` (același token) | `userinfo failed: invalid_grant`, `DRIVE v3 files.list FAILED`, **EXIT 2** |
| `gcloud` ADC | `authorized_user`, dar Drive API → **HTTP 403** (nu are scope de Drive) |

Reînnoirea tokenului cere **consimțământul lui Popy în browser** — e un act
ACCESS, nu o decizie tehnică. Până atunci, **baza locală a DriveFS e sursa de
adevăr**, și funcționează: `metadata_sqlite_db` (422 932 480 B) se citește
read-only; `mirror_metadata_sqlite_db` (2 278 027 264 B) e blocată de
DriveFS și **nu** e accesibilă.

---

## 4. Latentța, măsurată

| Scriere locală | Apariție în Drive | Lag |
|---|---|---|
| `README_SYSTEM_TOPOLOGY_AND_AGENT_GUIDELINES.md`, 2026-10-26 **22:11** | 2026-10-26 **23:31** | **≈ 80 min** |

**De ce atât?** DriveFS s-a repornit la **22:43** pe 26 octombrie (dovadă în
`drive_fs.txt`), în mijlocul propagării. O coadă de încărcare după un
restart explică cea mai mare parte a lag-ului. **Lag-ul în regim normal nu
e măsurat** — și nu e presupus nici el.

Consecință de proiectare: **cerințele care cer răspuns imediat nu merg pe
Drive.** Ele merg pe canalul secundar (GitHub), care are R0 la push.

---

## 5. Regulile de funcționare

1. **Un task, două canale, același `TASK_ID`.** Scris simultan. Nu „dacă
   primul cade, atunci scriu în al doilea" — pentru că atunci pierzi timp
   exact când transportul e bolnav.
2. **Publicat = măsurat.** Scriptul verifică în indice și raportează
   `SYNCED` / `PENDING` / `NOT_UPLOADED` / `UNVERIFIED`. `UNVERIFIED` **nu**
   e succes.
3. **Nu se suprascrie nimic.** Corecția = fișier nou.
4. **Nu se șterge nimic.** Se mută în `ISTORIC/`.
5. **Zero secrete în punte.** Se scanază index-ul înainte de commit, ca
   peste tot.

---

## 6. Granța R0

| Operație | Cere R0? | De ce |
|---|---|---|
| Scriere în `BRIDGE-DRIVE/` | **nu** | e fișier local, se sincronizează |
| Scriere în `QUEUE/TASKS-FOR-CLOUD.md` | **nu** | idem |
| Commit local pe `main` | **nu** | regula permanentă |
| **Push spre GitHub** | **da** | singura operație externă |
| Re-autentificarea DriveFS | **nu** (tehnic), dar **necesită Popy** | poate cere re-login |

---

## 7. Ce rămâne de făcut, măsurat

| # | Ce | De ce nu l-am făcut eu |
|---|---|---|
| 1 | Re-consent pentru tokenul Drive (`gdrive-oauth.js`) | cere browserul lui Popy — ACCESS |
| 2 | Verificarea DriveFS: rădăcina mirrorului e `connected=true` la startup, dar propagarea nu e confirmată pentru fișierele noi | DriveFS e procesul lui; un restart e decizie pe mașina lui |
| 3 | Re-măsurarea lag-ului în regim normal | nevoie de o propagare completă, ~1h+ |
| 4 | Push-ul celor 12 commituri locale în `MAVIS-OPTIMUS-CI` | **R0**, și remote-ul a avansat între timp |

---

*2026-10-27 · Mavis Local · aditiv · măsurat*
