# Modalità e varianti

## Catalogo

Il catalogo vive in `scripts/game_modes.gd`.

### `classic_2p` — produzione

- 1 giocatore umano contro Tony.
- 3 carte iniziali a testa.
- pesca dopo ogni presa, vincitore per primo.
- 20 prese, 120 punti.
- save/resume, AI facile/normale/difficile, QA browser e monitoring.

### `teams_4p` — beta giocabile

- Tu + Marco contro Sara + Luca.
- Le coppie sono opposte al tavolo.
- ordine di gioco: Tu → Luca → Marco → Sara, poi dal vincitore della presa.
- 3 carte iniziali a testa.
- 4 carte per presa.
- nessun obbligo di rispondere al seme.
- se entra una o più briscole vince la briscola più alta; altrimenti vince la carta più alta del seme aperto.
- dopo la presa si pesca in ordine partendo dal vincitore.
- 10 prese totali, punteggio di squadra.
- 3 bot team-aware; il compagno evita di sprecare carte quando la squadra sta già vincendo.
- save/resume separato dal single-player.

Implementazione:

- `scripts/four_player_engine.gd`
- `scripts/four_player.gd`
- `scenes/four_player.tscn`

## Varianti future

Il motore non deve accorpare regole regionali dentro `BriscolaEngine`. Ogni variante che cambia numero giocatori, distribuzione o condizione di vittoria deve avere un engine/configurazione distinta e un ID nel catalogo.

Candidate non ancora abilitate:

- rotazione del mazziere e giocatore iniziale;
- 4 giocatori locali/pass-and-play;
- Briscola a 4 con AI configurabili singolarmente;
- regole regionali sulla carta di briscola;
- Briscola Chiamata (5 giocatori), da trattare come gioco distinto per complessità di asta e squadre nascoste.


## 0.8.1: stato Beta 4P

La modalità a squadre è ora completa come loop di gioco e ha animazioni dedicate. Prima di promuoverla a production restano QA su device reali, tuning dell'AI di coppia e playtest con almeno 20 partite umane a quattro/bot. La modalità non condivide il save con il 1v1.
