import SwiftUI
import PhotosUI
import PencilKit
import ImageIO
import AVFoundation

struct JournalLibrary:View {
    @EnvironmentObject var store:HabitStore
    @State private var query=""
    @State private var favorites=false
    @State private var tag="Tutte"
    @State private var draft:JournalPage?
    var pages:[JournalPage]{JournalEngine.search(query,in:store.journal).filter{(!favorites || $0.favorite) && (tag=="Tutte" || $0.tags.contains(tag))}}
    var body:some View {NavigationStack{ScrollView{LazyVStack(alignment:.leading,spacing:18){
        if query.isEmpty{Text("I tuoi quaderni").font(.system(.title,design:.serif,weight:.bold));LazyVGrid(columns:[GridItem(.flexible(minimum:1)),GridItem(.flexible(minimum:1))],spacing:14){ForEach(store.journal.books.filter{!$0.archived}){b in NavigationLink{JournalBookDetail(id:b.id)}label:{JournalBookCover(book:b,count:store.journal.pages.filter{$0.notebookID==b.id}.count)}}}}
        HStack{Text("\(pages.count) pagine").font(.headline);Spacer();Toggle("Preferiti",isOn:$favorites).toggleStyle(.button)}
        if pages.isEmpty{ContentUnavailableView("Una pagina da iniziare",systemImage:"book.closed",description:Text("Scrivi, scegli un modello o raccogli un'idea nel registro rapido."))}
        ForEach(Array(pages.prefix(150))){p in JournalPageCard(page:p)}
        if pages.count>150{Text("Mostrate le prime 150 pagine: usa la ricerca o apri un quaderno per restringere i risultati.").font(.caption)}
    }.padding()}.navigationTitle("Diario").searchable(text:$query,prompt:"Testo, titoli, luoghi ed etichette").toolbar{ToolbarItem(placement:.topBarLeading){Menu{Picker("Etichetta",selection:$tag){Text("Tutte").tag("Tutte");ForEach(Array(Set(store.journal.pages.flatMap(\.tags))).sorted(),id:\.self){Text($0).tag($0)}};NavigationLink{JournalTemplates()}label:{Text("Modelli di pagina")}}label:{Image(systemName:"line.3.horizontal.decrease")}.accessibilityLabel("Filtri diario")};ToolbarItem(placement:.topBarTrailing){Button("Nuova pagina",systemImage:"plus"){draft=JournalPage(title:"")}}}.sheet(item:$draft){JournalPageEditor(page:$0)}}}
}
struct JournalBookCover:View {
    var book:JournalBook;var count:Int
    var body:some View {VStack(alignment:.leading,spacing:14){Image(systemName:book.symbol).font(.title2);Spacer();Text(book.title).font(.system(.title3,design:.serif,weight:.semibold)).multilineTextAlignment(.leading);Text("\(count) pagine").font(.caption)}.foregroundStyle(.primary).padding(18).frame(maxWidth:.infinity,alignment:.leading).frame(height:170).background(book.color.paletteColor.opacity(0.17),in:RoundedRectangle(cornerRadius:16)).overlay(alignment:.leading){RoundedRectangle(cornerRadius:2).fill(book.color.paletteColor.opacity(0.6)).frame(width:5).padding(.vertical,12)}}
}
struct JournalPageCard:View {
    var page:JournalPage
    var body:some View {NavigationLink{JournalPageDetail(id:page.id)}label:{VStack(alignment:.leading,spacing:9){HStack{Text(JournalEngine.label(page.date)).font(.caption).foregroundStyle(.secondary);Spacer();if let m=page.mood{Text(JournalUI.moods[m-1])};if page.favorite{Image(systemName:"star.fill").foregroundStyle(.orange)}};Text(page.title).font(.system(.title3,design:.serif,weight:.semibold)).foregroundStyle(.primary);Text(page.body).font(.subheadline).lineLimit(3).foregroundStyle(.secondary);HStack{Text("p. \(page.number)");if !page.tags.isEmpty{Text(page.tags.map{"#"+$0}.joined(separator:" "))};Spacer();if !page.photos.isEmpty{Image(systemName:"photo")};if page.ink != nil{Image(systemName:"pencil.tip")};if page.audio != nil{Image(systemName:"waveform")}}.font(.caption2).foregroundStyle(.secondary)}.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:18))}.buttonStyle(.plain)}
}
struct JournalBookDetail:View {
    @EnvironmentObject var store:HabitStore
    var id:UUID
    @State private var editing=false
    @State private var draft:JournalPage?
    var body:some View {ScrollView{LazyVStack(alignment:.leading,spacing:16){ForEach(store.journal.pages.filter{$0.notebookID==id}.sorted{$0.number<$1.number}){JournalPageCard(page:$0)};ForEach(store.journal.bullets.filter{$0.notebookID==id}){JournalBulletRow(bullet:$0)}}.padding()}.navigationTitle(store.journal.books.first{$0.id==id}?.title ?? "Quaderno").toolbar{Button("Modifica quaderno"){editing=true};Button("Nuova pagina",systemImage:"plus"){draft=JournalPage(notebookID:id,title:"")}}.sheet(item:$draft){JournalPageEditor(page:$0)}.sheet(isPresented:$editing){if let book=store.journal.books.first(where:{$0.id==id}){JournalBookEditor(book:book)}}}
}
struct JournalBookEditor:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) private var dismiss
    @State var book:JournalBook
    var body:some View {NavigationStack{Form{TextField("Nome quaderno",text:$book.title);Picker("Colore",selection:$book.color){ForEach(["mint","blue","orange","pink","purple","cyan"],id:\.self){Text($0).tag($0)}};Picker("Simbolo",selection:$book.symbol){ForEach(["book.closed","tray","lightbulb","graduationcap","heart","leaf","airplane","target"],id:\.self){Label($0,systemImage:$0).tag($0)}};Toggle("Archiviato",isOn:$book.archived);Text("Archiviare nasconde la copertina e conserva pagine e indice.").font(.caption)}.navigationTitle("Quaderno").toolbar{ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Salva quaderno"){if store.journalChange({j in if let i=j.books.firstIndex(where:{$0.id==book.id}){j.books[i]=book}else{j.books.append(book)}}){dismiss()}}.disabled(book.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}}}
}
struct JournalTemplates:View {
    @State private var draft:JournalPage?
    var body:some View {ScrollView{LazyVStack(alignment:.leading,spacing:16){Text("Dai una forma ai tuoi pensieri.").font(.system(.title,design:.serif,weight:.bold));ForEach(JournalTemplate.all){t in Button{draft=JournalPage(title:t.id=="libera" ? "":t.title,body:t.body,template:t.id)}label:{VStack(alignment:.leading,spacing:7){Text(t.title).font(.headline).foregroundStyle(.primary);Text(t.subtitle).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(.mint.opacity(0.08),in:RoundedRectangle(cornerRadius:16))}}}.padding()}.navigationTitle("Modelli").sheet(item:$draft){JournalPageEditor(page:$0)}}
}
struct JournalPageDetail:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) private var dismiss
    var id:UUID
    @State private var editing:JournalPage?
    @State private var deleting=false
    @State private var audioPlayer:AVAudioPlayer?
    var page:JournalPage?{store.journal.pages.first{$0.id==id}}
    var body:some View {Group{if let p=page{ScrollView{VStack(alignment:.leading,spacing:22){
        Text(JournalEngine.label(p.date)+" · p. \(p.number)").font(.caption).foregroundStyle(.secondary)
        Text(p.title).font(.system(.largeTitle,design:.serif,weight:.semibold))
        HStack{if let mood=p.mood{Label(JournalUI.moods[mood-1],systemImage:"heart")};if let energy=p.energy{Text("Energia \(energy)/5")};if let sleep=p.sleep{Text("Sonno \(sleep.formatted()) h")}}.font(.subheadline)
        Text(LocalizedStringKey(p.body)).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled)
        if !p.place.isEmpty{Label(p.place,systemImage:"mappin")}
        if !p.tags.isEmpty{Text(p.tags.map{"#"+$0}.joined(separator:" ")).font(.caption).foregroundStyle(.mint)}
        ForEach(p.photos){photo in if let image=UIImage(data:photo.data){Image(uiImage:image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:16));if !photo.caption.isEmpty{Text(photo.caption).font(.caption)}}}
        if let data=p.ink,let drawing=try? PKDrawing(data:data),!drawing.bounds.isEmpty{Image(uiImage:drawing.image(from:drawing.bounds.insetBy(dx:-12,dy:-12),scale:2)).resizable().scaledToFit().frame(maxHeight:600)}
        if let data=p.audio{Button("Ascolta registrazione",systemImage:"play.circle"){do{audioPlayer=try AVAudioPlayer(data:data);audioPlayer?.play()}catch{store.problem=error.localizedDescription}}}
        ForEach(store.journal.bullets.filter{$0.pageID==id}){JournalBulletRow(bullet:$0)}
        Button(p.favorite ? "Rimuovi dai preferiti":"Aggiungi ai preferiti",systemImage:p.favorite ? "star.slash":"star"){var x=p;x.favorite.toggle();_ = store.savePage(x)}
        ShareLink(item:p.title+"\n"+JournalEngine.label(p.date)+"\n\n"+p.body){Label("Condividi testo",systemImage:"square.and.arrow.up")}
        Button("Elimina pagina",role:.destructive){deleting=true}
    }.frame(maxWidth:.infinity,alignment:.leading).padding(22)}.background{JournalPaper()}.navigationTitle("Pagina \(p.number)").navigationBarTitleDisplayMode(.inline).toolbar{Button("Modifica pagina"){editing=p}}.sheet(item:$editing){JournalPageEditor(page:$0)}.alert("Eliminare la pagina e i suoi allegati?",isPresented:$deleting){Button("Annulla",role:.cancel){};Button("Elimina",role:.destructive){if store.journalChange({JournalEngine.removePage(id,in:&$0)}){dismiss()}}}.onDisappear{audioPlayer?.stop()}}}}
}
struct JournalPageEditor:View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) private var dismiss
    @State var page:JournalPage
    @State private var tags=""
    @State private var sleepText=""
    @State private var photoItems:[PhotosPickerItem]=[]
    @State private var importing=false
    @State private var drawing=false
    @State private var error:String?
    @StateObject private var voice=JournalVoiceRecorder()
    var body:some View {NavigationStack{Form{
        Section("La tua pagina"){TextField("Titolo pagina",text:$page.title).accessibilityIdentifier("journalTitle");DatePicker("Data della pagina",selection:$page.date);Picker("Quaderno",selection:$page.notebookID){ForEach(store.journal.books){Text($0.title).tag($0.id)}};TextField("Etichette separate da virgole",text:$tags);Toggle("Preferita",isOn:$page.favorite)}
        Section("Pensieri"){TextEditor(text:$page.body).frame(height:260).accessibilityIdentifier("journalBody");Text("Puoi usare **grassetto**, *corsivo* ed elenchi nel testo.").font(.caption).foregroundStyle(.secondary)}
        wellbeing
        media
    }.navigationTitle("Scrivi una pagina").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Annulla"){voice.cancel();dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Salva pagina"){save()}.disabled(importing || voice.recording)}}
        .onAppear{tags=page.tags.joined(separator:", ");sleepText=page.sleep.map{String($0)} ?? ""}.onDisappear{voice.cancel()}
        .onChange(of:photoItems){_,items in Task{await importPhotos(items)}}
        .onChange(of:voice.clip){_,clip in if let clip=clip{page.audio=clip.data;page.audioDuration=clip.duration}}
        .sheet(isPresented:$drawing){JournalDrawing(data:page.ink){page.ink=$0}}
        .alert("Pagina",isPresented:Binding(get:{error != nil || voice.error != nil},set:{if !$0{error=nil;voice.error=nil}})){Button("OK"){error=nil;voice.error=nil}}message:{Text(error ?? voice.error ?? "")}
    }
    }
    private var wellbeing:some View {Section("Check-in facoltativo"){
        Picker("Umore",selection:Binding(get:{page.mood ?? 0},set:{page.mood=$0==0 ? nil:$0})){Text("Non indicato").tag(0);ForEach(1...5,id:\.self){Text(JournalUI.moods[$0-1]).tag($0)}}
        Picker("Energia",selection:Binding(get:{page.energy ?? 0},set:{page.energy=$0==0 ? nil:$0})){Text("Non indicata").tag(0);ForEach(1...5,id:\.self){Text("\($0)/5").tag($0)}}
        TextField("Ore di sonno (facoltativo)",text:$sleepText).keyboardType(.decimalPad)
        TextField("Luogo (inserimento manuale)",text:$page.place)
    }}
    private var media:some View {Section("Foto, voce e disegni"){
        if page.photos.count<4{PhotosPicker(selection:$photoItems,maxSelectionCount:4-page.photos.count,matching:.images){Label("Aggiungi foto",systemImage:"photo")}}
        if importing{ProgressView("Preparazione foto…")}
        ScrollView(.horizontal){HStack{ForEach(page.photos){p in VStack{if let image=UIImage(data:p.data){Image(uiImage:image).resizable().scaledToFill().frame(width:110,height:110).clipped().clipShape(RoundedRectangle(cornerRadius:12))};Button("Rimuovi foto",role:.destructive){page.photos.removeAll{$0.id==p.id}}.font(.caption)}}}}.frame(height:page.photos.isEmpty ? 0:150)
        Button(page.ink==nil ? "Disegna sulla pagina":"Modifica disegno",systemImage:"pencil.tip"){drawing=true}
        if voice.recording{TimelineView(.periodic(from:.now,by:1)){_ in Text("Registrazione · \(Int(voice.elapsed)) s / 120").monospacedDigit()};Button("Ferma registrazione"){finishVoice()}}else{Button("Registra una nota vocale",systemImage:"mic"){Task{await voice.start()}}}
        if page.audio != nil{Label("Registrazione allegata",systemImage:"waveform");Button("Rimuovi audio",role:.destructive){page.audio=nil;page.audioDuration=nil}}
        Text("Massimo 4 foto ridimensionate e 120 secondi di audio per pagina. Gli allegati sono inclusi nel backup.").font(.caption).foregroundStyle(.secondary)
    }}
    func save(){if !sleepText.isEmpty{guard let hours=Double(sleepText.replacingOccurrences(of:",",with:".")),(0...24).contains(hours) else{error="Inserisci ore di sonno tra 0 e 24.";return};page.sleep=hours}else{page.sleep=nil};page.tags=tags.split(separator:",").map{$0.trimmingCharacters(in:.whitespacesAndNewlines)};if store.savePage(page){dismiss()}else{error=store.problem}}
    @MainActor func importPhotos(_ items:[PhotosPickerItem])async {guard !items.isEmpty else{return};importing=true;defer{importing=false;photoItems=[]};do{for item in items.prefix(max(0,4-page.photos.count)){guard let data=try await item.loadTransferable(type:Data.self),let source=CGImageSourceCreateWithData(data as CFData,nil),let thumb=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1600,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary),let jpeg=UIImage(cgImage:thumb).jpegData(compressionQuality:0.65),jpeg.count<=1_000_000 else{throw HabitError.invalid};page.photos.append(JournalPhoto(data:jpeg))}}catch{self.error="Foto non importata: "+error.localizedDescription}}
    func finishVoice(){if let result=voice.finish(){page.audio=result.0;page.audioDuration=result.1}}
}
struct JournalCanvas:UIViewRepresentable {
    var canvas:PKCanvasView
    func makeUIView(context:Context)->PKCanvasView{canvas.drawingPolicy = .anyInput;canvas.tool=PKInkingTool(.pen,color:.systemTeal,width:3);canvas.backgroundColor = .clear;return canvas}
    func updateUIView(_ view:PKCanvasView,context:Context){}
}
struct JournalDrawing:View {
    @Environment(\.dismiss) private var dismiss
    var data:Data?;var save:(Data)->Void
    @State private var canvas=PKCanvasView()
    var body:some View {NavigationStack{JournalCanvas(canvas:canvas).background{JournalPaper()}.navigationTitle("Spazio per disegnare").toolbar{ToolbarItem(placement:.cancellationAction){Button("Annulla"){dismiss()}};ToolbarItemGroup(placement:.bottomBar){Button("Penna"){canvas.tool=PKInkingTool(.pen,color:.systemTeal,width:3)};Button("Evidenziatore"){canvas.tool=PKInkingTool(.marker,color:.systemMint,width:16)};Button("Gomma"){canvas.tool=PKEraserTool(.bitmap)}};ToolbarItem(placement:.confirmationAction){Button("Salva disegno"){save(canvas.drawing.dataRepresentation());dismiss()}}}.onAppear{if let data=data,let drawing=try? PKDrawing(data:data){canvas.drawing=drawing}}}}
}
