# Briscola Napoletana — Godot 4

Versione **0.6.2-alpha / production beta candidate** di una Briscola 1 contro CPU realizzata con Godot 4.3 e pronta per export Web / GitHub Pages.

## Novità v6.2

Questa revisione continua il lavoro sul **game feel** e rende il tavolo più simile a una partita reale:

- mano del giocatore disposta a **ventaglio**, con leggero overlap e inclinazione naturale;
- le carte si alzano e si raddrizzano dolcemente al passaggio del mouse/focus, senza modificare l'area cliccabile;
- aggiunta un'ombra discreta sotto ogni carta della mano;
- input della carta affidato al comportamento nativo `Button.pressed`, valido per mouse e touch;
- l'animazione di giocata ora segue un **piccolo arco** e termina con un impatto/assestamento sul feltro;
- angolo delle carte sul tavolo leggermente variabile a ogni presa, per evitare l'effetto “slot”;
- distribuzione iniziale rifatta: ogni carta arriva e resta nella mano subito; le carte del giocatore si girano mostrando il fronte, quelle di Tony restano coperte;
- pesca migliorata con traiettoria curva e flip della nuova carta del giocatore;
- introdotti due **mazzetti fisici delle prese vinte** sul tavolo, con conteggio prese;
- la presa viene letta in tre fasi: carta vincente evidenziata → perdente che scivola sotto → coppia che vola nel mazzetto del vincitore;
- il punteggio del vincitore viene incrementato visivamente durante la raccolta;
- indicazione del turno resa più evidente: nome di Tony e didascalia della mano cambiano enfasi in base a chi deve giocare;
- piccolo pulse su “TOCCA A TE” quando il controllo torna al giocatore.

Restano tutte le correzioni della v6.1: niente riquadri visibili per le carte giocate, niente numeri `1 / 2 / 3` sulle carte e click/touch diretto anche al primo giro. Restano inoltre salvataggi, responsive mobile, AI con memoria, statistiche e suite da 600 partite simulate introdotti dalla v6.

## Gameplay già presente

- Briscola completa 1 contro CPU;
- mazzo napoletano da 40 carte;
- tre difficoltà: Facile, Normale, Difficile;
- distribuzione animata;
- animazione carta giocata e flip della CPU;
- animazione della presa;
- animazione della pesca;
- punteggi e schermata risultato;
- effetti sonori;
- input mouse e touch diretto sulle carte; scorciatoie tastiera `1 / 2 / 3` ancora supportate;
- rivincita e ritorno al menu.

## Struttura

```text
briscola-v6.2/
├── project.godot
├── export_presets.cfg
├── scenes/
│   └── main.tscn
├── scripts/
│   ├── briscola_engine.gd    # regole, stato, serializzazione, CPU
│   ├── game_persistence.gd   # save game, preferenze, statistiche
│   ├── card_view.gd          # carta interattiva
│   ├── main.gd               # UI, responsive, flow e animazioni
│   └── self_test.gd          # test regole + save + simulazioni
├── assets/
│   ├── cards/
│   ├── audio/
│   └── ui/
└── .github/workflows/
    └── deploy-pages.yml
```

## Salvataggio

Il gioco salva automaticamente uno snapshot dello stato in:

```text
user://briscola_save.json
```

Le preferenze e le statistiche vengono salvate in:

```text
user://briscola_settings.cfg
```

Sul Web, `user://` viene gestito da Godot tramite lo storage persistente del browser. Il salvataggio rimane legato al browser/origine da cui viene eseguito il gioco.

Il salvataggio comprende:

- mazzo residuo;
- entrambe le mani;
- carte sul tavolo;
- prese effettuate;
- punteggi;
- giocatore di turno;
- carta/seme di briscola;
- numero della presa;
- storico delle carte giocate;
- difficoltà CPU.

Prima del resume il motore verifica che lo snapshot rappresenti ancora un mazzo valido da 40 carte e che punteggi, prese e storico siano coerenti.

## AI difficile

La CPU difficile usa esclusivamente informazioni che un giocatore reale può conoscere:

```text
mano CPU
+ carta di briscola
+ carta/carte sul tavolo
+ storico delle carte già uscite
```

Non usa la mano umana né l'ordine effettivo del mazzo per scegliere una mossa.

Tiene conto di:

- punti presenti nella presa;
- costo della carta che dovrebbe spendere;
- briscole ancora non viste;
- numero di carte sconosciute capaci di battere una carta quando apre;
- fase della partita;
- deduzione completa delle carte residue quando il mazzo è esaurito.

È ancora una AI euristica, non un solver perfetto/minimax completo.

## Responsive/mobile

La base logica del progetto è ora `720×720` con aspect `expand`.

Su landscape desktop il viewport si espande orizzontalmente e mantiene il layout completo. Su portrait/mobile entra in modalità compatta:

- titolo desktop nascosto;
- score/header compressi;
- pannello del turno nascosto;
- mazzo e briscola restano visibili;
- carte del giocatore ingrandite rispetto alla scala fisica del telefono;
- controlli touch più facili da colpire;
- testo della mano abbreviato;
- pulsante restart compatto.

La modalità landscape su schermi bassi usa un set di dimensioni intermedio per evitare overflow verticale.

## Accessibilità

Dal menu puoi attivare **Riduci animazioni**. La preferenza viene ricordata e riduce drasticamente tween, pause e tempi di attesa del bot mantenendo intatto il flusso di gioco.

Restano disponibili anche le scorciatoie da tastiera `1`, `2`, `3`.

## Test automatici

Esegui:

```bash
godot --headless --path . -s res://scripts/self_test.gd
```

Il test verifica:

- valori e forza delle carte;
- stato iniziale e unicità delle 40 carte;
- presenza di tutti gli asset del mazzo;
- save/load JSON a metà presa;
- memoria delle carte della CPU;
- validità degli indici scelti dalle tre AI;
- 300 partite completamente casuali;
- 100 partite contro Facile;
- 100 contro Normale;
- 100 contro Difficile;
- 120 punti complessivi e 20 prese a ogni fine partita.

Output atteso:

```text
BriscolaEngine: self-test OK (rules + save roundtrip + assets + 600 simulated games)
```

## Deploy GitHub Pages

Il workflow incluso:

1. installa Godot 4.3 ufficiale;
2. installa i template Web ufficiali, compresi quelli single-threaded;
3. importa gli asset e valida gli script;
4. esegue la suite di test;
5. esporta la build Web;
6. verifica `index.html`, `index.js`, `index.wasm` e `index.pck`;
7. avvia un server HTTP locale nel runner e verifica che i file siano realmente servibili;
8. pubblica l'artefatto su GitHub Pages.

Per pubblicare, sostituisci il contenuto della root del repository con questa versione e fai push su `main`.

## Cosa manca ancora prima di chiamarla release 1.0

La base single-player è molto più vicina a un prodotto, ma prima di una release commerciale sono ancora consigliati test manuali su dispositivi reali, polishing grafico/audio, un tutorial/onboarding, una AI difficile ulteriormente validata contro giocatori forti, gestione di eventuali aggiornamenti incompatibili dei salvataggi, privacy/termini se verranno introdotti analytics/account e soprattutto la verifica delle licenze degli asset delle carte.

## Asset e licenze

Le carte napoletane e il retro derivano dal progetto **Bastoni** fornito come materiale di partenza. Nel repository originario analizzato non era presente una licenza chiara per questi asset: **prima di una distribuzione pubblica o commerciale verifica i diritti oppure sostituisci il mazzo con asset di cui possiedi una licenza esplicita**.

Gli effetti sonori del prototipo sono stati generati appositamente per questo progetto.
