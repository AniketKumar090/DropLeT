import WidgetKit
import SwiftUI

struct WaterEntry: TimelineEntry {
    let date: Date
    let amount: Int
    let configuration: String?
}
struct WaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "WaterWidget",
            provider: Provider()
        ) { entry in
            WaTerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Water Tracker")
        .description("Track your daily water intake")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}
