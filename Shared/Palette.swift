import SwiftUI

enum HabitPalette {
    static let colors = ["mint","cyan","blue","orange","pink","purple","#EF4444","#F87171","#FB7185","#F43F5E","#EC4899","#F472B6","#D946EF","#A855F7","#8B5CF6","#6366F1","#3B82F6","#60A5FA","#0EA5E9","#06B6D4","#22D3EE","#14B8A6","#10B981","#22C55E","#4ADE80","#84CC16","#A3E635","#EAB308","#FACC15","#F59E0B","#FB923C","#F97316","#A16207","#A8A29E","#94A3B8","#64748B"]
    static let symbols = ["checkmark","book.closed","books.vertical","text.book.closed","graduationcap","pencil","pencil.and.outline","doc.text","newspaper","rectangle.on.rectangle","brain.head.profile","lightbulb","figure.walk","figure.run","figure.yoga","figure.strengthtraining.traditional","figure.pool.swim","bicycle","dumbbell","sportscourt","soccerball","basketball","tennisball","heart","heart.fill","cross.case","pills","bed.double","moon","sun.max","sunrise","drop","drop.fill","cup.and.saucer","mug","wineglass","carrot","fork.knife","leaf","flame","smoke","lungs","tooth","shower","bathtub","hands.sparkles","sparkles","music.note","pianokeys","guitars","headphones","mic","camera","paintpalette","theatermasks","film","tv","gamecontroller","desktopcomputer","laptopcomputer","iphone","keyboard","curlybraces","terminal","hammer","wrench","house","building.2","car","airplane","tram","map","globe","mountain.2","tree","pawprint","cat","dog","person","person.2","person.3","phone","envelope","message","hand.wave","gift","cart","creditcard","banknote","chart.line.uptrend.xyaxis","target","flag","medal","trophy","star","bolt","timer","hourglass","calendar","clock","alarm"]
}
extension String {
    var paletteColor: Color {
        guard hasPrefix("#"), let hex = UInt32(dropFirst(), radix: 16) else { switch self { case "cyan": return .cyan; case "blue": return .blue; case "orange": return .orange; case "pink": return .pink; case "purple": return .purple; default: return .mint } }
        return Color(red: Double((hex >> 16)&255)/255, green: Double((hex >> 8)&255)/255, blue: Double(hex&255)/255)
    }
}
