import SwiftUI
import SwiftData


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
                showingAddDrink: $showingAddDrink, recentDrinks: drinkRecords
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
          
         
        }
        
        .sheet(isPresented: $showingAddDrink) {
            AddDrinkView { amount, type in
                let drink = DrinkRecord(amount: amount, type: type, isQuickAdd: false)
                modelContext.insert(drink)
                try? modelContext.save()
                todayProgress = calculateTodayProgress()
                
             
            }
        }
    }
    
  
    
    public func calculateTodayProgress() -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let todayDrinks = drinkRecords.filter {
            Calendar.current.isDate($0.timestamp, inSameDayAs: today)
        }
        return todayDrinks.reduce(0) { $0 + $1.amount }
    }
}


