import SwiftUI

private struct JournalDaySelection:Identifiable {var date:Date;var id:Date{date}}
struct JournalPixelYear:View {
    @EnvironmentObject var store:HabitStore
    @State private var year=Calendar.current.component(.year,from:Date())
    @State private var selection:JournalDaySelection?
    var summaries:[String:Int] {
        let pages=store.journal.pages.filter{Calendar.current.component(.year,from:$0.date)==year && $0.mood != nil}
        return Dictionary(grouping:pages,by:{JournalEngine.day($0.date)}).mapValues{values in Int((Double(values.compactMap(\.mood).reduce(0,+))/Double(values.count)).rounded())}
    }
    var body:some View {
        let moods=summaries
        VStack(alignment:.leading,spacing:15){
            HStack{Text("Un anno in pixel").font(.system(.title3,design:.serif,weight:.semibold));Spacer();Stepper("\(year)",value:$year,in:1900...Calendar.current.component(.year,from:Date())).fixedSize()}
            HStack(alignment:.top,spacing:5){ForEach(1...12,id:\.self){month in VStack(spacing:4){Text(monthName(month)).font(.system(size:9));ForEach(1...31,id:\.self){day in if let date=dayDate(month,day){let value=moods[JournalEngine.day(date)];Button{selection=JournalDaySelection(date:date)}label:{RoundedRectangle(cornerRadius:2).fill(color(value)).frame(width:14,height:8)}.buttonStyle(.plain).accessibilityLabel(JournalEngine.label(date)+(value.map{" · umore \($0)/5"} ?? " · senza check-in"))}else{Color.clear.frame(width:14,height:8)}}}}}.frame(maxWidth:.infinity)
            Text("Ogni colonna è un mese. Più check-in nello stesso giorno vengono riassunti con la media; i giorni vuoti restano vuoti. Tocca un pixel per aprire le pagine di quel giorno.").font(.caption).foregroundStyle(.secondary)
            HStack{ForEach(1...5,id:\.self){m in HStack(spacing:4){Circle().fill(color(m)).frame(width:9,height:9);Text(JournalUI.moods[m-1])}}}
        }.sheet(item:$selection){selected in NavigationStack{ScrollView{LazyVStack{ForEach(store.journal.pages.filter{Calendar.current.isDate($0.date,inSameDayAs:selected.date)}){JournalPageCard(page:$0)};if !store.journal.pages.contains(where:{Calendar.current.isDate($0.date,inSameDayAs:selected.date)}){ContentUnavailableView("Nessuna pagina",systemImage:"book.closed",description:Text(JournalEngine.label(selected.date)))}}.padding()}.navigationTitle(JournalEngine.label(selected.date)).toolbar{Button("Chiudi"){selection=nil}}}}
    }
    func dayDate(_ month:Int,_ day:Int)->Date?{guard let date=Calendar.current.date(from:DateComponents(year:year,month:month,day:day)),Calendar.current.component(.month,from:date)==month else{return nil};return date}
    func monthName(_ month:Int)->String{var c=Calendar.current;c.locale=Locale(identifier:"it_IT");return String(c.shortMonthSymbols[month-1].prefix(1)).uppercased()}
    func color(_ mood:Int?)->Color{guard let mood=mood else{return Color.secondary.opacity(0.14)};return [Color.red,.orange,.yellow,.mint,.cyan][min(4,max(0,mood-1))].opacity(0.8)}
}
