import Foundation
import UserNotifications

@MainActor enum HabitReminders {
    static func authorize() async throws -> Bool { try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge]) }
    static func count(_ db: HabitDatabase) -> Int { Tracker.reminderRequestCount(db) }
    static func sync(_ db: HabitDatabase) async -> String {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else { return "" }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("habit.") }.map(\.identifier))
        let count = count(db)
        guard count <= 60 else { return "Troppi promemoria: riduci orari o giorni (massimo 60 combinazioni)." }
        guard count > 0 else { return "Nessun promemoria programmato" }
        let settings = await center.notificationSettings()
        guard [.authorized,.provisional,.ephemeral].contains(settings.authorizationStatus) else { return "Notifiche non autorizzate: abilita Abitudini Locale nelle impostazioni iPhone." }
        do {
            if let minute = db.checkInMinute {
                var components = DateComponents(); components.hour = minute/60; components.minute = minute%60
                let content = UNMutableNotificationContent(); content.title = "Il tuo ritmo, oggi"; content.body = "Hai registrato le tue abitudini di oggi?"; content.sound = .default
                try await center.add(UNNotificationRequest(identifier: "habit.checkin", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
            }
            for h in db.habits where !h.archived {
                let p = db.plan(h)
                let days = p.weekdays.count == 7 ? [0] : p.weekdays.sorted()
                for minute in p.reminders { for day in days {
                    guard !Task.isCancelled else { return "" }
                    var components = DateComponents(); if day > 0 { components.weekday = day }; components.hour = minute/60; components.minute = minute%60
                    let content = UNMutableNotificationContent(); content.title = h.title; content.body = p.description.isEmpty ? "Un piccolo passo per la tua abitudine." : p.description; content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    try await center.add(UNNotificationRequest(identifier: "habit.\(h.id).\(day).\(minute)", content: content, trigger: trigger))
                } }
            }
            return "\(count) richieste di promemoria programmate"
        } catch { return "Promemoria: \(error.localizedDescription)" }
    }
}
