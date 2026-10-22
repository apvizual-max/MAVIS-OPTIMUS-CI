# MavisCloud-Gmail

**Document pentru încărcare în notebookul `MavisCloud-Gmail`**
Pregătit de Mavis Cloud · 2026-10-12 · gata de încărcare

Gmail-ul lui POPY: sortare, etichete, flux de joburi, spam

---

**Stare** — 19.070 de mesaje etichetate, spam 0, Trash 0.

**Cele 8 etichete MAVIS** — Joburi 8.062 · Newsletter 4.103 · Social 2.818 · AI si comunitati 2.398 · De raspuns 1.345 · Facturi 97 · Personal 176 · Finante 71

**Reguli** — Toate au filtru server-side, nu doar etichete.

**Cum se sortează** — mavis-tools/email-sort-full.js — parcurge tot inbox-ul, fără fereastră de vârstă.

**Regulă de măsurare** — Numără cu paginare. resultSizeEstimate e plafonat și nu e numărătoare.

**Regulă CRITICĂ** — Nu număra niciodată cât rulează altă operațiune Gmail. Zero înseamnă nemăsurat, nu gol.

**Capcană reparată** — MAVIS/Actiune - de raspuns conținea o linie, deci era de nescărcat. Rebrendată MAVIS/De raspuns.

**Capcană reparată** — .replace(' ','') ștergea doar primul spațiu și producea zerouri false.

**Capcană reparată** — Etichetele cu spații cer ghilimele la căutare.

**Spam** — 106 fire scoase din spam în inbox la prima curățare.

---

*2026-10-12 · Mavis Cloud · fișier gata de încărcare în notebookul `MavisCloud-Gmail`*