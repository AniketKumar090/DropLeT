import Foundation
import WidgetKit


struct Provider: TimelineProvider {
        
        // Placeholder for the widget when it's in a non-ready state (e.g., during initialization)
        func placeholder(in context: Context) -> WaterEntry {
            // Return a placeholder entry with the current date and a default water amount (e.g., 0)
            return WaterEntry(date: Date(), amount: 0, configuration: nil)
        }
        
        // Snapshot for previewing the widget (used in the widget configuration screen)
        func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> ()) {
            // Get the current water amount for the snapshot
            let currentWaterAmount = UserDefaults.group.integer(forKey: UserDefaults.todayWaterAmountKey)
            
            // Create an entry for the snapshot with the current date and water amount
            let entry = WaterEntry(date: Date(), amount: currentWaterAmount, configuration: nil)
            
            // Return the entry via the completion handler
            completion(entry)
        }
        
        // Timeline that will update the widget at regular intervals (e.g., hourly or daily)
        func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> ()) {
            // Get the current water amount from UserDefaults
            let currentWaterAmount = UserDefaults.group.integer(forKey: UserDefaults.todayWaterAmountKey)
            
            // Define a timeline with entries that will update at regular intervals (e.g., hourly)
            let currentDate = Date()
            let timeline = Timeline(entries: [
                WaterEntry(date: currentDate, amount: currentWaterAmount, configuration: nil)
            ], policy: .atEnd) // Refresh the widget once the timeline ends
            
            // Pass the timeline to the completion handler
            completion(timeline)
        }
    }


//extension UserDefaults {
//    static let group = UserDefaults(suiteName: "group.Aniket.TDWidget.TaskWidget")!
//    
//    static let todayWaterAmountKey = "todayWaterAmount"
//    static let dailyGoalKey = "dailyGoal"
//}
