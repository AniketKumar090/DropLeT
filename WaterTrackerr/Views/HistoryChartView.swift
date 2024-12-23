import SwiftUI
import Charts

struct ConsumptionChartView: View {
    let drinkRecords: [DrinkRecord]
    let timeframe: HistoryView.Timeframe
    
    struct ChartData: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let amount: Double
        let type: DrinkType? // Optional for combined amounts
        
        static func combined(date: Date, label: String, amount: Double) -> ChartData {
            ChartData(date: date, label: label, amount: amount, type: nil)
        }
        
        static func daily(date: Date, label: String, amount: Double, type: DrinkType) -> ChartData {
            ChartData(date: date, label: label, amount: amount, type: type)
        }
    }
    
    private var chartData: [ChartData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var data: [ChartData] = []
        
        switch timeframe {
        case .week:
            let dates = (-3...3).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: dayOffset, to: today)
            }
            for date in dates {
                let startOfDay = calendar.startOfDay(for: date)
                guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }
                
                let dayRecords = drinkRecords.filter {
                    $0.timestamp >= startOfDay && $0.timestamp < endOfDay
                }
                
                for type in DrinkType.allCases {
                    let amount = dayRecords.filter { $0.type == type }
                                        .reduce(0) { $0 + $1.amount }
                    data.append(.daily(date: date,
                                     label: formatDate(date),
                                     amount: amount,
                                     type: type))
                }
            }
            
        case .month:
            let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
            
            let weekStarts = (-2...2).compactMap { weekOffset in
                calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: currentWeekStart)
            }.reversed()
            
            for (index, weekStart) in weekStarts.enumerated() {
                guard let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else {
                    continue
                }
                
                let weekRecords = drinkRecords.filter {
                    $0.timestamp >= weekStart && $0.timestamp < weekEnd
                }
                
                let totalAmount = weekRecords.reduce(0) { $0 + $1.amount }
                
                let weekNumber = index + 1
                data.append(.combined(date: weekStart,
                                    label: "Week \(weekNumber)",
                                    amount: totalAmount))
            }
            
        case .year:
            for monthOffset in (-6...6).reversed() {
                guard let date = calendar.date(byAdding: .month, value: -monthOffset, to: today),
                      let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
                      let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                    continue
                }
                
                let monthRecords = drinkRecords.filter {
                    $0.timestamp >= monthStart && $0.timestamp < monthEnd
                }
                
                let totalAmount = monthRecords.reduce(0) { $0 + $1.amount }
                data.append(.combined(date: monthStart,
                                    label: formatDate(monthStart),
                                    amount: totalAmount))
            }
        }
        
        return data
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .week:
            formatter.dateFormat = "EEE"
        case .month:
            return ""
        case .year:
            formatter.dateFormat = "MMM"
        }
        
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Consumption Trend")
                .font(.title3)
                .fontWeight(.semibold)
            
            if chartData.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else {
                Chart(chartData) { item in
                    if timeframe == .week {
                        BarMark(
                            x: .value("Date", item.label),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(by: .value("Type", item.type?.rawValue.capitalized ?? "Unknown"))
                        .position(by: .value("Type", item.type?.rawValue.capitalized ?? "Unknown"))
                    } else {
                        BarMark(
                            x: .value("Date", item.label),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                }
                .chartForegroundStyleScale([
                    "Water": Color.blue,
                    "Coffee": Color.brown,
                    "Tea": Color.green,
                    "Soda": Color.pink
                ])
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("\(Int(amount))ml")
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, spacing: 20)
                .frame(height: 200)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(.gray.opacity(0.1))
        }
    }
}
