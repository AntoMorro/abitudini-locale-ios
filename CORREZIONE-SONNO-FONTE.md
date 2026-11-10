# Fonte mancante nei segmenti sonno — build 18

Il telefono ha restituito FONTE-VUOTA: la fonte del segmento non viene fornita da Comandi Rapidi. Solo per i segmenti sonno, fonte assente/vuota/solo spazi viene ora registrata esplicitamente come Fonte non disponibile (Comandi Rapidi). Le fonti presenti, date e fasi restano invariate. Non viene attribuita una provenienza Apple Watch inventata.

Nell’analisi automatica di una notte si preferisce una fonte identificata con sonno osservato; se manca, si usano i segmenti non attribuiti, visibili con quella etichetta. Non si mescolano le due fonti. Puoi scegliere esplicitamente la fonte nelle preferenze. Quando la provenienza è assente non è possibile distinguere più dispositivi di origine: non è un certificato di omogeneità dei campioni.

La deduplicazione, la separazione delle fasi e l’esclusione esplicita dei segmenti futuri introdotta nella build 17 restano attive. Fonti vuote di altri tipi e date invertite restano errori. I comandi firmati sono compatibili senza modifiche o nuova firma.
