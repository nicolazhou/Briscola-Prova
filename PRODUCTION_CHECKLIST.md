# Production checklist — 0.8.1-rc5

## Stato go / no-go

| Area | Stato | Criterio GO |
|---|---|---|
| Regole / 120 punti | ✅ | self-test verde |
| Save/resume | ✅ automatico | Playwright fresh→reload→resume verde |
| PWA install/offline | ✅ automatico | manifest + service worker + Chromium offline boot verde |
| Single-player 1v1 | ✅ stable | engine/CI/browser QA invariati |
| 4 giocatori a squadre | 🟡 Beta | 150 simulazioni + save separato; non blocca la 1.0 single-player |
| Chromium desktop | ✅ automatico | Playwright verde |
| Firefox desktop | ✅ automatico | Playwright verde |
| WebKit desktop | ✅ automatico | Playwright verde |
| iPhone/WebKit emulato | ✅ automatico | Playwright verde |
| Android/Chromium emulato | ✅ automatico | Playwright verde |
| Hardware iPhone/Android reale | 🔴 GATE | `DEVICE_QA.md` firmato |
| Safari macOS/Chrome reale | 🔴 GATE | `DEVICE_QA.md` firmato |
| Feedback/playtest infrastructure | ✅ | rating + issue template + endpoint opzionale |
| Playtest umano | 🔴 GATE | campione `PLAYTEST_PLAN.md` completato |
| Brand UI/favicon | ✅ | `BRAND.md` applicato |
| Licenza carte | 🔴 BLOCKER | licenza scritta o asset sostituiti |
| Error capture locale | ✅ | runtime.js attivo |
| Error monitoring remoto | 🟡 scelta prod | endpoint configurato oppure no-go documentato |
| Support/feedback | ✅ | link in-game + issue template |
| Privacy | 🟡 | aggiornare se endpoint remoto abilitato |
| Rollback | ✅ | artifact 30 giorni + runbook |

## Prima del tag v1.0.0

- [ ] risolvere `ASSET_NOTICE.md`;
- [ ] completare `DEVICE_QA.md` su device reali;
- [ ] completare il campione di `PLAYTEST_PLAN.md`;
- [ ] zero bug P0/P1 aperti;
- [ ] definire owner supporto;
- [ ] decidere `ERROR_REPORT_ENDPOINT` e relativa privacy/retention;
- [ ] decidere se configurare `PLAYTEST_ENDPOINT`;
- [ ] nome/logo/iconografia approvati;
- [ ] dominio e HTTPS definitivi;
- [ ] test rete lenta/cache vuota;
- [ ] installazione PWA reale su Android e aggiunta Home su iPhone;
- [ ] verifica aggiornamento PWA dalla release N alla N+1 senza cache stale;
- [ ] performance accettabile su smartphone non top di gamma;
- [ ] GitHub Actions completamente verde;
- [ ] artifact rollback identificato;
- [ ] changelog aggiornato;
- [ ] tag immutabile `v1.0.0`;
- [ ] verifica finale produzione in finestra privata e su mobile reale.

## Prime 48 ore dopo go-live

- controllare error monitoring o issue in arrivo;
- verificare caricamento su rete mobile;
- eseguire almeno un save/resume direttamente sul dominio produzione;
- verificare `version.txt` / `commit.txt`;
- non introdurre nuove feature finché i bug di lancio non sono stabilizzati.


## Gate aggiunto RC5 — Briscola 4P
- [ ] QA Playwright `?qa=4p` verde su Chromium, Firefox, WebKit, iPhone emulato e Android emulato.
- [ ] 300 simulazioni engine 4P verdi.
- [ ] Deal a quattro lati, presa verso pile NOI/LORO e pescata verificati manualmente.
- [ ] Nessuna regressione sul ramo 1v1 production.
