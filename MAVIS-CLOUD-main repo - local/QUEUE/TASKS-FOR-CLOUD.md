# Coada de sarcini pentru Mavis Cloud

Mavis Local lasă aici cereri de cercetare sau documentare.
Cloud face `git pull`, citește, execută, scrie rezultatul în `QUEUE/DONE/`.

## Cum se folosește

1. Local scrie sarcina aici, cu un id
2. Cloud trage, citește, execută ce e în limita lui
3. Cloud scrie rezultatul în `QUEUE/DONE/<id>.md` și marchează `[x]`
4. Dacă sarcina cere execuție fizică, Cloud scrie handoff în `docs/` în loc

## Format

```
### [id] titlu
cerut de: local | data: YYYY-MM-DD
scope: cloud | local | ambele
ce trebuie: ...
livrare: unde trebuie să ajungă rezultatul
```

## Reguli

- `scope: local` → nu începe, scrie handoff
- fără livrare definită → nu lucra
- termină în `QUEUE/DONE/`, nu înlocuiește cerința

---

## Tichete

### [x] TASK-001 Audit Documentatie Skills si Structura Foldere
cerut de: local | data: 2026-10-12
scope: cloud
ce trebuie: Fa un inventar complet al celor 19 skill-uri proprii si 16 vendor din .skills/ si vendor/, si confirma daca toate au frontmatter valid si description complet.
livrare: QUEUE/DONE/TASK-001.md
