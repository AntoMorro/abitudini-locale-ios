# Quaderno Locale 2.1 — Salute in locale

Un unico archivio per journal, abitudini e Salute. Stesso bundle ID `local.abitudinilocale.habits`, stessa cartella Application Support/AbitudiniLocale/abitudini.json. Aggiornare sopra l’app precedente con stesso Apple ID e stessa configurazione di bundle ID in Sideloadly. Prima esportare un backup; non disinstallare.

## Salute

Oggi → icona cuore oppure Altro → Apri Salute. La sezione comprende panoramica, recupero personale, sonno, trend e carico degli allenamenti. Non richiede HealthKit nella firma: Comandi Rapidi legge i dati dopo il consenso dell’utente e li passa alle azioni native di importazione. Il percorso precedente Salute → Comandi Rapidi → nota è stato confermato dall’utente; le nuove azioni strutturate richiedono collaudo sul dispositivo dopo l’aggiornamento.

- HRV SDNN e frequenza a riposo con date originali, fonte e unità; importazioni ripetute aggiornano i campioni. HRV in secondi normalizzata in millisecondi, senza convertire SDNN in RMSSD.
- Sonno per segmenti, fasi, durata, efficienza quando sono presenti intervalli a letto, obiettivo personale, deficit osservato e regolarità del risveglio. Risoluzione degli intervalli sovrapposti e una sola fonte per notte.
- Grafici e statistiche a 7/28/90 giorni; correlazione HRV/riposo con numerosità e collegamenti descrittivi ai tag del diario. Giorni senza dati assenti dal grafico, mai riempiti con zero.
- Baseline robusta dei 28 giorni precedenti, almeno 14 giorni appaiati; esclusione del giorno corrente e sospensione dell’indice in caso di fonti miste non selezionate. L’indice composito è una formula originale sperimentale spiegata nell’app, non un algoritmo Athlytic o una percentuale fisiologica validata.
- Registro allenamenti manuale/JSON con session-RPE (minuti × RPE). Copertura dei giorni confermata dall’utente, includendo il riposo. Medie 7/28 giorni, rapporto, monotonia e strain soltanto con dati sufficienti. Nessuna previsione di infortuni.
- Archivio campioni con modifica/eliminazione, selezione delle fonti, importazione JSON atomica con anteprima, esportazione e backup completo. Supporto generico opzionale per battito, respirazione, SpO₂, temperatura, peso, VO₂ max, passi ed energia: richiedono campioni espliciti nelle unità indicate.

## Comandi nell’app

Sono disponibili le azioni `Importa HRV nel quaderno`, `Importa frequenza a riposo nel quaderno`, `Importa segmento sonno nel quaderno` e `Importa dati Salute JSON nel quaderno`. L’app contiene una guida e pulsanti per aprire/eseguire i comandi salvati, con nomi configurabili. I tre comandi vanno creati una volta in Comandi Rapidi sull’iPhone: l’app non può installarli o concedersi i permessi in silenzio. Per i dettagli vedere SALUTE-COMANDI.md.

## Privacy e compatibilità

Nessun account sanitario, backend, analytics o API a pagamento. I calcoli sono sul dispositivo. Nessuna nuova libreria esterna. L’esecuzione di Comandi Rapidi può richiedere il telefono sbloccato. Non è sincronizzazione continua o lettura diretta HealthKit. Il backup completo contiene ora anche dati sanitari leggibili: salvarlo o condividerlo è una scelta esplicita dell’utente. I vecchi backup privi di Salute conservano la sezione già presente durante il ripristino; un backup completo che la contiene la sostituisce. Le pagine/abitudini restano compatibili; documentazione journal in README-JOURNAL.md.

## Relazione con Athlytic

Ispirazione alle categorie pubbliche, con interfaccia, testi e formule indipendenti. Nessuna modifica di Athlytic, sblocco del suo PRO, uso dei suoi server o copia di algoritmi privati. La batteria/stress 24/7, sensori e GPS in tempo reale, battito dopo allenamento, allenamenti strutturati sul Watch, chat AI generativa, widget sanitari e firma/installazione Watch non sono resi equivalenti da questi importatori. Per questo la versione non viene presentata come replica integrale di ogni funzione PRO. L’app indica l’assenza dei dati necessari anziché simulare quei risultati.

## Metodi e fonti

- Session-RPE: Foster et al., 2001: https://pubmed.ncbi.nlm.nih.gov/11708692/
- Confronto HRV con baseline individuale: studio con lnRMSSD (non SDNN): https://www.mdpi.com/2411-5142/6/4/102
- Limiti ACWR: https://pubmed.ncbi.nlm.nih.gov/32125672/
- Azioni Trova campioni: https://support.apple.com/en-mt/guide/shortcuts/apd3c845e881/ios
- Avvio di un comando salvato: https://support.apple.com/en-euro/guide/shortcuts/apd624386f42/10.0/ios/27
- Funzioni pubbliche Athlytic: https://athlyticapp.helpscoutdocs.com/article/13-getting-started

Risultati effettivi di build e test in VERIFICA.json. Dati sintetici soltanto nei test; nessun valore sanitario personale pubblicato nel repository.
