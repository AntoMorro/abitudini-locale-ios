import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WellnessWidgetBridge {
    static var url:URL?{HabitEnvironment.groupURL?.appendingPathComponent("wellness-widget.json")}
    static func publish(_ archive:WellnessArchive){
        guard let url else{return}
        if archive.preferences.widgetsEnabled != true {
            // Only the opt-in summary is removed, never the journal archive.
            try? FileManager.default.removeItem(at:url)
        }else{
            do{
                let data=try JSONEncoder().encode(WellnessInsights.snapshot(archive,on:Date()))
                try data.write(to:url,options:[.atomic,.completeFileProtection])
            }catch{return}
        }
        #if canImport(WidgetKit)
        for kind in ["QuadernoRecovery","QuadernoSleep","QuadernoVitals","QuadernoLoad"]{WidgetCenter.shared.reloadTimelines(ofKind:kind)}
        #endif
    }
    static func read()->WellnessWidgetSnapshot?{
        guard let url,let data=try? Data(contentsOf:url),data.count<50_000 else{return nil}
        return try? JSONDecoder().decode(WellnessWidgetSnapshot.self,from:data)
    }
}
