import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum WellnessHealthXML {
    static let types:[String:WellnessMetric]=[
        "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":.hrv,"HKQuantityTypeIdentifierRestingHeartRate":.rhr,
        "HKQuantityTypeIdentifierHeartRate":.heart,"HKQuantityTypeIdentifierRespiratoryRate":.respiration,
        "HKQuantityTypeIdentifierOxygenSaturation":.oxygen,"HKQuantityTypeIdentifierAppleSleepingWristTemperature":.temperature,
        "HKQuantityTypeIdentifierStepCount":.steps,"HKQuantityTypeIdentifierActiveEnergyBurned":.energy,
        "HKQuantityTypeIdentifierDietaryEnergyConsumed":.food,"HKQuantityTypeIdentifierBodyMass":.weight,
        "HKQuantityTypeIdentifierVO2Max":.vo2,"HKCategoryTypeIdentifierSleepAnalysis":.sleep]
    static func read(url:URL,since:Date,metrics:Set<WellnessMetric>,now:Date=Date())throws->[WellnessRecord]{
        guard let parser=XMLParser(contentsOf:url) else{throw WellnessError.invalid("File XML non leggibile. Estrai prima export.xml dallo ZIP di Salute.")}
        return try parse(parser,since:since,metrics:metrics,now:now)
    }
    static func read(data:Data,since:Date,metrics:Set<WellnessMetric>,now:Date=Date())throws->[WellnessRecord]{
        try parse(XMLParser(data:data),since:since,metrics:metrics,now:now)
    }
    private static func parse(_ parser:XMLParser,since:Date,metrics:Set<WellnessMetric>,now:Date)throws->[WellnessRecord]{
        let delegate=Reader(since:since,metrics:metrics,now:now);parser.delegate=delegate;parser.shouldResolveExternalEntities=false
        let ok=parser.parse()
        if let error=delegate.failure{throw error}
        guard ok,delegate.rootSeen else{throw WellnessError.invalid("Atteso export.xml di Salute Apple valido. Nessun campione importato.")}
        guard !delegate.records.isEmpty else{throw WellnessError.invalid("Nessun campione del periodo e dei tipi selezionati.")}
        return delegate.records
    }
    private final class Reader:NSObject,XMLParserDelegate {
        let since:Date;let metrics:Set<WellnessMetric>;let now:Date
        let formatter:DateFormatter
        let coarseCutoff:String
        var records:[WellnessRecord]=[];var failure:Error?;var rootSeen=false
        init(since:Date,metrics:Set<WellnessMetric>,now:Date){
            self.since=since;self.metrics=metrics;self.now=now
            formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US_POSIX");formatter.calendar=Calendar(identifier:.gregorian);formatter.dateFormat="yyyy-MM-dd HH:mm:ss Z"
            coarseCutoff=String(formatter.string(from:since.addingTimeInterval(-172800)).prefix(10))
        }
        func parser(_ parser:XMLParser,didStartElement name:String,namespaceURI:String?,qualifiedName:String?,attributes a:[String:String]){
            if Task.isCancelled{failure=CancellationError();parser.abortParsing();return}
            if name=="HealthData"{rootSeen=true;return}
            guard rootSeen else{return}
            let metric:WellnessMetric?
            if name=="Record"{metric=a["type"].flatMap{WellnessHealthXML.types[$0]}}
            else if name=="Workout"{metric = .workout}else{return}
            guard let metric,metrics.contains(metric) else{return}
            do{
                guard let startText=a["startDate"] else{throw WellnessError.invalid("Data di un campione selezionato mancante.")}
                // Fast skip for distant history; a two-day margin preserves timezone/DST edges.
                if startText.count>=10 && String(startText.prefix(10))<coarseCutoff{return}
                guard let start=formatter.date(from:startText) else{throw WellnessError.invalid("Data di un campione selezionato non valida.")}
                guard start>=since else{return}
                guard records.count<10_000 else{throw WellnessError.invalid("Oltre 10.000 campioni: scegli un periodo più breve o meno tipi. Nessun salvataggio parziale.")}
                let end=a["endDate"].flatMap{formatter.date(from:$0)} ?? start
                let source=a["sourceName"] ?? "Salute Apple"
                let record:WellnessRecord
                if metric == .sleep {
                    let phases:[String:WellnessPhase]=["HKCategoryValueSleepAnalysisInBed":.inBed,"HKCategoryValueSleepAnalysisAsleep":.asleep,"HKCategoryValueSleepAnalysisAsleepUnspecified":.asleep,"HKCategoryValueSleepAnalysisAwake":.awake,"HKCategoryValueSleepAnalysisAsleepCore":.core,"HKCategoryValueSleepAnalysisAsleepDeep":.deep,"HKCategoryValueSleepAnalysisAsleepREM":.rem]
                    guard let raw=a["value"],let phase=phases[raw] else{throw WellnessError.invalid("Fase sonno XML non riconosciuta. Non è stata convertita in una fase generica.")}
                    record=WellnessRecord(metric:.sleep,value:end.timeIntervalSince(start)/60,start:start,end:end,source:source,phase:phase)
                }else if metric == .workout{
                    let activity=(a["workoutActivityType"] ?? "Allenamento").replacingOccurrences(of:"HKWorkoutActivityType",with:"")
                    record=WellnessRecord(metric:.workout,value:end.timeIntervalSince(start)/60,start:start,end:end,source:source,name:activity)
                }else{
                    guard let raw=a["value"],let value=Double(raw),value.isFinite,let unit=a["unit"] else{throw WellnessError.invalid("Valore o unità XML mancanti.")}
                    let outputUnit:String
                    switch metric{
                    case .oxygen:
                        // HealthKit export uses fractions with HKUnit.percent (0.97 = 97%).
                        guard unit=="%",(0...1).contains(value) else{throw WellnessError.invalid("SpO₂ XML: attesa frazione HealthKit 0–1 con unità %.")}
                        outputUnit="fraction"
                    case .steps:guard unit=="count" else{throw WellnessError.invalid("Passi XML: unità count richiesta.")};outputUnit="passi"
                    default:outputUnit=unit
                    }
                    let normalized=try WellnessImport.scalar(value,unit:outputUnit,type:metric)
                    record=WellnessRecord(metric:metric,value:normalized,start:start,end:end,source:source)
                }
                try record.validate(now:now);records.append(record)
            }catch{failure=error;parser.abortParsing()}
        }
    }
}
