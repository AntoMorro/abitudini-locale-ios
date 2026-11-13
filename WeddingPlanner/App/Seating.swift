import SwiftUI

struct SeatingView:View {
    @EnvironmentObject var store:WeddingStore
    @State private var plan = true; @State private var edit:EditRequest?; @State private var selected:WeddingTable?
    var body:some View {
        List {
            Section {Picker("Vista",selection:$plan) {Text("Pianta").tag(true);Text("Elenco").tag(false)}.pickerStyle(.segmented); Text("\(store.db.totalSeats) posti richiesti · \(store.db.tables.reduce(0) {$0 + $1.capacity}) posti totali").font(.headline); Text("\(store.db.unassigned.reduce(0) {$0 + $1.seats}) persone senza tavolo").foregroundStyle(store.db.unassigned.isEmpty ? .secondary : .orange) }
            if store.db.tables.isEmpty {EmptyHint(title:"Disegna la vostra sala",text:"Aggiungi il primo tavolo con +, poi assegna gli invitati.",icon:"square.grid.3x3")}
            if plan && !store.db.tables.isEmpty {
                Section("Trascina i tavoli · tocca per assegnare") {
                    GeometryReader { geo in
                        ZStack {
                            RoundedRectangle(cornerRadius:22).fill(Color(uiColor:.secondarySystemGroupedBackground))
                            ForEach(store.db.tables) {table in TableToken(table:table,occupied:store.db.seats(table.id),size:geo.size,onSelect:{selected = table},onMove:{x,y in _ = store.change { db in if let i = db.tables.firstIndex(where:{$0.id == table.id}) {db.tables[i].x = x;db.tables[i].y = y} }}) }
                        }
                    }.frame(height:440).listRowInsets(EdgeInsets()).accessibilityLabel("Planimetria della sala")
                    Text("Con VoiceOver usa Elenco: contiene le stesse assegnazioni. Le posizioni sono modificabili anche tramite cursori nell’editor del tavolo.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Tavoli") {
                ForEach(store.db.tables) { table in Button {selected = table} label:{ VStack(alignment:.leading,spacing:6) {LabeledContent(table.name,value:"\(store.db.seats(table.id))/\(table.capacity) posti").font(.headline);if store.db.seats(table.id) > table.capacity {Label("Oltre capienza di \(store.db.seats(table.id) - table.capacity) posti",systemImage:"exclamationmark.triangle.fill").foregroundStyle(.red)} else {Text("\(store.db.freeSeats(table.id)) posti liberi").foregroundStyle(.secondary)};if !table.category.isEmpty {Text(table.category).font(.caption)} }.foregroundStyle(.primary).padding(.vertical,5)}.contextMenu {Button("Modifica tavolo") {edit = EditRequest(kind:.table,objectID:table.id)}} }
            }
            Section("Da sistemare") {ForEach(store.db.unassigned) {guest in Button {edit = EditRequest(kind:.guest,objectID:guest.id)} label:{LabeledContent(guest.name,value:"\(guest.seats) posti")}}; if store.db.unassigned.isEmpty {Text("Nessun invitato da assegnare.").foregroundStyle(.secondary)} }
        }.navigationTitle("Sala e tavoli").toolbar {Button {edit = EditRequest(kind:.table)} label:{Image(systemName:"plus").accessibilityLabel("Nuovo tavolo")}.accessibilityIdentifier("addTable")}.sheet(item:$edit) {EntityEditor($0,archive:store.db)}.sheet(item:$selected) {table in TableAssignmentView(tableID:table.id)}
    }
}
struct TableToken:View {
    let table:WeddingTable; let occupied:Int; let size:CGSize; let onSelect:()->Void; let onMove:(Double,Double)->Void
    @State private var translation = CGSize.zero
    private var width:CGFloat {max(1,size.width - 112)}
    private var height:CGFloat {max(1,size.height - 112)}
    var body:some View {
        Button(action:onSelect) {VStack(spacing:5) {Image(systemName:"circle.grid.cross").font(.title2);Text(table.name).font(.caption.bold()).lineLimit(2);Text("\(occupied)/\(table.capacity)").font(.caption).monospacedDigit()}.foregroundStyle(occupied > table.capacity ? Color.red : Palette.plum).frame(width:100,height:100).background(.background,in:RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).stroke(occupied > table.capacity ? Color.red : Palette.rose.opacity(0.4),lineWidth:2))}
        .buttonStyle(.plain).position(x:56 + table.x * width + translation.width,y:56 + table.y * height + translation.height)
        .simultaneousGesture(DragGesture(minimumDistance:10).onChanged {translation = $0.translation}.onEnded {v in let x = min(1,max(0,table.x + v.translation.width/width));let y = min(1,max(0,table.y + v.translation.height/height));translation = .zero;onMove(x,y)})
        .accessibilityLabel("\(table.name), \(occupied) occupati di \(table.capacity) posti").accessibilityHint("Tocca due volte per assegnare invitati")
    }
}
struct TableAssignmentView:View {
    @EnvironmentObject var store:WeddingStore; @Environment(\.dismiss) private var dismiss
    let tableID:UUID; @State private var search = ""; @State private var editing = false
    private var table:WeddingTable? {store.db.tables.first {$0.id == tableID}}
    var body:some View {
        NavigationStack {
            List {
                if let table {
                    Section {Text("\(store.db.seats(tableID)) di \(table.capacity) posti").font(.title2.bold()); if store.db.seats(tableID) > table.capacity {Text("Tavolo oltre capienza. Sposta un nucleo o modifica la capienza.").foregroundStyle(.red)}; if !table.notes.isEmpty {Text(table.notes)}; Button("Modifica tavolo") {editing = true} }
                    Section("Seduti qui · tocca per rimuovere") { ForEach(store.db.guests.filter {$0.tableID == tableID}) {g in Button { _ = store.change {try $0.assign(g.id,to:nil)} } label:{HStack {Text(g.name);Spacer();Text("\(g.seats) posti");Image(systemName:"minus.circle")}} } }
                    Section("Assegna o sposta qui") {
                        ForEach(store.db.guests.filter {$0.tableID != tableID && $0.seats > 0 && (search.isEmpty || ($0.name + $0.group).localizedCaseInsensitiveContains(search))}) {g in Button { _ = store.change {try $0.assign(g.id,to:tableID)} } label:{VStack(alignment:.leading,spacing:4) {LabeledContent(g.name,value:"\(g.seats) posti");Text(store.db.tables.first {$0.id == g.tableID}?.name ?? "Senza tavolo").font(.caption).foregroundStyle(.secondary)}} }
                        Text("Ogni tocco sposta l’intero nucleo a questo tavolo. È consentito superare la capienza: l’avviso resta visibile.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.navigationTitle(table?.name ?? "Tavolo rimosso").searchable(text:$search,prompt:"Cerca un invitato da assegnare").toolbar {ToolbarItem(placement:.confirmationAction) {Button("Fine") {dismiss()}}}.sheet(isPresented:$editing) {EntityEditor(EditRequest(kind:.table,objectID:tableID),archive:store.db)}
        }
    }
}
