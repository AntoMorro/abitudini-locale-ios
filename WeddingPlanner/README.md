# Promessa — wedding planner locale

App nativa SwiftUI per iPhone, iOS 17 o successivo. Progetto separato: non sostituisce Quaderno, Abitudini o le altre app. Bundle ID `local.promessa.wedding`. Uso locale senza account, oppure condivisione Firebase facoltativa con due accessi personali. Nessun analytics, chatbot o integrazione AI. Tutti i contenuti sono inseriti dall'utente. Il reel Instagram fornito non è risultato accessibile durante lo sviluppo: nessuna pretesa di averne riprodotto funzioni non osservate.

## Funzioni

- Oggi: data, luogo, conto alla rovescia per giorni di calendario, RSVP, checklist completata, scadenze scadute/prossime, prossima spesa, agenda e tavoli.
- Attività: checklist personalizzabile con categoria, scadenza, priorità, stato, responsabile, note e fornitore; calendario per giorno, ricerca, filtri e ordinamento.
- Budget: importi interi nell'unità minima della valuta (centesimi per EUR), budget totale e per categoria, previsioni, preventivi, registro dei pagamenti con date e note, saldi e avvisi. EUR iniziale; anche USD, GBP, CHF, CAD, AUD, JPY. Nessuna conversione: cambio valuta consentito soltanto senza importi registrati. Un preventivo sostituisce la previsione nel costo impegnato. I costi indicativi dei fornitori non si sommano alle spese. Un saldo negativo viene mostrato separatamente come pagamento eccedente. Il budget utilizzato include il maggiore tra preventivo/previsione e pagato per ciascuna spesa, quindi anche gli esborsi oltre preventivo.
- Invitati: nominativo, nucleo/gruppo, RSVP, accompagnatori, alimentazione, allergie, note, tavolo; ricerca, filtri, conferma tramite swipe e menu RSVP. Conteggi persone separati dai nominativi. Il nominativo e i suoi accompagnatori occupano un unico tavolo. I non partecipanti non occupano posti.
- Fornitori: categoria/servizio, contatto, costo indicativo, stato, scadenza, note, elenco delle attività/spese/momenti collegati. Condivisione manuale di un testo da completare, senza invii automatici.
- Programma: data/ora, durata, luogo, descrizione, responsabile, fornitore; ordine cronologico o manuale con Modifica; avviso di sovrapposizione. Supporta anche appuntamenti prima del matrimonio.
- Sala: pianta con tavoli trascinabili e coordinate normalizzate; tocco sul tavolo per assegnare, rimuovere o trasferire l'intero nucleo. Elenco equivalente, cursori accessibili per posizione, capienza/categorie/note, conteggi posti liberi/occupati, avvisi oltre capienza e persone senza tavolo. Nessuna assegnazione automatica.
- Note: generali oppure collegate a un invitato, fornitore o attività; ricerca globale tra tutti gli archivi.
- Impostazioni: backup JSON completo, ripristino validato con anteprima/conferma, esportazione invitati e programma CSV UTF-8 con BOM, eliminazione totale con conferma, promemoria locali facoltativi.

## Dati, sicurezza e limiti

Riutilizza lo stack e il modello di archiviazione JSON validata/atomica con lock dei progetti precedenti. Il dominio matrimonio è indipendente perché dati e relazioni sono diversi. Firebase Apple SDK 12.19.2 via Swift Package Manager, prodotti FirebaseAuth e FirebaseFirestore; nessun SDK Analytics o AI.

Archivio privato in Application Support/Promessa/promessa.json; salvataggio atomico con protezione completa dei file iOS. Copia precedente in promessa.previous.json. Se il file è corrotto, l'app non lo sovrascrive: offre esportazione originale e ripristino. Un backup non valido non modifica l'archivio. Limite 20 MB e 50.000 voci, incluse le singole registrazioni di pagamento. Le versioni schema sconosciute sono rifiutate. Rimozione tavolo libera gli invitati; rimozione fornitore/attività/invitato conserva e scollega i record dipendenti.

Le esportazioni includono dati personali, comprese allergie: scegliere con attenzione dove salvarle e con chi condividerle. È possibile scegliere iCloud Drive nel selettore File come destinazione dei backup manuali. La condivisione automatica facoltativa usa invece Firebase, descritta in CONDIVISIONE.md. Disinstallando l'app i dati privati vengono rimossi: esportare prima un backup. La cancellazione totale azzera l'archivio corrente ed elimina la copia di recupero precedente; i backup già esportati non sono cancellati.

Promemoria: permesso iOS richiesto soltanto all'attivazione. Prossime 60 scadenze di attività aperte e saldi non pagati, aggiornate ad ogni modifica/apertura. Nessuna garanzia di avvisi se le notifiche sono disabilitate o la firma dell'app è scaduta. Dopo cambio fuso orario riaprire l'app. Categorie iniziali fisse; titoli attività e contenuti personalizzabili. Tavoli geometrici semplici: non è un CAD e non modella posti individuali numerati. PDF non implementato: gli export pratici disponibili sono CSV e JSON. Nessun widget o app Watch incluso in questa richiesta.

Interfaccia italiana, colori di sistema nelle aree di contenuto, testo dinamico, etichette VoiceOver; pianta con alternativa elenco. Verificare anche sul proprio dispositivo con le dimensioni testo preferite.

## Compilazione

Windows non include Xcode: il workflow `.github/workflows/promessa.yml` compila su `macos-26` con Xcode 26.2. La matrice ufficiale Apple include deployment iOS 17 per questa versione: https://developer.apple.com/xcode/system-requirements . Il deployment target dell'app è 17.0; il binario non viene generato con requisiti inferiori alterando il plist.

Da Mac con Xcode 26.2 e XcodeGen:

```sh
cd WeddingPlanner
swift test
brew install xcodegen
xcodegen generate --spec project.json
xcodebuild build -project Promessa.xcodeproj -scheme Promessa -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
mkdir -p build/package/Payload
cp -R build/device/Build/Products/Release-iphoneos/Promessa.app build/package/Payload/
cd build/package
zip -qry Promessa-unsigned.ipa Payload
```

Su GitHub aprire Actions → Promessa · Wedding planner. L'artefatto Promessa-IPA include IPA non firmato, sorgenti e impronta SHA-256. Il job UI separato compila e avvia test reali su simulatore iPhone; gli screenshot usano esclusivamente dati fittizi creati dai test in un archivio isolato.

## Installazione da Windows

1. Scaricare l'artefatto Promessa-IPA ed estrarre Promessa-unsigned.ipa. Verificare SHA-256 con VERIFICA.json (`Get-FileHash -Algorithm SHA256`).
2. Collegare iPhone sbloccato via USB, autorizzare questo PC. Il dispositivo deve apparire in Sideloadly. Installare i componenti Apple indicati dal sito ufficiale se il telefono non compare.
3. Trascinare l'IPA in Sideloadly, selezionare iPhone e inserire personalmente l'Apple ID nello strumento. Nessuna password nel codice o in chat. Mantenere il bundle ID automatico coerente negli aggiornamenti e lo stesso Apple ID. Non disinstallare per aggiornare.
4. Premere Start e completare personalmente gli eventuali passaggi di autenticazione. Se richiesto, autorizzare il profilo in Impostazioni → Generali → VPN e gestione dispositivo e attivare Modalità sviluppatore in Privacy e sicurezza.
5. Avviare Promessa. Esportare periodicamente un backup, soprattutto prima di aggiornamenti o modifiche alla firma.

La firma gratuita scade normalmente dopo 7 giorni; Sideloadly offre rinnovo automatico se configurato. Resta il limite di app firmate simultaneamente dell'account gratuito (già incontrato su questo dispositivo): Promessa è una nuova app e richiede un posto libero. Nessun pagamento richiesto dall'app. La firma usa i servizi Apple tramite Sideloadly; il funzionamento di Promessa resta offline. Documentazione verificata: https://sideloadly.io/ . Il test sul simulatore non verifica la firma personale né l'installazione sul telefono fisico.


## Condivisione opzionale

Dalla versione 1.1 è disponibile Organizza → Condividi con il partner. Consulta CONDIVISIONE.md per configurazione, privacy, accessi, offline e conflitti. I backup esportati non contengono credenziali o metadati di collegamento al cloud. Le preferenze notifiche restano personali al telefono. Durante la condivisione il ripristino e la cancellazione totale sono bloccati per evitare cancellazioni involontarie dei dati del partner; uscire prima dall'account.
