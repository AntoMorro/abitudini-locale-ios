import SwiftUI

struct JournalTabs:View {
    var body:some View {TabView{JournalToday().tabItem{Label("Oggi",systemImage:"sun.max")};JournalPlanner().tabItem{Label("Agenda",systemImage:"calendar")};HabitBoard().tabItem{Label("Abitudini",systemImage:"square.grid.3x3")};JournalLibrary().tabItem{Label("Diario",systemImage:"book.closed")};JournalMore().tabItem{Label("Altro",systemImage:"ellipsis.circle")}}}
}
struct JournalPaper:View {
    var body:some View {Canvas{context,size in for x in stride(from:12.0,to:size.width,by:20){for y in stride(from:12.0,to:size.height,by:20){context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:1.4,height:1.4)),with:.color(.secondary.opacity(0.18)))}}}.allowsHitTesting(false).accessibilityHidden(true)}
}
struct JournalToday:View {
    @EnvironmentObject var store:HabitStore
    @State private var text=""
    @State private var kind:BulletKind = .task
    @FocusState private var captureFocused:Bool
    @State private var draft:JournalPage?
    var today:[JournalBullet]{store.journal.bullets.filter{JournalEngine.day($0.date)==JournalEngine.day(Date())}.sorted{$0.important && !$1.important}}
    var body:some View {
        NavigationStack {
            ScrollView {LazyVStack(alignment:.leading,spacing:22){
                header;capture;checkinButtons;writingActions;register;habits
                ForEach(store.journal.pages.filter{JournalEngine.day($0.date)==JournalEngine.day(Date())}.sorted{$0.updated>$1.updated}){JournalPageCard(page:$0)}
            }.padding(20)}
            .background{JournalPaper()}.navigationTitle("Quaderno").navigationBarTitleDisplayMode(.inline)
            .toolbar{NavigationLink{WellnessHome()}label:{Image(systemName:"heart.text.clipboard")}.accessibilityLabel("Salute personale");NavigationLink{JournalPreferencesView()}label:{Image(systemName:"gearshape")}.accessibilityLabel("Preferenze quaderno")}
            .sheet(item:$draft){JournalPageEditor(page:$0)}
        }
    }
    private var header:some View {VStack(alignment:.leading,spacing:8){Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier:"it_IT")))).font(.subheadline).foregroundStyle(.secondary);Text("Una pagina alla volta.").font(.system(.largeTitle,design:.serif,weight:.semibold));Text("Scegli cosa merita spazio oggi.").foregroundStyle(.secondary)}.padding(.vertical,8)}
    private var checkinButtons:some View {VStack(alignment:.leading,spacing:12){Text("Come stai, adesso?").font(.headline);HStack(spacing:22){ForEach(1...5,id:\.self){m in Button{checkin(m)}label:{Text(JournalUI.moods[m-1]).font(.largeTitle)}.accessibilityLabel("Umore \(m)")}}}}
    private var writingActions:some View {HStack{Button("Scrivi nel diario",systemImage:"square.and.pencil"){draft=JournalPage(title:"")}.buttonStyle(.borderedProminent);Spacer();NavigationLink{JournalTemplates()}label:{Label("Modelli",systemImage:"square.grid.2x2")}}}
    private var register:some View {VStack(alignment:.leading,spacing:12){HStack{Text("Il registro di oggi").font(.title3.bold());Spacer();Text("\(today.filter{$0.status == .done}.count)/\(today.count)").font(.caption.monospacedDigit())};ForEach(today){JournalBulletRow(bullet:$0)};if today.isEmpty{Text("Il registro di oggi è ancora vuoto.").foregroundStyle(.secondary)}}}
    @ViewBuilder private var habits:some View {
        if !store.db.habits.filter({!$0.archived}).isEmpty {
            VStack(alignment:.leading,spacing:12){Text("Il tuo ritmo").font(.title3.bold())
                ForEach(Array(store.db.habits.filter{!$0.archived}.prefix(4))){h in HStack{Image(systemName:h.symbol).foregroundStyle(h.color.paletteColor);Text(h.title);Spacer();if h.kind == .check{Button{store.toggleDay(h,date:Date())}label:{Image(systemName:Tracker.complete(h,db:store.db,date:Date()) ? "checkmark.circle.fill":"circle")}.accessibilityLabel("Spunta "+h.title)}else{Text(Tracker.total(h,db:store.db,date:Date()).formatted()).font(.caption)}}}
            }.padding().background(.mint.opacity(0.1),in:RoundedRectangle(cornerRadius:20))
        }
    }
    private var capture:some View {VStack(alignment:.leading,spacing:12){Picker("Tipo di annotazione",selection:$kind){ForEach(BulletKind.allCases){k in Text(k.glyph+" "+k.title).tag(k)}}.pickerStyle(.segmented);HStack{TextField("Un pensiero o una prossima azione…",text:$text).focused($captureFocused).submitLabel(.done).onSubmit(add).accessibilityIdentifier("rapidText");Button(action:add){Image(systemName:"arrow.up.circle.fill").font(.title)}.accessibilityLabel("Aggiungi al registro").disabled(text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}.padding().background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:18))}
    func add(){captureFocused=false;let value=text.trimmingCharacters(in:.whitespacesAndNewlines);guard !value.isEmpty else{return};if store.saveBullet(JournalBullet(text:value,kind:kind)){text=""}}
    func checkin(_ mood:Int){var p=store.journal.pages.first{JournalEngine.day($0.date)==JournalEngine.day(Date()) && $0.template=="checkin"} ?? JournalPage(title:"Check-in · "+JournalEngine.label(Date()),template:"checkin");p.mood=mood;_ = store.savePage(p)}
}
enum JournalUI {static let moods=["😔","🙁","😐","🙂","😄"]}
struct JournalBulletRow:View {
    @EnvironmentObject var store:HabitStore
    var bullet:JournalBullet
    @State private var editing=false
    @State private var deleting=false
    var body:some View {HStack(alignment:.top,spacing:12){
        Button{if bullet.kind == .task && [.open,.done].contains(bullet.status){store.completeBullet(bullet)}else{editing=true}}label:{Text(glyph).font(.title2.monospaced()).frame(width:25)}.accessibilityLabel((bullet.status == .done ? "Riapri ":"Completa ")+bullet.text)
        Button{editing=true}label:{VStack(alignment:.leading,spacing:5){Text(bullet.text).strikethrough(bullet.status == .done || bullet.status == .cancelled).foregroundStyle(.primary).multilineTextAlignment(.leading);HStack{if bullet.important{Image(systemName:"star.fill").foregroundStyle(.orange)};if bullet.status == .migrated{Text("Migrata")}else if bullet.recurrence != .none{Text(bullet.recurrence.title)};if bullet.reminder != nil{Image(systemName:"bell")}}.font(.caption).foregroundStyle(.secondary)}}.buttonStyle(.plain)
        Spacer(minLength:0)
        Menu{Button("Modifica"){editing=true};if bullet.kind == .task && bullet.status == .open{Button("Migra a oggi"){store.journalChange{try JournalEngine.migrate(bullet.id,to:Date(),in:&$0)}};Button("Annulla attività"){var b=bullet;b.status = .cancelled;b.reminder=nil;_ = store.saveBullet(b)}};Button("Elimina",role:.destructive){deleting=true}}label:{Image(systemName:"ellipsis").padding(.vertical,5)}.accessibilityLabel("Opzioni "+bullet.text)
    }.padding(13).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:15)).sheet(isPresented:$editing){JournalBulletEditor(bullet:bullet)}.alert("Eliminare l'annotazione?",isPresented:$deleting){Button("Annulla",role:.cancel){};Button("Elimina",role:.destructive){store.journalChange{JournalEngine.removeBullet(bullet.id,in:&$0)}}}}
    var glyph:String{switch bullet.status{case .done:return "×";case .cancelled:return "–";case .migrated:return ">";case .open:return bullet.kind.glyph}}
}
struct JournalPlanner:View {
    @EnvironmentObject var store:HabitStore
    @State private var date=Date()
    @State private var period="Giorno"
    @State private var adding=false
    @State private var migrating=false
    var values:[JournalBullet]{let c=Calendar.current;return store.journal.bullets.filter{b in switch period{case "Settimana":return inInterval(b.date,.weekOfYear);case "Mese":return inInterval(b.date,.month);case "Futuro":return b.date>c.date(byAdding:.day,value:1,to:c.startOfDay(for:Date()))!;default:return c.isDate(b.date,inSameDayAs:date)}}.sorted{$0.date<$1.date}}
    func inInterval(_ value:Date,_ part:Calendar.Component)->Bool {guard let i=Calendar.current.dateInterval(of:part,for:date) else{return false};return value>=i.start && value<i.end}
    var overdue:[JournalBullet]{store.journal.bullets.filter{$0.kind == .task && $0.status == .open && $0.date<Calendar.current.startOfDay(for:date)}}
    var body:some View {NavigationStack{ScrollView{LazyVStack(alignment:.leading,spacing:16){
        Picker("Vista agenda",selection:$period){ForEach(["Giorno","Settimana","Mese","Futuro"],id:\.self){Text($0)}}.pickerStyle(.segmented)
        if period != "Futuro"{DatePicker("Data del registro",selection:$date,displayedComponents:.date)}
        if !overdue.isEmpty && period != "Futuro"{Button("Rivedi \(overdue.count) attività precedenti"){migrating=true}.buttonStyle(.bordered)}
        if values.isEmpty{ContentUnavailableView("Spazio per i tuoi piani",systemImage:"calendar",description:Text("Registra attività, eventi e note; le viste usano gli stessi elementi, senza duplicarli."))}
        ForEach(values){b in VStack(alignment:.leading,spacing:5){if period != "Giorno"{Text(JournalEngine.label(b.date)).font(.caption).foregroundStyle(.secondary)};JournalBulletRow(bullet:b)}}
    }.padding()}.navigationTitle(period=="Futuro" ? "Future log":"Agenda").toolbar{Button("Nuova annotazione",systemImage:"plus"){adding=true}}.sheet(isPresented:$adding){JournalBulletEditor(bullet:JournalBullet(text:"",date:date))}.sheet(isPresented:$migrating){JournalMigration(date:date)}}}
}
struct JournalMigration:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) private var dismiss
    var date:Date
    var values:[JournalBullet]{store.journal.bullets.filter{$0.kind == .task && $0.status == .open && $0.date<Calendar.current.startOfDay(for:date)}}
    var body:some View {NavigationStack{ScrollView{LazyVStack(alignment:.leading,spacing:18){Text("Vale ancora il tuo tempo?").font(.title2.bold());Text("Scegli cosa portare avanti e cosa lasciare andare. L'originale conserva il segno di migrazione.").foregroundStyle(.secondary);ForEach(values){b in VStack(alignment:.leading){Text(b.text);HStack{Button("Migra"){store.journalChange{try JournalEngine.migrate(b.id,to:date,in:&$0)}};Spacer();Button("Lascia andare"){var x=b;x.status = .cancelled;x.reminder=nil;_ = store.saveBullet(x)}}}.padding().background(.mint.opacity(0.08),in:RoundedRectangle(cornerRadius:14))};if values.isEmpty{Text("Revisione completata.")}}.padding()}.navigationTitle("Migrazione").toolbar{Button("Fine"){dismiss()}}}}
}
struct JournalBulletEditor:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) private var dismiss
    @State var bullet:JournalBullet
    @State private var reminding=false
    @State private var reminderDate=Date().addingTimeInterval(3600)
    @State private var migrationDate=Date()
    var body:some View {NavigationStack{Form{
        TextField("Testo annotazione",text:$bullet.text,axis:.vertical).lineLimit(2...5)
        Picker("Tipo",selection:$bullet.kind){ForEach(BulletKind.allCases){Text($0.title).tag($0)}}
        DatePicker("Giorno",selection:$bullet.date,displayedComponents:.date)
        Picker("Quaderno",selection:$bullet.notebookID){ForEach(store.journal.books){Text($0.title).tag($0.id)}}
        Toggle("Importante",isOn:$bullet.important)
        if bullet.kind == .task{Picker("Ripeti",selection:$bullet.recurrence){ForEach(BulletRepeat.allCases){Text($0.title).tag($0)}}}
        Section("Promemoria"){Toggle("Avvisami",isOn:$reminding);if reminding{DatePicker("Quando",selection:$reminderDate)};Text("Le notifiche condividono il limite dell'app con le abitudini. Si programmano prima le abitudini, poi i prossimi avvisi del journal.").font(.caption)}
        if store.journal.bullets.contains(where:{$0.id==bullet.id}) && bullet.status == .open && bullet.kind == .task{Section("Sposta avanti"){DatePicker("Migra al",selection:$migrationDate,displayedComponents:.date);Button("Migra attività"){if store.journalChange({try JournalEngine.migrate(bullet.id,to:migrationDate,in:&$0)}){dismiss()}}}}
    }.navigationTitle("Registro rapido").toolbar{ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Salva annotazione"){bullet.reminder=reminding ? reminderDate:nil;if store.saveBullet(bullet){if reminding{Task{_ = try? await HabitReminders.authorize();store.syncReminders()}};dismiss()}}.disabled(bullet.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}.onAppear{reminding=bullet.reminder != nil;reminderDate=bullet.reminder ?? reminderDate}}}
}
