# Aggiornamento da Abitudini Locale a Quaderno Locale

Quaderno Locale aggiorna l’app delle abitudini già presente. L’identificatore originale è `local.abitudinilocale.habits`, il file è ancora `abitudini.json` nella cartella originale. La firma di Sideloadly può aggiungere un suffisso personale: deve rimanere lo stesso per conservare il contenitore dell’app e usare lo stesso slot.

1. Se l’app precedente si apre, esporta un backup da Impostazioni e salvalo fuori dall’app in File/iCloud Drive. Se la firma è scaduta, puoi prima rinnovarla con lo stesso IPA e Apple ID.
2. In Sideloadly seleziona `QuadernoLocale-Base-unsigned.ipa`, il tuo iPhone e lo stesso Apple ID usato per Abitudini Locale. Mantieni le stesse opzioni di bundle ID; non creare una seconda identità e non disinstallare la vecchia app.
3. Premi Start e completa personalmente eventuali richieste di autenticazione Apple. Non inviare password o codici in chat.
4. Apri Quaderno Locale: il tracker è nella scheda Abitudini e lo storico resta nel medesimo archivio. Le nuove schede sono Oggi, Agenda, Diario e Altro.
5. Prima di usare allegati o iniziare a scrivere, prova un nuovo backup completo da Altro → Preferenze, privacy ed esportazione → Prepara backup completo JSON → Salva o condividi → Salva su File.

## Primo utilizzo

- Oggi: cattura attività/eventi/note e registra un check-in. Scrivi nel diario apre una pagina personale; Modelli propone dieci strutture modificabili.
- Agenda: giorno, settimana, mese e Future log. Rivedi le attività precedenti e scegli se migrarle o lasciarle andare. Le ricorrenze si creano quando completi un’attività.
- Diario: quaderni, etichette, ricerca e preferiti. Puoi allegare fino a quattro foto, un disegno e una registrazione fino a 120 secondi.
- Altro: indice, ricordi, revisioni con anno in pixel, backup e collegamento al Watch. Il sonno, l’energia e l’umore sono inserimenti personali, non letture automatiche da Salute.
- Protezione: attiva il blocco del quaderno per richiedere l’autenticazione del dispositivo al rientro. Il backup JSON esportato resta un file leggibile.

## Apple Watch Ultra con l’account gratuito

Percorso tramite le app Apple: chiedi a Siri sul Watch di creare un promemoria nella lista che scegli. Su iPhone apri Altro → Importa da Promemoria, concedi l’accesso e scegli quella lista. Importa attività non completate. Gli originali restano in Promemoria e le importazioni ripetute non aggiungono gli stessi elementi.

Il pacchetto `QuadernoLocale-Watch-unsigned.ipa`, se disponibile dopo la build, contiene anche la companion nativa e una complicazione di cattura rapida. La compilazione senza firma non dimostra l’installazione sul Watch. Non usare quel pacchetto come prova di compatibilità con Sideloadly: Apple Watch, iPhone e le estensioni richiedono profili coerenti. Con un Mac e Xcode si possono verificare i test personali con un Personal Team gratuito; senza Mac può servire un percorso di firma/distribuzione diverso. Non è richiesto acquistare una membership per usare la versione iPhone qui preparata.

Quando la companion è installata, attiva Altro → Apple Watch → Invia il riepilogo. Il Watch mantiene le catture in coda e attende la conferma dell’iPhone. Il riepilogo può essere meno recente dello stato sul telefono: la consegna è decisa da watchOS e può richiedere di aprire l’app su entrambi i dispositivi. Il tasto Azione Ultra si configura personalmente con un comando rapido compatibile.

La versione Watch e la firma sul dispositivo vanno verificate separatamente. Il documento VERIFICA.json riporta ciò che è stato effettivamente compilato e testato.
