# Briscola Napoletana — Godot 4

Versione **production alpha** di una Briscola 1 contro CPU, realizzata in Godot 4.3 e pronta per export Web / GitHub Pages.

## Cosa c'è in questa versione

- partita completa di Briscola a 2 giocatori;
- mazzo napoletano da 40 carte;
- menu iniziale;
- tre difficoltà CPU: **Facile**, **Normale**, **Difficile**;
- distribuzione iniziale animata;
- carta del giocatore animata verso il tavolo;
- carta CPU animata e girata sul tavolo;
- animazione di raccolta della presa;
- animazione di pesca dal mazzo;
- hover/focus delle carte del giocatore;
- scoreboard separato per giocatore e CPU;
- schermata finale con rivincita/menu;
- effetti sonori per shuffle, carta giocata, presa, vittoria e sconfitta;
- interruttore effetti sonori;
- scorciatoie `1`, `2`, `3` per giocare le carte;
- layout landscape con stretch `canvas_items` + `expand`;
- self-test delle regole + **200 partite complete simulate automaticamente**;
- deploy automatico GitHub Pages tramite GitHub Actions.

## Struttura

```text
briscola-v5/
├── project.godot
├── export_presets.cfg
├── scenes/
│   └── main.tscn
├── scripts/
│   ├── briscola_engine.gd   # regole, stato e CPU
│   ├── card_view.gd         # carta interattiva UI
│   ├── main.gd              # flow, UI e animazioni
│   └── self_test.gd         # regole + simulazioni complete
├── assets/
│   ├── cards/
│   ├── audio/
│   └── ui/
└── .github/workflows/
    └── deploy-pages.yml
```

## Avvio locale

Apri `project.godot` con Godot 4.3+ e premi **F6/F5**.

Da terminale, per eseguire i test:

```bash
godot --headless --path . -s res://scripts/self_test.gd
```

L'output atteso è:

```text
BriscolaEngine: self-test OK (rules + 200 simulated games)
```

## Deploy GitHub Pages

Il workflow è già incluso.

1. Metti il contenuto di questa cartella nella root del repository.
2. In GitHub: **Settings → Pages → Source: GitHub Actions**.
3. Push su `main`.
4. Il workflow:
   - installa Godot 4.3;
   - installa gli export template ufficiali;
   - importa gli asset;
   - compila gli script;
   - esegue il self-test;
   - esporta la build Web single-threaded;
   - pubblica su GitHub Pages.

## Difficoltà CPU

### Facile
Sceglie una carta casualmente.

### Normale
Cerca di vincere la presa usando la carta vincente meno costosa e tende a conservare carichi e briscole importanti.

### Difficile
Valuta anche il valore della presa corrente e tende a non sprecare briscole/carichi sulle prese povere. È ancora un'AI euristica, non una AI perfetta con memoria completa delle carte.

## Stato del prodotto

Questa versione è una **production alpha**: l'esperienza di gioco è molto più vicina a un prodotto reale, ma prima di una release commerciale restano consigliati:

- test manuali su Chrome, Safari, Firefox, Android e iPhone;
- UI specifica portrait/mobile;
- salvataggio impostazioni e partita;
- accessibilità più completa;
- audio professionale;
- bot difficile con memoria delle carte giocate;
- telemetria/crash reporting se previsto;
- verifica licenze asset;
- privacy/termini se vengono aggiunti account o analytics;
- backend autorevole se verrà aggiunto multiplayer.

## Asset e licenze

Le carte napoletane e il retro derivano dal progetto **Bastoni** fornito come materiale di partenza. Nel repository originario analizzato non era presente una licenza chiara per questi asset: **prima di una distribuzione pubblica/commerciale verifica i diritti oppure sostituisci le carte con asset di cui possiedi la licenza**.

Gli effetti sonori presenti in questa versione sono stati generati appositamente per il prototipo.
