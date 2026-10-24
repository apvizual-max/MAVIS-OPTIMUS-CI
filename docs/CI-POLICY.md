# CI POLICY — puntea, guvernanța Git, și verificarea

> Politica de integrare continuă a **CI**. **Nu se schimbă fără R0.**
>
> **Suprapunere rezolvată:** politica anterioară amesteca Live Review +
> Jules (care sunt **CD**) cu puntea și guvernanța Git (care sunt **CI**).
> Live Review și Jules au plecat în folderul CD, la
> `docs/POLITICA-LIVE-REVIEW-JULES.md` al acestuia. **Un document trăiește
> în folderul sistemului pe care îl guvernează.**

---

## 1. Puntea Local ↔ Cloud

### 1.1 Principiul

**Repo-ul e puntea.** Nu un server, nu un webhook, nu un API. Git are diff,
istoric, rollback, și nu pica.

### 1.2 Singura diferență între cele două părți

| | Mavis Cloud | Mavis Local |
|---|---|---|
| Unde rulez | container MiniMax, volatil | calculatorul lui Popy |
| Văd discul | **nu** | **da** |
| Rulez când laptopul e închis | **da** | nu |
| Rol | cercetare, date, CV-uri, rapoarte | producție, cod, sistem |
| **PUSH** | **automat, fără R0** | **doar cu R0** |

Atât. Cloudul împinge fără să întrebe fiindcă altfel pierde datele la
oprirea containerului. Local nu poate face asta, fiindcă Popy nu vrea nimic
să ajungă pe GitHub fără acordul lui.

### 1.3 Canalul

```
   Mavis Cloud (server MiniMax)        Mavis Local (calculatorul lui Popy)
            |                                      |
            |  git push automat                     |
            |-------------------------------------->|
            |                                      | git pull (MavisSyncBridge 08:30)
            |<--------------------------------------|
            |  git pull                             | commit pe main
   (următorul pas)                                 | push doar cu -Acord
```

**Cerințele** intră în `QUEUE/TASKS-FOR-CLOUD.md` — canalul unic către
Cloud. Cloud livrează în `QUEUE/DONE/` și marchează `[x]`.

### 1.4 Fluxul zilnic

```
1. Local scrie ce vrea în QUEUE/TASKS-FOR-CLOUD.md
2. Local: pull (MavisSyncBridge 08:30), citește
3. Dacă e cerință de date → lasă cererea pentru Cloud
4. Cloud: pull, face cercetarea, scrie datele în repo, push
5. Local: pull, ia datele
6. Popy nu face niciun pas intermediar
```

### 1.5 Starea — măsurată 2026-10-24

`MavisSyncBridge` rulat, `LastTaskResult=0`:
`exit_pull=0`, `local_dupa == remote`, `PAS2_LOCAL|status=curat`,
`impingere=NEEXECUTATA|poarta_R0=ramane_la_Popy`, ieșire 0.

**Puntea e vie și nu împinge.** Detalii: `docs/STARE-MASURATA-CI.md` §1.

### 1.6 Riscurile, tratate

| Risc | Tratament |
|---|---|
| Editare concurentă pe același fișier | `git pull` înainte de orice scriere |
| Conflict de merge | `git pull --abort`, se raportează, **nu se forțează** |
| Un agent moare la mijloc | nimic necomandat nu se pierde; se reia de la ultimul commit |
| Rate limit pe API | quota manager cu backoff exponențial |

---

## 2. Guvernanța Git

| | |
|---|---|
| **COMMIT** | automat, pe `main`, **fără R0** |
| **PUSH** | **singurul** cu R0 |
| **≥50 neîmpinse** | alertă la fiecare răspuns, până dă R0 |
| **Changes** | gol, permanent, peste tot |
| **Instanța Cloud** | singura care împinge fără R0 |

Mecanismul complet, cu măsurătorile: **`docs/GIT-GITHUB-PROCEDURI.md`**.

---

## 3. Workflow-ul de verificare — cele 7 verificări

Moștenit din MAVIS-CLOUD, extins pentru OPTIMUS:

1. **niciun secret în commit**
2. JSON-uri valide
3. sintaxă JavaScript
4. sintaxă Python
5. build-ul proiectului reușește
6. regulile de business (ex: șabloanele nu conțin nume de firmă)
7. **puntea e vie** (mesajul pentru celălalt agent)

Toate în `on: schedule` + `on: workflow_dispatch`. **Niciuna pe push.**

### Regula de ieșire

Dacă un repo nu poate fi măsurat, titlul devine **„MĂSURĂTURĂ
INCOMPLETĂ"** și ieșirea e `2`.

Un senzor mort care raportează sănătate e mai prost decât un senzor care
lipsește.

---

## 4. Ce a plecat în CD — și unde se găsește acum

| Subiect | Unde trăiește acum |
|---|---|
| Platforma Jules (10 scripturi) | folder CD → `JULES - Optimus CD\scripts\` |
| Politica Live Review | folder CD → `docs\POLITICA-LIVE-REVIEW-JULES.md` |
| Trigger-ul `jules.yml` / `verify.yml` | folder CD → `JULES - Optimus CD\workflows\` |
| Registrul repo-urilor pentru Jules | folder CD → `JULES - Optimus CD\config\repos.json` |
| Contextul canonic trimis lui Jules | folder CD → `JULES - Optimus CD\config\jules-context.md` |
| Triajul, adaptările, rapoartele | folder CD → `JULES - Optimus CD\docs\` |

**Regula rămâne:** `MAVIS-CLOUD` e sursă read-only pentru conținut.
Instanța Cloud nu are rol în CD.

---

## 5. Reguli care nu se negociază

- **Merge = push = R0.** Triajul produce verdict, nu merge.
- **Niciodată ștergere definitivă.** Arhivare prin mutare în `docs/arhiva/`.
- **Zero cifre nereproductibile.** Tot ce se raportează e măsurat acum.
- **Un verdict care acuză trebuie să dovedească imputabilitatea.**
- **Instrument lipsă ≠ test picat** → `NO_MEASUREMENT`.
