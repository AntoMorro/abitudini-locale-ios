import Foundation
import ActivityKit

struct HabitActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var title: String; var started: Date; var goalEnd: Date }
    var habitID: String
}
@MainActor enum LiveTimer {
    static func start(habit: Habit, db: HabitDatabase) {
        #if WIDGETS && !WIDGET_HOST
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let remaining = max(1, habit.goal - HabitEngine.progress(habit, in: db))
        let state = HabitActivityAttributes.ContentState(title: habit.title, started: Date(), goalEnd: Date().addingTimeInterval(Double(remaining)))
        _ = try? Activity.request(attributes: HabitActivityAttributes(habitID: habit.id.uuidString), content: ActivityContent(state: state, staleDate: nil), pushType: nil)
        #endif
    }
    static func end() {
        #if WIDGETS && !WIDGET_HOST
        for activity in Activity<HabitActivityAttributes>.activities { Task { await activity.end(nil, dismissalPolicy: .immediate) } }
        #endif
    }
}
