# Briscola Godot

Prototipo giocabile di **Briscola 1 contro CPU** realizzato in Godot 4.x.

## Funzioni già implementate

- mazzo italiano da 40 carte;
- carte napoletane;
- 3 carte iniziali per giocatore;
- briscola scoperta e pescata per ultima;
- turni e prese secondo le regole della Briscola;
- pesca: il vincitore della presa pesca per primo;
- punteggio corretto (Asso 11, Tre 10, Re 4, Cavallo 3, Fante 2);
- CPU con strategia semplice: prova a vincere con la carta meno costosa e conserva carte di valore/briscole quando può;
- partita completa di 20 prese;
- vittoria, sconfitta e pareggio a 60;
- click/touch sulle carte;
- scorciatoie `1`, `2`, `3` per giocare le carte della mano;
- layout in landscape pensato anche per schermi touch.

## Aprire il progetto

1. Installa Godot 4.x.
2. Apri Godot Project Manager.
3. Seleziona **Import** e scegli `project.godot` in questa cartella.
4. Premi **F6/F5** o il pulsante Play.

Non servono plugin o dipendenze esterne.

## Struttura

```text
briscola-godot/
├── project.godot
├── scenes/
│   └── main.tscn
├── scripts/
│   ├── briscola_engine.gd   # regole e stato della partita
│   ├── main.gd              # interfaccia e animazione del turno
│   └── self_test.gd         # piccoli test delle regole
└── assets/
    └── cards/
```

Il motore è intenzionalmente separato dalla UI. `BriscolaEngine` non dipende dalla scena principale: è quindi una buona base per aggiungere in seguito multiplayer, replay, bot diversi o una nuova interfaccia.

## Self-test

Con Godot disponibile da terminale:

```bash
godot --headless --path . -s res://scripts/self_test.gd
```

Il test verifica i valori principali delle carte, alcuni casi di presa e la distribuzione iniziale.

## Prossimi passi consigliati

1. Animazioni con Tween per distribuzione, gioco e raccolta delle carte.
2. Audio per carta giocata, presa e fine partita.
3. Selettore mazzo napoletano/piacentino.
4. Difficoltà CPU (casuale, greedy, memoria delle carte).
5. Menu principale e impostazioni.
6. Multiplayer online con server autorevole (WebSocket/ENet).
7. Export Web, Android, iOS e desktop.

## Asset carte

Le carte napoletane e il retro sono state copiate dal progetto **Bastoni** fornito dall'utente come materiale di partenza. Nel pacchetto Bastoni analizzato non era presente un file di licenza; prima di distribuire o pubblicare il gioco, verifica i diritti/licenza degli asset grafici o sostituiscili con un mazzo di cui possiedi i diritti.

## Deploy automatico su GitHub Pages

Il repository include `export_presets.cfg` e `.github/workflows/deploy-pages.yml`.

1. Crea un repository GitHub e carica il contenuto di questa cartella nella branch `main`.
2. In GitHub apri **Settings > Pages** e imposta **Source: GitHub Actions**.
3. Fai un push su `main` (oppure avvia manualmente il workflow da **Actions**).
4. Il workflow esporta il progetto Godot per Web e pubblica `build/web` su GitHub Pages.

Il workflow usa `barichello/godot-ci:4.3`, una versione compatibile con questo prototipo. Se in futuro il progetto richiede una versione Godot differente, aggiorna sia l'immagine Docker sia il percorso `4.3.stable` nel workflow.

## CI note

This package uses `lihop/setup-godot@v3` with `export-templates: true` so the GitHub runner installs the exact Godot 4.3 editor and matching export templates. This avoids depending on Docker HOME/template path relocation.


## CI validation

The GitHub Actions workflow validates GDScript imports, runs `scripts/self_test.gd`, and only then exports the Web build. This makes script/type errors visible before the export step.
