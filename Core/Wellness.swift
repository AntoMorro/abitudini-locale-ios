import Foundation

enum WellnessError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
enum WellnessMetric: String, Codable, CaseIterable, Identifiable {
    case hrv, rhr, heart, sleep, respiration, oxygen, temperature, weight, vo2, energy, food, steps, workout
    var id: String { rawValue }
    var title: String { switch self {
    case .hrv: return "HRV · SDNN"; case .rhr: return "Frequenza a riposo"; case .heart: return "Frequenza cardiaca"
    case .sleep: return "Sonno"; case .respiration: return "Respirazione"; case .oxygen: return "Ossigenazione"
    case .temperature: return "Temperatura polso"; case .weight: return "Peso"; case .vo2: return "VO₂ max"
    case .energy: return "Energia attiva"; case .food: return "Energia alimentare"; case .steps: return "Passi"; case .workout: return "Allenamento" } }
    var unit: String { switch self {case .hrv:return "ms"; case .rhr,.heart:return "bpm";case .sleep,.workout:return "min";case .respiration:return "atti/min";case .oxygen:return "%";case .temperature:return "°C";case .weight:return "kg";case .vo2:return "ml/kg/min";case .energy,.food:return "kcal";case .steps:return "passi"} }
}
enum WellnessPhase: String, Codable, CaseIterable, Identifiable {
    case inBed, asleep, awake, core, deep, rem
    var id: String { rawValue }
    var title: String { switch self {case .inBed:return "A letto";case .asleep:return "Addormentato";case .awake:return "Sveglio";case .core:return "Principale";case .deep:return "Profondo";case .rem:return "REM"} }
    var rank: Int { switch self {case .inBed:return 0;case .asleep:return 1;case .core:return 2;case .rem:return 3;case .deep:return 4;case .awake:return 5} }
    var sleeping: Bool { ![.inBed,.awake].contains(self) }
    static func parse(_ text: String) throws -> Self {
        let s = text.folding(options:[.diacriticInsensitive,.caseInsensitive],locale:Locale(identifier:"it_IT")).trimmingCharacters(in:.whitespacesAndNewlines)
        if s == "0" || s == "inbed" || s.contains("a letto") || s == "in bed" { return .inBed }
        if s == "2" || s.contains("vegl") || s.contains("awake") { return .awake }
        if s == "4" || s.contains("profond") || s.contains("deep") { return .deep }
        if s == "5" || s.contains("rem") { return .rem }
        if s == "3" || s.contains("essenzial") || s.contains("principal") || s.contains("legger") || s.contains("core") { return .core }
        if ["1","asleep","asleepunspecified","asleep unspecified","asleep (unspecified)","addormentato","addormentato (non specificato)","addormentato non specificato","sonno","in sonno","in sonno (non specificato)","sonno (non specificato)","sonno non specificato"].contains(s) { return .asleep }
        // Report only a short alphabetic category label, never a raw quantity, duration or JSON.
        let allowed=CharacterSet.letters.union(.whitespaces).union(CharacterSet(charactersIn:"()’-"))
        let label = !s.isEmpty && s.count<=80 && s.unicodeScalars.allSatisfy({allowed.contains($0)}) ? "Etichetta non riconosciuta: «\(s)»." : s.isEmpty ? "La fase ricevuta è vuota." : "Il campo fase non contiene un’etichetta riconoscibile."
        throw WellnessError.invalid(label+" Usa 0 a letto, 1 addormentato, 2 sveglio, 3 principale (essenziale), 4 profondo o 5 REM. Nessun campione del lotto è salvato.")
    }
}
struct WellnessRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var metric: WellnessMetric
    var value: Double
    var start: Date
    var end: Date
    var source: String
    var phase: WellnessPhase?
    var externalID: String?
    var name = ""
    var rpe: Double?
    var imported = Date()
    var key: String {
        guard start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite, abs(start.timeIntervalSince1970)<1e12, abs(end.timeIntervalSince1970)<1e12 else { return "invalid-date" }
        let origin = source.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        if let externalID, !externalID.isEmpty { return metric.rawValue+"|"+origin+"|id:"+externalID }
        let base=metric.rawValue+"|"+origin+"|"+String(Int64((start.timeIntervalSince1970*1000).rounded()))
        if metric != .sleep && metric != .workout { return base }
        return base+"|"+String(Int64((end.timeIntervalSince1970*1000).rounded()))+"|"+(phase?.rawValue ?? "")
    }
    func validate(now: Date = Date()) throws {
        func failure(_ code:String,_ message:String)->WellnessError{.invalid("\(metric.title) [\(code)]: "+message)}
        guard value.isFinite,start.timeIntervalSince1970.isFinite,end.timeIntervalSince1970.isFinite else{throw failure("NUMERO-DATA","Numero o data non finiti.")}
        guard start>=Date(timeIntervalSince1970:0) else{throw failure("DATA-ORIGINE","Data precedente al 1970. Controlla il campo Data di inizio del comando.")}
        guard end>=start else{throw failure("ORDINE-DATE","La fine precede l’inizio. Controlla i collegamenti Data di inizio e Data di fine.")}
        guard end<=now.addingTimeInterval(300) else{throw failure("DATA-FUTURA","La fine supera l’ora attuale di oltre 5 minuti. Il campione non viene salvato.")}
        guard !source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw failure("FONTE-VUOTA","Il comando non ha fornito una fonte. Controlla il dettaglio Fonte del campione.")}
        guard source.count<=160 else{throw failure("FONTE-LUNGA","Il campo Fonte supera 160 caratteri. Passa il dettaglio Fonte, non l’intero campione.")}
        guard name.count<=200,(externalID?.count ?? 0)<=200 else{throw failure("TESTO-LUNGO","Nome o identificatore troppo lunghi.")}
        guard rpe == nil || (rpe!.isFinite && (0...10).contains(rpe!)) else{throw failure("RPE","Lo sforzo percepito deve essere fra 0 e 10.")}

        let valid: Bool
        switch metric {
        case .hrv: valid = (0.1...1000).contains(value)
        case .rhr,.heart: valid = (15...300).contains(value)
        case .sleep: valid = phase != nil && end>start && end.timeIntervalSince(start)<=86400
        case .workout: valid = end>start && end.timeIntervalSince(start)<=86400
        case .respiration: valid = (1...100).contains(value)
        case .oxygen: valid = (1...100).contains(value)
        case .temperature: valid = (20...45).contains(value)
        case .weight: valid = (1...500).contains(value)
        case .vo2: valid = (1...120).contains(value)
        case .energy,.food: valid = (0...50_000).contains(value)
        case .steps: valid = (0...500_000).contains(value) && value.rounded()==value
        }
        guard valid else { throw WellnessError.invalid("Valore fuori intervallo o segmento incompleto per "+metric.title+". Verifica l’unità.") }
    }
}
struct WellnessPreferences: Codable {
    var sleepGoal = 8.0
    var hrvSource = ""
    var sleepSource = ""
    var rhrSource = ""
    var nocturnalHRV = false
    var shortcutNames = ["HRV nel quaderno","Riposo nel quaderno","Sonno nel quaderno"]
    var sleepPlan:WellnessSleepPlan?
    var widgetsEnabled:Bool?
}
struct WellnessArchive: Codable {
    var version = 1
    var records: [WellnessRecord] = []
    var preferences = WellnessPreferences()
    var confirmedTrainingDays: [String] = []
    func validated(now: Date = Date()) throws -> Self {
        guard version==1, records.count<=50_000, Set(records.map(\.id)).count==records.count,
              Set(records.map(\.key)).count==records.count, (4...12).contains(preferences.sleepGoal),
              preferences.shortcutNames.count==3, preferences.shortcutNames.allSatisfy({$0.count<=150}),
              preferences.hrvSource.count<=160, preferences.rhrSource.count<=160, preferences.sleepSource.count<=160, preferences.sleepPlan?.valid != false,
              confirmedTrainingDays.count<=20_000, Set(confirmedTrainingDays).count==confirmedTrainingDays.count,
              confirmedTrainingDays.allSatisfy({$0.count==10 && $0.filter({$0 == "-"}).count==2}) else { throw WellnessError.invalid("Archivio Salute non valido o limite raggiunto.") }
        for r in records { try r.validate(now:now) }; return self
    }
    @discardableResult mutating func merge(_ incoming: [WellnessRecord], now: Date = Date()) throws -> (added:Int,updated:Int) {
        guard incoming.count<=10_000 else { throw WellnessError.invalid("Importa al massimo 10.000 campioni per volta.") }
        // Validate the whole batch before changing the in-memory candidate.
        for r in incoming { try r.validate(now:now) }
        var candidate = self, indices = Dictionary(uniqueKeysWithValues:records.enumerated().map{($0.element.key,$0.offset)})
        var added=0, updated=0
        for var r in incoming {
            if let i = indices[r.key] { r.id=candidate.records[i].id; candidate.records[i]=r; updated+=1 }
            else { indices[r.key]=candidate.records.count;candidate.records.append(r);added+=1 }
        }
        _ = try candidate.validated(now:now); self=candidate; return (added,updated)
    }
}
struct WellnessWire: Codable {
    var type: WellnessMetric
    var value: Double?
    var unit: String?
    var start: String
    var end: String?
    var source: String?
    var stage: String?
    var externalID: String?
    var name: String?
    var rpe: Double?
    var value64: String?
    var unit64: String?
    var source64: String?
    var stage64: String?
}
struct WellnessEnvelope: Codable { var version: Int; var records: [WellnessWire] }
enum WellnessImport {
    static let unknownSleepSource="Fonte non disponibile (Comandi Rapidi)"
    static func text(_ encoded:String?) throws -> String? {
        guard let encoded else{return nil}
        guard encoded.count<=8000,let data=Data(base64Encoded:encoded,options:.ignoreUnknownCharacters),let text=String(data:data,encoding:.utf8) else{throw WellnessError.invalid("Testo del comando non valido: atteso Base64 UTF-8.")}
        return text
    }
    static func unit(_ raw:String,type:WellnessMetric)throws->String {
        let s=raw.lowercased().trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:" ",with:"")
        if type == .hrv {
            if ["ms","millisecond","milliseconds","millisecondo","millisecondi"].contains(s){return "ms"}
            if ["s","sec","second","seconds","secondo","secondi"].contains(s){return "s"}
        }
        if [.rhr,.heart].contains(type) && ["bpm","count/min","count/minute","battiti/min","battiti/minuto","beats/min","beats/minute"].contains(s){return "bpm"}
        if type == .respiration && ["atti/min","atti/minuto","count/min","count/minute","breaths/min","breaths/minute","respiri/min","respirazioni/minuto"].contains(s){return "atti/min"}
        if type == .oxygen && ["%","percent","percento","percentuale"].contains(s){return "%"}
        if type == .temperature {
            if ["°c","℃","celsius","degreecelsius","degc"].contains(s){return "°c"}
            if ["°f","℉","fahrenheit","degreefahrenheit","degf"].contains(s){return "°f"}
        }
        return s
    }
    static func number(_ raw:String,unit expected:String,type:WellnessMetric)throws->Double {
        let s=raw.trimmingCharacters(in:.whitespacesAndNewlines)
        let pattern="^([+-]?[0-9]+(?:[.,][0-9]+)?(?:[eE][+-]?[0-9]+)?)\\s*(.*?)$"
        let expression=try NSRegularExpression(pattern:pattern)
        guard let match=expression.firstMatch(in:s,range:NSRange(s.startIndex...,in:s)),let numericRange=Range(match.range(at:1),in:s),let suffixRange=Range(match.range(at:2),in:s),let n=Double(s[numericRange].replacingOccurrences(of:",",with:".")),n.isFinite else{throw WellnessError.invalid("Il Valore del campione non è un numero leggibile. Il comando deve passare il dettaglio Valore, non l’intero campione.")}
        let suffix=String(s[suffixRange])
        if !suffix.isEmpty,try unit(suffix,type:type) != unit(expected,type:type){throw WellnessError.invalid("Unità nel valore e unità del campione diverse: controlla il comando.")}
        return n
    }
    static func scalar(_ raw:Double,unit rawUnit:String,type:WellnessMetric)throws->Double {
        var value=raw
        let u=try unit(rawUnit,type:type)
        switch type {
        case .hrv: if ["s","sec"].contains(u) { value*=1000 } else if u != "ms" { throw WellnessError.invalid("HRV SDNN: usa ms o s; RMSSD non è intercambiabile con SDNN.") }
        case .rhr,.heart: if ["count/s","beats/s"].contains(u){value*=60}else if u != "bpm"{throw WellnessError.invalid("Frequenza: usa bpm o count/s espliciti.")}
        case .respiration: if ["count/s","breaths/s","atti/s"].contains(u){value*=60}else if u != "atti/min"{throw WellnessError.invalid("Respirazione: usa atti/min, count/min o count/s espliciti.")}
        case .sleep,.workout: break
        case .temperature:
            if u=="°f"{value=(value-32)*5/9}else if u != "°c"{throw WellnessError.invalid("Temperatura assoluta: usa °C o °F, non uno scostamento dalla baseline.")}
        case .oxygen:
            if u=="fraction"{guard (0...1).contains(value) else{throw WellnessError.invalid("Frazione SpO₂ fuori intervallo.")};value*=100}
            else if u != "%"{throw WellnessError.invalid("SpO₂: usa % oppure fraction esplicita.")}
        default: guard u==type.unit.lowercased().replacingOccurrences(of:" ",with:"") else { throw WellnessError.invalid("Unità richiesta: "+type.unit) }
        }
        return value
    }
    static func date(_ text: String) throws -> Date {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        if let d=f.date(from:text) { return d }; f.formatOptions=[.withInternetDateTime]
        guard let d=f.date(from:text) else { throw WellnessError.invalid("Formato data non riconosciuto: serve ISO 8601 con fuso orario. Nessuna data è stata modificata.") }; return d
    }
    static func record(_ w: WellnessWire, now: Date = Date()) throws -> WellnessRecord {
        let start=try date(w.start), end=try w.end.map(date) ?? start
        let unitText=try text(w.unit64) ?? w.unit ?? w.type.unit
        var value=try text(w.value64).map{try number($0,unit:unitText,type:w.type)} ?? w.value ?? 0
        if w.type == .sleep || w.type == .workout {value=end.timeIntervalSince(start)/60}
        else{value=try scalar(value,unit:unitText,type:w.type)}
        if w.type != .sleep && w.type != .workout && w.value == nil && w.value64 == nil { throw WellnessError.invalid("Valore mancante.") }
        let stageText=try text(w.stage64) ?? w.stage ?? "asleep"
        let phase: WellnessPhase? = w.type == .sleep ? try WellnessPhase.parse(stageText) : nil
        let rawSource=try text(w.source64) ?? w.source
        let source:String
        if w.type == .sleep,(rawSource ?? "").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{
            source=unknownSleepSource
        }else{source=rawSource ?? "Comandi Rapidi"}
        let r=WellnessRecord(metric:w.type,value:value,start:start,end:end,source:source,phase:phase,externalID:w.externalID,name:w.name ?? "",rpe:w.rpe)
        try r.validate(now:now); return r
    }
    private static func readEnvelope(_ data:Data)throws->WellnessEnvelope{
        guard data.count<=5_000_000 else{throw WellnessError.invalid("File troppo grande: massimo 5 MB.")}
        let envelope:WellnessEnvelope
        do{envelope=try JSONDecoder().decode(WellnessEnvelope.self,from:data)}
        catch{throw WellnessError.invalid("JSON del comando non valido: servono version e records.")}
        guard envelope.version==1,!envelope.records.isEmpty,envelope.records.count<=10_000 else{throw WellnessError.invalid("Formato versione 1: servono da 1 a 10.000 campioni.")}
        return envelope
    }
    private static func checked(_ wire:WellnessWire,index:Int,count:Int,now:Date)throws->WellnessRecord{
        do{return try record(wire,now:now)}
        catch{throw WellnessError.invalid("Campione \(index+1)/\(count): "+error.localizedDescription)}
    }
    static func decode(_ data:Data,now:Date=Date())throws->[WellnessRecord]{
        let envelope=try readEnvelope(data)
        return try envelope.records.enumerated().map{try checked($0.element,index:$0.offset,count:envelope.records.count,now:now)}
    }
    struct ShortcutBatch {
        var records:[WellnessRecord];var futureSleepExcluded:Int
        var unknownSleepSourceCount:Int{records.filter{$0.metric == .sleep && $0.source==WellnessImport.unknownSleepSource}.count}
    }
    static func shortcutBatch(_ data:Data,now:Date=Date())throws->ShortcutBatch{
        let envelope=try readEnvelope(data)
        var records:[WellnessRecord]=[],excluded=0
        for (index,wire) in envelope.records.enumerated(){
            if wire.type == .sleep,let endText=wire.end,
               let start=try? date(wire.start),let end=try? date(endText),
               end>=start,end>now.addingTimeInterval(300){
                excluded+=1;continue
            }
            records.append(try checked(wire,index:index,count:envelope.records.count,now:now))
        }
        guard !records.isEmpty else{throw WellnessError.invalid("SONNO-FUTURO: esclusi \(excluded) segmenti con fine nel futuro. Nessun campione valido da salvare. Le date non sono state corrette automaticamente.")}
        return .init(records:records,futureSleepExcluded:excluded)
    }
    static func export(_ archive: WellnessArchive) throws -> Data {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let records=archive.records.map { r in WellnessWire(type:r.metric,value:r.value,unit:r.metric.unit,start:f.string(from:r.start),end:f.string(from:r.end),source:r.source,stage:r.phase?.rawValue,externalID:r.externalID,name:r.name,rpe:r.rpe) }
        let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];return try e.encode(WellnessEnvelope(version:1,records:records))
    }
}
