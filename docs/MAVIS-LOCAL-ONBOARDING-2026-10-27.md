# MAVIS-LOCAL — ONBOARDING Optimus CI (2026-10-27)

> Document scris de **Mavis Local**, pentru orice agent care vine nou în
> acest proiect și nu are memorie între sesiuni.
> Tot ce e mai jos e **măsurat**, nu povestit. Cifrele au metoda lor.

---

## 1. Ce e, în trei rânduri

`Optimus CI` e **puntea** dintre două instanțe de Mavis:

| | Cine | Unde rulează | Ce deține |
|---|---|---|---|
| **Local** | această sesiune | mașina lui Popy, `E:` | proiectul, puntea, coada, porțile |
| **Cloud** | instanța Mavis Cloud | Google Drive + GitHub | contractul, execuția, rezultatele |

Cele două **nu se ating niciodată direct**. Ele comunică prin două canale,
unul la rând cu celălalt, și **cloud-ingest/ e read-only pentru Local** —
cu două excepții declarate, ambele aditive: adăugarea de fișiere
`MAVIS-LOCAL-*` și scrierea tichetei în contractul consumatorului.

**Regula Triadei:** `1 conversație = 1 folder local = 1 repo GitHub`.
Fiecare proiect are contextul lui. Un agent fără context într-un repo străin
e exact defectul pe care îl repară aici.

---

## 2. Topologia fizică (măsurată 2026-10-27)

```
E:\Google\GDrive\                                  ← RĂDĂCINA MIRRORULUI DriveFS
└── GDrive-Second_Brain_PKMS\02_Areas\02-2-AI-SOT\CASA\OPTIMUS - Prime\
    └── Optimus_CI (by Mavis)\                     ← PROIECTUL (mirror)
        ├── .git                                   ← FIȘIER pointer → E:\Google\GitData-Optimus-CI\repo
        ├── BRIDGE-DRIVE\                          ← canalul PRIMAR (Google Drive)
        ├── QUEUE\                                 ← canalul SECUNDAR (GitHub)
        ├── scripts\                              ← instrumentele + cele 7 porți
        ├── tools\google-access\                   ← sursa reconstruibilă a containerului
        ├── docs\                                 ← documentația
        ├── cloud-ingest\                          ← clonele (gitignored!)
        │   ├── MAVIS-CLOUD\.git                   ← pointer → E:\Google\GitData-Optimus-CI\clone-MAVIS-CLOUD
        │   └── MAVIS-OPTIMUS-CI\.git              ← pointer → E:\Google\GitData-Optimus-CI\clone-MAVIS-OPTIMUS-CI
        └── state\                                ← măsurători (gitignored)

E:\Google\                                        ← ÎN AFARA mirrorului
├── GitData-Optimus-CI\               ← SINGURUL folder: tot ce e git, al acestui proiect
│   ├── repo\                        gitdir-ul acestui repo (MAVIS-OPTIMUS-CI)
│   ├── clone-MAVIS-CLOUD\            gitdir-ul clonei Cloud
│   ├── clone-MAVIS-OPTIMUS-CI\       gitdir-ul clonei CI
│   └── scratch\                      ← laboratorul porților: fixture-uri git
├── GitData-Optimus-CD\               gitdir-ul CD (proiect separat)
└── GitData-PKMS\                     gitdir-ul vaultului (proiect separat)
```

### De ce gitdata stă în afara mirrorului

Google Drive for Desktop (DriveFS) **administrează spațiul** din
`E:\Google\GDrive\` cât timp sincronizează: materializează, înlocuiește sau
șterge fișiere. Un `.git\` e un fișier viu — `index`, `refs`, `objects`,
`HEAD`. DriveFS nu știe că e un repository; pentru el sunt fișiere oarecare.

Deci: **tot ce înseamnă date git local stă în afara mirrorului**, într-un
**singur folder** pe proiect: `E:\Google\GitData-Optimus-CI\`. În arborele
proiectului, `.git` e **un fișier** de 38–43 de octeți care spune
`gitdir: E:/Google/GitData-Optimus-CI/<subfolder>`.

> **Măsurat înainte/după (2026-10-27):** în arborele CI erau **63 de
> directorii `.git`** în plus față de cele ale proiectelor — toate erau
> fixture-uri de test. După mutare: **0**. Celelalte 32 care au rămas în
> mirror sunt în proiecte **surori** (CD: 21, `AI_Tools`: 8 clonelor
> vendor, Plugins-Config: 2, PKMS: 1) — **în afara frontierei acestui
> proiect**, deci neatinse.
>
> **Consolidare (2026-10-27, 11:40).** Gitdata acestui proiect a fost
> adusă într-**un singur folder**, `E:\Google\GitData-Optimus-CI\`, cu patru
> subfoldere: `repo\`, `clone-MAVIS-CLOUD\`, `clone-MAVIS-OPTIMUS-CI\`,
> `scratch\`. CD și PKMS au rămas în folderele lor — sunt **alte proiecte**
> (1 proiect = 1 folder), nu bucăți din acesta.

---

## 3. Cele două canale

### Canalul primar — Google Drive

| Fișier | Scrie | Citește |
|---|---|---|
| `BRIDGE-DRIVE\TASKURI-PENTRU-CLOUD.md` | Local | Cloud |
| `BRIDGE-DRIVE\INTENTII.md` | Popy (text liber) | Cloud |
| `BRIDGE-DRIVE\INTRARI-CLOUD\` | Cloud | Local |
| `BRIDGE-DRIVE\ISTORIC\` | Local (**mută**, nu șterge) | — |

Instrumentul: `scripts\mavis-drive-bridge.ps1 -Publish -Title "<subiect>" -Body "<text>"`.
Scrie **două fișiere în aceeași operație**: blocul în `TASKURI-PENTRU-CLOUD.md`
și **aceeași tichetă, în contractul consumatorului**, în `QUEUE\TASKS-FOR-CLOUD.md`.

**„Publicat" înseamnă măsurat.** Scriptul scrie, apoi măsoară în indicele
DriveFS și raportează: `SYNCED` · `PENDING` · `NOT_UPLOADED` · `UNVERIFIED`.
> `UNVERIFIED` **nu** e succes.

Măsurat: latența propagării Drive ≈ **80 min**. Acceptabil pentru un
handoff, inacceptabil ca singur canal.

### Canalul secundar — GitHub

Ticheta reală stă în repo-ul **Cloud-ului**:
`cloud-ingest\MAVIS-CLOUD\QUEUE\TASKS-FOR-CLOUD.md`.

Ciclul: `scripts\queue-deliver.ps1 -Deliver [-Push]` →
sync (`--ff-only` / `merge --no-ff`, ambele istorice păstrate) → construiește
blocul în contract → **round-trip prin același parser** → scanare secrete →
commit → push → verificare prin `ls-remote` **și** prin conținutul cozii la remote.

Cloud-ul citește din **repo-ul lui**, scrie rezultatul în `QUEUE/DONE/<id>.md`,
marchează `[x]`, apoi **mută** cu `git mv` în `docs/arhiva/handoffs-vechi/`.

### Contractul cozii (citit de pe discul Cloud-ului, nu din copie)

```
### [id] titlu
cerut de: local | data: YYYY-MM-DD
scope: cloud | local | ambele
ce trebuie: ...
livrare: unde trebuie să ajungă rezultatul
```

> **Ticheta fără `scope: cloud` nu e executată.** Nu e „executată mai târziu" —
> nu e executată deloc. O coadă plină de tichete fără `scope` e o coadă goală.

Regulile consumatorului: `scope: local` → nu începe, scrie handoff ·
fără livrare definită → nu lucra · termină în `QUEUE/DONE/`, nu înlocuiește
cerința.

`TASK_ID` e **cheia de urmărire** comună celor două canale, nu o convenție
de nume.

---

## 4. Cele șapte porți

Toate au fost rulate după mutarea datelor git, toate au dat **exit 0**:

| Poartă | Ce măsoară | Ce a măsurat |
|---|---|---|
| `scan-staged-secrets-selfcheck.ps1` | scannerul de secrete | `SECRET_PROBLEMS=0 UNKNOWN=0` |
| `merge-check-selfcheck.ps1` | `merge-check.ps1` | `MERGE_GATE_PROBLEMS=0 FALSIFIED=5` |
| `publish-ci-selfcheck.ps1` | `publish-ci.ps1` | `PUBLISH_GATE_PROBLEMS=0 FALSIFIED=13` |
| `queue-contract-check-selfcheck.ps1` | contractul cozii | `QUEUE_GATE_PROBLEMS=0 FALSIFIED=14` |
| `queue-deliver-selfcheck.ps1` | livrarea cozii | `DELIVER_GATE_PROBLEMS=0 FALSIFIED=15` |
| `mavis-drive-bridge-selfcheck.ps1` | puntea Drive | `BRIDGE_PROBLEMS=0 UNKNOWN=0` |
| `mavis-sync-selfcheck.ps1` | puntea zilnică + poarta ei | `SYNC_PROBLEMS=0 FALSIFIED=4` |

> **O măsurătoare care nu poate eșua nu e o măsurătoare.** Fiecare poartă
> e falsificată în ambele sensuri: ceea ce trebuie blocat e blocat, ceea ce
> e inocent trece.

### Exit codes (contractul porților)

| Cod | `queue-deliver.ps1` | `queue-contract-check.ps1` | `mavis-drive-bridge.ps1` | `scan-staged-secrets.ps1` |
|---|---|---|---|---|
| `0` | măsurat și adevărat | măsurat și adevărat | măsurat și sănătos | `BLOCKS=0` |
| `1` | N tichete **nu** sunt în coada Cloud-ului | o tichetă rupe contractul | — | cel puțin un `BLOCK` |
| `2` | **refuzat / nemăsurabil** — nimic publicat | măsurătoare incompletă | input lipsă | scannerul nu a putut citi index-ul |
| `3` | — | — | ținta nu e în Drive | — |
| `4` | scris, **nepublicat** | — | scris, neconfirmat | — |
| `5` | push **refuzat** de remote | — | transportul Drive e jos | — |

---

## 5. Laboratorul porților (nou, 2026-10-27)

Fixture-urile porților sunt repository-uri git proprii (un bare remote, o
clonă, o copie de conflict). Înainte stăteau în `state\tmp\`, adică **în
mirror**. Mutarea lor în afara mirrorului e o **singură decizie**, nu șase
edite riscante:

```powershell
# scripts\git-scratch.ps1
Get-GitScratchRoot -ProjectRoot <proiect>   # → E:\Google\GitData-Optimus-CI\scratch
```

Radicalul se **derivează din gitdir-ul repo-ului propriu** (care stă în afara
mirrorului), deci laboratorul urmează repository-ul în loc să hard-codeze o
cale de mașină. Se poate suprascrie cu `MAVIS_CI_SCRATCH`.

`Assert-ScratchOutsideMirror` **refuză explicit** un radical care cade în
mirror — pentru că un radical greșit nu trebuie să treacă în tăcere.

> **Lecție generalizabilă:** când mutați date git în afara unui arbore
> sincronizat, mutați și **fixture-urile**. Un test care construiește
> repository-uri într-un arbore pe care un agent extern îl administrează
> măsoară pe un teren care se mișcă sub el.

---

## 6. Regulile care leagă (pe scurt, cu sursa)

| Acțiune | R0? | Cine |
|---|---|---|
| `git add` | nu | agentul |
| `git commit` pe `main` | **nu — automat, mereu, fără întrebare** | agentul |
| `git push` spre GitHub | **DA — singurul lucru care cere R0** | agentul, după R0-ul lui Popy |
| merge de pull request | **DA** | agentul |
| ramură nouă / fork | doar la cerere explicită, ca GOAL + CRITERIA | Popy cere |
| `reset --hard` · `clean -fdx` · force-push · ștergere definitivă | **interzise** | — |

- **Poarta trăiește în hook, nu într-un switch de script.** `core.hooksPath`
  e **local, per repo** — niciodată global (un global a stricat ~70 repo-uri).
- **Martorul de push** e `$(git rev-parse --git-dir)/PUSH-ACORD` — deci
  **migrează odată cu gitdir-ul**. Un acord = o împingere. Martorul se consumă.
- **Un cod de ieșire citit greșit e un fals verdict.** Verificarea de push
  se face cu `git ls-remote`, nu cu exit code-ul.
- **`git ls-remote`, nu codul de ieșire.**
- **Dacă o poartă blochează comiturile, defectul e poarta, nu comitul.**

Detalii: `docs\GIT-GITHUB-PROCEDURI.md`.

---

## 7. Google Access — starea măsurată

| Ce | Valoare |
|---|---|
| Container | `Google_Access`, imagine `google-access:1.0.4`, healthy, `--restart unless-stopped` |
| Endpoint | `http://127.0.0.1:8766/mcp` (doar loopback) |
| Grant | **LIVE**, `reauth_required: false` |
| Scope granted | **28** |
| Unelte | **26** |
| Secret | **niciunul în imagine** — refresh token în volumul montat `/data` |
| Sursă vie ≡ container | `server.mjs` sha256 `bd09f1df…` — **identic** |

Sursa vie e în `C:\Users\apviz\.minimax\google-access\`, oglindă în
`tools\google-access\`. Resincronizarea e **un instrument**, nu o copie
manuală:

```powershell
python "<CI>\tools\google-access\sync-source.py"
```

Instrumentul copiază o listă albă, verifică SHA256, scanează destinația de
secrete **și** compară `server.mjs` cu cel din containerul care rulează.
Ultima comparație e cea care contează: o sursă editată după build-ul
imaginii înseamnă că repo-ul nu mai descrie sistemul care rulează.

> **Doar două scope-uri rămân inaccesibile**, și nu pentru că nu au fost
> cerute: `sites` (API-ul nu mai există) și `keep` (Google nu publică scope
> acordabil). Măsurat: acele două **invalidau întreaga cerere**, deci cele
> 28 valide nu treceau. Au fost scoase din `FULL_SCOPES`, cu motivul scris în
> sursă.

Skillul: `mavis-google-access-skill` (în `~/.minimax/agents/mavis/skills/`).

---

## 8. Skillurile

| Skill | Rol | Unde |
|---|---|---|
| `mavis-optimus-continuous-integration-skill` | **scopul acestui proiect** | `~/.minimax/agents/mavis/skills/` |
| `mavis-google-access-skill` | accesul Google permanent | idem |
| `mavis-git-autonom-skill` | lucru zilnic cu Git | idem |
| `mavis-git-install-skill` | ridicarea unui repo nou | idem |
| `mavis-autonomous-operator-skill` | **se încarcă primul** | idem |

La nivel general, `mavis` are **76 de skilluri**. La nivel de proiect, sursa
canonică e `tools\google-access\`.

---

## 9. Ce NU e în frontiera acestui proiect

- **`Optimus_CD (by Jules)`** — proiect paralel, cu repo și buget proprii.
  CD nu scrie în `MAVIS-CLOUD`; CI nu rulează triajul. **Nu ne atingem.**
- **`PKMS (by Antigravity)`** — vaultul, alt repo, altă porțiune.
- **`AI_Tools\*`** — clone vendor (ComfyUI, qwen-system, wayland, agent-zero…).
  Nu se atinge: nu sunt ale lui Popy.
- **Orice repo care nu e al lui Popy** — nici măsurătoare scriind în el, nici
  hook, nici config.

---

## 10. Dacă vii din sesiunea „Google_Access"

Sesiunea sursă: `mvs_dad1539226c34024bbba6dfae62a616e` („Mavis - Google_Access").
A murit pe un `500` de provider **după** ce grantul se obținuse — deci
lucrarea ei e făcută, dar raportul nu s-a scris. Ce s-a întâmplat, măsurat:

1. **Consimțământul.** Popy a apăsat Allow; `consent-result.json` a consemnat
   `TOKEN_ENDPOINT_HTTP=200`, `REFRESH_PROBE_HTTP=200`, `PERMANENT=1`,
   **28 scope-uri**, `probe_verdict: PASS`.
2. **Defectul care bloca:** `keep` + `sites` în `FULL_SCOPES` invalidau
   întreaga cerere (`invalid_scope`). Scoase.
3. **API-uri activate:** `books.googleapis.com` și `chat.googleapis.com`
   lipseau din proiect; activate.
4. **Rebuild:** imaginea a mers `1.0.0 → 1.0.4`; containerul recreat de
   două ori; instrumentele au urcat 25 → 26.

**Atenție:** sesiunea sursă a continuat să lucreze după ultimul ei mesaj
(noi fișiere la 10:42, rebuild la 10:42). Înainte de a rescrie ceva în
`C:\Users\apviz\.minimax\google-access\`, **măsoară** — și folosește
`sync-source.py`, nu o copie manuală.

---

## 11. Unde se uită mai întâi

| Întrebare | Fișier |
|---|---|
| Unde stă tot? | `MAPARE-SISTEM.md` |
| Ce face fiecare folder? | `docs\MAPARE-FOLDERE.md` |
| Cum se lucrează? | `DOCTRINA-CI.md`, `docs\WORKFLOWS.md` |
| De ce așa? (7 conflicte + hotărâri) | `docs\CONFLICTE-DOZTRINA.md` |
| Cum se face Git/GitHub? | `docs\GIT-GITHUB-PROCEDURI.md` |
| Ce spune contractul? | `docs\CONTRACT-CLOUD-QUEUE.md` |
| Starea măsurată de azi | `docs\STARE-MASURATA-CI-2026-10-27.md` |
| Repo-urile lui Popy | `docs\INVENTAR-REPO-URI.md` |
| Ce se știe despre remote | `docs\STARE-MAVIS-OPTIMUS-CI-REMOTE.md` |

---

*Scris de Mavis Local · 2026-10-27 · măsurat, nu povestit · SLG = 100%*
