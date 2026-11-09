# Collegare Salute al quaderno, senza HealthKit nella firma

## Aggiornamento

Esporta prima il backup completo e installa QuadernoSalute-Base-unsigned.ipa sopra Quaderno Locale, con lo stesso Apple ID e le medesime opzioni bundle ID. Non disinstallare. Versione 2.1 (11), iOS 18+. Il vecchio comando che crea una nota continua a funzionare, ma quella nota non è un dato strutturato per i nuovi grafici.

## Primo collaudo: un campione HRV

1. In Comandi Rapidi crea `HRV nel quaderno`.
2. Trova campioni di Salute: Variabilità frequenza cardiaca (SDNN), ultimi 28 giorni, una fonte sola, ordina per data. Per la prova attiva limite 1.
3. Se i campioni hanno un valore, Ripeti con ogni campione. Tutti i dettagli successivi devono ricevere l’Elemento ripetizione originale.
4. Ottieni dettagli → Valore e Ottieni dettagli → Data di inizio. Se disponibile scegli anche la Fonte. Verifica che l’unità mostrata sia ms; se è secondi scegli s nell’azione seguente.
5. Aggiungi Quaderno Locale → Importa HRV nel quaderno. Passa Valore, Data della misurazione, unità ms/s e una fonte coerente, es. Apple Watch. Non usare Data attuale al posto della data del campione.
6. Chiudi Ripeti. Nel ramo Altrimenti mostra Nessun campione accessibile. Esegui a telefono sbloccato e concedi personalmente i permessi.
7. Apri Oggi → cuore → Campioni, fonti ed esportazione; controlla data, fonte e valore. Ripeti il comando: il conteggio non deve crescere per lo stesso campione. Poi elimina il limite 1 per importare la storia disponibile.

Non inviare i tuoi valori sanitari in chat: basta indicare l’esito e l’eventuale errore.

## Frequenza a riposo

Duplica il comando in `Riposo nel quaderno`. Cambia il tipo in Frequenza cardiaca a riposo e l’azione in Importa frequenza a riposo nel quaderno. Valore in bpm e data originale. Non sostituire con i campioni di frequenza cardiaca generica.

## Sonno

Crea `Sonno nel quaderno`: Trova campioni Sonno, ultimi 28 giorni, una sola fonte; Se risultato presente → Ripeti con ogni campione. Ottieni Data di inizio, Data di fine e Valore/fase dal campione ripetuto. Passali a Importa segmento sonno nel quaderno con la stessa fonte. Includi tutte le fasi che Comandi Rapidi rende disponibili; non sommare prima i campioni.

Fasi accettate: 0/a letto, 1/addormentato, 2/sveglio, 3/essenziale, 4/profondo, 5/REM; nomi italiani e inglesi. Un’etichetta sconosciuta produce errore, non viene convertita arbitrariamente in addormentato. Se la versione di Comandi Rapidi non espone le fasi, usa segmenti generici addormentato e non attenderti un grafico REM/profondo. Non mappare campioni a letto o sveglio a sonno.

## Avviarli dall’app

Salute → Preferenze → nomi dei tre comandi. Imposta i nomi esatti. Poi Salute → Comandi Rapidi e sincronizzazione → Esegui. Il comando deve già esistere nell’app Apple. Puoi configurare personalmente un’automazione, ma sblocco e permessi possono impedire l’esecuzione in background. L’app non configura automaticamente automazioni o consensi.

## JSON per importazioni estese

Azione Importa dati Salute JSON nel quaderno oppure Salute → Importa → file/testo con anteprima. Massimo 5 MB e 10.000 campioni per lotto. Formato:

```json
{"version":1,"records":[
 {"type":"hrv","value":42,"unit":"ms","start":"2026-01-01T07:00:00+01:00","source":"Apple Watch"},
 {"type":"rhr","value":60,"unit":"bpm","start":"2026-01-01T08:00:00+01:00","source":"Apple Watch"},
 {"type":"sleep","start":"2025-12-31T23:00:00+01:00","end":"2026-01-01T07:00:00+01:00","stage":"asleep","source":"Apple Watch"},
 {"type":"workout","start":"2026-01-01T15:00:00+01:00","end":"2026-01-01T16:00:00+01:00","name":"Camminata","rpe":4,"source":"Manuale"}
]}
```

L’esempio è sintetico e non si importa automaticamente. Tipi aggiuntivi: heart/rhr bpm, respiration atti/min, oxygen %, temperature °C, weight kg, vo2 ml/kg/min, energy/food kcal, steps passi. I valori sono campioni, non totali giornalieri mescolati a segmenti. Non sommare contemporaneamente Watch e iPhone per passi/energia: importa una sola fonte e un solo livello di aggregazione. RMSSD non viene interpretata come SDNN. Date ISO 8601 con fuso obbligatorio.

Campo opzionale externalID: identificatore stabile del campione, se disponibile. Altrimenti deduplica per tipo, fonte normalizzata e istante; per sonno/allenamento considera anche fine e fase. Una fonte cambiata intenzionalmente resta una serie diversa. Le ricerche ripetute non moltiplicano gli stessi campioni. Non vengono eliminati automaticamente campioni che hai cancellato successivamente da Salute: puoi rimuoverli dall’archivio del quaderno.

## Leggere gli indicatori

HRV e riposo: giornate con mediana, baseline 28 giorni precedenti e almeno 14 giorni appaiati. Puoi selezionare una fonte e solo l’HRV dentro il sonno importato. Senza dati sufficienti non compare un indice. Sonno: finestra mezzogiorno → mezzogiorno, una fonte per notte, sovrapposizioni risolte. Carico: minuti × RPE; conferma giornate complete o riposo prima dei confronti 7/28. Non interpretare indice, rapporto o correlazione come diagnosi, predizione di infortuni o prescrizione di allenamento. Le formule complete sono in Salute → Metodi.
