import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    let drinkRecords: [DrinkRecord]
    @State private var selectedTimeframe: Timeframe = .week
    @State private var animateContent = false
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Time Selector
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 15) {
                        StatCard(
                            title: "Average",
                            value: "\(calculateAverage())ml",
                            icon: "chart.bar.fill",
                            color: .purple
                        )
                        
                        StatCard(
                            title: "Best Day",
                            value: "\(calculateBestDay())ml",
                            icon: "star.fill",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Goal Rate",
                            value: "\(calculateGoalRate())%",
                            icon: "target",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Total Drinks",
                            value: "\(drinkRecords.count)",
                            icon: "cup.and.saucer.fill",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        ConsumptionChartView(drinkRecords: drinkRecords, timeframe: selectedTimeframe)
                      
                    }
                   
                    .background {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.gray.opacity(0.1))
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recent Drinks")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        ForEach(todaysDrinks.prefix(5), id: \.id) { record in
                            DrinkRowView(record: record)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.gray.opacity(0.1))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("History")
        }
    }
    public var todaysDrinks: [DrinkRecord] {
            let today = Calendar.current.startOfDay(for: Date())
            return drinkRecords.filter {
                Calendar.current.isDate($0.timestamp, inSameDayAs: today)
            }.reversed()
        }
    
    private func calculateAverage() -> Int {
        let filteredRecords = getFilteredRecords()
        guard !filteredRecords.isEmpty else { return 0 }
        
        let totalAmount = filteredRecords.reduce(0) { $0 + $1.amount }
        let numberOfDays = Double(getNumberOfDays(for: selectedTimeframe))
        
        return Int(totalAmount / numberOfDays)
    }
    private func calculateBestDay() -> Int {
        let filteredRecords = getFilteredRecords()
        
        // Group drinks by day
        let groupedByDay = Dictionary(grouping: filteredRecords) { record in
            Calendar.current.startOfDay(for: record.timestamp)
        }
        
        // Calculate total intake for each day
        let dailyTotals = groupedByDay.mapValues { records in
            records.reduce(0) { $0 + $1.amount }
        }
        
        return Int(dailyTotals.values.max() ?? 0)
    }
    private func calculateGoalRate() -> Int {
        let filteredRecords = getFilteredRecords()
        let groupedByDay = Dictionary(grouping: filteredRecords) { record in
            Calendar.current.startOfDay(for: record.timestamp)
        }
        
        let dailyGoal = 10000.0 // You might want to make this configurable
        let numberOfDays = getNumberOfDays(for: selectedTimeframe)
        let daysAchievedGoal = groupedByDay.values.filter { records in
            records.reduce(0) { $0 + $1.amount } >= dailyGoal
        }.count
        
        return Int((Double(daysAchievedGoal) / Double(numberOfDays)) * 100)
    }
    
    private func getFilteredRecords() -> [DrinkRecord] {
        let calendar = Calendar.current
        let today = Date()
        
        let startDate: Date
        switch selectedTimeframe {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: today)!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -29, to: today)!
        case .year:
            startDate = calendar.date(byAdding: .month, value: -11, to: today)!
        }
        
        return drinkRecords.filter { record in
            record.timestamp >= startDate && record.timestamp <= today
        }
    }
    
    private func getNumberOfDays(for timeframe: Timeframe) -> Int {
        switch timeframe {
        case .week:
            return 7
        case .month:
            return 30
        case .year:
            return 365
        }
    }
}


struct DrinkRowView: View {
    let record: DrinkRecord
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: record.type.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(.blue.opacity(0.1))
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(record.amount))ml \(record.type.rawValue.capitalized)")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

