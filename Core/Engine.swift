import Foundation

enum HabitEngine {
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = calendar.timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func timerSeconds(_ timer: HabitTimer, now: Date, uptime: Double = ProcessInfo.processInfo.systemUptime) -> Int {
        if !timer.background && timer.processID != ProcessInfo.processInfo.processIdentifier { return 0 }
        let delta = uptime >= timer.uptime ? uptime - timer.uptime : now.timeIntervalSince(timer.started)
        return Int(min(604800, max(0, delta)))
    }
    static func settleTimer(_ db: inout HabitDatabase, now: Date, uptime: Double = ProcessInfo.processInfo.systemUptime, keepRunning: Bool = false, calendar: Calendar = .current) {
        guard let t = db.timer else { return }
        let seconds = timerSeconds(t, now: now, uptime: uptime)
        let finish = t.started.addingTimeInterval(Double(seconds))
        var cursor = t.started
        while cursor < finish {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cursor))!
            let end = min(nextDay, finish)
            let key = "timer." + t.id.uuidString
            let dateKey = day(cursor, calendar: calendar)
            let old = db.samples.first { $0.habitID == t.habitID && $0.day == dateKey && $0.key == key }?.amount ?? 0
            db.upsert(ProgressSample(habitID: t.habitID, day: dateKey, key: key, amount: old + Int(end.timeIntervalSince(cursor)), date: end))
            cursor = end
        }
        db.timer = keepRunning ? HabitTimer(habitID: t.habitID, started: now, uptime: uptime, background: t.background) : nil
    }
    static func progress(_ habit: Habit, in db: HabitDatabase, now: Date = Date(), uptime: Double = ProcessInfo.processInfo.systemUptime, calendar: Calendar = .current) -> Int {
        var copy = db
        if db.timer?.habitID == habit.id { settleTimer(&copy, now: now, uptime: uptime, calendar: calendar) }
        let total = copy.samples.filter { $0.habitID == habit.id && $0.day == day(now, calendar: calendar) }.reduce(0) { min(1_000_000_000, $0 + $1.amount) }
        return habit.capOnceDaily ? min(habit.goal, total) : total
    }
    static func active(_ rule: BlockRule, now: Date, calendar: Calendar = .current) -> Bool {
        guard rule.enabled else { return false }
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        let minute = c.hour! * 60 + c.minute!
        if rule.startMinute == rule.endMinute || (rule.startMinute == 0 && rule.endMinute == 1440) { return rule.weekdays.contains(c.weekday!) }
        if rule.startMinute < rule.endMinute { return rule.weekdays.contains(c.weekday!) && minute >= rule.startMinute && minute < rule.endMinute }
        if minute >= rule.startMinute { return rule.weekdays.contains(c.weekday!) }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        return minute < rule.endMinute && rule.weekdays.contains(calendar.component(.weekday, from: yesterday))
    }
    static func sessionOpen(_ rule: BlockRule, now: Date, calendar: Calendar = .current) -> Bool {
        guard let s = rule.session else { return false }
        return !s.exhausted && s.day == day(now, calendar: calendar) && now < s.ends
    }
    static func earned(_ rule: BlockRule, db: HabitDatabase, now: Date, calendar: Calendar = .current) -> Int {
        let cycles = rule.habitIDs.compactMap { id in db.habits.first { $0.id == id } }.map { progress($0, in: db, now: now, calendar: calendar) / $0.goal }.sorted(by: >)
        guard cycles.count == rule.habitIDs.count, !cycles.isEmpty else { return 0 }
        switch rule.requirement { case .all: return cycles.last!; case .any: return cycles.first!; case .atLeast: return cycles[min(cycles.count, max(1, rule.minimum)) - 1] }
    }
    static func credits(_ rule: BlockRule, db: HabitDatabase, now: Date, calendar: Calendar = .current) -> Int {
        max(0, earned(rule, db: db, now: now, calendar: calendar) - db.spends.filter { $0.ruleID == rule.id && $0.day == day(now, calendar: calendar) }.count)
    }
    static func shouldShield(_ rule: BlockRule, db: HabitDatabase, now: Date, calendar: Calendar = .current) -> Bool {
        active(rule, now: now, calendar: calendar) && !(db.emergencyUntil.map { now < $0 } ?? false) && !sessionOpen(rule, now: now, calendar: calendar)
    }
    static func spend(_ ruleID: UUID, db: inout HabitDatabase, now: Date, calendar: Calendar = .current) throws {
        settleTimer(&db, now: now, keepRunning: db.timer != nil, calendar: calendar)
        guard let i = db.rules.firstIndex(where: { $0.id == ruleID }) else { throw HabitError.missing }
        let r = db.rules[i]
        guard !sessionOpen(r, now: now, calendar: calendar) else { throw HabitError.alreadyOpen }
        guard active(r, now: now, calendar: calendar), credits(r, db: db, now: now, calendar: calendar) > 0 else { throw HabitError.noCredit }
        let endDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let end = r.unlockMode == .session ? min(endDay, now.addingTimeInterval(Double(r.unlockMinutes * 60))) : endDay
        db.rules[i].session = UnlockSession(day: day(now, calendar: calendar), mode: r.unlockMode, started: now, ends: end, minutes: r.unlockMinutes)
        db.spends.append(Spend(ruleID: r.id, day: day(now, calendar: calendar), date: now))
    }
    static func locked(_ rule: BlockRule, now: Date) -> Bool { rule.commitmentUntil.map { now < $0 } ?? false }
    static func add(_ habitID: UUID, amount: Int, db: inout HabitDatabase, now: Date) throws {
        guard let h = db.habits.first(where: { $0.id == habitID }), !h.archived, !h.kind.automatic, h.kind != .timer, amount > 0, amount <= 1_000_000 else { throw HabitError.invalid }
        db.samples.append(ProgressSample(habitID: habitID, day: day(now), key: "manual." + UUID().uuidString, amount: amount, date: now))
    }
    static func heatmap(_ habit: Habit, db: HabitDatabase, days: Int = 84, now: Date = Date(), calendar: Calendar = .current) -> [(Date, Double)] {
        (0..<days).reversed().map { offset in let date = calendar.date(byAdding: .day, value: -offset, to: now)!; let total = db.samples.filter { $0.habitID == habit.id && $0.day == day(date, calendar: calendar) }.reduce(0) { $0 + $1.amount }; return (date, min(1, Double(total) / Double(habit.goal))) }
    }
    static func mergedSeconds(_ intervals: [DateInterval], within limit: DateInterval) -> Int {
        let sorted = intervals.compactMap { $0.intersection(with: limit) }.sorted { $0.start < $1.start }
        var total: TimeInterval = 0, current: DateInterval?
        for interval in sorted {
            if let old = current { if interval.start <= old.end { current = DateInterval(start: old.start, end: max(old.end, interval.end)) } else { total += old.duration; current = interval } }
            else { current = interval }
        }
        return Int(total + (current?.duration ?? 0))
    }
    static func demo(now: Date = Date()) -> HabitDatabase {
        var db = HabitDatabase(); db.onboarded = true
        let study = Habit(title: "Studio profondo", symbol: "book.closed", color: "cyan", kind: .timer, goal: 25 * 60, capOnceDaily: false)
        let cards = Habit(title: "Ripassa 20 carte", symbol: "rectangle.on.rectangle", color: "blue", kind: .counter, goal: 20)
        let journal = Habit(title: "Scrivi una pagina", symbol: "pencil", color: "orange")
        db.habits = [study, cards, journal]
        for i in db.habits.indices { db.habits[i].created = Calendar.current.date(byAdding: .day, value: -84, to: now)! }
        db.rules = [BlockRule(title: "Prima lo studio", habitIDs: [study.id, cards.id], unlockMinutes: 15)]
        for offset in 1...20 where offset % 4 != 0 { let date = Calendar.current.date(byAdding: .day, value: -offset, to: now)!; db.samples.append(ProgressSample(habitID: cards.id, day: day(date), key: "demo.\(offset)", amount: 20, date: date)) }
        return db
    }
}
