import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var drinkRecords: [DrinkRecord]
    @State private var dailyGoal: Double = 10000
    @State private var showingAddDrink = false
    @State private var todayProgress: Double = 0
   
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
        .sheet(isPresented: $showingAddDrink) {
            AddDrinkView { amount, type in
                addDrink(amount: amount, type: type, isQuickAdd: false)
            }
        }
    }
    
    private func addDrink(amount: Double, type: DrinkType, isQuickAdd: Bool) {
        let drink = DrinkRecord(amount: amount, type: type, isQuickAdd: isQuickAdd)
        modelContext.insert(drink)
        try? modelContext.save()
        
        // Update the progress immediately
        todayProgress = calculateTodayProgress()
        updateWidget()
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
    
    static let todayWaterAmountKey = "todayWaterAmount"
    static let dailyGoalKey = "dailyGoal"
}
