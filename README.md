# Abitudini Locale 1.1

La schermata principale ora è un tracker ispirato alle funzioni e schermate pubbliche di HabitKit: https://habitkit.app/ e https://habitkit.app/help. È una realizzazione indipendente; non è una copia perfetta e non importa i backup proprietari di HabitKit.

## Tracker delle abitudini

- Schede colorate con griglie a colonne settimanali, vista compatta o a due colonne; anno scorrevole nel dettaglio.
- Spunta di oggi con annullamento, contatori interi o misure con tre decimali e unità personalizzata, quantità conservate anche oltre il traguardo.
- Abitudini da costruire o abbandonare. Per queste ultime serve una registrazione esplicita; un giorno non registrato non è un successo. Il limite numerico è stretto: meno del valore scelto.
- Giorni previsti e obiettivi giornalieri, settimanali e mensili. Un giorno vale al massimo una volta, anche con quantità maggiori. Serie e record contano giorni previsti o periodi riusciti; il periodo corrente aperto non interrompe la serie.
- Calendario con giorni colorati, modifica delle registrazioni passate e note, nessuna registrazione futura. Non si possono modificare manualmente i valori automatici di Salute/Screen Time.
- Categorie, filtri, riordino, archivio, eliminazione confermata; 36 colori e 101 simboli di sistema.
- Check-in quotidiano opzionale a un orario scelto dalle Impostazioni.
- Fino a tre orari di promemoria per abitudine, nei giorni selezionati. Limite globale di 60 richieste: un orario quotidiano usa una sola richiesta, mentre i giorni selezionati richiedono una richiesta ciascuno; richiedono il consenso notifiche e iOS può ritardarle per Focus o altre impostazioni.
- Grafici mensili, tasso nei giorni previsti conclusi (oggi incluso solo se già completato), serie, record, condivisione della griglia PNG e registrazioni CSV, backup JSON in File/iCloud Drive.
- Widget configurabili per una specifica abitudine o le prime dell’elenco; spunte e incrementi interattivi. La prova sul telefono resta necessaria.

I blocchi già preparati restano in Impostazioni → Blocchi e regole di sblocco. Le abitudini da abbandonare non si collegano ai blocchi. I vecchi backup JSON dell’app sono compatibili; i nuovi campi sono opzionali. Esporta una copia prima di aggiornare o cambiare tipo di pacchetto.

## Installazione dei widget

Il pacchetto Widgets ora include soltanto tracker, widget e Live Activity, senza HealthKit o Family Controls. Per tentare l’installazione con Sideloadly, conserva le estensioni (non usare Remove App Extensions). Dopo l’installazione apri l’app, controlla in Impostazioni che Archivio condiviso sia disponibile, poi Home → pressione prolungata → Modifica → Aggiungi widget → Abitudini Locale. Con una pressione prolungata sul widget scegli Modifica widget per selezionare l’abitudine.

La sola installazione dell’app non garantisce l’App Group: deve essere autorizzato dai profili e mantenuto dal risigner. Se viene cambiato l’identificatore condiviso, anche HabitAppGroup in Info.plist deve corrispondere. Senza il contenitore condiviso il widget mostra una richiesta di configurazione, non dati inventati. Non è stata verificata la firma con l’account gratuito dell’utente. Il pacchetto Base rimane l’alternativa senza estensioni; il pacchetto Completa conserva Salute e Screen Time con i relativi profili.

Le funzioni di pagamento, gli account e le integrazioni private non sono inclusi. La condivisione PNG usa il tema dell’app e il colore dell’abitudine, senza un editor separato dei temi.

---

# Abitudini Locale

App iPhone nativa SwiftUI (iOS 18+), indipendente e ispirata al flusso di Habits First di Eric Su. Non è affiliata all'originale e non riproduce tutte le sue funzioni o ogni schermata. Le schermate pubbliche sono state usate come riferimento visivo; non viene incluso codice, grafica o infrastruttura privata dell'app originale.

## Tre configurazioni reali

| Pacchetto | Funzioni compilate | Firma e stato sul dispositivo |
| --- | --- | --- |
| Base | Abitudini manuali, contatori, timer, storico, bozze di regole, Comandi Rapidi, backup | Non contiene Family Controls, HealthKit o widget. È il candidato per la firma gratuita con Sideloadly. Non blocca altre app. |
| Widgets | Base + widget Home/Lock Screen interattivi, heatmap, Live Activity/Dynamic Island | App ed estensione richiedono profili coerenti e App Group. La tabella Apple consultata elencava App Groups anche per account gratuiti; l'effettiva preservazione delle capability da parte dello strumento di firma deve essere verificata sul telefono. |
| Completa | Widgets + FamilyActivityPicker, shield ManagedSettings, monitor DeviceActivity, sblocchi, report protetto Screen Time | Richiede Apple Developer Program e profili Family Controls validi per app ed estensioni. La compilazione senza firma non dimostra che questi diritti siano concessi. |

Lo stato delle verifiche è registrato in VERIFICA.json quando disponibile. Nessun blocco viene simulato come se fosse reale. Il pacchetto Base rifiuta l'attivazione delle regole e l'app completa verifica autorizzazione, archivio condiviso e configurazione del monitoraggio prima di presentarlo come pronto.

## Funzioni implementate

- Abitudini a spunta, contatori ripetibili, timer di studio, passi, allenamenti, mindfulness, soglia giornaliera di utilizzo app e aggiornamento da Comandi Rapidi (secondo il pacchetto).
- Obiettivi, limite di uno sblocco al giorno, icone, colori, archiviazione e storico con heatmap delle ultime 12 settimane.
- Una sessione timer attiva per volta, conteggio monotono quando disponibile, suddivisione a mezzanotte e scelta tra pausa quando lasci l'app e conteggio in background. I timer in primo piano di un processo terminato non continuano a guadagnare progresso.
- Regole con tutte/una/almeno N abitudini, crediti guadagnati separati dagli sblocchi consumati, giorni della settimana e fasce anche notturne (minimo 15 minuti).
- Sblocco fino a fine giornata, per tempo continuo o per minuti cumulativi di uso effettivo. I blocchi sovrapposti mantengono la restrizione finché ogni regola pertinente è sbloccata.
- Impegni temporanei che impediscono modifiche dall'app, tre emergenze nell'archivio locale, pausa globale di un'ora con richiamo DeviceActivity.
- Due tipi di widget con più famiglie Home/Lock Screen, progressi e spunte interattive; Live Activity del timer.
- Lettura Salute su richiesta e all'apertura dell'app, somma passi e unione temporale degli allenamenti/meditazioni sovrapposti. Un ritorno zero non cancella dati precedentemente osservati, perché HealthKit nasconde l'eventuale rifiuto di lettura.
- App Intents: aggiungi quantità, imposta totale giornaliero in modo idempotente, avvia/ferma timer; utilizzabili in Comandi Rapidi e Action Button.
- Salvataggio atomico, blocco di file tra app/widget/monitor, copia precedente, validazione backup e ripristino confermato. Ripristinare disattiva le regole, azzera le selezioni delle app e rimuove gli impegni: è necessario riconfigurare prima di riattivare.
- Archivio locale e backup JSON esportabile nella cartella iCloud Drive scelta dall'utente in File. Nessuna sincronizzazione automatica.

## Limiti espliciti

Non sono implementati: account e sincronizzazione cloud dell'originale, posizione/checkpoint/vacanza, Bluetooth, NFC, cicli automatici lavoro/pausa, integrazioni dirette AnkiWeb/KOReader/Chess.com/Duolingo/GitHub/Audiobookshelf/Jellyfin, server webhook o paywall. L'integrazione generica con Comandi Rapidi non viene presentata come integrazione diretta con questi servizi o con Studio Locale.

Massimo otto blocchi e 200 abitudini per contenere il numero di monitor e il carico delle estensioni. I widget mostrano le prime abitudini attive dell'elenco. WidgetKit decide i tempi di aggiornamento. L'obiettivo app-time rileva una soglia al giorno, non una misurazione continua esportata dell'intero uso del telefono. I dati reali del report restano nell'estensione DeviceActivityReport e non vengono esportati ai widget o nel backup.

I callback Screen Time sono gestiti da iOS e possono arrivare in ritardo. Gli sblocchi continui più corti di 16 minuti usano l'avviso di fine di un intervallo DeviceActivity più lungo; questo deve essere verificato su un dispositivo autorizzato. L'autorizzazione individuale resta revocabile. Gli impegni locali e il contatore emergenze non rendono il telefono inviolabile: orologio modificato, autorizzazioni revocate, reinstallazione e manomissione dell'archivio non sono protetti da un server o da gestione MDM.

## Build da Windows con GitHub Actions

Il workflow esegue i test core su macOS, compila tre IPA arm64 senza firma e svolge un flusso UI sul simulatore per il pacchetto Base. Le estensioni vengono compilate contro il vero SDK iOS; la loro esecuzione autorizzata non è simulata nei test.

Artifact: `AbitudiniLocale-Base-IPA`, `AbitudiniLocale-Extensions-IPA`, `AbitudiniLocale-UI-verification`.

Per il Base seleziona l'IPA in Sideloadly. Per i pacchetti con capability, i profili dell'app e di ciascuna estensione devono autorizzare gli entitlements effettivi e usare lo stesso App Group; rimuovere gli entitlements per far passare la firma disabilita le funzioni. L'App Group predefinito è `group.local.abitudinilocale.shared`: impostalo a un identificatore registrato e coerente nei profili e nel progetto. Un risigner che cambia automaticamente i bundle/App Group ID può richiedere modifiche anche alla proprietà Info.plist `HabitAppGroup`.

La versione completa va firmata nel cloud con certificato e profili di sviluppo del titolare, registrando l'iPhone; non richiede necessariamente un Mac personale. Chiavi private e profili non vanno committati o inviati in chat. Il progetto non contiene credenziali o una configurazione che acquisti/iscriva automaticamente al programma Apple.

Prima di cambiare pacchetto esporta un backup: il Base usa l'archivio privato dell'app, mentre i pacchetti con un App Group disponibile usano quello condiviso. Ripristina il backup nella nuova configurazione. L'aggiornamento del pacchetto non trasferisce automaticamente i dati tra questi due contenitori.

## Membership Apple

Apple indica 99 USD per anno, con prezzo in valuta locale mostrato all'iscrizione. Per lo sviluppo sul proprio dispositivo serve la membership con Family Controls Development; l'approvazione Family Controls Distribution è distinta e serve per TestFlight/App Store, anche per le relative estensioni.

- https://developer.apple.com/programs/enroll/
- https://developer.apple.com/help/account/reference/supported-capabilities-ios
- https://developer.apple.com/documentation/xcode/configuring-family-controls
- https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement

Analisi delle funzioni pubbliche dell'originale e relative fonti: ANALISI.json.

## Sviluppo su Mac

`swift test`, `brew install xcodegen`, poi `xcodegen generate --spec project.json` (Base), `project-widgets.json` oppure `project-full.json`. Apri AbitudiniLocale.xcodeproj. Il progetto usa framework Apple di sistema senza dipendenze esterne.

## Verifica della versione 1.1

I risultati e gli hash degli IPA sono in VERIFICA.json. Sono passati i 20 test del motore e la compilazione nativa arm64 dei tre pacchetti. La verifica UI è riportata separatamente: nessuna prova sul telefono, delle notifiche reali, dei dati condivisi dei widget o dei blocchi Screen Time viene dedotta dalla sola compilazione. Gli IPA sono senza firma.

Il flusso UI Base è passato sul simulatore iPhone 16 Pro con iOS 18.5: creazione, spunta, nota, annullamento della spunta, statistiche e impostazioni. Durata del caso: 80,126 secondi. Le quattro schermate reali sono incluse in VerificaSchermate nello ZIP dei sorgenti consegnato. I dati “Lettura” delle schermate sono dati del test.

Build e verifica riuscite: https://github.com/AntoMorro/abitudini-locale-ios/actions/runs/41520832819

Il dettaglio e i grafici usano contenitori a scorrimento per evitare un ciclo del layout della lista nativa. Un probe diagnostico opzionale ha segnalato un errore nella propria asserzione di disponibilità, pur catturando il dettaglio renderizzato. Questo non viene dichiarato un probe superato: la prova funzionale principale è il test UI completo riuscito. Il relativo script diagnostico è stato corretto e controllato sintatticamente, senza ripetere la build applicativa già verificata.

L’installazione fisica e la firma gratuita con App Group restano da eseguire. Il controllo Windows di Sideloadly non era disponibile durante la consegna; carica personalmente l’IPA e completa l’eventuale autenticazione Apple.
