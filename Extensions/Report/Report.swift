import DeviceActivity
import SwiftUI

@main struct HabitReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene { DailyReport { DailyReportView(total: $0) } }
}
struct DailyReport: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("abitudini.total")
    let content: (TimeInterval) -> DailyReportView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TimeInterval {
        var total: TimeInterval = 0
        for await entry in data { for await segment in entry.activitySegments { total += segment.totalActivityDuration } }
        return total
    }
}
struct DailyReportView: View {
    let total: TimeInterval
    var body: some View { VStack(spacing: 8) { Text("\(Int(total / 3600)) h \(Int(total.truncatingRemainder(dividingBy: 3600) / 60)) min").font(.system(size: 34, weight: .bold, design: .rounded)); Text("Tempo di utilizzo nel filtro scelto").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
}
