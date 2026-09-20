# Changelog

## 0.8.3-rc8

- Fixed a false-negative Firefox CI gate: headless Firefox on Linux may expose no WebGL2 context even when production Firefox browsers are supported.
- Firefox smoke QA now validates browser startup, WebAssembly support and reachability of the production Godot payload (`index.js`, `index.wasm`, `index.pck`).
- Firefox WebGL2 availability is attached to the Playwright report as diagnostics instead of failing the deployment.
- Chromium/WebKit/iPhone/Android smoke tests continue to require a real Godot application boot.

## 0.8.3-rc7

- CI/browser QA accelerato: test completi solo su Chromium, smoke boot paralleli sugli altri profili.
- Modalità QA 1v1 ora pilota direttamente il motore e la persistenza, senza animazioni.
- Playwright passa da 1 a 3 worker e non ritenta automaticamente test lenti.
- Timeout QA ridotti e diagnostica di boot più chiara.

## 0.8.2-rc6

- Il giocatore di mano iniziale della modalità 4P varia tra i quattro posti ed è salvato nello stato.
- La distribuzione iniziale segue il vero ordine di mano della partita.
- Se apre un bot, il tavolo prosegue automaticamente fino al turno umano senza input artificiale.
- Finale 4P più leggibile: dopo l'ultima pescata il mazzo si ritira e compare `MAZZO ESAURITO · ULTIME 3 PRESE`.
- Hard AI di coppia migliorata: carica punti quando il compagno ha una presa certa, usa il vincente meno costoso da ultima posizione e riconosce aperture non superabili nel finale usando solo informazione osservabile.
- Simulazioni 4P distribuite sui quattro possibili giocatori di mano.
- Test su roundtrip del giocatore iniziale e decisione cooperativa dell'AI.
- QA browser 4P avvia intenzionalmente la partita da un bot.
- Feedback post-partita dedicato all’AI di squadra (`Troppo facile / Giusta / Troppo difficile`) con `mode=teams_4p` nel payload opzionale.
- Restano i miglioramenti RC5: deal a quattro lati, pile NOI/LORO, badge DI MANO, pescata animata, PWA safe-update.

## 0.7.0-rc3

### QA / produzione
- Playwright cross-browser in CI: Chromium, Firefox, WebKit, iPhone/WebKit e Android/Chromium emulati;
- scenario E2E Web `fresh -> save -> reload -> resume -> game over` sul filesystem persistente di Godot;
- PR gate senza deploy e push `main` con deploy Pages;
- artifact Web e report Playwright conservati 30/14 giorni;
- menu scrollabile su viewport basse.

### Playtest / supporto
- feedback CPU post-partita `Troppo facile / Giusta / Troppo difficile`;
- persistenza locale dei conteggi per difficoltà;
- endpoint playtest remoto opzionale;
- template GitHub per bug e playtest;
- link supporto/feedback integrato nel menu e nella schermata risultato.

### Monitoring / privacy
- runtime Web post-processato con error capture per `window.error`, promise rejection e `console.error`;
- ultimi errori mantenuti localmente e inclusi nei report;
- endpoint remoto opzionale, disattivato per default;
- documentazione privacy/monitoring/supporto.

### Branding
- nuova icona originale verde/avorio/oro;
- favicon/meta theme e brand shell Web;
- watermark coerente sul feltro;
- brand system documentato.

## 0.6.5-rc2
- tutorial/onboarding in 4 step;
- conferma prima del restart;
- artifact Web per rollback;
- `version.txt` / `commit.txt` nella build.

## 0.6.4-rc1
- distribuzione iniziale riallineata ai nodi reali;
- save transazionale;
- warm-up asset;
- invarianti su 600 simulazioni;
- release audit e documentazione operativa.

## 0.6.3-alpha
- mazzo/briscola sul feltro, `DI MANO`, pescata finale esplicita.

## 0.6.2-alpha
- mano a ventaglio, prese fisiche, animazioni migliorate.

## 0.6.1-alpha
- rimozione slot artificiali, fix click primo giro, presa più leggibile.

## 0.8.0-rc4

- Aggiunta PWA custom installabile/offline con cache versionata per commit.
- Aggiunto pulsante di installazione Web e istruzioni iOS fallback.
- Aggiunto test Playwright di boot offline.
- Aggiunto catalogo modalità.
- Aggiunta Briscola 4 giocatori a squadre come Beta giocabile contro 3 bot.
- Aggiunti punteggio di squadra, AI team-aware, save/resume 4P e simulazioni automatiche.
- Single-player 1v1 mantenuto come modalità production/stable separata.
