import DeviceActivity
import Foundation
import WidgetKit

final class HabitMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) { super.intervalDidStart(for: activity); apply() }
    override func intervalDidEnd(for activity: DeviceActivityName) { super.intervalDidEnd(for: activity); expire(activity); apply() }
    override func intervalWillEndWarning(for activity: DeviceActivityName) { super.intervalWillEndWarning(for: activity); if activity.rawValue.hasPrefix("al.unlock.") { expire(activity); apply() } }
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let repository = HabitEnvironment.sharedRepository else { return }
        do {
            let parts = event.rawValue.split(separator: ".").map(String.init)
            try repository.update { db in
                if parts.count == 2, parts[0] == "goal", let id = UUID(uuidString: parts[1]), let h = db.habits.first(where: { $0.id == id }) {
                    db.upsert(ProgressSample(habitID: id, day: HabitEngine.day(Date()), key: "app.goal", amount: h.goal, date: Date()))
                } else if parts.count == 3, parts[0] == "spent", let id = UUID(uuidString: parts[1]), let sid = UUID(uuidString: parts[2]), let i = db.rules.firstIndex(where: { $0.id == id && $0.session?.id == sid }) { db.rules[i].session?.exhausted = true }
            }
            apply(); WidgetCenter.shared.reloadAllTimelines()
        } catch { /* Keep existing OS shields if a protected archive is temporarily unavailable. */ }
    }
    private func expire(_ activity: DeviceActivityName) {
        let parts = activity.rawValue.split(separator: ".").map(String.init)
        guard parts.count == 4, parts[1] == "unlock", let rid = UUID(uuidString: parts[2]), let sid = UUID(uuidString: parts[3]), let repository = HabitEnvironment.sharedRepository else { return }
        try? repository.update { db in if let i = db.rules.firstIndex(where: { $0.id == rid && $0.session?.id == sid }) { db.rules[i].session?.exhausted = true } }
    }
    private func apply() { if let db = try? HabitEnvironment.sharedRepository?.read() { ScreenPolicy.apply(db) } }
}
