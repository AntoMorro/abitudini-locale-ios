import Foundation

extension JournalEngine {
    static func receive(_ command:JournalWatchCommand,in db:inout HabitDatabase,now:Date=Date())throws {
        try command.validate(now:now)
        var j=db.journal ?? JournalDatabase()
        if j.receipts.contains(where:{$0.id==command.id && $0.accepted}){return}
        switch command.action {
        case .note:
            if !j.bullets.contains(where:{$0.id==command.id}){j.bullets.append(JournalBullet(id:command.id,text:command.text,date:command.created,kind:.note))}
        case .mood:
            if !j.pages.contains(where:{$0.id==command.id}){var p=JournalPage(id:command.id,title:"Check-in dal Watch",date:command.created,template:"checkin");p.mood=command.mood;save(p,in:&j)}
        case .completeTask:
            guard let id=command.targetID.flatMap(UUID.init(uuidString:)),let b=j.bullets.first(where:{$0.id==id}),b.kind == .task,b.status != .cancelled else{throw HabitError.missing}
            if b.status != .done {try complete(id,in:&j)}
        case .completeHabit:
            guard let id=command.targetID.flatMap(UUID.init(uuidString:)),let h=db.habits.first(where:{$0.id==id}),!h.archived,h.kind == .check,!db.rules.contains(where:{$0.habitIDs.contains(id) && HabitEngine.locked($0,now:now)}) else{throw HabitError.locked}
            try Tracker.record(h,db:&db,date:command.created,amount:1)
        }
        j.receipts.append(JournalReceipt(id:command.id,accepted:true,message:"Salvato su iPhone",date:now));j.receipts=Array(j.receipts.suffix(2000));db.journal=j
    }
}
