# Promessa condivisa — piano gratuito e offline

La versione 1.1 mantiene l'app locale e aggiunge una condivisione facoltativa con Firebase Authentication (email/password) e Cloud Firestore Standard. **Non effettuare pagamenti, non aggiungere carte e non attivare Blaze, runner a pagamento, servizi a consumo o acquisti.** Il progetto Firebase deve restare Spark. La sezione Budget registra importi manualmente: nessun pagamento viene eseguito.

## Configurazione predisposta

- Progetto dell'utente: `promessa-condivisa`, piano Spark, senza fatturazione collegata durante questa configurazione.
- Firestore Standard `(default)` nella regione `europe-west8` (Milano), inizializzato in produzione e protetto dalle regole in `Firebase/firestore.rules`.
- Provider email/password attivo; nessun accesso anonimo, SMS, Google Sign-In, Cloud Functions, Storage o servizio AI richiesto.
- `App/GoogleService-Info.plist` contiene i normali identificatori pubblici del client Firebase, non credenziali amministrative. Le password non sono nel codice. La protezione dei dati dipende dalle regole e dall'autenticazione, non dalla segretezza di questo file.
- I sorgenti sono nel repository pubblico già esistente, ramo `promessa-wedding`, cartella WeddingPlanner. Nessun dato del matrimonio è nel repository. I job usano runner standard gratuiti per repository pubblici. Non vengono creati account a pagamento o modificati limiti di spesa.

Documentazione ufficiale: [piani Firebase](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans), [quote Firestore](https://firebase.google.com/docs/firestore/quotas), [API key Firebase](https://firebase.google.com/docs/projects/api-keys), [GitHub Actions](https://docs.github.com/en/actions/concepts/billing-and-usage).

## Prima installazione e aggiornamento

1. Esportare un backup da Promessa → Organizza → Impostazioni e backup.
2. Sul tuo telefono, installare l'IPA 1.1 sopra Promessa con Sideloadly, usando lo stesso Apple ID e bundle ID dell'installazione precedente, senza disinstallare.
3. Sul telefono del partner installare lo stesso IPA tramite Sideloadly, usando il suo Apple ID. I due account Apple possono essere diversi: i dati condivisi sono associati ai vostri accessi Firebase.
4. Restano validi i normali limiti della firma gratuita Apple: tre app simultanee e rinnovo dopo sette giorni. L'app non richiede abbonamenti Apple a pagamento né HealthKit, App Groups, iCloud o altre capability a pagamento.

## Collegare i due telefoni

Sul primo iPhone (quello con i dati che vuoi condividere):

1. Organizza → Condividi con il partner.
2. Crea un account con la tua email personale e una password di almeno 12 caratteri. La password viene inserita personalmente sul telefono e gestita da Firebase. Non inviarla in chat e non usare la stessa password tra voi.
3. Apri l'email di verifica, premi il link, poi torna nell'app e premi **Ho verificato l'email**.
4. Premi **Condividi i dati presenti su questo iPhone** e conferma il caricamento. Solo questo telefono deve creare il matrimonio. La prima sincronizzazione richiede rete e può impiegare qualche minuto con molti dati.
5. Attendi il completamento dell'invio, inserisci l'email personale del partner e premi **Crea / rinnova invito privato**.
6. Condividi manualmente il codice generato. L'app non invia messaggi al partner automaticamente. L'invito è riservato all'email indicata, utilizzabile una sola volta per 48 ore. Un nuovo codice invalida quello precedente.

Sul secondo iPhone:

1. Crea un account personale con la stessa email indicata nell'invito e verifica l'email.
2. Incolla il codice in **Codice invito ricevuto** e premi **Accetta invito del partner**.
3. Conferma il collegamento. I dati condivisi sostituiscono la vista locale, senza unire due matrimoni diversi. Prima viene conservato un backup locale.
4. Quando entrambi siete connessi, una modifica viene ricevuta dall'altro telefono tramite aggiornamenti Firestore in tempo reale. La scheda Oggi mostra lo stato di condivisione; la pagina Condivisione mostra coda, ultimo contatto col server ed eventuali conflitti.

## Offline, conflitti e protezione dei dati

- L'archivio JSON protetto sul telefono resta la fonte dei dati visualizzati offline. Ogni modifica e la relativa coda di invio sono salvate **nello stesso aggiornamento atomico**. Chiudere l'app o riavviare il telefono non deve perdere la coda.
- Senza connessione potete continuare a lavorare sui dati già scaricati. Al ritorno della rete riaprire o tenere attiva l'app: l'invio riprende automaticamente. Non è promessa una sincronizzazione a app chiusa; non viene usato un servizio push in background.
- Primo accesso, verifica email, primo collegamento, inviti e accettazione richiedono internet.
- Si sincronizzano voci separate e solo i campi effettivamente modificati. Le preferenze dei promemoria restano personali al telefono.
- Le transazioni leggono la versione corrente del documento sul server e confrontano i campi con la versione da cui è iniziata la modifica. Campi diversi si uniscono; cambiamenti incompatibili sullo stesso campo restano in coda e vengono mostrati in **Modifiche da confrontare**. Puoi mantenere le modifiche locali o usare la versione condivisa, con conferma.
- Le bozze già aperte proteggono anche gli aggiornamenti ricevuti mentre stai scrivendo: campi non modificati localmente conservano gli aggiornamenti del partner. Se lo stesso campo cambia, il salvataggio chiede di riaprire la voce invece di sovrascriverlo.
- I pagamenti sono registrazioni separate, identificate da UUID, per non perdere due versamenti aggiunti contemporaneamente. Se una spesa viene eliminata mentre restano pagamenti, spesa e importi rimangono recuperabili nella vista/backup con un avviso: bisogna scegliere se ripristinarli o confermare l'eliminazione. Nessuna operazione bancaria viene effettuata.
- Le eliminazioni sono rappresentate da record eliminati sul server (tombstone), così un client offline vecchio non ricrea automaticamente una voce. Riferimenti a tavoli/fornitori rimossi vengono scollegati nella vista, conservando i record dipendenti.
- La valuta resta fissa durante la condivisione per non reinterpretare importi inseriti dall'altro telefono. Non sono effettuate conversioni.
- Non disinstallare né cambiare account con modifiche non inviate, salvo averle prima esportate e aver confermato di scartarle. Se una scrittura viene rifiutata o finisce la quota, la coda resta sul dispositivo.

## Backup, uscita e revoca

Il backup JSON esportato contiene i dati del matrimonio, senza credenziali, account cloud o coda di collegamento. È una copia portabile, non un secondo sistema di sincronizzazione. CSV resta disponibile per invitati e programma.

Prima del collegamento è conservato `Application Support/Promessa/prima-condivisione.json`, esportabile dalle Impostazioni. Una riconnessione da un archivio vuoto non sovrascrive un backup personale già presente. È comunque consigliato esportare copie periodiche in File, anche iCloud Drive se desiderato.

Durante la condivisione, ripristino totale e cancellazione totale sono bloccati per evitare di propagare cancellazioni involontarie. **Esci dall'account** rimuove la copia condivisa e la coda da questo telefono (con conferma esplicita se non ancora inviata), senza cancellare dati sul server o sul telefono del partner. Il backup personale precedente al collegamento viene conservato; la cancellazione totale locale, quando scollegati, elimina anche quel backup.

Il proprietario può **Revocare l'accesso del partner**: le regole bloccano nuove letture/scritture sul server e l'invito precedente viene invalidato. Non è possibile cancellare da remoto copie offline e backup già scaricati. Per ricollegarsi dopo revoca, uscire e accettare un nuovo invito destinato alla stessa email.

## Privacy e limiti

Condividendo autorizzi l'invio su Firebase dei dati inseriti: invitati e contatti, allergie/preferenze, note, programma e importi. Le connessioni usano TLS; i dati non sono cifrati end-to-end dall'app. Google fornisce infrastruttura e autenticazione, e l'amministratore del progetto può accedere dal pannello. Le regole del client autorizzano i due membri; sapere il nome del progetto o l'ID del matrimonio non dà accesso ai contenuti.

Il piano Spark ha quote gratuite finite. Se vengono esaurite, le operazioni possono essere bloccate e l'app continua con i dati locali: **non si attiva automaticamente un piano a pagamento**. Nessuna garanzia di disponibilità continua o sincronizzazione istantanea senza rete. Non sono implementati collaborazione oltre due persone, messaggistica, allegati cloud, notifiche remote o PDF.

L'archivio locale resta limitato a 20 MB e 50.000 voci; la metainformazione di sincronizzazione usa parte dello spazio. Le singole voci condivise sono limitate a circa 800 KB, sotto il limite documento Firestore. Righe e registrazioni eliminate sul server restano come tombstone fino a una futura manutenzione esplicita; non vengono attivati servizi di pulizia a pagamento.

## Compilazione e prove

XcodeGen usa Firebase Apple SDK **12.19.2** fissato esattamente, compilatore Xcode **26.2** su runner standard **macos-26**, iOS minimo **17.0**. Le app esistenti restano intatte. `swift test` verifica il Core senza Firebase; il job security usa Node 22, Java 21 e gli emulatori locali con progetto `demo-promessa`, senza credenziali o dati reali. I test UI usano storage isolato e un endpoint Auth di emulazione locale, senza contattare il progetto reale.

```sh
cd WeddingPlanner
swift test
xcodegen generate --spec project.json
xcodebuild build -project Promessa.xcodeproj -scheme Promessa -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
cd Firebase
npm ci --ignore-scripts
npm test
```

Il workflow `.github/workflows/promessa.yml` prepara IPA, sorgenti, log e screenshot. Le regole pubblicate devono corrispondere al file testato. I risultati specifici della release sono riportati nel collaudo della cartella di distribuzione. La compilazione e gli emulatori non sostituiscono la prova di firma personale e sincronizzazione sui due iPhone fisici.
