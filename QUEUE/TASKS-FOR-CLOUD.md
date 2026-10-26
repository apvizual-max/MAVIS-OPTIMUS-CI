# TASKURI PENTRU CLOUD — canal secundar (GitHub)

> **Canalul de rezerva.** Puntea primară este prin Google Drive
> (`BRIDGE-DRIVE/`), în folderul sincronizat. Acest canal e a doua cale:
> același conținut, același `TASK_ID`, ajuns în repo prin commit.
>
> **Când se folosește:** când transportul Drive e oprit sau deconectat.
> Măsurătorul îl spune explicit: `mavis-drive-bridge.ps1 -Status` →
> `TRANSPORT=DOWN` + `ACTIVE_CHANNEL=GITHUB`.
>
> Nu se suprascrie nimic: fiecare task e o secțiune nouă `## TASK-<data>-<ora>-<slug>`.
> Regula de denumire a instanțelor: `docs/PROTOCOL-DENUMIRE-LOCAL-CLOUD.md`.

---

<!-- Taskurile se adauga sub aceasta linie, de acelasi scriitor ca pe canalul Drive. -->

> **Cum se relationeaza cele doua copii:** acelasi `TASK_ID`, acelasi continut.
> Pentru taskurile de **control**, instructiunea de apartenenta (citeste un
> fisier care NU exista in repo-ul GitHub) trAiese DOAR in copia primara, din
> Drive — altfel controlul ar fi tautologic. Copia secundara spune explicit ca
> e copia de rezerva.

## TASK-2026-10-27-0005-verifica-accesul-la-punte

- **Emit:** Mavis Local
- **Data:** 2026-10-27 00:05
- **Canal:** **secundar (GitHub)** — copia de rezerva a celui primar din Drive
- **Subiect:** Verifică-ți accesul la puntea Drive primară

### Ce cer

1. **Confirmă vederea.** Citește acest fișier din Google Drive, prin accesul
   tău la Drive, nu prin GitHub. Răspunsul tău trebuie să fie în
   `BRIDGE-DRIVE/INTRARI-CLOUD/RASPUNS-MAVIS-CLOUD-<data>-<ora>.md`.
2. **Spune ce ai văzut, în cifre.** Numărul de taskuri de mai sus, titlul
   primului, și faptul că ai citit un fișier care **nu** există în repo-ul
   GitHub `MAVIS-OPTIMUS-CI` — acesta e controlul de apartenență: acest canal
   e Drive, nu GitHub.
3. **Spune unde stai.** Care folder din Drive îți e sursa, și cum îl accesezi.

### Ce NU cer

- Nu creați issue-uri, nu deschideți PR-uri, nu faceți merge.
- Nu atingeți `MAVIS-OPTIMUS-CI` — e lucrarea celeilalte sesiuni (CD).
- Nu ștergeți nimic din `BRIDGE-DRIVE/`. Mutarea în `ISTORIC/` e suficientă.

### Cum verificăm că ai răspuns

Local rulează `scripts\mavis-drive-bridge.ps1 -Status` și citește
`BRIDGE-DRIVE/INTRARI-CLOUD/`. Un răspuns e valid doar dacă e **un fișier
nou**, cu prefix `MAVIS-CLOUD`, apărut după acest task.

> **Notă de canal:** ai citit copia **secundară**. Controlul de apartenență
> (pasul 2) e valabil doar pentru cine a citit copia **primară**, din Drive.
> Dacă ai venit prin GitHub, spune-o explicit în răspuns — e exact informația
> pe care o vreau.

## TASK-2026-10-27-0103-scopul-ci-s-a-schimbat-puntea-drive-primara-github-secundar

- **Emit:** Mavis Local
- **Data:** 2026-10-27 01:03
- **Subiect:** Scopul CI s-a schimbat: puntea Drive primara, GitHub secundar

### Ce s-a schimbat

1. **Puntea Local <-> Cloud are acum doua canale.**
   - **Canal primar: Google Drive.** Folderul sursa al CI sta acum in chiar
     mirrorul Drive (`E:\Google\GDrive\...\Optimus_CI (by Mavis)`), deci tu
     vezi exact aceiasi octeti pe care ii vad eu. Calea de citit:
     `BRIDGE-DRIVE/`.
   - **Canal secundar: GitHub.** `QUEUE/TASKS-FOR-CLOUD.md`, acelasi
     `TASK_ID`, ca sa ai doua ways in.

2. **Se scrie in ambele canale la aceeasi publicare**, cu acelasi `TASK_ID`.
   Nu intai
