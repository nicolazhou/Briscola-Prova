# Playtest plan

Obiettivo: verificare che la CPU sia divertente e comprensibile, non solo corretta.

## Campione minimo prima della 1.0

- 5 giocatori che conoscono bene la Briscola.
- 5 giocatori occasionali.
- Almeno 3 partite a difficoltà Normale e 3 a Difficile per gruppo.
- Almeno 30 partite umane complessive.

## Dati raccolti

A fine partita il gioco chiede direttamente se la CPU è `Troppo facile`, `Giusta` o `Troppo difficile`. Il conteggio resta locale sul dispositivo; se il deploy configura la Actions variable `PLAYTEST_ENDPOINT`, viene inviato anche un evento anonimo con difficoltà, voto, punteggio finale, versione, commit e user-agent. Il pulsante **Invia feedback dettagliato** apre il template GitHub con versione, commit, browser e gli ultimi errori browser rilevati.

Per ogni sessione registra anche: risultato, difficoltà, momento in cui una mossa CPU è sembrata irrazionale, chiarezza delle prese e durata percepita.

## Go/no-go AI

Per una difficoltà destinata alla 1.0, la maggioranza dei tester del target dovrebbe scegliere `Giusta`; nessun comportamento ripetibile deve sembrare un bug o uso di informazioni nascoste. Se `Difficile` risulta semplicemente frustrante, va ritoccata prima del rilascio invece di aumentare ulteriormente la forza.
