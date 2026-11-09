import SwiftUI
import WidgetKit

struct CaptureEntry:TimelineEntry {var date:Date}
struct CaptureProvider:TimelineProvider {
    func placeholder(in context:Context)->CaptureEntry{CaptureEntry(date:Date())}
    func getSnapshot(in context:Context,completion:@escaping(CaptureEntry)->Void){completion(CaptureEntry(date:Date()))}
    func getTimeline(in context:Context,completion:@escaping(Timeline<CaptureEntry>)->Void){completion(Timeline(entries:[CaptureEntry(date:Date())],policy:.never))}
}
struct CaptureWidgetView:View {
    @Environment(\.widgetFamily) private var family
    var body:some View {Group{if family == .accessoryCircular{Image(systemName:"square.and.pencil").font(.title2)}else{Label("Annota al volo",systemImage:"square.and.pencil")}}.containerBackground(for:.widget){Color.clear}.widgetURL(URL(string:"quaderno-watch://capture"))}
}
struct QuadernoCaptureWidget:Widget {
    var body:some WidgetConfiguration{StaticConfiguration(kind:"quaderno.capture",provider:CaptureProvider()){_ in CaptureWidgetView()}.configurationDisplayName("Annota nel quaderno").description("Apre la cattura rapida sul Watch.").supportedFamilies([.accessoryCircular,.accessoryRectangular,.accessoryInline])}
}
@main struct QuadernoWatchWidgets:WidgetBundle {var body:some Widget{QuadernoCaptureWidget()}}
