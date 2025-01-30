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
    func colorHighlight() -> Color {
        switch self {
        case .water: return Color.randomBlue()
        case .tea: return Color.randomTea()
        case .coffee: return Color.randomCoffee()
        case .soda: return Color.randomSoda()
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
    private let updateQueue = DispatchQueue(label: "com.drink.updates", qos: .userInitiated)
    private let saveQueue = DispatchQueue(label: "com.drink.saveData", qos: .background)
        
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
    
    // Goal is constant and should not change
    var goal: Int = 3000 {
        didSet {
            saveGoal()
        }
    }
    
    // New property to track total consumed liquid
    var consumed: Int = 0 {
        didSet {
            saveConsumed()
        }
    }
    
    // Computed property to calculate percentage filled
    var percentageFilled: Double {
        guard goal > 0 else { return 0 } // Avoid division by zero
        return (Double(consumed) / Double(goal)) * 100
    }
    
    var leftGoal: Int{
        return max((goal - consumed),0)
    }
    
    private let queue = DispatchQueue(label: "com.drink.fillCircles", qos: .userInitiated)
    
    init() {
        self.circles = Self.loadCircles()
        self.drinkRecords = Self.loadDrinkRecords()
        self.goal = Self.loadGoal()
        self.consumed = Self.loadConsumed() // Load consumed amount
        self.totalDrinks = self.circles.filter { $0.drinkType != nil }.count
    }
    
    private func saveCircles() {
        saveQueue.async {
            if let encoded = try? JSONEncoder().encode(self.circles) {
                UserDefaults.standard.set(encoded, forKey: "circles")
            }
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
        saveQueue.async {
            if let encoded = try? JSONEncoder().encode(self.drinkRecords) {
                UserDefaults.standard.set(encoded, forKey: "drinkRecords")
            }
        }
    }
       
    private func saveGoal() {
        saveQueue.async {
            UserDefaults.standard.set(self.goal, forKey: "goal")
        }
    }
    
    // Save consumed amount
    private func saveConsumed() {
        saveQueue.async {
            UserDefaults.standard.set(self.consumed, forKey: "consumed")
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
    
    private static func loadGoal() -> Int {
        let goal = UserDefaults.standard.object(forKey: "goal") as? Int ?? 3000
        return goal
    }
    
    // Load consumed amount
    private static func loadConsumed() -> Int {
        let consumed = UserDefaults.standard.object(forKey: "consumed") as? Int ?? 0
        return consumed
    }
    
    func fillCircles(count: Int, with drinkType: DrinkType, volume: Int) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            var updatedCircles = self.circles
            var newTotalDrinks = self.totalDrinks
            
           
            let newConsumed = self.consumed + volume
            
            // Calculate how many circles to fill based on percentage of goal completed
            let percentageOfGoal = Double(volume) / Double(self.goal)
            let circlesToFill = Int(Double(self.circles.count) * percentageOfGoal)
            
            if let firstEmptyIndex = updatedCircles.lastIndex(where: { $0.drinkType == nil }) {
                for i in 0..<circlesToFill {
                    let index = firstEmptyIndex - i
                    if index >= 0 {
                        updatedCircles[index].drinkType = drinkType
                        newTotalDrinks += 1
                    }
                }
            }
            
            let record = DrinkRecords(
                id: UUID(),
                timestamp: Date(),
                drinkType: drinkType,
                quantity: volume
            )
            
            DispatchQueue.main.async {
                self.circles = updatedCircles
                self.totalDrinks = newTotalDrinks
                //self.goal = newGoal
                self.consumed = newConsumed // Update consumed amount
                self.drinkRecords.append(record)
            }
        }
    }
    
    func reset() {
        // Reset drink records
        drinkRecords = []
        
        // Reset circles
        circles = Array(0..<(50 * 24)).map { CircleData(id: $0, drinkType: nil) }
        
        // Reset total drinks
        totalDrinks = 0
        
        // Reset goal to default value
        goal = 3000
        
        // Reset consumed amount
        consumed = 0
        
        // Save the changes
        saveDrinkRecords()
        saveCircles()
        saveGoal()
        saveConsumed()
    }
}

struct Challenge: View {
    @StateObject var viewModel: DrinkViewModel
    @State private var hasShownCongratulations: Bool = false
    let totalCircles = 46.5 * 24.0
    @State private var waveOffset: Double = 0
    @State private var waveTimer: Timer?
    @State private var isAnimating = true
    @State private var resetScreen = false
    @AppStorage("wavesEnabled") private var waveMotion = true

    @State private var staticColors: [[Color]] = Array(repeating: Array(repeating: Color.randomMetallicGray(), count: 24), count: 50)
    
    private func startWaveAnimation() {
        waveTimer?.invalidate()
        waveTimer = nil
        
        guard waveMotion else {
            // Ensure wave offset is reset when animation is stopped
            waveOffset = 0
            return
        }
        
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if isAnimating {
                withAnimation(.linear(duration: 0.05)) {
                    waveOffset += 0.05
                    if waveOffset >= 2 * .pi {
                        waveOffset = 0
                    }
                }
            }
        }
    }
    
    var brandGradient = Gradient(colors:[Color(.systemPurple), Color(.systemPurple)])
    
    var showCongratulations: Bool {
        viewModel.goal >= 100 && !hasShownCongratulations && !UserDefaults.standard.bool(forKey: "hasShownCongratulations")
    }
    
    private var lastDrinkTypeColor: Color {
        viewModel.circles.first { $0.drinkType != nil }?.drinkType?.colorHighlight() ?? Color.randomMetallicGray()
    }
    
    func isCircleColored(row: Int, column: Int, percentageFilled: Double) -> Bool {
        let totalRows = 50
        if !waveMotion {
            // Static fill without wave effect
            let baselineRow = Double(totalRows) * (1 - percentageFilled / 100)
            return Double(row) >= baselineRow
        }
        
        // Wave effect when enabled
        let baselineRow = Double(totalRows) * (1 - percentageFilled / 100)
        let waveHeight = 2.0
        let frequency = 2.0 * .pi / 24.0
        let speed = 2.0
        
        let yOffset = waveHeight * sin(frequency * Double(column) + waveOffset * speed)
        let adjustedBaseline = baselineRow + yOffset
        if percentageFilled >= 100 {
            return true
        }
        return Double(row) >= adjustedBaseline
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    // Background gray circles
                    LazyVStack(spacing:2) {
                        Spacer()
                        ForEach(0..<50, id: \.self) { row in
                            LazyHStack(spacing: 8) {
                                ForEach(0..<24, id: \.self) { column in
                                    let index = row * 24 + column
                                    Circle()
                                        .fill(isCircleColored(row: row, column: column, percentageFilled: viewModel.percentageFilled)
                                               ? (viewModel.circles[index].drinkType?.colorHighlight() ?? lastDrinkTypeColor)
                                               : staticColors[row][column])
                                }
                            }.padding(.horizontal, 8)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    
                    VStack {
                        HStack {
                            Spacer()
                            HStack {
                                Text("  \(Int(viewModel.percentageFilled))")
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
                        .padding(.top, geometry.size.height * 0.08)
                        Spacer()
                    }
                    
                    // Bottom buttons
                    VStack {
                        Spacer()
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
                                    .background(Circle().fill(Color.white.opacity(0.07)))
                                    .cornerRadius(50)
                                    .shadow(color: .black, radius: 8)
                            }
                            .padding(30)
                            .padding(.bottom, geometry.safeAreaInsets.bottom - 30)
                            Spacer()
                            Button(action: {
                                self.resetScreen = true
                            }) {
                                Text(" Reset ")
                                    .foregroundColor(.white)
                                    .padding(25)
                                    .overlay(Capsule().stroke(LinearGradient(gradient: brandGradient,
                                                                             startPoint: .leading, endPoint: .trailing),lineWidth: 5))
                                    .frame(height: 50)
                            }
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
                                        .background(Circle().fill(Color.white.opacity(0.07)))
                                        .cornerRadius(50)
                                        .shadow(color: .black, radius: 8)
                                }
                                .padding(30)
                                .padding(.bottom, geometry.safeAreaInsets.bottom - 30)
                        }
                    }
                    
                    // Congratulations overlay
                    if showCongratulations {
                        VStack {
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
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    hasShownCongratulations = true
                                    UserDefaults.standard.set(true, forKey: "hasShownCongratulations")
                                }
                            }
                        }
                    }
                    
                    ChartView(viewModel: viewModel, percentageFilled: viewModel.percentageFilled)
                        .transition(.move(edge: .leading))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.chartViewEntry)
                        .offset(x: viewModel.chartViewEntry ? 0 : -UIScreen.main.bounds.width)
                        .frame(width: UIScreen.main.bounds.width)
                }
                .ignoresSafeArea()
            }
        }
        .onChange(of: waveMotion) { newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                startWaveAnimation()
            }
        }
        .onAppear {
            startWaveAnimation()
            
            // Notification setup
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if success {
                    print("All set!")
                } else if let error {
                    print(error.localizedDescription)
                }
            }
            scheduleNotificationsIfNeeded()
        }
        .onDisappear {
            waveTimer?.invalidate()
            waveTimer = nil
        }
        .accentColor(.gray)
        .fullScreenCover(isPresented: $resetScreen, content: {
            ResetScreen(viewModel: viewModel)
        })
        .onChange(of: viewModel.goal) { newValue in
            if newValue <= 0 {
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
struct ResetScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DrinkViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("wavesEnabled") private var waveMotion = true
    @State private var temporaryGoal: String = ""
    @State private var showInvalidGoalAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .lastTextBaseline) {
                Text("Settings")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.leading)
                Spacer()
                Button(action: {
                    dismiss()
                } ){
                    Image(systemName: "x.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            
            // Goal Setting Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Daily Goal")
                    .foregroundColor(.white)
                    .font(.headline)
                
                HStack {
                    TextField("",text: $temporaryGoal)
                        .font(.system(size: 18, weight: .bold,design: .monospaced))
                        .keyboardType(.numberPad)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
                    
                    Button("Set") {
                        if let newGoal = Int(temporaryGoal), newGoal > 0 {
                            viewModel.goal = newGoal
                            temporaryGoal = ""
                            dismiss()
                        } else {
                            showInvalidGoalAlert = true
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .alert("Invalid Goal", isPresented: $showInvalidGoalAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please enter a valid number greater than 0")
                }
                
                Text("Enter your goal in ml")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)
            
            // Toggles Section
            VStack(alignment: .leading, spacing: 15) {
                Toggle(isOn: $notificationsEnabled) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.yellow)
                        Text("Notifications")
                            .foregroundColor(.white)
                    }
                }
                .onChange(of: notificationsEnabled) { newValue in
                    if newValue {
                        scheduleNotifications()
                    } else {
                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    }
                }
                
                Toggle(isOn: $waveMotion) {
                    HStack {
                        Image(systemName: "wave.3.right")
                            .foregroundColor(.blue)
                        Text("Wave Animation")
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)
            
            Spacer()
            
            // Reset Button
            Button(action: {
                viewModel.reset()
                dismiss()
            }) {
                Text("Reset all Data")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(15)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(Color.black)
        .onAppear {
            temporaryGoal = String(viewModel.goal)
        }
    }
    
    private func scheduleNotifications() {
        let content = UNMutableNotificationContent()
        content.title = "Don't Forget to Get Hydrated"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
        let request = UNNotificationRequest(identifier: "hydration-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
struct CircleView: View {
    var circleData: CircleData
    let row: Int
    let column: Int
    let currentVolume: Double
    
    var body: some View {
        Circle()
            .overlay(
                Circle()
                    .fill(getCircleColor())
            )
            .foregroundStyle(circleData.drinkType == nil ? Color.randomMetallicGray() : .clear)
    }
    
    private func getCircleColor() -> Color {
        if let drinkType = circleData.drinkType {
            return drinkType.colorHighlight()
        }
        return Color.randomMetallicGray()
    }
}




struct AddCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var volume: CGFloat = 150
    let totalCircles = 33 * 15
    @State private var selectedType: DrinkType = .water
    @State var viewModel: DrinkViewModel
    
    
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
                            ), row: row, column: column, currentVolume: volume
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
                        .frame(height: geometry.size.height * 0.2)
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
                                    .shadow(color: .gray, radius: 10, y: 5)

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
    @Binding var percent: CGFloat
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
    static func randomBlue() -> Color{
        return Color(hue: 0.583 + .random(in: -0.1...0.1) , saturation: 0.85, brightness: 0.68)
    }
    static func randomTea() -> Color{
        return Color(hue: 0.333 + .random(in: -0.1...0.1), saturation: 0.8 + .random(in: -0.1...0.1), brightness: 0.7 + .random(in: -0.1...0.1))
    }
    static func randomCoffee() -> Color{
        return Color(hue: 0.083 + .random(in: -0.1...0.1), saturation: 0.7 + .random(in: -0.1...0.1), brightness: 0.6 + .random(in: -0.1...0.1))
    }
    static func randomSoda() -> Color{
        return Color(hue: 0.95 + .random(in: -0.1...0.1), saturation: 0.75 + .random(in: -0.1...0.1), brightness: 0.9 + .random(in: -0.1...0.1))
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
                        Text("\(viewModel.leftGoal)")
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
    @ObservedObject var viewModel: DrinkViewModel
    var percentageFilled: Double
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
                        y: .value("Quantity", Double(record.quantity))
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Color.gray)
                    
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", Double(record.quantity))
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
                        y: .value("Quantity", Double(record.quantity))
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
    Challenge(viewModel: DrinkViewModel())
}
