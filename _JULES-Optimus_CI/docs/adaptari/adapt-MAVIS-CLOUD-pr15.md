# JULES MAVIS-CLOUD #15

Ramura: `fix-command-injection-build-hub-9066737967641683037` - masurat pe aceasta masina: 2026-10-22 12:09

## Ce am schimbat

- `SITE/build-hub.py` (+14/-12) - import os, json, glob, datetime, subprocess, shutil, shlex

## De ce

**Axa securitate.** `sh()` rula cu `shell=True` pe comenzi construite cu f-string, inclusiv `f'git ls-remote origin refs/heads/{branch}'`. `branch` vine din `repos.json` - un fisier din repo, deci o sursa controlabila. Un branch care contine `;` ar fi fost executat de shell ca o a doua comanda. Fixul trece la lista de argumente, fara shell.

## Cum am verificat

### `node --test ALEX-KIT/cv-mutator.test.js`

- cod de iesire: **0**

```
  ✔ buildAchievements produces exactly 3 achievements (0.3223ms)
  ✔ pickLinks returns valid non-invented links and capped at 4 (0.3608ms)
  ✔ buildHeader builds valid object matching RULES without network dependencies (0.9605ms)
✔ ALEX-KIT/cv-mutator unit tests (18.9375ms)
ℹ tests 10
ℹ suites 1
ℹ pass 10
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 153.1584
```

## Ce NU am facut si de ce

Nu am inlocuit `shell=True` in tot repo-ul, ci doar in `sh()`; apelurile care trimiteau deja liste sunt neatinse. Nu am adaugat un test de regresie pentru injection - ar necesita un harness cu o comanda-cantacare, si nu exista unul in repo.

## Riscuri

`shlex.split` este un splitter **POSIX**: pe Windows mananca backslash-urile dintr-o cale. Astazi toate apelurile trimit liste sau comenzi git fara cai, deci e sigur - dar orice apel viitor cu o cale Windows ca sir va fi stricat. Separat: eliminarea lui `shell=True` schimba modul in care sunt interpretate operatorii si redirectarile din comenzile existente; niciuna n-a fost verificata cu un test.

## Conflict de fisiere cu alte PR-uri deschise

- PR #41 atinge acelasi fisier: `SITE/build-hub.py` - cele doua nu pot fi merge-uite amandoua
- PR #38 atinge acelasi fisier: `SITE/build-hub.py` - cele doua nu pot fi merge-uite amandoua
- PR #34 atinge acelasi fisier: `SITE/build-hub.py` - cele doua nu pot fi merge-uite amandoua
- PR #21 atinge acelasi fisier: `SITE/build-hub.py` - cele doua nu pot fi merge-uite amandoua
- PR #13 atinge acelasi fisier: `SITE/build-hub.py` - cele doua nu pot fi merge-uite amandoua

---

Verdict local: ADAPT - asteapta decizia de merge a lui Popy

