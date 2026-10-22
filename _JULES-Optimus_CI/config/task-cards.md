# CARDURI DE TASK — ce i se cere lui Jules, pe axe

> Dispatcher-ul (`jules-dispatch.ps1`) alege **cardul** după axă și injectează
> **contextul canonic** (`config/jules-context.md`) în body-ul issue-ului.
>
> Regula: task-urile sunt **la nivel de sistem**, nu la nivel de virgulă.
> Un task bun schimbă un modul, o arhitectură, o performanță măsurabilă sau
> o vulnerabilitate reală. Nu „reformatează acest fișier".

## Reguli comune pentru orice card

- **O singură schimbare semnificativă** per PR.
- **Testul care pica înainte** e obligatoriu.
- **Cifre măsurate**: rulează instrumentul, raportează ieșirea cu cod de ieșire.
- **Raport în formatul din context** (secțiunea 6).
- **Dacă verificarea pică**, livrează ce ai și spune-o. Nu inventa trecerea.
- **Nu atinge** fișiere din `vendor/`, `node_modules/`, `dist/`, `docs/arhiva/`.
- **Nu inventa** conținut de business (CV-uri, clienți, prețuri, contacte).

<!-- AXIS:performance -->
### Card: performanta

**Tintita:** `{TARGET}` din `{REPO}` (ramura `{BRANCH}`).

**Ce ceri:**

1. Citește fișierul și înțelege ce face **la nivel de sistem**, nu linie cu
   linie. Identifică **calea caldă** (hot path): funcția sau bucla care se
   execută cel mai des, nu cea mai lungă.
2. Construiește mai întâi o **măsurătoare** — un benchmark sau un test care
   măsoară timpul / numărul de operații înainte de schimbare. Fără
   măsurătoare, nu atingi codul.
3. Aplică **o singură** optimizare, care să schimbe măsurătorul.
4. Lasă măsurătoarea în repo, ca test, ca să poată fi rulată din nou.

**Criterii de acceptare:**

- `măsurătoare_înainte` și `măsurătoare_după` — ambele raportate, cu comanda
  exactă și codul de ieșire.
- Testul rulează înainte de schimbare și **pică** pe codul vechi.
- Nicio schimbare de comportament: aceleași rezultate, alt cost.
- Diff-ul explică în 3 rânduri de ce varianta veche era lentă.

**Ce NU ceri:** micro-optimizări, renumerotări, rescrieri de stil, biblioteci
noi fără măsurător.
<!-- AXIS:design -->
### Card: design

**Tintita:** `{TARGET}` din `{REPO}` (ramura `{BRANCH}`).

**Ce ceri:**

1. Citește fișierul și identifică **decizia de design** pe care o ia — ierarhia
   vizuală, consistența, contractul de date, structura informației.
2. Judecă **consistența cu restul repo-ului**, nu cu un gust personal.
   Citește 2-3 fișiere vecine și verifică: aceleași convenții? aceleași
   nume? același nivel de detaliu?
3. Propune **o singură schimbare de design** care face structura mai
   consistentă sau mai ușoară de înțeles.
4. Dacă schimbarea e de înțeles, **noteaz-o în cod** cu un comentariu scurt
   care spune *de ce*, nu *ce*.

**Criterii de acceptare:**

- Justificarea compară explicit cu 2-3 fișiere din același repo.
- Testele existente încă trec (dacă există).
- Nicio schimbare de comportament vizibil fără un motiv explicit în raport.
- Dacă `design` înseamnă *aspect vizual*, PR-ul conține și o descriere
  scrisă a rezultatului, pentru că nu poți atașa imagini.

**Ce NU ceri:** redesign complet, schimbare de bibliotecă de UI, rescris
integral de componentă fără motiv măsurat.
<!-- AXIS:security -->
### Card: security

**Tintita:** `{TARGET}` din `{REPO}` (ramura `{BRANCH}`).

**Ce ceri:**

1. Citește fișierul și caută **de ce ar putea fi un pericol**: secret
   expus, injection, path traversal, permisiune prea largă, dependență
   nesigură, log care scrie date sensibile, race condition.
2. Verifică **dacă e o problemă reală**, nu un clișeu. Dacă nu e, spune
   clar „nu am găsit o vulnerabilitate aici" și **nu deschide PR**. Un raport
   negativ corect e un rezultat bun.
3. Dacă e reală, repară **o singură** vulnerabilitate și adaugă un **test de
   regresie** care o prinde.
4. Verifică că nu e în fișierele de secrete, și nu atinge `client.json`.

**Criterii de acceptare:**

- Vulnerabilitatea e descrisă cu un **vector concret** de atac, nu generic.
- Testul de regresie pică pe codul vechi.
- Niciun secret nou în diff. Niciun token, nicio cheie, niciun `.env`.
- Raportul spune și **ce NU ai verificat**.

**Ce NU ceri:** scanare de dependențe fără fix, "hardening" speculativ,
rescrieri de securitate care schimbă comportamentul fără un atac demonstrat.
