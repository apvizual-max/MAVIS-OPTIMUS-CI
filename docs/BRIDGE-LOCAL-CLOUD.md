# PUNTEA LOCAL ↔ CLOUD

> **Principiul rămâne al lui Cloud, și e corect: repo-ul e puntea.**
> Nu un server, nu un webhook, nu un API. Git are diff, istoric,
> rollback, și nu pica.

**Ce se schimbă:** Cloud a scris puntea ca și cum ambele părți sunt
egale. **Nu sunt.** Local are poartă. Cloud nu.

---

## Diferența, care e singura diferență

| | Mavis Cloud | Mavis Local (eu) |
|---|---|---|
| Unde rulez | container MiniMax, volatil | calculatorul lui Popy |
| Văd discul | **nu** | **da** |
| Edit fișiere | nu pot | da |
| Rulez când laptopul e închis | **da** | nu |
| Rol | cercetare, date, CV-uri, rapoarte | producție, cod, sistem |
| **PUSH** | **automat, fără R0** | **doar cu R0** |

**Atât.** Cloudul împinge fără să întrebe fiindcă altfel pierde datele la
oprirea containerului. Eu nu pot face asta, fiindcă Popy nu vrea nimic să
ajungă pe GitHub fără acordul lui.

> **ATENȚIE la `docs/BRIDGE.md` din repo-ul Cloud.** Tabelul „Autonomia
> maximă" scrie „orice push — fără aprobare". **Acolo e fals pentru
> Local.** Nu îl copiem. Vezi `CONFLICTE-DOZTRINA.md` C5.

---

## Canalul

```
   Mavis Cloud (server MiniMax)        Mavis Local (calculatorul lui Popy)
            │                                      │
            │  git push automat                     │
            ├──────────────────────────────────────►│
            │                                      │ git pull
            │◄──────────────────────────────────────┤
            │  git pull                             │ commit pe main
   (următorul pas)                                 │ push doar cu -Acord
```

**Cerințele** intră în `docs/INTENTII.md` — acolo le scrie Popy cu
cuvintele lui, fără jargon.

---

## Comanda unică, pentru orice agent fără memorie

```
git clone https://github.com/apvizual-max/MAVIS-OPTIMUS-CI
cd MAVIS-OPTIMUS-CI
cat README.md DOCTRINA-CI.md docs/CONFLICTE-DOZTRINA.md
```

**Trei fișiere. Știi tot.**

---

## Fluxul zilnic

```
1. Popy scrie ce vrea în INTENTII.md
2. Local: pull, citește
3. Dacă e cerință de date → lasă cererea pentru Cloud
4. Cloud: pull, face cercetarea, scrie datele în repo, push
5. Local: pull, ia datele
6. Popy nu face niciun pas intermediar
```

---

## De ce nu construiesc `mavis-sync.sh` ca l-a scris Cloud

Cloud propune:

```bash
while true; do
  git pull origin main
  git add -A && git commit -m "..." 2>/dev/null
  git push origin main 2>/dev/null     # ← AICI
  sleep 300
done
```

**Acest push ocolește poarta R0.** E exact accidentul care a trimis 12
comituri pe GitHub fără acord.

**Puntea merge prin poarta existentă**, nu prin `git push` direct:

```powershell
scripts\git-autopush.ps1 -Acord        # singura cale de push pe Local
```

Comportamentul dorit — „pornește o dată, merge singur" — se obține prin
faptul că **eu** sunt permanent prezent în această conversație. Nu printr-o
să fie nevoie să dorm. **Procesul care rulează sunt eu, nu un script.**

---

## Riscurile, tratate

| Risc | Tratament |
|---|---|
| Editare concurentă pe același fișier | `git pull` înainte de orice scriere |
| Conflict de merge | `git pull --abort`, se raportează, **nu se forțează** |
| Un agent moare la mijloc | nimic necomandat nu se pierde; se reia de la ultimul commit |
| P0 ipriște datele | commit pe `main` la fiecare pas; nimic stă necomitat |
| Rate limit pe API | quota manager cu backoff exponențial |

---

## Testul punții — 2 minute

```
1. Cloud scrie docs/TEST-PUNTE.txt, face push   → eu: git pull, verific
2. Eu scriu înapoi în același fișier            → Cloud: git pull, verific
3. Rezultatul se vede în acest folder
```

**Dacă pasul 2 dă conflict: NU forța.** Se scrie în `INTENTII.md` și se
oprește.

---

**Stare curentă:** puntea e **specificată, neimplementată**. Cloud a
recunoscut-o în raportul lui. O construiesc la Pasul 4 al planului, după
ce infrastructura de poartă e rezolvată — pentru că o punte construită
peste o poartă care nu există e o scurgere, nu o punte.