import SwiftUI
import Charts
import Foundation
import UserNotifications
import UserNotificationsUI
import CoreMotion

enum DrinkType: String, CaseIterable, Codable {
    case water, tea, coffee, soda
    
    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .tea: return "leaf.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .soda: return "bubbles.and.sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .water: return Color.blue
        case .tea: return Color.green
        case .coffee: return Color.orange
        case .soda: return Color.pink
        }
    }
    

}

struct CircleData: Identifiable, Codable, Equatable {
    let id: Int
    var drinkType: DrinkType?
}


struct DrinkRecords: Identifiable, Codable, Equatable {
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
    var chartViewEntry: Bool = false
    
    var goal: Int = 3000 {
        didSet {
            
            saveGoal()
        }
    }
    
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
    @StateObject private var motionManager = MotionManager()
    @State private var hasShownCongratulations: Bool = false
    let totalCircles = 46.5 * 24.0
    
    var percentageFilled: Double {
        Double(viewModel.totalDrinks) / Double(totalCircles) * 100
    }
    
    var showCongratulations: Bool {
        viewModel.goal <= 0 && !hasShownCongratulations && !UserDefaults.standard.bool(forKey: "hasShownCongratulations")
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
                                                    circleData: viewModel.circles[index],
                                                    motionManager: motionManager,
                                                    row: row,
                                                    column: column, currentVolume: percentageFilled
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
                    
                    if showCongratulations {
                        VStack{
                            Text("🎉 Congratulations!")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                            Text("You have completed your goal!")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(15)
                        .shadow(radius: 10)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(), value: showCongratulations)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.3)
                        .onAppear{
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    hasShownCongratulations = true
                                    UserDefaults.standard.set(true, forKey: "hasShownCongratulations")
                                }
                            }
                        }
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
                    
                    ChartView(viewModel: viewModel, percentageFilled: percentageFilled)
                        .transition(.move(edge: .leading))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.chartViewEntry)
                        .offset(x: viewModel.chartViewEntry ? 0 : -UIScreen.main.bounds.width)
                        .frame(width: UIScreen.main.bounds.width)
                }
                .ignoresSafeArea()
            }
        }
        .accentColor(.gray)
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge, .sound]) { success, error in
                if success {
                    print("All set!")
                } else if let error {
                    print(error.localizedDescription)
                }
            }
            scheduleNotificationsIfNeeded()
        }
        .onChange(of: viewModel.goal) {
            if viewModel.goal <= 0 {
                removeAllNotifications()
            } else {
                scheduleNotificationsIfNeeded()
            }
        }
    }
    
    private func scheduleNotificationsIfNeeded() {
        guard viewModel.goal > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Don't Forget to Get Hydrated"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
        let request = UNNotificationRequest(identifier: "hydration-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
struct CircleView: View {
    var circleData: CircleData
    @ObservedObject var motionManager: MotionManager
    let row: Int
    let column: Int
    let currentVolume: Double
    
    @State private var animationTime: Double = 0
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    // Calculate if this circle should be part of the wave effect
    private var isInWaveZone: Bool {
        // Only apply the wave effect to circles with a drinkType (filled circles)
     //   guard circleData.drinkType == nil else { return false }
        return circleData.drinkType != nil
//        // Calculate the row where the wave should appear based on current volume percentage
//        let totalRows = 50 // Total number of rows in the grid
//        let filledPercentage = currentVolume / 100.0 // Convert percentage to decimal
//        let filledRows = Int(Double(totalRows) * filledPercentage)
//        let waveRow = totalRows - filledRows // Wave appears at the top of filled section
//        
//        // Create wave effect in a 3-row band around the boundary
//        return row >= waveRow && row <= (waveRow + 5)
    }
    private var isInWaveZonePartTwo: Bool {
        // Only apply the wave effect to metallic gray circles (no drinkType)
        guard circleData.drinkType == nil else { return false }
        
        // Calculate the row where the wave should appear based on current volume percentage
        let totalRows = 50 // Total number of rows in the grid
        let filledPercentage = currentVolume / 100.0 // Convert percentage to decimal
        let filledRows = Int(Double(totalRows) * filledPercentage)
        let waveRow = totalRows - filledRows // Wave appears at the top of filled section
        
        // Create wave effect in a 3-row band around the boundary
        return row >= (waveRow - 3) && row <= waveRow
    }
    var body: some View {
        Circle()
            .foregroundStyle(getCircleColor())
            .offset(y: getWaveOffset())
            .onReceive(timer) { _ in
                animationTime += 0.05
            }
    }
    
    private func getCircleColor() -> Color {
        if let drinkType = circleData.drinkType {
            return getHighlightColor(drinkType, motionManager.xAcceleration)
        }
        return Color.randomMetallicGray()
    }
    
    private func getWaveOffset() -> CGFloat {
        guard isInWaveZone else { return 0 }
        guard isInWaveZonePartTwo else  { return 0 }
        let amplitude: CGFloat = 12
        let frequency: Double = 1.0
        let speed: Double = 2.0
        
        // Incorporate motion acceleration into the wave effect
        let motionFactor = motionManager.xAcceleration * 10.0 // Scale the acceleration for a noticeable effect
        
        let horizontalOffset = Double(column) * frequency * 0.3 + motionFactor
        
        // Calculate wave intensity based on distance from the boundary (optional)
        let totalRows = 50
        let filledPercentage = currentVolume / 100.0
        let waveRow = Int((1 - filledPercentage) * Double(totalRows))
        let distanceFromBoundary = abs(Double(row - waveRow))
        let waveIntensity = 1.0 - (distanceFromBoundary / Double(totalRows)) // Fade effect across all rows
        
        let time = animationTime * speed
        let sineWave = sin(time + horizontalOffset)
        let cosineWave = cos(time * 0.5 + horizontalOffset) * 0.5
        
        return amplitude * (sineWave + cosineWave) * waveIntensity
    }
    
    private func getHighlightColor(_ drinkType: DrinkType, _ xAcceleration: Double) -> Color {
        let accelerationFactor = xAcceleration * 0.1
        switch drinkType {
        case .water:
            return Color(hue: 0.583 + .random(in: -0.1...0.1) + accelerationFactor, saturation: 0.85, brightness: 0.68)
        case .tea:
            return Color(hue: 0.333 + .random(in: -0.1...0.1) + accelerationFactor, saturation: 0.8 + .random(in: -0.1...0.1), brightness: 0.7 + .random(in: -0.1...0.1))
        case .coffee:
            return Color(hue: 0.083 + .random(in: -0.1...0.1) + accelerationFactor, saturation: 0.7 + .random(in: -0.1...0.1), brightness: 0.6 + .random(in: -0.1...0.1))
        case .soda:
            return Color(hue: 0.95 + .random(in: -0.1...0.1) + accelerationFactor, saturation: 0.75 + .random(in: -0.1...0.1), brightness: 0.9 + .random(in: -0.1...0.1))
        }
    }
}
struct WaveModifier: ViewModifier {
    let isActive: Bool
    let date: Date
    let column: Int
    let row: Int
    
    func body(content: Content) -> some View {
        content
            .offset(y: isActive ? calculateWaveOffset() : 0)
    }
    
    private func calculateWaveOffset() -> CGFloat {
        let amplitude: CGFloat = 12 // Increased amplitude for more visible effect
        let frequency: Double = 1.0 // Adjusted for better wave appearance
        let speed: Double = 2.0 // Animation speed
        
        // Create a continuous time value
        let time = date.timeIntervalSinceReferenceDate * speed
        
        // Add phase offset based on column position
        let horizontalOffset = Double(column) * frequency * 0.3
        
        // Add row-based phase offset for more natural look
        let rowOffset = Double(row) * 0.2
        
        // Calculate wave using both sine and cosine for more interesting motion
        let sineWave = sin(time + horizontalOffset + rowOffset)
        let cosineWave = cos(time * 0.5 + horizontalOffset) * 0.5
        
        return amplitude * (sineWave + cosineWave)
    }
}
@Observable class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    var xAcceleration: Double = 0.0
    
    init() {
        startMotionUpdates()
    }
    
    private func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 1.0 / 60.0 // 60 Hz update rate
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            
          
            withAnimation(.easeOut(duration: 0.2)) {
                self?.xAcceleration = data.acceleration.x * 0.5
            }
        }
    }
    
    deinit {
        motionManager.stopAccelerometerUpdates()
    }
}


struct AddCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var volume: CGFloat = 150
    let totalCircles = 33 * 15
    @State private var selectedType: DrinkType = .water
    @State var viewModel: DrinkViewModel
    @StateObject private var motionManager = MotionManager()
   
    private var volumeDisplayView: some View {
        HStack {
            Text("\(Int(volume))")
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
    }

    private func circleGridView(height: CGFloat) -> some View {
        VStack {
            ForEach(0..<33) { row in
                HStack(spacing: 10) {
                    ForEach(0..<15) { column in
                        let index = row * 15 + column
                        let shouldFill = (totalCircles - index - 1) < Int(volume / 1000 * CGFloat(totalCircles))
                        CircleView(
                            circleData: CircleData(
                                id: index,
                                drinkType: shouldFill ? selectedType : nil
                            ), motionManager: motionManager, row: row, column: column, currentVolume: volume
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func drinkTypeButton(type: DrinkType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
            Text(type.rawValue.capitalized)
                .font(.caption)
        }
        .frame(width: 100, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(selectedType == type ? .gray.opacity(0.6) : .gray.opacity(0.2))
        )
        .foregroundColor(selectedType == type ? .white : .primary)
        .padding(.trailing, 80)
        .shadow(color: type.color, radius: 15, y: 5)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                selectedType = type
            }
        }
    }

    private func getDynamicHeight(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let maxHeight: CGFloat = 550
        let minHeight: CGFloat = 250
        let adjustedHeight = screenHeight * 0.5
        return max(minHeight, min(adjustedHeight, maxHeight))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Background gradient
                VStack {
                    LinearGradient(gradient: Gradient(colors: [selectedType.color, Color.black]),
                                 startPoint: .top,
                                 endPoint: .bottom)
                        .frame(height: geometry.size.height * 0.95)
                        .edgesIgnoringSafeArea(.all)
                    Spacer()
                }
                
                // Main content
                VStack {
                    HStack {
                        // Left column - Volume slider and circles
                        VStack {
                            volumeDisplayView
                            
                            ZStack {
                                let sliderHeight = getDynamicHeight(geometry: geometry)
                                
                                InvisibleSlider(percent: $volume)
                                    .frame(width: 100, height: sliderHeight)
                                    .foregroundColor(.black)
                                    .shadow(color: .black.opacity(0.5), radius: 15, y: 5)

                                circleGridView(height: sliderHeight)
                                    .mask {
                                        InvisibleSlider(percent: $volume)
                                            .frame(width: 100, height: sliderHeight)
                                    }
                                    .animation(.easeInOut(duration: 0.5), value: volume)
                            }
                        }

                        // Right column - Drink types
                        VStack {
                            Text("Drinks")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.trailing, 80)

                            ForEach(DrinkType.allCases, id: \.self) { type in
                                drinkTypeButton(type: type)
                            }
                        }
                    }
                }

                // Bottom button
                VStack {
                    Spacer()
                    Button(action: {
                        let circlesToFill = Int(volume / 1000 * CGFloat(totalCircles))
                         viewModel.fillCircles(count: circlesToFill,
                                                        with: selectedType,
                                                        volume: Int(volume))
                         
                        dismiss()
                    }) {
                        Text("Add Drink")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
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
}

struct InvisibleSlider: View {
    @Binding var percent: CGFloat // This will now represent the stepped volume (50, 100, 150, ..., 1000)
    let minVolume: CGFloat = 50
    let maxVolume: CGFloat = 1000
    let step: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let dragGesture = DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Calculate the raw percentage based on the drag position
                    let rawPercent = 1.0 - Double(value.location.y / geo.size.height)
                    
                    // Convert the raw percentage to a raw volume (50-1000)
                    let rawVolume = rawPercent * (maxVolume - minVolume) + minVolume
                    
                    // Snap the raw volume to the nearest step of 50
                    let steppedVolume = round(rawVolume / step) * step
                    
                    // Clamp the stepped volume to the range of 50-1000
                    let clampedVolume = max(minVolume, min(maxVolume, steppedVolume))
                    
                    // Update the percent binding with the stepped volume
                    self.percent = clampedVolume
                }
            
            Capsule()
                .frame(width: geo.size.width, height: geo.size.height)
                .gesture(dragGesture)
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
    func adjustHue(by offset: CGFloat) -> Color {
        var h: CGFloat = 0.0
        var s: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        let uiColor = UIColor(self)
        let success = uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        // Only modify the hue if the extraction was successful
        if success {
            let adjustedHue = (h + offset).truncatingRemainder(dividingBy: 1.0)
            return Color(hue: adjustedHue, saturation: Double(s), brightness: Double(b))
        } else {
            // If the extraction fails, return the original color
            return self
        }
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

        // Sort records by timestamp in descending order (most recent first)
        let sortedRecords = viewModel.drinkRecords.sorted { $0.timestamp > $1.timestamp }

        // Get the start of the current day (today at midnight)
        let calendar = Calendar.current
        let currentDate = calendar.startOfDay(for: Date())

        // Initialize streak and previous date
        var streak = 0
        var previousDate = currentDate

        // Iterate through the sorted records
        for record in sortedRecords {
            let recordDate = calendar.startOfDay(for: record.timestamp)

            // If the record is from today, start the streak
            if recordDate == currentDate {
                streak = 1
                previousDate = recordDate
            }
            // If the record is from the previous day, increment the streak
            else if recordDate == calendar.date(byAdding: .day, value: -1, to: previousDate)! {
                streak += 1
                previousDate = recordDate
            }
            // If there's a gap in the days, break the loop
            else {
                break
            }
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
                        y: .value("Quantity", Double(record.quantity) * 2)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Color.gray)
                    
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", Double(record.quantity) * 2)
                    )
                    .interpolationMethod(.stepEnd)
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
                        y: .value("Quantity", Double(record.quantity) * 2)
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


#Preview{
    Challenge()
}
