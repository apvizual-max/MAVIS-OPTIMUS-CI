---
name: mavis-cloud-git-auto-commit-r0-push
description: Mavis Cloud comiteaza si impinge automat pe main, fara intrebari. R0 = verificare inainte de push. Popieste POPY daca se aduna prea multe commituri.
---

# Git automat · comit → R0 → push

**Nimeni nu întreabă.** Fiecare schimbare se comitează pe `main` și se împinge
automat pe `apvizual-max/MAVIS-CLOUD`. POPY urmărește din sesiune.

## Fluxul, exact

```bash
cd /workspace/Mavis

# 1. starea, ca să știu ce fac
git status --porcelain

# 2. commit pe main — NICIODATĂ ramură, decât POPY cere explicit
git add -A
git commit -m "ce s-a făcut, într-o linie"

# 3. R0 — verificarea ÎNAINTE de push
node --check ALEX-KIT/cv-mutator.js
node --check ALEX-KIT/letter-engine.js
python3 SITE/build-hub.py
python3 -c "import ast,io,glob; [ast.parse(io.open(f,encoding='utf-8').read()) for f in glob.glob('SITE/*.py')]"
git diff --cached --name-only | grep -iE "secret|token|credential" && STOP

# 4. push pe main
git push origin main
```

## R0 — ce înseamnă

**R0 este verificarea care are loc înainte de push.** Nu după. Dacă ceva nu trece,
nu împingi, corectezi, și abia apoi.

| Verificare | De ce |
|---|---|
| `node --check` pe tot JS-ul | a prins o sintaxă stricată după ce am comis |
| build-ul site-ului | site-ul nu trebuie să fie rupt când îl vezi |
| `ast.parse` pe Python | la fel |
| secret în diff | nu comite niciodată tokenuri |

## Regulile dure

1. **`main`, niciodată ramură.** Ramuri doar când POPY spune cuvântul „ramură".
2. **Fără întrebări.** Nu întreb dacă să comit. Comit.
3. **Fără „vrei să vezi?"** — împing și îi arăt starea.
4. **Fără deploy fără cerere explicită.** Un singur deployment:
   `https://da15e9yb994ps.space.minimax.io`. **Niciodată altul.**

## Când îi spun că împing

Nu mai mult de **5 commituri** pe `main` înainte de următoarea ședință, și
**niciodată** după 15 fără push. Îi spun într-un rând, ca să nu uităm.

## Cum îl vede POPY

În sesiune, panoul **Environmental Information** arată:
- **Changes** — fișierele modificate acum
- **Commit or push** — ce am comis
- **Git Graph** — istoricul pe main

De aceea comit și împing **imediat** după fiecare schimbare. Altfel panoul
rămâne gol și POPY nu vede nimic, crede că nu lucrez, și e frustrant.

## Ce NU este fluxul meu

**Nu versiunez prin deployment-uri.** Deploy-ul e un website, nu version control.
Version control e git: commit pe main, push, și istoricul rămâne.

Am făcut exact greșit aceasta: am creat 3 site-uri în loc să fac 1 și să-l
actualizez. **Nu se mai repetă.**