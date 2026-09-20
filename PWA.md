# PWA / installazione

La build Web genera una PWA installabile senza usare il service worker automatico del preset Godot.

## Perché custom

`tools/postprocess_web.py` crea dopo ogni export:

- `manifest.webmanifest`
- `service-worker.js`
- `offline.html`
- icone 192/512 e Apple Touch Icon

Il nome della cache include versione + commit (`briscola-<versione>-<sha>`). Ogni release elimina le cache Briscola precedenti durante `activate`.

Le navigazioni sono **network-first**: quando Internet è disponibile viene preferito sempre l'HTML della release corrente; offline viene usata la copia locale. Gli asset statici sono serviti cache-first dopo il primo caricamento.

## Installazione

Nel menu Web compare `INSTALLA APP / GIOCA OFFLINE`.

- Chromium/Android/desktop: usa `beforeinstallprompt` quando disponibile.
- iPhone/iPad: mostra le istruzioni per Safari → Condividi → Aggiungi alla schermata Home.
- Se l'app è già standalone non viene richiesto un nuovo install.

## QA

`tests/browser/pwa.spec.cjs` verifica su Chromium:

1. manifest e icone;
2. registrazione del service worker;
3. acquisizione del controller;
4. reload completo offline;
5. boot di Godot senza rete.

## Nota cache

Non rinominare `index.js`, `index.wasm` o `index.pck`: Godot si aspetta i nomi collegati all'export `index.html`.


## Update lifecycle RC5

Il nuovo service worker non esegue più `skipWaiting()` durante l'installazione di un update. La partita corrente resta sulla build attiva; quando il nuovo worker è pronto il menu mostra **AGGIORNAMENTO DISPONIBILE · APPLICA**. Solo l'azione dell'utente invia `SKIP_WAITING`, attende `controllerchange` e ricarica. Le nuove installazioni continuano a funzionare normalmente.
