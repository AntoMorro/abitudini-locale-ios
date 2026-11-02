import SwiftUI
import WidgetKit
import ActivityKit

struct HabitEntry: TimelineEntry { var date: Date; var db: HabitDatabase; var available: Bool }
struct HabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry { HabitEntry(date: Date(), db: HabitEngine.demo(), available: true) }
    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) { completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(15 * 60)))) }
    func entry() -> HabitEntry { guard let repo = HabitEnvironment.sharedRepository, let db = try? repo.read() else { return HabitEntry(date: Date(), db: HabitDatabase(), available: false) }; return HabitEntry(date: Date(), db: db, available: true) }
}
struct HabitWidgetView: View {
    var entry: HabitEntry
    var heatmap = false
    @Environment(\.widgetFamily) var family
    var habits: [Habit] { Array(entry.db.habits.filter { !$0.archived }.prefix(4)) }
    var body: some View {
        Group {
            if !entry.available { Label("Apri Abitudini Locale e verifica l’archivio condiviso", systemImage: "leaf").font(.caption) }
            else if let first = habits.first {
                switch family {
                case .accessoryCircular:
                    Gauge(value: ratio(first)) { Image(systemName: first.symbol) }.gaugeStyle(.accessoryCircularCapacity)
                case .accessoryInline:
                    Label("\(first.title): \(Int(ratio(first) * 100))%", systemImage: first.symbol)
                case .accessoryRectangular:
                    VStack(alignment: .leading) { Text(first.title).font(.headline).lineLimit(1); ProgressView(value: ratio(first)); Text("\(Int(ratio(first) * 100))% completato").font(.caption2) }
                default:
                    VStack(alignment: .leading, spacing: 9) {
                        Label(heatmap ? "Il tuo ritmo" : "Prima ciò che conta", systemImage: "leaf.fill").font(.caption.bold()).foregroundStyle(.mint)
                        if heatmap { Text(first.title).font(.headline).lineLimit(1); heat(first) }
                        else {
                            ForEach(family == .systemSmall ? Array(habits.prefix(1)) : habits) { h in
                                HStack {
                                    Image(systemName: h.symbol).foregroundStyle(.mint).frame(width: 20)
                                    VStack(alignment: .leading, spacing: 3) { Text(h.title).font(.caption.bold()).lineLimit(1); ProgressView(value: ratio(h)).tint(.mint) }
                                    if [.check, .counter].contains(h.kind) { Button(intent: MarkHabitIntent(h)) { Image(systemName: ratio(h) >= 1 ? "checkmark.circle.fill" : "plus.circle.fill") }.buttonStyle(.plain).tint(.mint) }
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        if family == .systemLarge, !heatmap { heat(first) }
                    }
                }
            } else { Label("Crea la tua prima abitudine", systemImage: "plus.circle").font(.caption) }
        }.containerBackground(for: .widget) { Color(red: 0.105, green: 0.11, blue: 0.13) }
        .foregroundStyle(.white)
        .widgetURL(URL(string: "abitudinilocale://home"))
    }
    func ratio(_ h: Habit) -> Double { min(1, Double(HabitEngine.progress(h, in: entry.db, now: entry.date)) / Double(h.goal)) }
    func heat(_ h: Habit) -> some View {
        let values = HabitEngine.heatmap(h, db: entry.db, days: family == .systemLarge ? 364 : 84)
        let columns = family == .systemSmall ? 14 : family == .systemMedium ? 21 : 28
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: columns), spacing: 3) { ForEach(values.indices, id: \.self) { i in RoundedRectangle(cornerRadius: 2).fill(values[i].1 > 0 ? Color.mint.opacity(0.25 + values[i].1 * 0.75) : Color.gray.opacity(0.22)).aspectRatio(1, contentMode: .fit) } }
    }
}
struct ProgressHabitWidget: Widget {
    let kind = "AbitudiniProgress"
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: HabitProvider()) { HabitWidgetView(entry: $0) }.configurationDisplayName("Abitudini di oggi").description("Obiettivi, progressi e spunte rapide.").supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]) }
}
struct HeatmapHabitWidget: Widget {
    let kind = "AbitudiniHeatmap"
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: HabitProvider()) { HabitWidgetView(entry: $0, heatmap: true) }.configurationDisplayName("Mappa delle abitudini").description("Dodici settimane, oppure un anno nel formato grande, per la prima abitudine.").supportedFamilies([.systemSmall, .systemMedium, .systemLarge]) }
}
struct FocusHabitActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HabitActivityAttributes.self) { context in
            HStack { Image(systemName: "timer").foregroundStyle(.mint); VStack(alignment: .leading) { Text(context.state.title).font(.headline); Text(timerInterval: context.state.started...context.state.goalEnd, countsDown: true).monospacedDigit() } }.padding().activityBackgroundTint(.black.opacity(0.8)).activitySystemActionForegroundColor(.mint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "timer").foregroundStyle(.mint) }
                DynamicIslandExpandedRegion(.trailing) { Text(timerInterval: context.state.started...context.state.goalEnd, countsDown: true).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) { Text(context.state.title).lineLimit(1) }
            } compactLeading: { Image(systemName: "timer").foregroundStyle(.mint) } compactTrailing: { Text(timerInterval: context.state.started...context.state.goalEnd, countsDown: true).monospacedDigit().frame(width: 48) } minimal: { Image(systemName: "timer") }
        }
    }
}
@main struct HabitWidgetBundle: WidgetBundle { var body: some Widget { ProgressHabitWidget(); HeatmapHabitWidget(); FocusHabitActivity() } }
