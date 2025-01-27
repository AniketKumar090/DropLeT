import SwiftUI
import Charts
import Foundation


struct CircleData: Identifiable, Codable {
    let id: Int
    var drinkType: DrinkType?
}


struct DrinkRecords: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let drinkType: DrinkType
    let quantity: Int
}
@Observable class DrinkViewModel: ObservableObject {
    var circles: [CircleData] {
        didSet {
            saveCircles()
        }
    }
    var selectedType: DrinkType = .water
    var totalDrinks: Int = 0
    var drinkRecords: [DrinkRecords] = [] {
        didSet {
            saveDrinkRecords()
        }
    }
    var goal: Int = 3000 {
        didSet {
            saveGoal()
        }
    }
    var chartViewEntry: Bool = false
    private let queue = DispatchQueue(label: "com.drink.fillCircles", qos: .userInitiated)
    
    init() {
        self.circles = Self.loadCircles()
        self.drinkRecords = Self.loadDrinkRecords()
        self.goal = Self.loadGoal()
        self.totalDrinks = self.circles.filter { $0.drinkType != nil }.count
    }
    
    private func saveCircles() {
        if let encoded = try? JSONEncoder().encode(circles) {
            UserDefaults.standard.set(encoded, forKey: "circles")
        }
    }
    
    private static func loadCircles() -> [CircleData] {
        if let data = UserDefaults.standard.data(forKey: "circles") {
            if let decoded = try? JSONDecoder().decode([CircleData].self, from: data) {
                return decoded
            }
        }

        return Array(0..<(50 * 24)).map { CircleData(id: $0, drinkType: nil) }
    }
    
    private func saveDrinkRecords() {
        if let encoded = try? JSONEncoder().encode(drinkRecords) {
            UserDefaults.standard.set(encoded, forKey: "drinkRecords")
        }
    }
    
    private static func loadDrinkRecords() -> [DrinkRecords] {
        if let data = UserDefaults.standard.data(forKey: "drinkRecords") {
            if let decoded = try? JSONDecoder().decode([DrinkRecords].self, from: data) {
                return decoded
            }
        }
        
        return []
    }
    
  
    private func saveGoal() {
        UserDefaults.standard.set(goal, forKey: "goal")
    }
    
    private static func loadGoal() -> Int {
        let goal = UserDefaults.standard.object(forKey: "goal") as? Int ?? 3000
        return goal
    }
    
   
    func fillCircles(count: Int, with drinkType: DrinkType, volume: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Update goal with safety check
            let newGoal = max(0, self.goal - volume)
            
            DispatchQueue.main.async {
                self.goal = newGoal
            }
            
            if let firstEmptyIndex = self.circles.lastIndex(where: { $0.drinkType == nil }) {
                for i in 0..<count {
                    let index = firstEmptyIndex - i
                    if index >= 0 {
                        DispatchQueue.main.async {
                            self.circles[index].drinkType = drinkType
                            self.totalDrinks += 1
                        }
                    }
                }
                
                let record = DrinkRecords(
                    id: UUID(),
                    timestamp: Date(),
                    drinkType: drinkType,
                    quantity: count
                )
                
                DispatchQueue.main.async {
                    self.drinkRecords.append(record)
                }
            } else {
                DispatchQueue.main.async {
                    self.totalDrinks += count
                    self.drinkRecords.append(DrinkRecords(
                        id: UUID(),
                        timestamp: Date(),
                        drinkType: drinkType,
                        quantity: count
                    ))
                }
            }
        }
    }
}
struct Challenge: View {
    @StateObject var viewModel = DrinkViewModel()
    let totalCircles = 46.5 * 24.0
    
    var percentageFilled: Double {
        Double(viewModel.totalDrinks) / Double(totalCircles) * 100
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottomTrailing) {
                    Color.black.edgesIgnoringSafeArea(.all)
                   
                    VStack(spacing: 13) {
                        Spacer()
                        
                        ForEach(0..<50) { row in
                            HStack(spacing: 13) {
                                ForEach(0..<24) { column in
                                    let index = row * 24 + column
                                    CircleView(
                                        circleData: viewModel.circles[index]
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color.black.opacity(0.95),
                                Color.black.opacity(0.3),
                                Color.clear,
                                Color.clear,
                                Color.clear,
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    
                    VStack {
                        HStack {
                            Spacer()
                            HStack{
                                Text("  \(Int(percentageFilled))")
                                    .font(.system(size: 60))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("%  ")
                                    .font(.system(size: 25))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.top)
                            }
                            Spacer()
                        }
                        .padding(.top, geometry.size.height * 0.05)
                        Spacer()
                    }
                    
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.chartViewEntry.toggle()
                            }
                        }) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .padding(25)
                                .foregroundColor(.white)
                                .background(.black)
                                .cornerRadius(50)
                                .shadow(color: .black, radius: 8)
                        }
                        .padding(30)
                        .padding(.bottom, geometry.safeAreaInsets.bottom - 30)
                        
                        Spacer()
                        
                        NavigationLink(destination: AddCircleView(viewModel: viewModel)
                            .transition(.move(edge: .trailing))
                            .animation(.easeInOut(duration: 0.3), value: true)
                            .navigationBarBackButtonHidden(true)) {
                                Image(systemName: "plus")
                                    .resizable()
                                    .frame(width: 25, height: 25)
                                    .padding(25)
                                    .foregroundColor(.white)
                                    .background(.black)
                                    .cornerRadius(50)
                                    .shadow(color: .black, radius: 8)
                            }
                            .padding(30)
                            .padding(.bottom, geometry.safeAreaInsets.bottom - 30)
                    }
                    
                    // Conditional view for ChartView with transition
                    ChartView(viewModel: viewModel, percentageFilled: percentageFilled)
                        .transition(.move(edge: .leading))
                            .animation(.easeInOut(duration: 0.3), value: viewModel.chartViewEntry)
                            .offset(x: viewModel.chartViewEntry ? 0 : -UIScreen.main.bounds.width)
                            .frame(width: UIScreen.main.bounds.width)
                }
                .ignoresSafeArea()
            }
        }.accentColor(Color.gray)
    }
}

struct DrinkTypeData {
    let type: String
    let amount: Double
}

struct DrinkPieChartView: View {
    @State var viewModel: DrinkViewModel
    var percentageFilled: Double
    // Calculate drink type data
    var drinkTypeData: [DrinkTypeData] {
        let groupedDrinks = Dictionary(grouping: viewModel.drinkRecords, by: { $0.drinkType })
        
        let typeTotals = groupedDrinks.mapValues { records in
            records.reduce(0) { $0 + $1.quantity }
        }
        
        let totalDrinks = typeTotals.values.reduce(0, +)
        
        return DrinkType.allCases.compactMap { type in
            guard let count = typeTotals[type], count > 0 else { return nil }
            return DrinkTypeData(
                type: type.rawValue.capitalized,
                amount: Double(count) / Double(totalDrinks)
            )
        }
    }
    
    
    var body: some View {
        HStack {
            ZStack {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(Int(percentageFilled))")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
                .padding(.top, 40)
                
                VStack {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(viewModel.goal)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.leading, 20)
                        Text("ml left")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.trailing, 32)
                    }
                    .padding(.bottom, 20)
                    
                    Chart {
                        if drinkTypeData.isEmpty {
                            SectorMark(angle: .value("Quadrant 1", 0.25), innerRadius: .ratio(0.5),
                                       angularInset: 1.5).cornerRadius(5)
                                .foregroundStyle(Color.randomMetallicGray()).shadow(color: Color.randomMetallicGray(), radius: 5)
                            SectorMark(angle: .value("Quadrant 2", 0.25), innerRadius: .ratio(0.5),
                                       angularInset: 1.5).cornerRadius(5)
                                .foregroundStyle(Color.randomMetallicGray()).shadow(color: Color.randomMetallicGray(), radius: 3)
                            SectorMark(angle: .value("Quadrant 3", 0.25), innerRadius: .ratio(0.5),
                                       angularInset: 1.5).cornerRadius(5)
                                .foregroundStyle(Color.randomMetallicGray()).shadow(color: Color.randomMetallicGray(), radius: 5)
                            SectorMark(angle: .value("Quadrant 4", 0.25), innerRadius: .ratio(0.5),
                                       angularInset: 1.5).cornerRadius(5)
                                .foregroundStyle(Color.randomMetallicGray()).shadow(color: Color.randomMetallicGray(), radius: 3)
                        } else {
                            ForEach(drinkTypeData, id: \.type) { dataItem in
                                SectorMark(
                                    angle: .value("Type", dataItem.amount),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(
                                    dataItem.type == "Water" ? Color.blue :
                                        dataItem.type == "Tea" ? Color.green :
                                        dataItem.type == "Coffee" ? Color.orange :
                                        Color.pink
                                )
                                .shadow(color:  dataItem.type == "Water" ? Color.blue :
                                            dataItem.type == "Tea" ? Color.green :
                                            dataItem.type == "Coffee" ? Color.orange :
                                            Color.pink, radius: 5)
                            }
                        }
                    }
                    .frame(width: 180, height: 180)
                }
            }
            Spacer()
        }
    }
}

struct TabletView: View {
    @State var viewModel: DrinkViewModel

    var totalDrinksVolume: Int {
        return viewModel.drinkRecords.count
    }

    var averageDrinkSize: Double {
        let totalVolume = viewModel.drinkRecords.reduce(0) { $0 + $1.quantity }
        return totalDrinksVolume == 0 ? 0 : Double(totalVolume) / Double(totalDrinksVolume)
    }
    var mostFrequentDrink: String {
        let groupedDrinks = Dictionary(grouping: viewModel.drinkRecords, by: { $0.drinkType })
        let sorted = groupedDrinks.sorted { $0.value.count > $1.value.count }
        return sorted.first?.key.rawValue.capitalized ?? "None"
    }
    var streakCounter: Int {
        guard !viewModel.drinkRecords.isEmpty else { return 0 }

        let sortedRecords = viewModel.drinkRecords.sorted { $0.timestamp > $1.timestamp }
        var streak = 1 // Start the streak count at 1 because the first record is a valid day
        var previousDate = Calendar.current.startOfDay(for: sortedRecords[0].timestamp)

        for record in sortedRecords.dropFirst() {
            let recordDate = Calendar.current.startOfDay(for: record.timestamp)
            
            // Check if the current record is from the previous day
            if Calendar.current.isDate(recordDate, inSameDayAs: previousDate.addingTimeInterval(-86400)) {
                streak += 1 // Increase streak if it is a consecutive day
            } else {
                break // Break as soon as there's a gap in the days
            }
            
            previousDate = recordDate // Update previous date to the current record's date
        }
        
        return streak
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.purple)
                Text("Drink Insights")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(spacing: 35) {
                HStack {
                    Image(systemName: "chart.pie")
                        .foregroundColor(.yellow)
                        .frame(width: 25)
                    Text("Average")
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f ml", averageDrinkSize))
                        .foregroundColor(.white)
                }
                
                
                HStack {
                    Image(systemName: "cup.and.saucer")
                        .foregroundColor(.blue)
                        .frame(width: 25)
                    Text("Total Drinks")
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(totalDrinksVolume))
                        .foregroundColor(.white)
                }
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .frame(width: 25)
                    
                    Text("Freq Drink")
                        .foregroundColor(.white)
                    Spacer()
                    Text(mostFrequentDrink)
                        .foregroundColor(.white)
                }
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.red)
                        .frame(width: 25)
                    Text("Streak")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(streakCounter) d")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            Spacer()
        }
        .frame(width: UIScreen.main.bounds.width / 2, height: 300)
    }
}

struct ChartView: View {
    @State var viewModel: DrinkViewModel
    var percentageFilled: Double
    @State private var fillPercentage: CGFloat = 0.0
    @State private var selectedTimeframe: Timeframe = .hour
    
    enum Timeframe: String, CaseIterable {
        case hour = "Hourly"
        case daily = "Daily"
        case week = "Weekly"
    }
    
    
    private var filteredRecords: [DrinkRecords] {
        let now = Date()
        switch selectedTimeframe {
        case .hour:
            return viewModel.drinkRecords.filter {
                now.timeIntervalSince($0.timestamp) <= 3600
            }
        case .daily:
            return viewModel.drinkRecords.filter {
                now.timeIntervalSince($0.timestamp) <= 86400
            }
        case .week:
            return viewModel.drinkRecords.filter {
                now.timeIntervalSince($0.timestamp) <= 604800
            }
        }
    }
    
    private var xAxisDomain: ClosedRange<Date> {
        let now = Date()
        switch selectedTimeframe {
        case .hour:
            return now.addingTimeInterval(-3600)...now.addingTimeInterval(120)
        case .daily:
            return now.addingTimeInterval(-86400)...now.addingTimeInterval(4600)
        case .week:
            return now.addingTimeInterval(-604800)...now.addingTimeInterval(22500)
        }
    }
    
 
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.smooth(duration: 2.3)) {
                            viewModel.chartViewEntry = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                selectedTimeframe = .hour
                            }
                        }
                    }, label: {
                        Text("Back")
                        Image(systemName: "arrowtriangle.right")
                    }).padding(.trailing,8).padding(.top,20)
                }
                Spacer()
                
                HStack {
                    TabletView(viewModel: viewModel)
                        .padding(.leading,8)
                    DrinkPieChartView(viewModel: viewModel, percentageFilled: percentageFilled)
                        .padding(.trailing,8)
                }
                 
                Spacer()
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(10)
                .foregroundColor(.white)
                .padding(.horizontal)
                Spacer()
                
                Chart(filteredRecords) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", Double(record.quantity) * 2.675)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.white)
                    
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", Double(record.quantity) * 2.675)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.7),
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.1),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    PointMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", Double(record.quantity) * 2.675)
                    )
                    .symbol(.circle)
                    .foregroundStyle(Color.white)
                }
                .chartXAxis {
                    switch selectedTimeframe {
                    case .hour:
                        AxisMarks(values: .stride(by: .minute, count: 5)) { value in
                            AxisValueLabel(format: .dateTime.hour().minute(),anchor: .top)
                                .foregroundStyle(Color.gray)
                        }
                    case .daily:
                        AxisMarks(values: .stride(by: .hour, count: 1)) { value in
                            AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                                .foregroundStyle(Color.gray)
                        }
                    case .week:
                        AxisMarks(values: .stride(by: .day, count: 1)) { value in
                            AxisValueLabel {
                                Text(value.as(Date.self)?.formatted(.dateTime.weekday(.abbreviated)) ?? "")
                            }    .foregroundStyle(Color.gray)
                        }
                    }
                }
                
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic) { value in
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0) ml")
                        }.foregroundStyle(Color.gray)
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
                .chartXScale(domain: xAxisDomain)
                .chartScrollPosition(x: .constant(Date()))
                .chartScrollableAxes(.horizontal)
                .chartYScale(domain: 0...1100)
                .frame(width: UIScreen.main.bounds.width,height: 350)
                .padding(.bottom,10)
            }
        }
    }
}


struct AddCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fillPercentage: CGFloat = 0.15
    let totalCircles = 25 * 15
    @State private var selectedType: DrinkType = .water
    @State var viewModel: DrinkViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
               Color.black.edgesIgnoringSafeArea(.all)
                VStack {
                    LinearGradient(gradient: Gradient(colors: [selectedType.color, Color.black]), startPoint: .top, endPoint: .bottom)
                        .frame(height: 200)
                        .edgesIgnoringSafeArea(.all)
                    Spacer()
                }
                VStack {
                    HStack {
                        VStack {
                            HStack {
                                Text("\(Int(fillPercentage * 100) * 10)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)

                                Text("ml")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .padding(.top, 5)
                                    .offset(x: -10)
                            }
                            
                            ZStack {
                                Capsule()
                                    .fill(LinearGradient.gradientBackground())
                                    .frame(width: 100, height: getDynamicHeight(geometry: geometry)) // Dynamically calculated height
                                    .shadow(color: .gray.opacity(0.5), radius: 15, y: 5)

                                VStack {
                                    ForEach(0..<26) { row in
                                        HStack(spacing: 10) {
                                            ForEach(0..<15) { column in
                                                CircleView(
                                                    circleData: CircleData(
                                                        id: row * 15 + column,
                                                        drinkType: (totalCircles - (row * 15 + column) - 1) < Int(fillPercentage * CGFloat(totalCircles)) ? selectedType : nil
                                                    )
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                    }
                                }
                                .mask {
                                    Capsule()
                                        .frame(width: 100, height: getDynamicHeight(geometry: geometry)) // Mask the content with the same dynamic height
                                }
                                .animation(.easeInOut(duration: 0.5), value: fillPercentage)
                            }
                        }

                        VStack {
                            Text("Drinks")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.trailing, 80)

                            ForEach(DrinkType.allCases, id: \.self) { type in
                                HStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.title2)
                                        .foregroundColor(type.color)
                                    Text(type.rawValue.capitalized)
                                        .font(.caption)
                                }
                                .frame(width: 100, height: 50)
                                .background {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(selectedType == type ? .gray.opacity(0.6) : .gray.opacity(0.2))
                                }
                                .foregroundColor(selectedType == type ? .white : .primary)
                                .padding(.trailing, 80)
                                .shadow(color: type.color, radius: 15, y: 5)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedType = type
                                    }
                                }
                            }
                        }
                    }

                    Slider(value: $fillPercentage, in: 0.05...1.025, step: 0.05)
                        .padding()
                        .tint(selectedType.color)
                }

                VStack {
                    Spacer()
                    Button(action: {
                        let circlesToFill = Int(fillPercentage * CGFloat(totalCircles))
                        viewModel.fillCircles(count: circlesToFill, with: selectedType, volume: (Int(fillPercentage * 100) * 10))
                        dismiss()
                    }) {
                        Text("Add Drink")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedType.color.opacity(0.8))
                            .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    
    private func getDynamicHeight(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let maxHeight: CGFloat = 350  // The maximum height we want for the capsule
        let minHeight: CGFloat = 250 // Minimum height if the space is constrained

        // Adjust height based on the available screen space
        let adjustedHeight = screenHeight * 0.4  // Let's say the capsule should take up 40% of screen height
        return max(minHeight, min(adjustedHeight, maxHeight)) // Ensure it doesn't exceed maxHeight or go below minHeight
    }
}

struct CircleView: View {
    let circleData: CircleData
    
    var body: some View {
        Circle()
            .foregroundStyle(circleData.drinkType.map(getHighlightColor) ?? Color.randomMetallicGray())
            .animation(.easeInOut(duration: 0.2), value: circleData.drinkType != nil)
    }
    
    private func getHighlightColor(_ drinkType: DrinkType) -> Color {
        switch drinkType {
        case .water:
            return Color(hue: 0.583 + .random(in: -0.1...0.1), saturation: 0.85, brightness: 0.68)
        case .tea:
            return Color(hue: 0.333 + .random(in: -0.1...0.1), saturation: 0.8 + .random(in: -0.1...0.1), brightness: 0.7 + .random(in: -0.1...0.1))
        case .coffee:
            return Color(hue: 0.083 + .random(in: -0.1...0.1), saturation: 0.7 + .random(in: -0.1...0.1), brightness: 0.6 + .random(in: -0.1...0.1))
        case .soda:
            return Color(hue: 0.95 + .random(in: -0.1...0.1), saturation: 0.75 + .random(in: -0.1...0.1), brightness: 0.9 + .random(in: -0.1...0.1))
        }
    }
}

extension LinearGradient {
    static func gradientBackground() -> LinearGradient {
        return LinearGradient(gradient: Gradient(colors: [Color.black, Color.black]), startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    static func randomMetallicGray() -> Color {
        let baseGray = 0.5 + .random(in: -0.1...0.1)
        let variation = 0.1 + .random(in: -0.05...0.05)

        return .init(
            red: baseGray + variation,
            green: baseGray + variation,
            blue: baseGray + variation
        )
    }
}

#Preview {
    Challenge(viewModel: DrinkViewModel())
}
