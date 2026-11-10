# Sonno e orologio manuale — build 17

Il vecchio messaggio raggruppava data futura, fine precedente all’inizio e fonte vuota/lunga. I controlli sono ora distinti e non mostrano date o nomi sanitari nei messaggi.

L’azione Importa dati Salute JSON nel quaderno, già usata dai comandi firmati, esclude e conta esplicitamente i soli segmenti sonno che terminano oltre 5 minuti nel futuro. Le date originali non vengono modificate. Se tutti i segmenti sono futuri non viene salvato nulla; gli altri errori del lotto restano bloccanti. L’importazione JSON manuale e quella XML rimangono rigorose e atomiche. Non occorre rifirmare i comandi.

Con data/ora ora corrette sul telefono, esegui di nuovo Sonno nel quaderno dopo l’aggiornamento. Il risultato indica quanti campioni sono stati ricevuti e quanti segmenti futuri esclusi. Eventuali segmenti sfalsati restano nella fonte Salute di Apple e non vengono eliminati o corretti dall’app.
