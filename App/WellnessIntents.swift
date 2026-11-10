import AppIntents
import Foundation

enum WellnessActions {
    static func ingest(_ records:[WellnessRecord]) throws {
        try HabitEnvironment.repository.update{db in var health=db.wellness ?? WellnessArchive();try health.merge(records);db.wellness=health}
        if let db=try? HabitEnvironment.repository.read(){WellnessWidgetBridge.publish(db.wellness ?? WellnessArchive())}
        Task{@MainActor in NotificationCenter.default.post(name:.habitDataChanged,object:nil)}
    }
    static func sample(_ type:WellnessMetric,value:Double,date:Date,unit:String,source:String)throws->WellnessRecord {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        return try WellnessImport.record(WellnessWire(type:type,value:value,unit:unit,start:f.string(from:date),source:source))
    }
}
struct ImportWellnessHRVIntent:AppIntent {
    static var title:LocalizedStringResource="Importa HRV nel quaderno"
    static var description=IntentDescription("Salva un campione SDNN locale. Passa il valore, la data originale e la fonte; ripetizioni dello stesso campione aggiornano la voce.")
    @Parameter(title:"Valore HRV") var value:Double
    @Parameter(title:"Unità: ms oppure s",default:"ms") var unit:String
    @Parameter(title:"Data della misurazione") var date:Date
    @Parameter(title:"Fonte",default:"Apple Watch") var source:String
    static var parameterSummary:some ParameterSummary {Summary("Importa HRV \(\.$value) del \(\.$date)"){\.$unit;\.$source}}
    func perform()async throws->some IntentResult {try WellnessActions.ingest([WellnessActions.sample(.hrv,value:value,date:date,unit:unit,source:source)]);return .result()}
}
struct ImportWellnessRestIntent:AppIntent {
    static var title:LocalizedStringResource="Importa frequenza a riposo nel quaderno"
    static var description=IntentDescription("Salva la frequenza cardiaca a riposo in bpm, con la data originale, nell'archivio locale.")
    @Parameter(title:"Battiti al minuto") var value:Double
    @Parameter(title:"Data della misurazione") var date:Date
    @Parameter(title:"Fonte",default:"Apple Watch") var source:String
    func perform()async throws->some IntentResult {try WellnessActions.ingest([WellnessActions.sample(.rhr,value:value,date:date,unit:"bpm",source:source)]);return .result()}
}
struct ImportWellnessSleepIntent:AppIntent {
    static var title:LocalizedStringResource="Importa segmento sonno nel quaderno"
    static var description=IntentDescription("Salva un segmento con inizio, fine e fase originale. Non sommare prima i segmenti; le sovrapposizioni vengono risolte nell'app.")
    @Parameter(title:"Inizio segmento") var start:Date
    @Parameter(title:"Fine segmento") var end:Date
    @Parameter(title:"Fase",default:"addormentato") var stage:String
    @Parameter(title:"Fonte",default:"Apple Watch") var source:String
    func perform()async throws->some IntentResult {
        let phase=try WellnessPhase.parse(stage)
        try WellnessActions.ingest([WellnessRecord(metric:.sleep,value:end.timeIntervalSince(start)/60,start:start,end:end,source:source,phase:phase)])
        return .result()
    }
}
struct ImportWellnessJSONIntent:AppIntent {
    static var title:LocalizedStringResource="Importa dati Salute JSON nel quaderno"
    static var description=IntentDescription("Importazione atomica di un JSON versione 1, massimo 10.000 campioni. Nessun dato viene inviato in rete.")
    @Parameter(title:"JSON") var json:String
    func perform()async throws->some IntentResult {
        let batch=try WellnessImport.shortcutBatch(Data(json.utf8))
        try WellnessActions.ingest(batch.records)
        return .result(dialog:"Ricevuti \(batch.records.count) campioni validi. Esclusi \(batch.futureSleepExcluded) segmenti sonno con fine oltre 5 minuti nel futuro. Fonte non disponibile per \(batch.unknownSleepSourceCount) segmenti sonno. Le date originali non sono state modificate.")
    }
}
struct OpenWellnessIntent:AppIntent {
    static var title:LocalizedStringResource="Apri Salute nel quaderno"
    static var openAppWhenRun=true
    @MainActor func perform()async throws->some IntentResult {NotificationCenter.default.post(name:Notification.Name("wellness.open"),object:nil);return .result()}
}
