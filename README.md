**Versione 0.8.1-rc5**

# Briscola Napoletana — Godot 4

Release candidate con **single-player 1v1 production/stable**, **PWA installabile/offline** e **Briscola a 4 giocatori a squadre in Beta**. Target Godot 4.3 Web/GitHub Pages, save locale separato per modalità, QA cross-browser e pipeline di rollback.

## Novità 0.8.1-rc5

- modalità 4P con distribuzione animata sui quattro lati;
- giocate animate dalla mano reale al centro;
- presa raccolta verso mazzetti visibili `NOI / LORO`;
- badge `DI MANO` sul giocatore corrente e `MARCO · COMPAGNO`;
- pescata a quattro animata, inclusa la briscola finale;
- AI Difficile a squadre che usa solo informazione osservabile e collabora col compagno;
- 300 simulazioni engine 4P + test legalità AI hard;
- QA browser dedicato `?qa=4p` su Chromium/Firefox/WebKit + profili iPhone/Android;
- PWA: gli update non vengono più applicati a metà partita; compare `AGGIORNAMENTO DISPONIBILE · APPLICA`;
- il ramo 1v1 resta congelato salvo bug/regressioni.

## Gameplay / UX

- 40 carte napoletane, 20 prese, 120 punti;
- CPU Facile / Normale / Difficile;
- distribuzione alternata naturale e reveal della briscola dopo la sesta carta;
- mouse/touch dalla prima mano;
- mano a ventaglio, prese leggibili, mazzetti conquistati e pescata finale corretta;
- tutorial iniziale e riapribile;
- responsive desktop/mobile;
- audio, riduzione animazioni, save/resume e statistiche locali.

## Test locali

```bash
python3 tools/release_audit.py
godot --headless --editor --path . --quit
godot --headless --path . -s res://scripts/self_test.gd
```

Dopo aver prodotto `build/web`:

```bash
npm install
npx playwright install chromium firefox webkit
python3 -m http.server 8765 --directory build/web
npm run test:browser
```

## Deploy

```bash
git add .
git commit -m "Briscola 0.7.0 rc3"
git push
```

La CI esegue audit, compilazione/import Godot, self-test, export Web, post-processing del browser shell, smoke HTTP, QA Playwright su cinque profili, archivio di rollback e deploy GitHub Pages. Le pull request eseguono build+QA ma non deployano.

## Variabili GitHub Actions opzionali

- `SUPPORT_URL`: destinazione alternativa al repository GitHub per i report;
- `ERROR_REPORT_ENDPOINT`: endpoint JSON per error monitoring remoto;
- `PLAYTEST_ENDPOINT`: endpoint JSON per feedback anonimo sulla difficoltà CPU.

Senza queste variabili il gioco continua a funzionare: supporto usa GitHub Issues e diagnostica/playtest restano locali.

## Prima della produzione

Leggere e completare:

- `PRODUCTION_CHECKLIST.md`
- `DEVICE_QA.md`
- `QA_CHECKLIST.md`
- `PLAYTEST_PLAN.md`
- `MONITORING.md`
- `SUPPORT.md`
- `BRAND.md`
- `PRIVACY.md`
- `ASSET_NOTICE.md`
- `HANDOFF.md`

**Blocco ancora aperto:** la licenza commerciale delle immagini delle carte deve essere documentata oppure gli SVG vanno sostituiti.


## Novità 0.8

- PWA installabile con gioco offline dopo il primo caricamento.
- Modalità stabile `1 contro 1`.
- Modalità Beta `4 giocatori · squadre` contro tre bot.
- Save separati per modalità, così la Beta non modifica i salvataggi 1v1.
- Test CI aggiuntivo per la PWA offline e 300 partite simulate 4P.

Documenti: `PWA.md`, `VARIANTS.md`, `SINGLE_PLAYER_PRODUCTION.md`.


## Novità 0.8.1 RC5

La modalità 4 giocatori riceve il primo vero passaggio di game-feel: deal alternato sui quattro lati, giocate animate, pile di prese per squadra, indicatore del giocatore di mano e pescata a quattro. Il ramo 1v1 rimane congelato salvo regressioni.
