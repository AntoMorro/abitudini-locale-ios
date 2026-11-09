import Foundation

struct JournalWatchHabit:Codable,Identifiable {var id:String;var title:String;var complete:Bool;var manual:Bool}
struct JournalWatchTask:Codable,Identifiable {var id:String;var title:String;var complete:Bool}
struct JournalWatchAck:Codable {var id:UUID;var accepted:Bool;var message:String}
struct JournalWatchSnapshot:Codable {
    var date=Date();var day:String;var tasks:[JournalWatchTask];var habits:[JournalWatchHabit];var acks:[JournalWatchAck];var mood:Int?
}
struct JournalWatchCommand:Codable,Identifiable {
    enum Action:String,Codable {case note,mood,completeTask,completeHabit}
    var id=UUID();var action:Action;var created=Date();var text="";var targetID:String?;var mood:Int?
    func validate(now:Date=Date())throws {
        guard text.count<=4000,created<=now.addingTimeInterval(300),created>=now.addingTimeInterval(-30*86400) else{throw WatchCommandError.invalid}
        switch action {
        case .note:guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw WatchCommandError.invalid}
        case .mood:guard let m=mood,(1...5).contains(m) else{throw WatchCommandError.invalid}
        case .completeTask,.completeHabit:guard let id=targetID,UUID(uuidString:id) != nil else{throw WatchCommandError.invalid}
        }
    }
}
enum WatchCommandError:LocalizedError {case invalid;var errorDescription:String?{"Comando non valido o più vecchio di 30 giorni. La bozza resta sul Watch."}}
