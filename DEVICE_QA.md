# Device QA gate

La CI copre automaticamente cinque profili browser: Chromium desktop, Firefox desktop, WebKit desktop, iPhone/WebKit emulato e Android/Chromium emulato. Per ogni profilo avvia il gioco, crea un salvataggio nel filesystem Web di Godot, ricarica la pagina, riprende la partita e la porta a termine.

Questa matrice **non sostituisce** hardware e Safari/Chrome reali. Prima della 1.0 il release owner deve firmare almeno questi test manuali:

| Target | Minimo da verificare | Esito |
|---|---|---|
| iPhone recente + Safari | partita completa, background/foreground, refresh + Continua, touch sulle 3 carte, audio dopo gesture | ☐ |
| Android recente + Chrome | partita completa, refresh + Continua, rotazione portrait/landscape, touch | ☐ |
| Windows/macOS + Chrome stabile | partita completa, mouse, resize, save/resume | ☐ |
| Windows/macOS + Firefox stabile | partita completa, mouse, resize, save/resume | ☐ |
| macOS + Safari stabile | partita completa, mouse, audio, save/resume | ☐ |

## Criteri di blocco release

Blocca il rilascio se si verifica almeno uno dei seguenti: carta non cliccabile; partita che non raggiunge 120 punti totali; save non ripristinabile; crash/WASM abort; layout che nasconde una carta; audio che impedisce l'avvio; impossibilità di capire chi ha preso una mano.

Annota modello dispositivo, versione OS/browser, commit e screenshot/video nel relativo issue GitHub.
