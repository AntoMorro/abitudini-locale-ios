import SwiftUI

@main struct PromessaApp: App {
    @StateObject private var store = WeddingStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene { WindowGroup { RootView().environmentObject(store).environmentObject(store.sharing).tint(Palette.plum).environment(\.locale,Locale(identifier:"it_IT")).onAppear {store.sharing.start()}.onChange(of:scenePhase) {_,phase in store.sharing.setActive(phase == .active)} } }
}
struct RootView: View {
    @EnvironmentObject var store: WeddingStore
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }.tabItem { Label("Oggi",systemImage:"heart.text.square") }
            NavigationStack { TasksView() }.tabItem { Label("Attività",systemImage:"checklist") }
            NavigationStack { BudgetView() }.tabItem { Label("Budget",systemImage:"chart.pie") }
            NavigationStack { GuestsView() }.tabItem { Label("Invitati",systemImage:"person.2") }
            NavigationStack { OrganizeView() }.tabItem { Label("Organizza",systemImage:"square.grid.2x2") }
        }
        .alert("Promessa",isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error = nil}})) { Button("OK") {store.error = nil} } message:{Text(store.error ?? "")}
        .onAppear { store.refreshReminders() }
    }
}
struct DashboardView: View {
    @EnvironmentObject var store: WeddingStore
    @State private var edit: EditRequest?
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                VStack(alignment:.leading,spacing:14) {
                    Label("PROMESSA",systemImage:"heart.fill").font(.caption.weight(.bold)).tracking(3)
                    Text(store.db.settings.names).font(.system(.largeTitle,design:.serif).weight(.semibold))
                    if let date = store.db.settings.date {
                        Text(date,format:.dateTime.day().month(.wide).year()).font(.headline)
                        if let days = store.db.countdown(now:Date()) { Text(days > 0 ? "Ancora \(days) giorni" : days == 0 ? "È il vostro giorno" : "\(-days) giorni dal vostro sì").font(.title3) }
                    } else { Text("Il prossimo capitolo comincia qui.").font(.title3); NavigationLink("Scegli data e luogo") { SettingsView() }.buttonStyle(.bordered) }
                    if !store.db.settings.location.isEmpty { Label(store.db.settings.location,systemImage:"mappin.and.ellipse") }
                }.frame(maxWidth:.infinity,alignment:.leading).padding(24).foregroundStyle(.white).background(LinearGradient(colors:[Palette.plum,Palette.rose],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:28))
                if store.db.cloud != nil {CloudStatusBanner()}
                if store.readOnly { Text("Archivio in sola lettura. Apri Impostazioni per recuperare un backup.").foregroundStyle(.red) }
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                    Metric(title:"Persone confermate",value:"\(store.db.people(.confirmed))",icon:"person.crop.circle.badge.checkmark")
                    Metric(title:"Budget disponibile",value:store.money(store.db.available),icon:"leaf")
                    Metric(title:"Attività completate",value:"\(store.db.completed) / \(store.db.tasks.count)",icon:"checkmark.circle")
                    Metric(title:"Posti liberi nei tavoli",value:"\(store.db.tables.reduce(0) { $0 + store.db.freeSeats($1.id) })",icon:"chair.lounge")
                }
                VStack(alignment:.leading,spacing:10) {
                    Text("Una risposta alla volta").font(.title3.bold())
                    LabeledContent("Confermati",value:"\(store.db.people(.confirmed)) persone")
                    LabeledContent("In attesa",value:"\(store.db.people(.pending)) persone")
                    LabeledContent("Non partecipano",value:"\(store.db.people(.declined)) persone")
                    Text("Persone = invitati nominativi + accompagnatori.").font(.caption).foregroundStyle(.secondary)
                }.padding().background(.background,in:RoundedRectangle(cornerRadius:20))
                if !store.db.tasks.isEmpty { ProgressView("La vostra checklist",value:Double(store.db.completed),total:Double(max(1,store.db.tasks.count))).tint(Palette.rose) }
                let overdue = store.db.overdue(at:Date())
                if !overdue.isEmpty { dashboardTasks("Da recuperare",Array(overdue.prefix(4)),warning:true) }
                let next = store.db.tasks.filter { $0.status != .done && ($0.due.map {$0 >= Date()} ?? false) }.sorted { $0.due! < $1.due! }
                dashboardTasks("Prossime scadenze",Array(next.prefix(4)))
                if let e = store.db.expenses.filter({$0.balance > 0 && $0.due != nil}).sorted(by:{$0.due! < $1.due!}).first { Button { edit = EditRequest(kind:.expense,objectID:e.id) } label:{ Label("\(e.title) · \(store.money(e.balance)) da pagare",systemImage:"creditcard").frame(maxWidth:.infinity,alignment:.leading).padding().background(.background,in:RoundedRectangle(cornerRadius:16)) } }
                VStack(alignment:.leading,spacing:10) {
                    Text("In agenda").font(.title3.bold())
                    let upcoming = store.db.schedule.filter { $0.end >= Date() }.sorted { $0.start < $1.start }
                    if upcoming.isEmpty { Text("Aggiungi appuntamenti e momenti del matrimonio in Organizza → Programma.").foregroundStyle(.secondary) }
                    ForEach(Array(upcoming.prefix(3))) { s in Button { edit = EditRequest(kind:.schedule,objectID:s.id) } label:{ VStack(alignment:.leading) { Text(s.title).bold(); Text(s.start,format:.dateTime.day().month().hour().minute()).font(.subheadline); Text(s.location).font(.caption) }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,6) } }
                }.padding().background(.background,in:RoundedRectangle(cornerRadius:20))
                NavigationLink { SeatingView() } label:{ Label("\(store.db.tables.count) tavoli · \(store.db.unassigned.reduce(0) {$0 + $1.seats}) persone senza posto",systemImage:"square.grid.3x3").frame(maxWidth:.infinity,alignment:.leading).padding().background(.background,in:RoundedRectangle(cornerRadius:20)) }
            }.padding()
        }.background(Color(uiColor:.systemGroupedBackground)).navigationTitle("Il vostro sì").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.topBarTrailing) { NavigationLink { GlobalSearchView() } label:{Image(systemName:"magnifyingglass").accessibilityLabel("Cerca ovunque")} }; ToolbarItem(placement:.topBarTrailing) { NavigationLink { SettingsView() } label:{Image(systemName:"gearshape").accessibilityLabel("Impostazioni")} } }
        .sheet(item:$edit) { EntityEditor($0,archive:store.db) }
    }
    private func dashboardTasks(_ title:String, _ tasks:[WeddingTask], warning:Bool = false) -> some View {
        VStack(alignment:.leading,spacing:12) { Text(title).font(.title3.bold()).foregroundStyle(warning ? .red : .primary); if tasks.isEmpty { Text("Nessuna scadenza in programma. Crea la prima attività dalla checklist.").foregroundStyle(.secondary) }; ForEach(tasks) { t in Button {edit = EditRequest(kind:.task,objectID:t.id)} label:{HStack { Image(systemName:"circle"); VStack(alignment:.leading) { Text(t.title); if let d = t.due { Text(d,format:.dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary) } }; Spacer() }.padding(.vertical,5)} } }.padding().background(.background,in:RoundedRectangle(cornerRadius:20))
    }
}
struct OrganizeView: View {
    var body: some View {
        List {
            Section("Tutto al proprio posto") {
                NavigationLink { CollectionView(kind:.vendor) } label:{Label("Fornitori",systemImage:"building.2")}
                NavigationLink { ScheduleView() } label:{Label("Programma",systemImage:"clock")}
                NavigationLink { SeatingView() } label:{Label("Sala e tavoli",systemImage:"square.grid.3x3")}
                NavigationLink { CollectionView(kind:.note) } label:{Label("Note e idee",systemImage:"note.text")}
            }
            Section { NavigationLink { GlobalSearchView() } label:{Label("Cerca ovunque",systemImage:"magnifyingglass")}; NavigationLink { SettingsView() } label:{Label("Impostazioni e backup",systemImage:"gearshape")} }
            Section {NavigationLink {SharingView()} label:{Label("Condividi con il partner",systemImage:"person.2.badge.gearshape")}.accessibilityIdentifier("openSharing")}
            Section { Text("Funziona sul tuo iPhone anche offline. Se attivi la condivisione, i dati vengono sincronizzati tramite Firebase con i due account autorizzati. Nessun assistente automatico.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Organizza")
    }
}
struct CloudStatusBanner:View {
    @EnvironmentObject var sharing:SharingService
    var body:some View {NavigationLink {SharingView()} label:{HStack {Image(systemName:"person.2.fill");VStack(alignment:.leading,spacing:4) {Text("Promessa condivisa").font(.headline);Text(sharing.status).font(.caption)};Spacer();Image(systemName:"chevron.right")}.padding().foregroundStyle(sharing.conflicts.isEmpty ? Palette.plum:Color.orange).background(.background,in:RoundedRectangle(cornerRadius:18))}.accessibilityElement(children:.combine)}
}
