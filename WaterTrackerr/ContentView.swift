import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var drinkRecords: [DrinkRecord]
    
    @State private var dailyGoal: Double = 10000
    @State private var showingAddDrink = false
    @State private var todayProgress: Double = 0
    @State private var isSyncing = false  // Add flag to prevent sync loops
    @AppStorage(UserDefaults.todayWaterAmountKey, store: UserDefaults.group) private var widgetProgress: Int = 0
    
    var body: some View {
        TabView {
            DashboardView(
                dailyGoal: $dailyGoal,
                todayProgress: $todayProgress,
                showingAddDrink: $showingAddDrink,
                recentDrinks: drinkRecords,
                onQuickAdd: { amount, type in
                    addDrink(amount: amount, type: type, isQuickAdd: true)
                }
            )
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }

            HistoryView(drinkRecords: drinkRecords)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
        }
        .onAppear {
            todayProgress = calculateTodayProgress()
            updateWidget()
        }
        .onChange(of: widgetProgress) { oldValue, newValue in
            guard !isSyncing else { return }  // Skip if already syncing
            if Double(newValue) != todayProgress {
                syncWidgetToApp(amount: Double(newValue))
            }
        }
        .sheet(isPresented: $showingAddDrink) {
            AddDrinkView { amount, type in
                addDrink(amount: amount, type: type, isQuickAdd: false)
            }
        }
    }

    private func syncWidgetToApp(amount: Double) {
        isSyncing = true
        
        // Check if this is a widget-originated update
        if UserDefaults.group.bool(forKey: UserDefaults.isWidgetUpdateKey) {
            // Just update the progress without creating a new record
            todayProgress = calculateTodayProgress()
            // Reset the flag
            UserDefaults.group.set(false, forKey: UserDefaults.isWidgetUpdateKey)
        } else {
            // Calculate the difference between current progress and widget amount
            let difference = amount - todayProgress
            
            if difference != 0 {
                // Create a new drink record for the difference
                let drink = DrinkRecord(
                    amount: difference,
                    type: .water,
                    isQuickAdd: true
                )
                modelContext.insert(drink)
                try? modelContext.save()
                
                todayProgress = calculateTodayProgress()
            }
        }
        
        isSyncing = false
    }
    private func addDrink(amount: Double, type: DrinkType, isQuickAdd: Bool) {
        isSyncing = true  // Set syncing flag
        
        let drink = DrinkRecord(amount: amount, type: type, isQuickAdd: isQuickAdd)
        modelContext.insert(drink)
        try? modelContext.save()

        todayProgress = calculateTodayProgress()
        updateWidget()
        
        isSyncing = false  // Reset syncing flag
    }

    private func updateWidget() {
        let todayAmount = calculateTodayProgress()
        UserDefaults.group.set(Int(todayAmount), forKey: UserDefaults.todayWaterAmountKey)
        UserDefaults.group.set(Int(dailyGoal), forKey: UserDefaults.dailyGoalKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func calculateTodayProgress() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let todayDrinks = drinkRecords.filter {
            $0.timestamp >= startOfDay && $0.timestamp < endOfDay
        }
        return todayDrinks.reduce(0) { $0 + $1.amount }
    }
}
extension UserDefaults {
    static let group = UserDefaults(suiteName: "group.Aniket.TDWidget.TaskWidget")!
    static let isWidgetUpdateKey = "isWidgetUpdate"
    static let todayWaterAmountKey = "todayWaterAmount"
    static let dailyGoalKey = "dailyGoal"
}
