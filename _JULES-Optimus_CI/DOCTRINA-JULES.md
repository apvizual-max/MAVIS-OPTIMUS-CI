# DOCTRINA JULES — cum judecă Mavis Local propunerile lui Jules

> **Jules propune. Local decide.** Aceasta nu e o preferință, e arhitectura:
> Jules lucrează într-un sandbox Google, fără acces la mașina lui Popy, fără
> acces la `MAVIS-OPTIMUS-CI`, fără memorie între sesiuni. Local are toate
> astea. Deci Local verifică, Local decide.

## 1. Cele patru porți

Niciun pull request nu trece fără să se lovească de toate patru.

| Poartă | Ce verifică | Cine măsoară |
|---|---|---|
| **P1 — Politică** | cai interzise (`node_modules/`, `vendor/`, `dist/`, lockfile-uri), secrete în diff, PR-uri prea late | `Test-DiffPolicy` în `jules-lib.ps1` |
| **P2 — Raport** | cele trei secțiuni obligatorii: *Ce am schimbat / De ce / Cum am verificat*, citite din raportul local de adaptare | `Get-AdaptReportState` în `jules-lib.ps1` |
| **P3 — Verificare fizică** | suita de teste a repo-ului, rulată **aici, acum**, pe codul propus | `jules-verify.ps1` |
| **P4 — Verdict** | ACCEPT / ADAPT / REJECT / UNVERIFIED, cu motiv scris | `jules-triage.ps1` |

## 2. Cele patru verdicte

| Verdict | Când | Ce urmează |
|---|---|---|
| **ACCEPT** | P1 curat, P2 complet, P3 verde | stă la coadă pentru merge cu R0 |
| **ADAPT** | substanța e bună, dar raportul sau forma trebuie refăcută | Local îl corectează și îl adaptază, **nu** îl acceptă ca atare |
| **REJECT** | P1 găsit o încălcare, sau P3 pică **reproductibil** și **nu exista în bază** | Local închide PR-ul cu motiv scris |
| **UNVERIFIED** | nu s-a putut verifica, sau eșecul **nu e imputabil** propunerii | **nu e ACCEPT.** Rămâne în coadă. Zero de la o măsurătoare care n-a măsurat nu e zero |

**Regula imputabilității.** O propunere poate fi blamată doar pentru un
eșec care (a) se reproduce în același arbore și (b) nu există și pe ramura
de bază. Un eșec care nu se reproduce sau care exista înainte este
**măsurat și raportat**, dar **nu închide** propunerea. Măsurat pe
`SENTINEL_PRIME#3`: același SHA, două arbori, rezultate diferite; iar
`test_suite.py` pica la fel și pe `main`.

## 3. Regula cifrelor

Jules raportează cifre. Local le verifică înainte să le creadă.

Proba de referință: Jules a raportat **95,35%** acoperire pentru
`ALEX-KIT/cv-mutator.js`. Local a rulat `c8` și a obținut **95,35%**. abia
atunci PR-ul a fost acceptat pentru merge.

**Regula:** o cifră din raportul lui Jules se verifică cu instrumentul, înainte
de a intra într-un verdict. Dacă instrumentul nu e disponibil, cifra rămâne
*neconfirmată*, iar verdictul reflectă asta.

## 4. Regula cotei

Cota lui Jules: **100 de taskuri pe zi**. Platforma arde cel mult 15
(5 repo-uri × 3 axe). Restul e rezervă.

**Un check care poate eșua în direcția greșită e periculos.** Deci:
- nu ardem cota cu taskuri de nimic — ținta se alege din arborele **real** al
  repo-ului, măsurată, nu aleatorie;
- nu trimitem task dacă repo-ul are deja 3 PR-uri Jules deschise (blocaj);
- nu trimitem task dacă eticheta `jules` lipsește sau secretul nu e acolo
  (altfel ardem cotă degeaba).

## 5. Regula arhivării

Niciun raport nu se șterge. Se mută cu `git mv` în `docs/arhiva/`.

**Atenție — asta a creat un defect real:** `jules.yml` din MAVIS-CLOUD îi
spunea lui Jules să citească `docs/HANDOFF-COMPLET.md`. Fișierul a fost arhivat
în `docs/arhiva/handoffs-vechi/`. Rezultatul: **fiecare task Jules primea
instrucțiunea de a citi un fișier inexistent** — și de aceea Jules „nu știa
regulile proiectului". Nu era o limitare a lui Jules. Era un pointer rupt,
făcut de mine.

**Legea:** orice cale menționată într-un prompt, workflow sau document
trebuie să existe în momentul în care e folosită. Un pointer în arhivă este
un pointer mort.

## 6. Regula contextului

Jules nu are memorie. **Contextul călătorește în corpul issue-ului.**

Acesta este singurul canal prin care Jules primește regulile noastre, și
funcționează fără intervenție umană în interfața Jules. De aceea
`config/jules-context.md` e **sursa unică**: dispatcher-ul îl injectează în
fiecare issue, și `jules-install.ps1` îl copiază în repo ca `JULES-CONTEXT.md`.

## 7. Regula fluxului

```
Local trimite  ->  Jules propune  ->  Local verifică  ->  Popy decide merge-ul
```

Niciun pas nu e sărit. Și niciun pas nu se întoarce cu un „am făcut" care nu
e măsurat.

## 8. Ce nu se negociază

- Merge-ul unui PR pe GitHub e **push** → cere **R0 explicit**.
- Nu se șterge definitiv. Arhivă prin `git mv`.
- Nu se cer parole, tokenuri sau coduri MFA în chat.
- Nu se inventează cifre, și nu se raportează cifre nereproductibile.
- `MAVIS-CLOUD` e sursă read-only pentru conținut; excepții doar cu acord
  explicit.
