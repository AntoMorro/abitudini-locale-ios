# Quaderno Locale 2.0

Aggiornamento nativo di Abitudini Locale: bullet journal, diario e tracker in un'unica app iPhone/iPad. Mantiene `local.abitudinilocale.habits` e la cartella del vecchio archivio. Il backup precedente è compatibile. Per aggiornare senza perdere dati, esportare una copia e installare sopra l'app con lo stesso Apple ID e la stessa configurazione di bundle ID usata in Sideloadly; non disinstallare l'app.

## Bullet journal e diario

Registro rapido con attività, eventi e note; importanza, completamento, annullamento e migrazione esplicita. Giorno/settimana/mese/future log sono viste degli stessi elementi, senza creare copie automatiche. Le ricorrenze giornaliere, feriali, settimanali e mensili generano una prossima istanza al completamento; una richiesta ripetuta non genera duplicati. I promemoria precedenti non si trasferiscono automaticamente alle nuove istanze.

Quaderni personalizzabili e archiviabili, indice numerato, ricerca nel testo e nelle etichette, preferiti, ricordi degli anni precedenti. Dieci modelli originali: pagina libera, mattino, sera, gratitudine, settimana, mese, lettura, raccolte, progetti e visione annuale. Check-in con umore, energia e ore di sonno inserite manualmente; grafico descrittivo degli ultimi 30 giorni.

Foto selezionate con il picker di sistema e ridimensionate; disegni a mano libera con PencilKit; audio fino a 120 secondi. Massimo quattro foto per pagina. Il backup JSON comprende anche gli allegati. Esportazione Markdown testuale e PDF con foto/disegni; l'audio rimane nel backup, non nel PDF. Protezione visiva dell'accesso con autenticazione del dispositivo e copertura delle schermate quando si esce dall'app. I backup esportati non sono cifrati dall'app.

Il tracker precedente resta disponibile con storico, calendari, contatori, obiettivi e statistiche. I vecchi backup senza journal conservano il journal già presente durante il ripristino. Un backup completo contenente journal sostituisce invece l'archivio previa conferma nell'interfaccia esistente.

## Apple Watch Ultra

La companion watchOS 11+ contiene cattura con tastiera/dettatura di sistema, umore e completamento di attività/abitudini a spunta. Le altre abitudini vengono mostrate in sola lettura. Una coda locale conserva le azioni e le rimuove solo dopo una conferma dell'iPhone. I comandi hanno un identificatore; note e completamenti sono idempotenti. Le bozze rifiutate rimangono sul Watch. Le azioni oltre 30 giorni richiedono recupero manuale.

Invio al Watch disattivato di default: attivarlo in Altro → Apple Watch. Viene inviato soltanto un riepilogo limitato di attività, abitudini e check-in, non l'intero diario. Il widget/complicazione apre la cattura rapida; non simula dati non disponibili. App Intent e comando rapido per aprire la cattura, assegnabile dall'utente al tasto Azione Ultra quando la companion è installata.

`project-watch.json` compila il pacchetto iPhone + Watch + complicazione. La firma e l'installazione sul Watch reale non sono dimostrate dalla build senza firma. Con Windows/Sideloadly e Apple ID gratuito non viene promessa l'installazione della companion: può essere necessario un passaggio su Mac con Xcode o una distribuzione con profili appropriati. Un account gratuito può fare test personali tramite Xcode; non si assume che una membership a pagamento sia sempre indispensabile.

Percorso con app Apple già presenti: chiedere a Siri sul Watch di creare un promemoria in una lista personale, quindi importare quella lista dal journal su iPhone. L'importazione richiede il consenso iOS, importa solo elementi non completati, evita duplicati e non modifica gli originali. La sincronizzazione della lista tra Watch e iPhone dipende dalle impostazioni Apple dell'utente. Nessuna sincronizzazione in tempo reale con Promemoria viene simulata.

## Archivio, notifiche e installazione

Archivio locale, senza account del journal o analytics. Backup completo JSON salvabile manualmente in File/iCloud Drive; nessuna sincronizzazione iCloud automatica del journal. Dimensione massima 90 MB. Pagine fino a 10.000, annotazioni rapide fino a 30.000. Per archivi con molte foto, esportare copie e liberare allegati non necessari.

Notifiche di abitudini e journal condividono un budget di 60 richieste; priorità ai promemoria delle abitudini, poi al diario e alle prossime attività. iOS può ritardarle secondo Focus e altre impostazioni. Le notifiche del journal usano testo generico per non mostrare il contenuto personale.

Il pacchetto Base è il candidato per l'installazione gratuita iPhone con Sideloadly e aggiorna l'app esistente, evitando un quarto slot. Il pacchetto Watch è separato e richiede verifica di firma. I progetti opzionali con widget/HealthKit/Screen Time dell'app precedente rimangono nei sorgenti; non sono inclusi nel pacchetto Base. Le capability devono essere autorizzate dai profili, non vengono simulate.

## Fonti e verifica

Realizzazione indipendente, con modelli e interfaccia originali. Riferimenti: [metodo Bullet Journal](https://bulletjournal.com/pages/migration), [setup pubblico AmandaRachLee](https://www.youtube.com/watch?v=erf7mDtZw9k), [modelli Day One](https://dayoneapp.com/guides/tips-and-tutorials/templates/), [umore Daylio](https://daylio.net/faq/docs/daylio-faq/tutorials/create-and-manage-moods/), [Diario Apple](https://support.apple.com/it-it/guide/iphone/iph9824e83ce/27/ios/27).

Integrazioni: [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity), [Siri su Apple Watch](https://support.apple.com/it-it/guide/watch/apd60099a41a/27/watchos/27), [account Apple e Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account). Lo stato effettivo delle build e dei test è riportato in VERIFICA.json quando disponibile; nessun dato personale nei test CI.
