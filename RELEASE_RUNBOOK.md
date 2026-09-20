# Release runbook — Briscola Napoletana

## Preparazione

1. Risolvere tutti i blocker in `PRODUCTION_CHECKLIST.md`.
2. Verificare che il QA Playwright sia verde e completare/firma `DEVICE_QA.md` sulla build candidata.
3. Aggiornare `CHANGELOG.md` e `application/config/version`.
4. Eseguire:

```bash
python3 tools/release_audit.py
godot --headless --editor --path . --quit
godot --headless --path . -s res://scripts/self_test.gd
```

## Deploy candidato

```bash
git add .
git commit -m "Release candidate <version>"
git push origin main
```

Attendere GitHub Actions verde, inclusi i cinque progetti Playwright. Verificare poi sulla build pubblicata:

- `version.txt` = versione attesa;
- `commit.txt` = SHA del commit atteso;
- nuova partita;
- resume;
- una presa umana e una CPU;
- audio e reduced motion;
- console browser senza errori critici;
- `monitoring-config.txt` coerente con gli endpoint configurati;
- link supporto/feedback funzionante.

## Tag produzione

Dopo QA e verifica URL produzione:

```bash
git tag -a v1.0.0 -m "Briscola Napoletana 1.0.0"
git push origin v1.0.0
```

Non spostare o riscrivere un tag già pubblicato.

## Rollback

Se la release ha un bug P0/P1:

1. identificare l'ultimo commit verde noto;
2. scaricare, se necessario, l'artifact `briscola-web-<sha>` conservato dalla CI;
3. preferire `git revert` del commit problematico;
4. push su `main`;
5. attendere deploy verde;
6. verificare `commit.txt` e `version.txt` in produzione;
7. annotare incidente e causa nel changelog/issue tracker.

## Severità bug

- **P0:** gioco non avviabile, save corrotto in massa, partita impossibile da completare.
- **P1:** regole/punteggio errati, input principale non funzionante su un target supportato, resume rotto.
- **P2:** problema grafico/animazione con workaround.
- **P3:** polish o miglioramento non bloccante.

P0/P1 bloccano il go-live.

## Prime 48 ore

- evitare feature nuove;
- controllare segnalazioni reali su device mobili;
- provare almeno una partita completa al giorno sulla build di produzione;
- verificare che non venga servita una build vecchia dalla cache;
- tenere pronto il commit di rollback.
