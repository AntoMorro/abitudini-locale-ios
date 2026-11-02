# Abitudini Locale

App iPhone nativa SwiftUI (iOS 18+), indipendente e ispirata al flusso di Habits First di Eric Su. Non è affiliata all'originale e non riproduce tutte le sue funzioni o ogni schermata. Le schermate pubbliche sono state usate come riferimento visivo; non viene incluso codice, grafica o infrastruttura privata dell'app originale.

## Tre configurazioni reali

| Pacchetto | Funzioni compilate | Firma e stato sul dispositivo |
| --- | --- | --- |
| Base | Abitudini manuali, contatori, timer, storico, bozze di regole, Comandi Rapidi, backup | Non contiene Family Controls, HealthKit o widget. È il candidato per la firma gratuita con Sideloadly. Non blocca altre app. |
| Widgets | Base + Salute, widget Home/Lock Screen interattivi, heatmap, Live Activity/Dynamic Island | App ed estensione richiedono profili coerenti, HealthKit e App Group. La tabella Apple attuale elenca App Groups e HealthKit anche per account gratuiti; l'effettiva preservazione delle capability da parte dello strumento di firma deve essere verificata sul telefono. |
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

## Membership Apple

Apple indica 99 USD per anno, con prezzo in valuta locale mostrato all'iscrizione. Per lo sviluppo sul proprio dispositivo serve la membership con Family Controls Development; l'approvazione Family Controls Distribution è distinta e serve per TestFlight/App Store, anche per le relative estensioni.

- https://developer.apple.com/programs/enroll/
- https://developer.apple.com/help/account/reference/supported-capabilities-ios
- https://developer.apple.com/documentation/xcode/configuring-family-controls
- https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement

Analisi delle funzioni pubbliche dell'originale e relative fonti: ANALISI.json.

## Sviluppo su Mac

`swift test`, `brew install xcodegen`, poi `xcodegen generate --spec project.json` (Base), `project-widgets.json` oppure `project-full.json`. Apri AbitudiniLocale.xcodeproj. Il progetto usa framework Apple di sistema senza dipendenze esterne.
