# Error monitoring

La build Web include `runtime.js`, aggiunto dopo l'export Godot. Il runtime intercetta `window.error`, `unhandledrejection` e `console.error`, conserva localmente gli ultimi 10 eventi e li include nel link **Segnala un problema**.

Per default **non invia nulla a terzi**. Questo permette di pubblicare la build senza telemetria implicita.

## Abilitare raccolta remota

Configura nel repository GitHub una Actions variable:

`ERROR_REPORT_ENDPOINT=https://...`

Ad ogni errore il browser invierà un POST JSON contenente solo: tipo errore, messaggio/stack troncati, path della pagina, user-agent, versione, commit e timestamp. Non vengono inviati nome, email, contenuto della partita, carte in mano, cookie o identificatori creati dal gioco.

L'endpoint deve accettare JSON cross-origin e applicare rate limiting. Può essere una funzione serverless propria oppure un adapter verso il provider di monitoring scelto. Se usi un provider terzo, aggiorna la privacy notice e valuta DPA/retention prima del go-live.

La build pubblica anche `monitoring-config.txt` per rendere evidente se la raccolta remota è attiva.

## Playtest endpoint separato

`PLAYTEST_ENDPOINT` è indipendente dall'error monitoring. Se configurato, riceve solo eventi di valutazione della difficoltà; se assente, il voto resta locale. Mantieni separati i due endpoint se hanno retention o finalità diverse.
