#if HEALTH_PROBE
import SwiftUI
import HealthKit

struct HealthProbeRow: Identifiable {
    let id: String
    let title: String
    var value = "Da leggere"
    var detail = ""
}

@MainActor final class HealthProbeStore: ObservableObject {
    private let health = HKHealthStore()
    @Published var busy = false
    @Published var status = "Lettura non ancora avviata"
    @Published var checked: Date?
    @Published var rows = [
        HealthProbeRow(id:"heart",title:"Frequenza cardiaca"),
        HealthProbeRow(id:"hrv",title:"Variabilità cardiaca (SDNN)"),
        HealthProbeRow(id:"rest",title:"Frequenza a riposo"),
        HealthProbeRow(id:"sleep",title:"Ultimo segmento di sonno"),
        HealthProbeRow(id:"workout",title:"Allenamenti recenti"),
        HealthProbeRow(id:"energy",title:"Energia attiva nelle ultime 24 ore")
    ]
    var available: Bool { HKHealthStore.isHealthDataAvailable() }
    private var readTypes: Set<HKObjectType> {
        [HKObjectType.quantityType(forIdentifier:.heartRate)!,
         HKObjectType.quantityType(forIdentifier:.heartRateVariabilitySDNN)!,
         HKObjectType.quantityType(forIdentifier:.restingHeartRate)!,
         HKObjectType.categoryType(forIdentifier:.sleepAnalysis)!,
         HKObjectType.workoutType(),
         HKObjectType.quantityType(forIdentifier:.activeEnergyBurned)!]
    }
    func read(requestPermission: Bool) async {
        guard !busy else { return }
        guard available else { status = "Salute non è disponibile su questo dispositivo."; return }
        busy = true
        defer { busy = false; checked = Date() }
        do {
            if requestPermission {
                // A successful request means the dialog completed, not that read access was granted.
                try await health.requestAuthorization(toShare: [], read: readTypes)
            }
        } catch {
            status = "Richiesta non riuscita: " + diagnostic(error)
            return
        }
        let end = Date()
        let start = Calendar.current.date(byAdding:.day,value:-30,to:end)!
        let predicate = HKQuery.predicateForSamples(withStart:start,end:end,options:.strictStartDate)
        await quantity("heart",identifier:.heartRate,unit:HKUnit.count().unitDivided(by:.minute()),suffix:"bpm",predicate:predicate)
        await quantity("hrv",identifier:.heartRateVariabilitySDNN,unit:.secondUnit(with:.milli),suffix:"ms",predicate:predicate)
        await quantity("rest",identifier:.restingHeartRate,unit:HKUnit.count().unitDivided(by:.minute()),suffix:"bpm",predicate:predicate)
        do {
            let type = HKObjectType.categoryType(forIdentifier:.sleepAnalysis)!
            let asleepValues = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue]
            let asleep = HKQuery.predicateForCategorySamples(with:.equalTo,value:asleepValues[0])
            let anyAsleep = NSCompoundPredicate(orPredicateWithSubpredicates:asleepValues.dropFirst().map { HKQuery.predicateForCategorySamples(with:.equalTo,value:$0) } + [asleep])
            let values = try await samples(type,predicate:NSCompoundPredicate(andPredicateWithSubpredicates:[predicate,anyAsleep]),limit:1)
            if let sample = values.first {
                set("sleep",value:sample.startDate.formatted(date:.abbreviated,time:.shortened)+" → "+sample.endDate.formatted(date:.omitted,time:.shortened),detail:"Singolo segmento, non durata totale della notte. Fonte: "+sample.sourceRevision.source.name)
            } else { empty("sleep") }
        } catch { failure("sleep",error) }
        do {
            let values = try await samples(HKObjectType.workoutType(),predicate:predicate,limit:20)
            if let workout = values.first as? HKWorkout {
                set("workout",value:"Letti \(values.count) allenamenti (massimo 20)",detail:"Ultimo: "+workout.startDate.formatted(date:.abbreviated,time:.shortened)+" · "+String(Int(workout.duration/60))+" minuti")
            } else { empty("workout") }
        } catch { failure("workout",error) }
        do {
            let type = HKObjectType.quantityType(forIdentifier:.activeEnergyBurned)!
            let day = HKQuery.predicateForSamples(withStart:end.addingTimeInterval(-86400),end:end,options:.strictStartDate)
            let sum: Double? = try await withCheckedThrowingContinuation { continuation in
                health.execute(HKStatisticsQuery(quantityType:type,quantitySamplePredicate:day,options:.cumulativeSum) { _, result, error in
                    if let error { continuation.resume(throwing:error) }
                    else { continuation.resume(returning:result?.sumQuantity()?.doubleValue(for:.kilocalorie())) }
                })
            }
            if let sum { set("energy",value:sum.formatted(.number.precision(.fractionLength(0)))+" kcal",detail:"Somma dei campioni accessibili iniziati nelle ultime 24 ore.") }
            else { empty("energy") }
        } catch { failure("energy",error) }
        status = "Lettura terminata. Controlla le singole voci."
    }
    private func samples(_ type:HKSampleType,predicate:NSPredicate,limit:Int) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            health.execute(HKSampleQuery(sampleType:type,predicate:predicate,limit:limit,sortDescriptors:[NSSortDescriptor(key:HKSampleSortIdentifierEndDate,ascending:false)]) { _, values, error in
                if let error { continuation.resume(throwing:error) }
                else { continuation.resume(returning:values ?? []) }
            })
        }
    }
    private func quantity(_ id:String,identifier:HKQuantityTypeIdentifier,unit:HKUnit,suffix:String,predicate:NSPredicate) async {
        do {
            let values = try await samples(HKObjectType.quantityType(forIdentifier:identifier)!,predicate:predicate,limit:1)
            if let sample = values.first as? HKQuantitySample {
                set(id,value:sample.quantity.doubleValue(for:unit).formatted(.number.precision(.fractionLength(1)))+" "+suffix,detail:sample.endDate.formatted(date:.abbreviated,time:.shortened)+" · "+sample.sourceRevision.source.name)
            } else { empty(id) }
        } catch { failure(id,error) }
    }
    private func set(_ id:String,value:String,detail:String) {
        guard let index = rows.firstIndex(where:{$0.id == id}) else { return }
        rows[index].value = value; rows[index].detail = detail
    }
    private func empty(_ id:String) { set(id,value:"Nessun campione accessibile",detail:"Dati assenti, accesso limitato o lettura non autorizzata: iOS non permette di distinguerli.") }
    private func failure(_ id:String,_ error:Error) { set(id,value:"Lettura non riuscita",detail:diagnostic(error)) }
    private func diagnostic(_ error:Error) -> String {
        let value = error as NSError
        return value.domain+" (codice \(value.code)): "+value.localizedDescription
    }
}

struct JournalHealthProbe: View {
    @StateObject private var probe = HealthProbeStore()
    var body: some View {
        List {
            Section {
                Label("Verifichiamo il collegamento a Salute",systemImage:"heart.text.clipboard").font(.headline)
                Text("Questa prova legge sei tipi di dati. Non scrive in Salute, non invia dati e mantiene i risultati soltanto in memoria durante questa schermata.")
                Text("Gli ultimi campioni possono risalire fino a 30 giorni fa: controlla data e fonte. Non sono punteggi Athlytic o misure in tempo reale.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Richiedi accesso e leggi") { Task { await probe.read(requestPermission:true) } }
                    .accessibilityIdentifier("healthProbeAuthorize")
                Button("Rileggi i dati") { Task { await probe.read(requestPermission:false) } }
                if probe.busy { ProgressView("Lettura in corso") }
                Text(probe.status).font(.caption)
                if let checked = probe.checked { Text("Ultimo tentativo: "+checked.formatted(date:.omitted,time:.shortened)).font(.caption) }
            }.disabled(probe.busy || !probe.available)
            ForEach(probe.rows) { row in
                Section(row.title) {
                    Text(row.value).font(.headline)
                    if !row.detail.isEmpty { Text(row.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                }
            }
            Section("Se non vedi i dati") {
                Text("Completa personalmente la richiesta di Salute. Se avevi negato l'accesso, modifica le autorizzazioni dell'app nelle impostazioni di Salute. Un elenco vuoto non dimostra un errore della firma e non dimostra un consenso negato.")
                Text("Se la richiesta fallisce con un errore sulle autorizzazioni della firma, annota dominio e codice: serviranno a verificare se Sideloadly ha conservato HealthKit. Non occorre condividere valori sanitari o schermate con dati personali.")
            }.font(.caption)
        }.navigationTitle("Prova Salute")
    }
}
#endif
