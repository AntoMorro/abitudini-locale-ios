import Foundation

enum GoalPeriod: String, Codable, CaseIterable { case daily, weekly, monthly }
struct HabitPlan: Codable, Equatable {
    var description = ""
    var category = ""
    var quit = false
    var scale = 1
    var unit = ""
    var period: GoalPeriod = .daily
    var target = 1
    var weekdays = Set(1...7)
    var reminders: [Int] = []
}
extension HabitDatabase {
    func plan(_ habit: Habit) -> HabitPlan { plans?[habit.id.uuidString] ?? HabitPlan() }
    func note(_ habit: Habit, on date: Date) -> String { notes?[habit.id.uuidString + "|" + HabitEngine.day(date)] ?? "" }
}
struct TrackerStats {
    var completions: Int
    var rate: Double
    var current: Int
    var longest: Int
}
enum Tracker {
    static func scheduled(_ h: Habit, db: HabitDatabase, date: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) >= calendar.startOfDay(for: h.created) && db.plan(h).weekdays.contains(calendar.component(.weekday, from: date))
    }
    static func total(_ h: Habit, db: HabitDatabase, date: Date, calendar: Calendar = .current) -> Int {
        db.samples.filter { $0.habitID == h.id && $0.day == HabitEngine.day(date, calendar: calendar) }.reduce(0) { min(1_000_000_000, $0 + $1.amount) }
    }
    static func complete(_ h: Habit, db: HabitDatabase, date: Date, calendar: Calendar = .current) -> Bool {
        let key = HabitEngine.day(date, calendar: calendar)
        guard db.samples.contains(where: { $0.habitID == h.id && $0.day == key }) else { return false }
        let amount = total(h, db: db, date: date, calendar: calendar)
        return db.plan(h).quit ? (h.kind == .check ? amount > 0 : amount < h.goal) : amount >= h.goal
    }
    static func record(_ h: Habit, db: inout HabitDatabase, date: Date, amount: Int?, note: String? = nil, now: Date = Date(), calendar: Calendar = .current) throws {
        guard db.habits.contains(where: { $0.id == h.id }), !h.archived, !h.kind.automatic,
              calendar.startOfDay(for: date) <= calendar.startOfDay(for: now),
              calendar.startOfDay(for: date) >= calendar.startOfDay(for: h.created),
              amount == nil || (0...1_000_000_000).contains(amount!), (note?.count ?? 0) <= 10_000 else { throw HabitError.invalid }
        let key = HabitEngine.day(date, calendar: calendar)
        if db.timer?.habitID == h.id { HabitEngine.settleTimer(&db, now: now, calendar: calendar) }
        db.samples.removeAll { $0.habitID == h.id && $0.day == key }
        if let amount { db.samples.append(ProgressSample(habitID: h.id, day: key, key: "tracker.total", amount: amount, date: date)) }
        if let note { if db.notes == nil { db.notes = [:] }; db.notes?[h.id.uuidString + "|" + key] = note.isEmpty ? nil : note }
    }
    static func periodProgress(_ h: Habit, db: HabitDatabase, date: Date, calendar: Calendar = .current) -> (Int, Int) {
        let p = db.plan(h)
        let component: Calendar.Component = p.period == .weekly ? .weekOfYear : p.period == .monthly ? .month : .day
        guard let interval = calendar.dateInterval(of: component, for: date) else { return (0,p.target) }
        var cursor = interval.start, count = 0
        while cursor < min(interval.end, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!) {
            if scheduled(h, db: db, date: cursor, calendar: calendar) && complete(h, db: db, date: cursor, calendar: calendar) { count += 1 }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return (count, p.period == .daily ? 1 : p.target)
    }
    static func stats(_ h: Habit, db: HabitDatabase, now: Date = Date(), calendar: Calendar = .current) -> TrackerStats {
        let p = db.plan(h), today = calendar.startOfDay(for: now)
        var cursor = calendar.startOfDay(for: h.created), completed = 0, due = 0
        var run = 0, longest = 0
        while cursor <= today {
            if scheduled(h, db: db, date: cursor, calendar: calendar) {
                if complete(h, db: db, date: cursor, calendar: calendar) { completed += 1 }
                if cursor < today || complete(h, db: db, date: cursor, calendar: calendar) { due += 1 }
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        let component: Calendar.Component = p.period == .daily ? .day : p.period == .weekly ? .weekOfYear : .month
        cursor = calendar.dateInterval(of: component, for: h.created)!.start
        let currentStart = calendar.dateInterval(of: component, for: now)!.start
        while cursor <= currentStart {
            let end = calendar.dateInterval(of: component, for: cursor)!.end
            if p.period == .daily && !scheduled(h, db: db, date: cursor, calendar: calendar) { cursor = end; continue }
            let evaluation = min(now, end.addingTimeInterval(-1))
            let progress = periodProgress(h, db: db, date: evaluation, calendar: calendar)
            if progress.0 >= progress.1 { run += 1; longest = max(longest,run) }
            else if cursor < currentStart { run = 0 }
            cursor = end
        }
        return TrackerStats(completions: completed, rate: due == 0 ? 0 : Double(completed) / Double(due), current: run, longest: longest)
    }
    static func csv(_ db: HabitDatabase) -> String {
        func cell(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["abitudine,data,valore,unita,completata,nota"]
        for h in db.habits {
            let keys = Set(db.samples.filter { $0.habitID == h.id }.map(\.day)).union((db.notes ?? [:]).keys.filter { $0.hasPrefix(h.id.uuidString + "|") }.map { String($0.suffix(10)) })
            for key in keys.sorted() {
                let amount = db.samples.filter { $0.habitID == h.id && $0.day == key }.reduce(0) { $0 + $1.amount }
                let exists = db.samples.contains { $0.habitID == h.id && $0.day == key }
                let done = exists && (db.plan(h).quit ? (h.kind == .check ? amount > 0 : amount < h.goal) : amount >= h.goal)
                lines.append([h.title, key, exists ? String(Double(amount) / Double(db.plan(h).scale)) : "", db.plan(h).unit, done ? "1" : "0", db.notes?[h.id.uuidString + "|" + key] ?? ""].map(cell).joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }
}
