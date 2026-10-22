# JULES MAVIS-CLOUD #16

Ramura: `jules-test-creds-from-env-868258936728205999` - masurat pe aceasta masina: 2026-10-22 12:10

## Ce am schimbat

- `mavis-tools/google-setup.js` (+6/-2) - if (require.main === module) {
- `mavis-tools/tests/google-setup.test.js` (+60/-0) - const { test, describe, beforeEach, afterEach } = require('node:test');

## De ce

`google-setup.js` pornea automat la import (IIFE la nivel de modul), deci **nu putea fi testat deloc**. Wrap-ul `require.main === module` plus exportul lui `credsFromEnv` fac functia accesibila fara a declansa setup-ul la import. Testul acopera toate cele patru combinatii de prezenta/absenta a celor doua variabile, inclusiv sirul vid.

## Cum am verificat

### `node --test ALEX-KIT/cv-mutator.test.js`

- cod de iesire: **0**

```
  ✔ buildAchievements produces exactly 3 achievements (0.2994ms)
  ✔ pickLinks returns valid non-invented links and capped at 4 (0.4149ms)
  ✔ buildHeader builds valid object matching RULES without network dependencies (0.8698ms)
✔ ALEX-KIT/cv-mutator unit tests (17.1903ms)
ℹ tests 10
ℹ suites 1
ℹ pass 10
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 143.0615
```

### `node --test "mavis-tools/tests/google-setup.test.js"`

- cod de iesire: **0**

```
  ✔ returns null when only GOOGLE_CLIENT_SECRET is present (0.8081ms)
  ✔ returns correct object when both vars are present (1.8121ms)
  ✔ returns null when vars are empty strings (1.8909ms)
✔ credsFromEnv (9.0647ms)
ℹ tests 5
ℹ suites 1
ℹ pass 5
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 161.2941
```

## Ce NU am facut si de ce

Nu am extras si celelalte functii din modul - doar `credsFromEnv` este exportat. Nu am testat comportamentul de browser (`openBrowser`).

## Riscuri

**Comportament schimbat la import:** orice cod care facea `require('google-setup.js')` si spera la pornirea automata **nu mai porneste**. Testul inlocuieste `process.env` cu o copie si il restaureaza in `afterEach` - daca un test esueaza intre cele doua, mediul ramane murdar pentru restul suitei.

## Conflict de fisiere cu alte PR-uri deschise

- PR #42 atinge acelasi fisier: `mavis-tools/google-setup.js` - cele doua nu pot fi merge-uite amandoua
- PR #32 atinge acelasi fisier: `mavis-tools/google-setup.js` - cele doua nu pot fi merge-uite amandoua

---

Verdict local: ADAPT - asteapta decizia de merge a lui Popy

