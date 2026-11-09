import SwiftUI
import UserNotifications
import EventKit

extension HabitStore {
    var journal:JournalDatabase {db.journal ?? JournalDatabase()}
    @discardableResult func journalChange(_ body:(inout JournalDatabase)throws->Void)->Bool {change{db in var j=db.journal ?? JournalDatabase();try body(&j);db.journal=j}}
    func savePage(_ p:JournalPage)->Bool {journalChange{JournalEngine.save(p,in:&$0)}}
    func saveBullet(_ b:JournalBullet)->Bool {journalChange{j in if let i=j.bullets.firstIndex(where:{$0.id==b.id}){j.bullets[i]=b}else{j.bullets.append(b)}}}
    func completeBullet(_ b:JournalBullet){journalChange{j in if b.status == .done,let i=j.bullets.firstIndex(where:{$0.id==b.id}){j.bullets[i].status = .open}else{try JournalEngine.complete(b.id,in:&j)}}}
}
@MainActor enum JournalReminders {
    static func sync(_ db:HabitDatabase) async {
        let center=UNUserNotificationCenter.current(),all=await center.pendingNotificationRequests()
        guard !Task.isCancelled else{return}
        center.removePendingNotificationRequests(withIdentifiers:all.filter{$0.identifier.hasPrefix("journal.")}.map(\.identifier))
        let settings=await center.notificationSettings();guard [.authorized,.provisional].contains(settings.authorizationStatus),let j=db.journal else{return}
        var remaining=max(0,60-HabitReminders.count(db))
        if let m=j.preferences.dailyReminderMinute,remaining>0 {
            let c=UNMutableNotificationContent();c.title="Un momento per te";c.body="Apri il quaderno e raccogli un pensiero della giornata.";c.sound = .default
            var d=DateComponents();d.hour=m/60;d.minute=m%60
            try? await center.add(UNNotificationRequest(identifier:"journal.daily",content:c,trigger:UNCalendarNotificationTrigger(dateMatching:d,repeats:true)));remaining-=1
        }
        let tasks=j.bullets.filter{$0.status == .open && ($0.reminder ?? .distantPast)>Date()}.sorted{$0.reminder!<$1.reminder!}
        for b in tasks.prefix(remaining){guard !Task.isCancelled else{return};let c=UNMutableNotificationContent();c.title="Quaderno Locale";c.body="Hai un'attività programmata nel tuo quaderno.";c.sound = .default
            let d=Calendar.current.dateComponents([.year,.month,.day,.hour,.minute],from:b.reminder!);try? await center.add(UNNotificationRequest(identifier:"journal."+b.id.uuidString,content:c,trigger:UNCalendarNotificationTrigger(dateMatching:d,repeats:false)))
        }
    }
}
@MainActor final class JournalReminderImporter:ObservableObject {
    @Published var calendars:[EKCalendar]=[]
    @Published var error:String?
    @Published var ready=false
    let events=EKEventStore()
    func authorize()async {
        do{let allowed=try await withCheckedThrowingContinuation{(c:CheckedContinuation<Bool,Error>) in events.requestFullAccessToReminders{ok,error in if let error=error{c.resume(throwing:error)}else{c.resume(returning:ok)}}};guard allowed else{error="Accesso ai promemoria non concesso.";return};calendars=events.calendars(for:.reminder);ready=true}catch{self.error=error.localizedDescription}
    }
    func load(_ id:String)async->[EKReminder] {
        guard let c=calendars.first(where:{$0.calendarIdentifier==id}) else{return []}
        return await withCheckedContinuation{continuation in events.fetchReminders(matching:events.predicateForIncompleteReminders(withDueDateStarting:nil,ending:nil,calendars:[c])){continuation.resume(returning:$0 ?? [])}}
    }
    func importItems(_ values:[EKReminder],store:HabitStore)->Int {
        var count=0
        _=store.journalChange{j in
            var seen=Set(j.bullets.compactMap(\.sourceReminderID))
            for r in values {
                let id=r.calendar.source.sourceIdentifier+"|"+(r.calendarItemExternalIdentifier ?? r.calendarItemIdentifier)
                guard seen.insert(id).inserted else{continue}
                let title=String((r.title ?? "Promemoria").prefix(3500));guard !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{continue}
                let date=r.dueDateComponents.flatMap{Calendar.current.date(from:$0)} ?? Date()
                j.bullets.append(JournalBullet(text:title,date:date,kind:.task,sourceReminderID:id));count+=1
            }
        };return count
    }
}
