# Changelog

## 0.8.1-rc5

- Briscola 4 giocatori: distribuzione iniziale animata a quattro lati.
- Giocate animate dalla mano reale al centro del tavolo.
- Raccolta della presa verso mazzetti NOI/LORO visibili.
- Indicatore DI MANO e highlight del giocatore corrente.
- Marco marcato esplicitamente come COMPAGNO.
- Pescata a quattro animata, inclusa la briscola finale.
- AI Difficile a squadre: conserva risorse, collabora col compagno e usa solo informazione osservabile.
- 300 simulazioni automatiche 4P più test di legalità dell'AI hard.
- Il single-player 1v1 resta ramo production/stable invariato.

# Changelog

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
