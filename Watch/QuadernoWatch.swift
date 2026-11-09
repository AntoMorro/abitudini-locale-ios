import SwiftUI
import WatchConnectivity
import WatchKit
import AppIntents

@MainActor final class JournalWatchStore:NSObject,ObservableObject,WCSessionDelegate {
    @Published var snapshot:JournalWatchSnapshot?
    @Published var pending:[JournalWatchCommand]=[]
    @Published var failed:[JournalWatchCommand]=[]
    @Published var status="Apri il quaderno su iPhone"
    override init(){super.init();let d=UserDefaults.standard
        if let data=d.data(forKey:"journal.pending"){pending=(try? JSONDecoder().decode([JournalWatchCommand].self,from:data)) ?? []}
        if let data=d.data(forKey:"journal.failed"){failed=(try? JSONDecoder().decode([JournalWatchCommand].self,from:data)) ?? []}
        if let data=d.data(forKey:"journal.snapshot"){snapshot=try? JSONDecoder().decode(JournalWatchSnapshot.self,from:data)}
        if WCSession.isSupported(){WCSession.default.delegate=self;WCSession.default.activate()}
    }
    func saveQueue(){UserDefaults.standard.set(try? JSONEncoder().encode(pending),forKey:"journal.pending");UserDefaults.standard.set(try? JSONEncoder().encode(failed),forKey:"journal.failed")}
    @discardableResult func enqueue(_ value:JournalWatchCommand)->Bool {
        guard pending.count+failed.count<100 else{status="Coda piena: apri l'iPhone prima di aggiungere altro.";return false}
        do{try value.validate();pending.append(value);saveQueue();status="In coda · attendo conferma iPhone";WKInterfaceDevice.current().play(.click);send();return true}catch{status=error.localizedDescription;return false}
    }
    func retryFailed(_ id:UUID){guard let i=failed.firstIndex(where:{$0.id==id}) else{return};var c=failed.remove(at:i);c.created=Date();pending.append(c);saveQueue();send()}
    func send(){let s=WCSession.default;guard s.activationState == .activated else{return};let outstanding=Set(s.outstandingUserInfoTransfers.compactMap{($0.userInfo["id"] as? String)})
        for command in pending where !outstanding.contains(command.id.uuidString){if let data=try? JSONEncoder().encode(command){s.transferUserInfo(["command":data,"id":command.id.uuidString])}}
    }
    func apply(_ context:[String:Any]) {
        if context["enabled"] as? Bool == false{snapshot=nil;UserDefaults.standard.removeObject(forKey:"journal.snapshot");status="Collegamento disattivato su iPhone";return}
        guard let data=context["snapshot"] as? Data,data.count<60_000,let snap=try? JSONDecoder().decode(JournalWatchSnapshot.self,from:data) else{return}
        snapshot=snap;UserDefaults.standard.set(data,forKey:"journal.snapshot")
        var rejected=false
        for ack in snap.acks{if let c=pending.first(where:{$0.id==ack.id}){if !ack.accepted{rejected=true;failed.append(c);failed=Array(failed.suffix(100));status=ack.message};pending.removeAll{$0.id==ack.id}}}
        if pending.isEmpty && !rejected{status="Confermato da iPhone"};saveQueue();send()
    }
    nonisolated func session(_ session:WCSession,activationDidCompleteWith activationState:WCSessionActivationState,error:Error?){Task{@MainActor in self.apply(session.receivedApplicationContext);self.send()}}
    nonisolated func session(_ session:WCSession,didReceiveApplicationContext applicationContext:[String:Any]){Task{@MainActor in self.apply(applicationContext)}}
}
@main struct QuadernoWatchApp:App {
    @StateObject private var store=JournalWatchStore()
    var body:some Scene {WindowGroup{WatchJournalHome().environmentObject(store).tint(.mint)}}
}
struct WatchJournalHome:View {
    @EnvironmentObject var store:JournalWatchStore
    @Environment(\.scenePhase) private var phase
    @State private var capture=false
    @State private var discardID:UUID?
    @State private var discarding=false
    var body:some View {NavigationStack{List{
        Section{Button("Annota al volo",systemImage:"square.and.pencil"){capture=true}.buttonStyle(.borderedProminent);Text(store.status).font(.caption2).foregroundStyle(.secondary);if !store.pending.isEmpty{Text("\(store.pending.count) azioni in attesa").font(.caption)}}
        Section("Come stai?"){HStack{ForEach(1...5,id:\.self){m in Button(["😔","🙁","😐","🙂","😄"][m-1]){_ = store.enqueue(JournalWatchCommand(action:.mood,mood:m))}.buttonStyle(.plain)}}}
        if let snapshot=store.snapshot {
            Section("Le tue attività"){ForEach(snapshot.tasks){task in Button{_ = store.enqueue(JournalWatchCommand(action:.completeTask,targetID:task.id))}label:{Label(task.title,systemImage:task.complete ? "checkmark.circle.fill":"circle")}.disabled(task.complete)}}
            Section("Abitudini"){ForEach(snapshot.habits){h in Button{_ = store.enqueue(JournalWatchCommand(action:.completeHabit,targetID:h.id))}label:{Label(h.title,systemImage:h.complete ? "checkmark.circle.fill":"circle")}.disabled(h.complete || !h.manual)}}
            Text("Riepilogo del "+snapshot.date.formatted(date:.abbreviated,time:.shortened)).font(.caption2).foregroundStyle(.secondary)
        }
        if !store.failed.isEmpty{Section("Bozze da recuperare"){ForEach(store.failed){c in VStack(alignment:.leading){Text(c.text.isEmpty ? c.action.rawValue:c.text);Text("Non salvato su iPhone. Il contenuto resta qui.").font(.caption2);Button("Riprova bozza"){store.retryFailed(c.id)};Button("Scarta",role:.destructive){discardID=c.id;discarding=true}}}}}
        Button("Riprova invio"){store.send()}
    }.navigationTitle("Quaderno").confirmationDialog("Scartare questa bozza dal Watch?",isPresented:$discarding,presenting:discardID){id in Button("Scarta bozza",role:.destructive){store.failed.removeAll{$0.id==id};store.saveQueue()}}.sheet(isPresented:$capture){WatchCapture()}.onOpenURL{url in if url.host=="capture"{capture=true}}.onReceive(NotificationCenter.default.publisher(for:Notification.Name("journal.capture"))){_ in capture=true}.onChange(of:phase){_,p in if p == .active{if UserDefaults.standard.bool(forKey:"journal.capture"){UserDefaults.standard.set(false,forKey:"journal.capture");capture=true};store.send()}}}}
}
struct WatchCapture:View {
    @EnvironmentObject var store:JournalWatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var text=""
    var body:some View {ScrollView{VStack(spacing:16){Text("Un pensiero da conservare").font(.headline);TextField("Annotazione",text:$text);Text("Usa la tastiera o la dettatura del Watch.").font(.caption2);Button("Metti in coda"){if store.enqueue(JournalWatchCommand(action:.note,text:text)){dismiss()}}.disabled(text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}.navigationTitle("Annota")}
}
struct WatchCaptureIntent:AppIntent {
    static var title:LocalizedStringResource="Apri cattura quaderno"
    static var openAppWhenRun=true
    @MainActor func perform()async throws->some IntentResult{UserDefaults.standard.set(true,forKey:"journal.capture");NotificationCenter.default.post(name:Notification.Name("journal.capture"),object:nil);return .result()}
}
struct WatchJournalShortcuts:AppShortcutsProvider {
    static var appShortcuts:[AppShortcut]{AppShortcut(intent:WatchCaptureIntent(),phrases:["Annota in \(.applicationName)"],shortTitle:"Annota",systemImageName:"square.and.pencil")}
}
