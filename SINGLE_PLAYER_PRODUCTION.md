# Single-player produzione

La modalità `classic_2p` resta il ramo stabile del prodotto.

## Contratto di stabilità

Le feature sperimentali non devono cambiare:

- `BriscolaEngine` e formato delle carte;
- salvataggio storico `briscola_save.json`;
- flusso QA `?qa=fresh` / `?qa=resume`;
- difficoltà CPU esistenti;
- export Web single-thread;
- monitoring e support hooks.

## Gate per 1.0

Obbligatori:

1. CI Godot + simulazioni verde.
2. Playwright Chromium/Firefox/WebKit verde.
3. PWA offline test verde.
4. QA fisico iPhone/Safari e Android/Chrome firmato in `DEVICE_QA.md`.
5. almeno 30 partite del playtest umano documentate.
6. asset carte con licenza certa o sostituiti.
7. endpoint monitoring/support scelti oppure decisione documentata di mantenere solo diagnostica locale.

## Separazione dalla beta 4P

`teams_4p` usa un engine e save separati. Un bug della beta non deve rendere incompatibile un save 1v1 né modificare la schermata di gioco classica.
