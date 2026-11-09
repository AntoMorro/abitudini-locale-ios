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
    var title: String { switch self {case .inBed:return "A letto";case .asleep:return "Addormentato";case .awake:return "Sveglio";case .core:return "Essenziale";case .deep:return "Profondo";case .rem:return "REM"} }
    var rank: Int { switch self {case .inBed:return 0;case .asleep:return 1;case .core:return 2;case .rem:return 3;case .deep:return 4;case .awake:return 5} }
    var sleeping: Bool { ![.inBed,.awake].contains(self) }
    static func parse(_ text: String) throws -> Self {
        let s = text.folding(options:[.diacriticInsensitive,.caseInsensitive],locale:Locale(identifier:"it_IT")).trimmingCharacters(in:.whitespacesAndNewlines)
        if s == "0" || s == "inbed" || s.contains("a letto") || s == "in bed" { return .inBed }
        if s == "2" || s.contains("vegl") || s.contains("awake") { return .awake }
        if s == "4" || s.contains("profond") || s.contains("deep") { return .deep }
        if s == "5" || s.contains("rem") { return .rem }
        if s == "3" || s.contains("essenzial") || s.contains("legger") || s.contains("core") { return .core }
        if ["1","asleep","asleepunspecified","asleep unspecified","addormentato","addormentato (non specificato)","sonno"].contains(s) { return .asleep }
        throw WellnessError.invalid("Fase sonno non riconosciuta: usa 0 a letto, 1 addormentato, 2 sveglio, 3 essenziale, 4 profondo o 5 REM.")
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
        guard value.isFinite, start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite,
              start >= Date(timeIntervalSince1970:0), end >= start, end <= now.addingTimeInterval(300),
              !source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, source.count<=160, name.count<=200,
              (externalID?.count ?? 0)<=200, rpe == nil || (rpe!.isFinite && (0...10).contains(rpe!)) else { throw WellnessError.invalid("Valori, fonte o date non validi. Nessuna importazione futura.") }
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
              preferences.hrvSource.count<=160, preferences.rhrSource.count<=160, preferences.sleepSource.count<=160,
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
    static func date(_ text: String) throws -> Date {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        if let d=f.date(from:text) { return d }; f.formatOptions=[.withInternetDateTime]
        guard let d=f.date(from:text) else { throw WellnessError.invalid("Data ISO 8601 richiesta, con fuso orario: "+text) }; return d
    }
    static func record(_ w: WellnessWire, now: Date = Date()) throws -> WellnessRecord {
        let start=try date(w.start), end=try w.end.map(date) ?? start
        let unitText=try text(w.unit64) ?? w.unit ?? w.type.unit
        var value=try text(w.value64).map{try number($0,unit:unitText,type:w.type)} ?? w.value ?? 0
        let u=try unit(unitText,type:w.type)
        switch w.type {
        case .hrv: if ["s","sec"].contains(u) { value*=1000 } else if u != "ms" { throw WellnessError.invalid("HRV SDNN: usa ms o s; RMSSD non è intercambiabile con SDNN.") }
        case .rhr,.heart: guard ["bpm","count/min","battiti/min"].contains(u) else { throw WellnessError.invalid("Frequenza: unità bpm richiesta.") }
        case .sleep,.workout: value=end.timeIntervalSince(start)/60
        default: guard u==w.type.unit.lowercased().replacingOccurrences(of:" ",with:"") else { throw WellnessError.invalid("Unità richiesta: "+w.type.unit) }
        }
        if w.type != .sleep && w.type != .workout && w.value == nil && w.value64 == nil { throw WellnessError.invalid("Valore mancante.") }
        let stageText=try text(w.stage64) ?? w.stage ?? "asleep"
        let phase: WellnessPhase? = w.type == .sleep ? try WellnessPhase.parse(stageText) : nil
        let source=try text(w.source64) ?? w.source ?? "Comandi Rapidi"
        let r=WellnessRecord(metric:w.type,value:value,start:start,end:end,source:source,phase:phase,externalID:w.externalID,name:w.name ?? "",rpe:w.rpe)
        try r.validate(now:now); return r
    }
    static func decode(_ data: Data, now: Date = Date()) throws -> [WellnessRecord] {
        guard data.count<=5_000_000 else { throw WellnessError.invalid("File troppo grande: massimo 5 MB.") }
        let envelope:WellnessEnvelope
        do{envelope=try JSONDecoder().decode(WellnessEnvelope.self,from:data)}catch{
            throw WellnessError.invalid("JSON del comando non valido. Usa il comando preconfigurato: l’azione richiede un testo JSON con version e records, non una misura o una data come ingresso diretto.")
        }
        guard envelope.version==1,!envelope.records.isEmpty,envelope.records.count<=10_000 else { throw WellnessError.invalid("Formato versione 1: servono da 1 a 10.000 campioni.") }
        return try envelope.records.map{try record($0,now:now)}
    }
    static func export(_ archive: WellnessArchive) throws -> Data {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let records=archive.records.map { r in WellnessWire(type:r.metric,value:r.value,unit:r.metric.unit,start:f.string(from:r.start),end:f.string(from:r.end),source:r.source,stage:r.phase?.rawValue,externalID:r.externalID,name:r.name,rpe:r.rpe) }
        let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];return try e.encode(WellnessEnvelope(version:1,records:records))
    }
}
