import Foundation

enum BulletKind:String,Codable,CaseIterable,Identifiable {case task,event,note;var id:String{rawValue};var title:String{switch self{case .task:return "Attività";case .event:return "Evento";case .note:return "Nota"}};var glyph:String{switch self{case .task:return "•";case .event:return "○";case .note:return "–"}}}
enum BulletStatus:String,Codable {case open,done,cancelled,migrated}
enum BulletRepeat:String,Codable,CaseIterable,Identifiable {case none,daily,weekdays,weekly,monthly;var id:String{rawValue};var title:String{switch self{case .none:return "Mai";case .daily:return "Ogni giorno";case .weekdays:return "Giorni feriali";case .weekly:return "Ogni settimana";case .monthly:return "Ogni mese"}}}
struct JournalBullet:Codable,Identifiable,Equatable {
    var id=UUID();var text:String;var date=Date();var kind:BulletKind = .task;var status:BulletStatus = .open
    var important=false;var notebookID=JournalBook.inboxID;var pageID:UUID?;var migratedTo:UUID?;var nextID:UUID?
    var recurrence:BulletRepeat = .none;var anchorDay:Int?;var reminder:Date?;var sourceReminderID:String?
}
struct JournalBook:Codable,Identifiable,Equatable {
    static let inboxID=UUID(uuidString:"A922D2D5-13AB-4401-AD76-A7CF10B1C001")!
    static let diaryID=UUID(uuidString:"A922D2D5-13AB-4401-AD76-A7CF10B1C002")!
    static let studyID=UUID(uuidString:"A922D2D5-13AB-4401-AD76-A7CF10B1C003")!
    var id=UUID();var title:String;var symbol="book.closed";var color="mint";var archived=false
}
struct JournalPhoto:Codable,Identifiable,Equatable {var id=UUID();var data:Data;var caption=""}
struct JournalPage:Codable,Identifiable,Equatable {
    var id=UUID();var number=0;var notebookID=JournalBook.diaryID;var title:String;var body="";var date=Date();var updated=Date()
    var tags:[String]=[];var favorite=false;var template="libera";var mood:Int?;var energy:Int?;var sleep:Double?;var place=""
    var photos:[JournalPhoto]=[];var ink:Data?;var audio:Data?;var audioDuration:Double?
}
struct JournalReceipt:Codable,Equatable {var id:UUID;var accepted:Bool;var message:String;var date:Date}
struct JournalPreferences:Codable {
    var lock=false;var dailyReminderMinute:Int?;var watchEnabled=false
}
struct JournalDatabase:Codable {
    var version=1
    var books=[JournalBook(id:JournalBook.inboxID,title:"Raccolta rapida",symbol:"tray",color:"mint"),JournalBook(id:JournalBook.diaryID,title:"Il mio diario",symbol:"book.closed",color:"indigo"),JournalBook(id:JournalBook.studyID,title:"Studio e idee",symbol:"lightbulb",color:"orange")]
    var pages:[JournalPage]=[];var bullets:[JournalBullet]=[];var receipts:[JournalReceipt]=[];var preferences=JournalPreferences()
    func validated()throws->JournalDatabase {
        guard version==1,books.count<=100,pages.count<=10_000,bullets.count<=30_000,receipts.count<=2000 else{throw HabitError.invalid}
        guard Set(books.map(\.id)).count==books.count,Set(pages.map(\.id)).count==pages.count,Set(bullets.map(\.id)).count==bullets.count,Set(receipts.map(\.id)).count==receipts.count else{throw HabitError.invalid}
        let bookIDs=Set(books.map(\.id)),pageIDs=Set(pages.map(\.id)),bulletIDs=Set(bullets.map(\.id))
        guard bookIDs.contains(JournalBook.inboxID),bookIDs.contains(JournalBook.diaryID),bookIDs.contains(JournalBook.studyID),preferences.dailyReminderMinute==nil || (0..<1440).contains(preferences.dailyReminderMinute!) else{throw HabitError.invalid}
        for b in books{guard !b.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,b.title.count<=200,b.symbol.count<=100,b.color.count<=30 else{throw HabitError.invalid}}
        guard Set(pages.map(\.number)).count==pages.count else{throw HabitError.invalid}
        for p in pages {
            guard (1...1_000_000).contains(p.number),bookIDs.contains(p.notebookID),p.title.count<=500,p.body.count<=250_000,p.tags.count<=30,p.tags.allSatisfy({$0.count<=80}),p.mood==nil || (1...5).contains(p.mood!),p.energy==nil || (1...5).contains(p.energy!),p.sleep==nil || (p.sleep!.isFinite && (0...24).contains(p.sleep!)),p.photos.count<=4,p.photos.allSatisfy({$0.data.count<=1_000_000}),Set(p.photos.map(\.id)).count==p.photos.count,(p.ink?.count ?? 0)<=2_000_000,(p.audio?.count ?? 0)<=3_000_000,p.audioDuration==nil || (p.audioDuration!.isFinite && (0...120).contains(p.audioDuration!)) else{throw HabitError.invalid}
        }
        for b in bullets {guard !b.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,b.text.count<=4000,bookIDs.contains(b.notebookID),b.pageID==nil || pageIDs.contains(b.pageID!),b.migratedTo==nil || bulletIDs.contains(b.migratedTo!),b.nextID==nil || bulletIDs.contains(b.nextID!),b.anchorDay==nil || (1...31).contains(b.anchorDay!),b.sourceReminderID==nil || b.sourceReminderID!.count<=1000 else{throw HabitError.invalid}}
        return self
    }
}
struct JournalTemplate:Identifiable {
    var id:String;var title:String;var subtitle:String;var body:String
    static let all:[JournalTemplate]=[
        .init(id:"libera",title:"Pagina libera",subtitle:"Il tuo spazio, senza schema",body:""),
        .init(id:"mattino",title:"Intenzione del mattino",subtitle:"Tre priorità e un'intenzione",body:"La mia intenzione\n\nLe tre cose che contano\n1. \n2. \n3. \n\nUna cosa da rendere più semplice\n"),
        .init(id:"sera",title:"Riflessione serale",subtitle:"Chiudere la giornata con consapevolezza",body:"Che cosa è successo oggi?\n\nUna cosa che ho imparato\n\nUn momento da ricordare\n\nChe cosa lascio andare?\n"),
        .init(id:"gratitudine",title:"Gratitudine",subtitle:"Tre dettagli che meritano attenzione",body:"Oggi sono grato per…\n1. \n2. \n3. \n\nA chi vorrei dire grazie?\n"),
        .init(id:"settimana",title:"Revisione settimanale",subtitle:"Rivedi, scegli, prepara",body:"Vittorie della settimana\n\nChe cosa mi ha dato energia?\n\nChe cosa mi ha tolto energia?\n\nAttività da eliminare o migrare\n\nPriorità della prossima settimana\n"),
        .init(id:"mese",title:"Apertura del mese",subtitle:"Obiettivi, appuntamenti e spazio",body:"Il tema del mese\n\nTre obiettivi concreti\n\nDate importanti\n\nAbitudini da coltivare\n\nUna cosa da non sovraccaricare\n"),
        .init(id:"lettura",title:"Libro e apprendimento",subtitle:"Collega conoscenza e azione",body:"Libro o fonte\n\nDomanda di partenza\n\nIdee principali\n\nCitazione e riferimento\n\nCome posso applicarlo?\n\nDomande ancora aperte\n"),
        .init(id:"raccolta",title:"Raccolta personale",subtitle:"Libri, viaggi, progetti o idee",body:"Scopo della raccolta\n\nIdee e riferimenti\n\nProssime azioni\n"),
        .init(id:"progetto",title:"Progetto",subtitle:"Da un'intenzione ai prossimi passi",body:"Risultato desiderato\n\nPerché conta\n\nDefinizione di completato\n\nProssima azione concreta\n\nOstacoli e risorse\n"),
        .init(id:"anno",title:"Visione annuale",subtitle:"Valori, direzione e ricordi",body:"Che persona voglio diventare?\n\nValori da proteggere\n\nEsperienze desiderate\n\nTraguardi personali\n\nCose a cui dire di no\n")]
}
enum JournalEngine {
    static func day(_ date:Date,calendar:Calendar = .current)->String{HabitEngine.day(date,calendar:calendar)}
    static func label(_ date:Date)->String{date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier:"it_IT")))}
    static func save(_ page:JournalPage,in db:inout JournalDatabase) {
        var p=page;p.updated=Date();p.title=p.title.trimmingCharacters(in:.whitespacesAndNewlines);if p.title.isEmpty{p.title="Una pagina del mio diario"};p.tags=Array(Set(p.tags.map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty})).sorted()
        if let i=db.pages.firstIndex(where:{$0.id==p.id}){p.number=db.pages[i].number;db.pages[i]=p}else{p.number=(db.pages.map(\.number).max() ?? 0)+1;db.pages.append(p)}
    }
    static func removePage(_ id:UUID,in db:inout JournalDatabase){db.pages.removeAll{$0.id==id};for i in db.bullets.indices where db.bullets[i].pageID==id{db.bullets[i].pageID=nil}}
    static func removeBullet(_ id:UUID,in db:inout JournalDatabase){db.bullets.removeAll{$0.id==id};for i in db.bullets.indices{if db.bullets[i].nextID==id{db.bullets[i].nextID=nil};if db.bullets[i].migratedTo==id{db.bullets[i].migratedTo=nil}}}
    static func complete(_ id:UUID,in db:inout JournalDatabase,calendar:Calendar = .current)throws {
        guard let i=db.bullets.firstIndex(where:{$0.id==id}),db.bullets[i].status != .migrated else{throw HabitError.missing}
        db.bullets[i].status = .done;db.bullets[i].reminder=nil
        let old=db.bullets[i]
        guard old.kind == .task,old.nextID==nil,let date=nextDate(old,calendar:calendar) else{return}
        var next=old;next.id=UUID();next.date=date;next.status = .open;next.reminder=nil;next.nextID=nil;next.migratedTo=nil;next.sourceReminderID=nil;next.anchorDay=old.anchorDay ?? calendar.component(.day,from:old.date)
        db.bullets[i].nextID=next.id;db.bullets.append(next)
    }
    static func nextDate(_ b:JournalBullet,calendar:Calendar = .current)->Date? {
        let start=calendar.startOfDay(for:b.date)
        switch b.recurrence {
        case .none:return nil
        case .daily:return calendar.date(byAdding:.day,value:1,to:start)
        case .weekly:return calendar.date(byAdding:.day,value:7,to:start)
        case .weekdays:var d=start;repeat{d=calendar.date(byAdding:.day,value:1,to:d)!}while [1,7].contains(calendar.component(.weekday,from:d));return d
        case .monthly:
            let m=calendar.date(byAdding:.month,value:1,to:calendar.date(from:calendar.dateComponents([.year,.month],from:start))!)!
            var c=calendar.dateComponents([.year,.month],from:m);c.day=min(b.anchorDay ?? calendar.component(.day,from:start),calendar.range(of:.day,in:.month,for:m)!.count);return calendar.date(from:c)
        }
    }
    @discardableResult static func migrate(_ id:UUID,to date:Date,in db:inout JournalDatabase)throws->UUID {
        guard let i=db.bullets.firstIndex(where:{$0.id==id}) else{throw HabitError.missing}
        if let target=db.bullets[i].migratedTo{return target}
        guard db.bullets[i].status == .open,db.bullets[i].kind == .task else{throw HabitError.invalid}
        var next=db.bullets[i];next.id=UUID();next.date=date;next.reminder=nil;next.migratedTo=nil;next.sourceReminderID=nil;next.nextID=nil
        db.bullets[i].status = .migrated;db.bullets[i].migratedTo=next.id;db.bullets[i].reminder=nil;db.bullets.append(next);return next.id
    }
    static func search(_ query:String,in db:JournalDatabase)->[JournalPage] {db.pages.filter{query.isEmpty || ([$0.title,$0.body,$0.place]+$0.tags).joined(separator:" ").localizedStandardContains(query)}.sorted{$0.date>$1.date}}
    static func onThisDay(_ db:JournalDatabase,now:Date=Date(),calendar:Calendar = .current)->[JournalPage] {db.pages.filter{calendar.component(.month,from:$0.date)==calendar.component(.month,from:now) && calendar.component(.day,from:$0.date)==calendar.component(.day,from:now) && calendar.component(.year,from:$0.date)<calendar.component(.year,from:now)}}
    static func markdown(_ db:JournalDatabase)->String {
        let pages=db.pages.sorted{$0.date<$1.date}.map{p in "## \(p.title)\n\n\(label(p.date)) · pagina \(p.number)\n\n\(p.body)\n\n"+p.tags.map{"#"+$0}.joined(separator:" ")}
        let bullets=db.bullets.sorted{$0.date<$1.date}.map{b in "\(b.status == .done ? "[x]":b.status == .migrated ? ">":b.status == .cancelled ? "~":b.kind.glyph) \(label(b.date)) · \(b.text)"}
        return "# Quaderno Locale\n\n"+pages.joined(separator:"\n\n---\n\n")+"\n\n# Registro rapido\n\n"+bullets.joined(separator:"\n")
    }
}
