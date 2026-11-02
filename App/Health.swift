import Foundation
#if HEALTH
import HealthKit

@MainActor final class HabitHealth {
    let store = HKHealthStore()
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HabitError.invalid }
        let types: Set<HKObjectType> = [HKQuantityType.quantityType(forIdentifier: .stepCount)!, HKObjectType.workoutType(), HKCategoryType.categoryType(forIdentifier: .mindfulSession)!]
        try await store.requestAuthorization(toShare: [], read: types)
    }
    func refresh(_ repository: HabitRepository) async throws {
        let db = try repository.read(), now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let strict = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        for habit in db.habits where !habit.archived && [.steps, .workout, .mindfulness].contains(habit.kind) {
            let amount: Int
            if habit.kind == .steps {
                let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
                amount = try await withCheckedThrowingContinuation { continuation in
                    let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate), options: .cumulativeSum) { _, statistics, error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)) }
                    }; store.execute(query)
                }
            } else {
                let type: HKSampleType = habit.kind == .workout ? HKObjectType.workoutType() : HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
                let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
                    store.execute(HKSampleQuery(sampleType: type, predicate: strict, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, values, error in if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: values ?? []) } })
                }
                let intervals = samples.flatMap { sample -> [DateInterval] in
                    guard let workout = sample as? HKWorkout else { return [DateInterval(start: sample.startDate, end: sample.endDate)] }
                    var active: [DateInterval] = [], cursor = workout.startDate, running = true
                    for event in (workout.workoutEvents ?? []).sorted(by: { $0.dateInterval.start < $1.dateInterval.start }) {
                        let date = max(workout.startDate, min(workout.endDate, event.dateInterval.start))
                        switch event.type {
                        case .pause, .motionPaused:
                            if running && cursor < date { active.append(DateInterval(start: cursor, end: date)) }; running = false
                        case .resume, .motionResumed:
                            if !running { cursor = date; running = true }
                        default: break
                        }
                    }
                    if running && cursor < workout.endDate { active.append(DateInterval(start: cursor, end: workout.endDate)) }
                    return active
                }
                amount = HabitEngine.mergedSeconds(intervals, within: DateInterval(start: start, end: end))
            }
            // HealthKit hides denied read permission. Never overwrite prior observed data
            // with a lower zero simply because a later query returns no accessible samples.
            try repository.update { current in let key = "health." + habit.kind.rawValue; let day = HabitEngine.day(now); let previous = current.samples.first { $0.habitID == habit.id && $0.day == day && $0.key == key }?.amount ?? 0; current.upsert(ProgressSample(habitID: habit.id, day: day, key: key, amount: max(previous, amount), date: now)) }
        }
    }
}
#endif
