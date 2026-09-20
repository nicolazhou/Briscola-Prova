# Supporto e feedback

Nel menu e nella schermata finale è presente un link di feedback. In GitHub Pages, se non viene impostata una destinazione diversa, il link punta automaticamente alla pagina `Issues/new` dello stesso repository e precompila versione, commit, browser, viewport ed eventuali errori recenti.

Per usare un help desk o un modulo esterno imposta la Actions variable:

`SUPPORT_URL=https://support.example.com/...`

La destinazione deve accettare query string `title` e `body` se vuoi mantenere la precompilazione diagnostica. In alternativa può ignorarle.

Prima della 1.0 assegna una persona/ruolo proprietario della coda di supporto e definisci un tempo obiettivo di risposta per crash e perdita salvataggi.
