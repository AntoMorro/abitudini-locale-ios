import Foundation
import WatchConnectivity

@MainActor final class JournalPhoneBridge:NSObject,ObservableObject,WCSessionDelegate {
    static let shared=JournalPhoneBridge()
    @Published var status="Companion non collegata"
    weak var store:HabitStore?
    func start(_ store:HabitStore){self.store=store;guard WCSession.isSupported() else{return};WCSession.default.delegate=self;WCSession.default.activate()}
    func publish(_ db:HabitDatabase,extra:JournalWatchAck?=nil) {
        guard WCSession.isSupported() else{return};let s=WCSession.default
        guard s.activationState == .activated else{return}
        guard db.journal?.preferences.watchEnabled == true else{status="Invio al Watch disattivato";try? s.updateApplicationContext(["enabled":false]);return}
        guard s.isPaired,s.isWatchAppInstalled else{status="La companion deve essere installata sul Watch";return}
        let j=db.journal ?? JournalDatabase(),day=JournalEngine.day(Date())
        let tasks=j.bullets.filter{JournalEngine.day($0.date)==day && $0.kind == .task && [.open,.done].contains($0.status)}.prefix(12).map{JournalWatchTask(id:$0.id.uuidString,title:String($0.text.prefix(120)),complete:$0.status == .done)}
        let habits=db.habits.filter{!$0.archived}.prefix(8).map{JournalWatchHabit(id:$0.id.uuidString,title:String($0.title.prefix(120)),complete:Tracker.complete($0,db:db,date:Date()),manual:$0.kind == .check)}
        var acks=j.receipts.suffix(128).map{JournalWatchAck(id:$0.id,accepted:$0.accepted,message:$0.message)};if let extra=extra{acks.append(extra)}
        let snapshot=JournalWatchSnapshot(day:day,tasks:Array(tasks),habits:Array(habits),acks:acks,mood:j.pages.filter{JournalEngine.day($0.date)==day}.sorted{$0.updated>$1.updated}.compactMap(\.mood).first)
        do{let data=try JSONEncoder().encode(snapshot);guard data.count<60_000 else{throw HabitError.invalid};try s.updateApplicationContext(["enabled":true,"snapshot":data]);status="Riepilogo inviato · "+Date().formatted(date:.omitted,time:.shortened)}catch{status=error.localizedDescription}
    }
    nonisolated func session(_ session:WCSession,activationDidCompleteWith activationState:WCSessionActivationState,error:Error?){Task{@MainActor in if let db=self.store?.db{self.publish(db)}}}
    nonisolated func sessionDidBecomeInactive(_ session:WCSession){}
    nonisolated func sessionDidDeactivate(_ session:WCSession){session.activate()}
    nonisolated func session(_ session:WCSession,didReceiveUserInfo userInfo:[String:Any]) {
        guard let data=userInfo["command"] as? Data,data.count<24_000,let command=try? JSONDecoder().decode(JournalWatchCommand.self,from:data) else{return}
        Task{@MainActor in
            guard let store=self.store,store.journal.preferences.watchEnabled else{return}
            let ok=store.change{try JournalEngine.receive(command,in:&$0)}
            self.publish(store.db,extra:JournalWatchAck(id:command.id,accepted:ok,message:ok ? "Salvato su iPhone":store.problem ?? "Apri il quaderno su iPhone e riprova"))
        }
    }
}
