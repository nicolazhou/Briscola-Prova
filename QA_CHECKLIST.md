# QA checklist — Briscola Napoletana 0.7.0-rc3

## Copertura automatica CI

Ogni PR e push eseguono una partita Web con save/reload/resume su:

- Chromium desktop;
- Firefox desktop;
- WebKit desktop;
- iPhone 13 / WebKit emulato;
- Pixel 7 / Chromium emulato.

Il test fallisce per `window.error`, promise rejection non gestite, boot timeout o mancato completamento del flusso di partita.

**WebKit Playwright non equivale a Safari reale e i profili mobile non equivalgono a hardware reale.** Per il go-live resta obbligatorio `DEVICE_QA.md`.

## Checklist manuale build pubblicata

### Primo avvio
- [ ] menu leggibile senza clipping anche su schermo piccolo;
- [ ] tutorial appare soltanto al primo avvio;
- [ ] `?` e `COME SI GIOCA` funzionano;
- [ ] `SEGNALA UN PROBLEMA / FEEDBACK` apre la destinazione corretta.

### Gameplay
- [ ] distribuzione iniziale fluida e senza pop;
- [ ] prima carta cliccabile/touch;
- [ ] chi prende è sempre evidente;
- [ ] mazzetto prese e punteggio sono coerenti;
- [ ] ultima briscola pescata correttamente;
- [ ] totale finale sempre 120.

### Save/resume
- [ ] refresh durante il proprio turno;
- [ ] refresh con una carta sul tavolo;
- [ ] chiusura/riapertura tab;
- [ ] `CONTINUA` ripristina mano, punteggio, turno, briscola;
- [ ] nessun duplicato dopo resume.

### Feedback / diagnostica
- [ ] rating CPU selezionabile a fine partita;
- [ ] i tre pulsanti si disabilitano dopo il voto;
- [ ] feedback dettagliato apre issue/modulo con versione e browser;
- [ ] `monitoring-config.txt` corrisponde alla configurazione del deploy;
- [ ] se `ERROR_REPORT_ENDPOINT` è attivo, un errore di test arriva al collector in ambiente staging.

### Responsive / accessibilità
- [ ] focus tastiera visibile;
- [ ] target touch comodi;
- [ ] nessun testo importante tagliato a 320 CSS px;
- [ ] rotazione portrait/landscape non rompe la partita;
- [ ] menu può scorrere su viewport basse.

## Firma release

- Tester:
- Data:
- Commit:
- URL produzione:
- Device reali testati:
- Esito: GO / NO-GO
- Bug noti accettati:
