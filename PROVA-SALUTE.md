# Prova HealthKit con account gratuito

Variante Quaderno Locale 2.0 (10), stesso bundle ID e archivio. Non è una replica di Athlytic: serve soltanto a verificare lettura HealthKit con la firma disponibile.

1. Esporta un backup di Abitudini/Quaderno e salvalo fuori dall'app. Non disinstallarla.
2. Seleziona in Sideloadly `QuadernoLocale-Salute-da-firmare.ipa`, lo stesso iPhone e Apple ID usati per l'app precedente. Mantieni le stesse impostazioni del bundle ID automatico. Non usare l'opzione a pagamento per entitlements personalizzati per questa prova: stiamo verificando la firma normale.
3. Avvia la firma e l'installazione. Password, codici e autorizzazioni del telefono vanno inseriti personalmente. Se l'installazione fallisce, conserva il messaggio di errore e non eliminare l'app precedente.
4. Apri Quaderno Locale → Altro → Prova lettura Salute → Richiedi accesso e leggi. Concedi personalmente la lettura dei tipi desiderati.
5. Verifica se compaiono valori reali con data e fonte. Basta comunicare «lettura riuscita» o il dominio/codice dell'errore: non inviare dati sanitari.

La richiesta riguarda esclusivamente battito, HRV SDNN, frequenza a riposo, sonno, allenamenti ed energia attiva. Nessuna scrittura o trasmissione. I risultati restano soltanto in memoria nella schermata e non entrano nel backup del journal. Nessuna richiesta automatica all'avvio. Nessun punteggio di recupero viene inventato.

La prova usa gli ultimi campioni accessibili entro 30 giorni; la data può non essere quella odierna. Il sonno è un singolo segmento, non il totale della notte. Gli allenamenti sono limitati agli ultimi 20; l'energia è la somma dei campioni iniziati nelle ultime 24 ore. I risultati vuoti non distinguono dati assenti, consenso negato o accesso limitato: è una protezione HealthKit.

L'IPA include una firma ad hoc che mantiene `com.apple.developer.healthkit=true` per rendere la capability ispezionabile dallo strumento di firma. Questa firma non permette da sola l'installazione sull'iPhone. La compilazione e il controllo del pacchetto non provano che Sideloadly conservi la capability nel profilo finale: quella è la verifica reale da completare.

Apple elenca HealthKit anche per Apple Developer senza membership a pagamento: https://developer.apple.com/help/account/reference/supported-capabilities-ios . Per l'autorizzazione di lettura: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data .

Il ramo `healthkit-probe` contiene la variante; il ramo main resta alla release journal verificata. Non attiviamo HealthKit background delivery, Health Records, App Groups o Screen Time. Non serve installare una companion Watch per leggere sul telefono i campioni già sincronizzati in Salute.
