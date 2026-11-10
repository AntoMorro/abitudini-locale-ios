# Quaderno Locale 2.3 — Salute
Journal, abitudini e Salute nello stesso archivio iPhone. Aggiornamento Base 16, stesso bundle local.abitudinilocale.habits. Prima esportare un backup; installare sopra l’app con stesso Apple ID e bundle ID in Sideloadly, senza disinstallare.

## Schermate
- Stress e contesto: battito importato in finestre di 15 minuti, scostamento percentuale dalla baseline a riposo e contesto disponibile. Non misura stress psicologico, non è un monitor 24/7.
- Carico: medie 7/28 giorni, rapporto descrittivo, storico 30/60/180/365 giorni con interruzioni dove i dati sono incompleti. Session-RPE: minuti × RPE. Confermare i giorni completi, inclusi i riposi.
- Monitor salute: HRV, riposo, respirazione, SpO₂ e temperatura assoluta del polso. Baseline personale con almeno 14 giorni precedenti; una fonte mostrata per parametro. Nessuna previsione di malattia.
- Sonno avanzato: fasi originali, quota REM+profondo osservata, veglia interna, intervalli di risveglio e piano organizzativo di sonno con sveglia e latenza configurabili.
- Riepiloghi e widget: schede funzionanti nella Base. Quattro estensioni WidgetKit predisposte nella configurazione project-widgets.json; richiedono App Group e profili di firma compatibili. Condivisione disattivata inizialmente.

Le fasi Principale/Core/Essenziale corrispondono allo stesso valore interno core. Le fasi sconosciute restano un errore: non vengono convertite in sonno generico. I giorni mancanti non valgono zero.

## Importazione senza costi di API
I quattro comandi firmati già preparati importano HRV, riposo e sonno e li possono richiamare insieme. Non serve rifirmarli per questo aggiornamento. HRV/RHR e deduplicazione sono stati confermati dall’utente sul telefono; l’ultima correzione Principale e le nuove funzioni richiedono collaudo fisico.

Per gli altri parametri: Salute Apple → profilo → Esporta tutti i dati sanitari → salva ZIP in File → tocca ZIP per estrarlo. Nell’app scegli Importa Salute XML, seleziona periodo/tipi e poi export.xml. Lettura in streaming sul dispositivo; massimo 10.000 campioni selezionati per lotto, anteprima e conferma. Nessun caricamento a server. L’XML completo può essere grande; puoi annullare la lettura. I formati clinici CDA e i percorsi GPS non vengono importati.

Gli allenamenti XML non inventano RPE o copertura: completali nel registro. SpO₂ HealthKit nell’XML usa una frazione e viene convertita esplicitamente in percentuale; non si applica questa convenzione alla generica importazione JSON con unità %. Temperatura assoluta in °C/°F; gli scostamenti dalla baseline non vengono usati al suo posto.

## Metodi
Il monitor usa mediana ± 2 dispersioni robuste, con 1,4826 × MAD e pavimenti numerici dichiarati nell’app. HRV nel dominio logaritmico. Esclude il giorno corrente e richiede almeno 14 giorni precedenti su 28. Sono fasce descrittive, non intervalli clinici.

Il piano sonno parte dall’obiettivo scelto e può aggiungere il deficit medio osservato delle ultime 7 notti importate, arrotondato a 15 minuti, massimo 60 minuti extra, con almeno 3 notti; totale massimo 12 ore. È una regola organizzativa originale e disattivabile, non una previsione del fabbisogno biologico.

Le finestre cardiache vengono associate al sonno/allenamento soltanto se tutti i loro campioni rientrano negli intervalli noti. Il margine post-allenamento di 20 minuti è una convenzione di contesto. Non equivale a una misura clinica di stress o recupero.

## Privacy e limiti
Nessun account sanitario, backend, analytics o API a pagamento. La Base non richiede HealthKit nella firma. Backup JSON leggibile con dati sanitari: condivisione e salvataggio in iCloud Drive restano scelte personali. Nuove preferenze opzionali, compatibili con i vecchi backup. Snapshot widget minimo e separato, protetto, solo dopo opt-in con App Group; la visibilità dei widget dipende da iOS.

Non è una replica integrale di Athlytic o dei suoi algoritmi proprietari. Nessun rilevamento anticipato di malattia, stress fisiologico continuo, AI chat o allenamento live GPS viene dichiarato.

## Verifica
Test con dati fittizi e build su GitHub. Anteprime esplicitamente contrassegnate, archivio del simulatore isolato; generatore escluso da Release. L’esito UI è separato dal successo della compilazione. Il pacchetto contiene VERIFICA-RELEASE.json con hash IPA e commit e lo ZIP dei sorgenti.

Fonti: https://support.apple.com/it-it/108906 ; https://support.apple.com/guide/iphone/iph5ede58c3d/ios ; https://pubmed.ncbi.nlm.nih.gov/11708692/ ; https://aasm.org/resources/pdf/adultsleepdurationconsensus.pdf ; https://help.apple.com/xcode/mac/current/en.lproj/dev8dd3880fe.html .
