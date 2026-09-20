# Handoff tecnico — Briscola Napoletana

**Versione:** `0.8.2-rc6`  
**Engine:** Godot 4.3 / GDScript  
**Target:** Web single-threaded / GitHub Pages  
**Modalità:** 1v1 production/stable + 4 giocatori a squadre Beta 2 + PWA/offline

## Stato

Il 1v1 è il ramo production/stable. La modalità 4 giocatori è isolata in engine/scena/save dedicati ed è Beta. La PWA usa service worker custom con cache versionata e update esplicito. I gate esterni principali restano licenza mazzo, device QA reale e playtest umano (in particolare 4P/AI di coppia).

## Architettura

```text
scenes/main.tscn
  -> scripts/main.gd
  -> scripts/briscola_engine.gd          # 1v1 stable

scenes/four_player.tscn
  -> scripts/four_player.gd
  -> scripts/four_player_engine.gd       # 4P Beta

scripts/game_persistence.gd             # save separati per modalità
scripts/card_view.gd                     # carta interattiva
scripts/game_modes.gd                    # catalogo modalità/status

Web export
  -> tools/postprocess_web.py
  -> manifest + service worker + runtime.js
  -> Playwright: 1v1 save/resume + 4P full QA + PWA offline
```

Regola architetturale: **BriscolaEngine non dipende dalla UI**. Il motore deve rimanere eseguibile headless.

## QA Web bridge

`main.gd` supporta query riservate alla CI:

- `?qa=fresh`: crea partita, gioca alcune mani, salva e forza sync Web;
- `?qa=resume`: ricarica il save persistente e completa la partita;
- `?qa=full`: completa una partita automatica.

`tests/browser/game.spec.cjs` usa `fresh` e `resume` nello stesso browser context. La CI esegue il flusso su Chromium desktop, Firefox desktop, WebKit desktop, iPhone/WebKit emulato e Android/Chromium emulato.

Non usare queste query come feature utente; servono solo al test harness.

## Supporto e diagnostica

`tools/postprocess_web.py` aggiunge alla build `runtime.js` e meta/favicons. Il runtime:

- intercetta `window.error`, `unhandledrejection`, `console.error`;
- mantiene gli ultimi 10 eventi in localStorage;
- apre un report precompilato tramite `BriscolaSupport.openFeedback()`;
- invia errori solo se `ERROR_REPORT_ENDPOINT` è configurato;
- invia feedback playtest solo se `PLAYTEST_ENDPOINT` è configurato.

Nessuna telemetria remota è attiva per default.

## Feedback AI

A fine partita tre pulsanti registrano la percezione della difficoltà. I conteggi sono salvati in `briscola_settings.cfg`; sul Web vengono anche passati al runtime, che li conserva localmente e opzionalmente li invia a `PLAYTEST_ENDPOINT`.

## Persistenza

Partita: `user://briscola_save.json` con `.tmp` + `.bak`.  
Impostazioni: `user://briscola_settings.cfg`.

Su Web `_save_progress()` chiama `JavaScriptBridge.force_fs_sync()` dopo il save, utile per rendere affidabile il test reload/resume.

## CI/CD

```text
release audit
 -> Godot 4.3 + export templates
 -> import / compile GDScript
 -> self-test + 600 simulazioni
 -> Web export
 -> brand/runtime postprocess
 -> HTTP smoke
 -> Playwright: Chromium / Firefox / WebKit / iPhone emulato / Android emulato
 -> artifact rollback 30 giorni
 -> GitHub Pages (solo push main)
```

Le pull request eseguono gli stessi gate fino al browser QA, senza deploy Pages.

## Rollback

1. scegliere l'ultimo commit verde;
2. scaricare `briscola-web-<sha>` oppure usare `git revert`;
3. push su `main`;
4. verificare `version.txt` e `commit.txt` sull'URL di produzione;
5. ripetere un test save/resume rapido.

## Gate per 1.0

P0:
- licenza carte risolta/sostituita;
- `DEVICE_QA.md` firmato su hardware reale;
- nessun P0/P1 aperto;
- almeno 30 partite di playtest umano come da `PLAYTEST_PLAN.md`.

P1:
- endpoint di monitoring deciso oppure esplicita scelta di restare solo con diagnostica locale;
- support owner definito;
- dominio/branding finale approvato;
- privacy note aggiornata se si abilita telemetria remota.

P2:
- PWA solo dopo una strategia di cache/version update testata;
- multiplayer/account solo dopo stabilizzazione della 1.0 offline.

## 0.8.2-rc6: PWA e modalità

Il ramo stabile resta `classic_2p` (`BriscolaEngine` + `main.gd`). Non fondere il motore 4P dentro l'engine 1v1.

La nuova modalità `teams_4p` vive in `FourPlayerEngine` e `four_player.gd`, con salvataggio namespaced tramite `GamePersistence.save_mode_game()`.

La PWA è generata da `tools/postprocess_web.py`, non dal flag PWA del preset Godot. Il preset deve quindi continuare a mostrare `progressive_web_app/enabled=false`. Il service worker custom usa una cache versionata con versione + commit e navigation network-first.

Vedi `PWA.md`, `VARIANTS.md` e `SINGLE_PLAYER_PRODUCTION.md`.


## 4P game-feel RC5

`four_player.gd` possiede ora tre layer distinti: `trick_layer` (carte sul tavolo), `capture_layer` (pile NOI/LORO) e `deal_layer` (carte transitorie in volo). Non animare direttamente i nodi della mano per la distribuzione: usa `_animate_flying_card()` e `_visible_hand_counts`, così lo stato logico può restare completo mentre la rivelazione visiva avanza una carta alla volta.


## 0.8.2-rc6 — note operative

La modalità 4P ha ora `starting_player` persistito. Non reintrodurre assunzioni UI del tipo “la prima presa parte sempre da human”: deal, badge `DI MANO`, autoplay dei bot e test devono usare `engine.starting_player/current_player`.

Quando `deck.is_empty()` dopo l'ultima sequenza di pescata, la UI entra nel finale di tre prese e rimuove il mazzo con `_announce_endgame_if_needed()`. Questa transizione è solo presentazionale: il motore continua a determinare la fine partita esclusivamente da mazzo/tavolo/mani vuoti.

## QA CI performance (0.8.3-rc7)

Il QA browser e deliberatamente diviso in due livelli. I flussi costosi (save/resume, 4P completa, PWA offline) girano una sola volta su Chromium. Gli altri profili eseguono smoke test in parallelo. Non reintrodurre partite animate complete in `?qa=`: i test browser devono pilotare il motore direttamente; animazioni e game feel appartengono a QA/playtest manuale.
