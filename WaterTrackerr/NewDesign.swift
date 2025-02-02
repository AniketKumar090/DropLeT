import SwiftUI
import Charts
import Foundation
import UserNotifications
import UserNotificationsUI
import SimpleCameraLibrary


struct DrinkTypeData {
    let type: String
    let amount: Double
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



class NotificationManager: ObservableObject {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    // This method will schedule notifications
    func scheduleNotifications() {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Don't Forget to Get Hydrated"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
        let request = UNNotificationRequest(identifier: "hydration-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notifications: \(error.localizedDescription)")
            } else {
                print("Notification scheduled.")
            }
        }
    }

    // This method will remove all scheduled notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // This method handles toggling notifications on/off
    func toggleNotifications(_ isEnabled: Bool) {
        notificationsEnabled = isEnabled
        
        if isEnabled {
            scheduleNotifications()
        } else {
            removeAllNotifications()
        }
    }
}


@Observable class DrinkViewModel: ObservableObject {
    private let updateQueue = DispatchQueue(label: "com.drink.updates", qos: .userInitiated)
    private let saveQueue = DispatchQueue(label: "com.drink.saveData", qos: .background)

    var circles: [CircleData] {
        didSet {
            saveCircles()
        }
    }

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

    var consumed: Int = 0 {
        didSet {
            saveConsumed()
        }
    }

   var percentageFilled: Double {
        guard goal > 0 else { return 0 } // Avoid division by zero
        return (Double(consumed) / Double(goal)) * 100
    }

    var leftGoal: Int{
        return max((goal - consumed),0)
    }
    
    var hasShownCongratulations: Bool = false
    
    private let queue = DispatchQueue(label: "com.drink.fillCircles", qos: .userInitiated)

    var waveOffset: Double = 0 {
           didSet {
               if waveOffset >= 2 * .pi {
                   waveOffset = 0
               }
           }
       }
       
       // Add the wave calculation function
       func isCircleColored(row: Int, column: Int, percentageFilled: Double, totalRows: Int, waveMotion: Bool) -> Bool {
           if !waveMotion {
               let baselineRow = Double(totalRows) * (1 - percentageFilled / 100)
               return Double(row) >= baselineRow
           }
           
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
        return Array(0..<(23 * 15)).map { CircleData(id: $0, drinkType: nil) }
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
        drinkRecords = []

        circles = Array(0..<(23 * 15)).map { CircleData(id: $0, drinkType: nil) }

        totalDrinks = 0

        goal = 3000

        consumed = 0
        hasShownCongratulations = false
        UserDefaults.standard.removeObject(forKey: "hasShownCongratulations")

        saveDrinkRecords()
        saveCircles()
        saveGoal()
        saveConsumed()
    }
}


struct CongratulationsToast: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack {
            if isVisible {
                Text("🎉 Goal Completed !!!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.15, green: 0.02, blue: 0.25))
                    .cornerRadius(25)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                            withAnimation {
                                isVisible = false
                            }
                        }
                    }
            }
        }
        .animation(.spring(), value: isVisible)
    }
}

struct NewDesign: View {
    @StateObject var viewModel: DrinkViewModel
    let totalCircles = 23.0 * 15.0
    @State private var waveOffset: Double = 0
    @State private var volume: CGFloat = 0
    @State private var waveTimer: Timer?
    @State private var isAnimating = true
    @State private var addScreen = false
    @AppStorage("wavesEnabled") private var waveMotion = true
    @State private var showCongratulations = false
    @State private var staticColors: [[Color]] = Array(repeating: Array(repeating: Color.randomMetallicGray(), count: 15), count: 24)
    
    // Create an instance of NotificationManager
    @StateObject private var notificationManager = NotificationManager()
    
    func isCircleColored(row: Int, column: Int, percentageFilled: Double) -> Bool {
        return viewModel.isCircleColored(row: row,
                                         column: column,
                                         percentageFilled: percentageFilled,
                                         totalRows: 23,
                                         waveMotion: waveMotion)
    }
    
    private func startWaveAnimation() {
            waveTimer?.invalidate()
            waveTimer = nil
            
            guard waveMotion else {
                viewModel.waveOffset = 0
                return
            }
            
            waveTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak viewModel] _ in
                if isAnimating {
                    withAnimation(.linear(duration: 0.05)) {
                        viewModel?.waveOffset += 0.05
                    }
                }
            }
        }
    
    var brandGradient = Gradient(colors:[Color(.systemPurple), Color(.systemPurple)])
    
    private var lastDrinkTypeColor: Color {
        viewModel.circles.first { $0.drinkType != nil }?.drinkType?.colorHighlight() ?? Color.randomMetallicGray()
    }
    
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let circleCountPerRow: CGFloat = 15
                let totalPadding: CGFloat = 64
                let availableWidth = screenWidth - totalPadding
                let dynamicSpacing = availableWidth / circleCountPerRow - 4
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        // Percentage and remaining amount
                        HStack(alignment: .lastTextBaseline) {
                            Text("\(Int(viewModel.percentageFilled))%")
                                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.leading, 32)
                            Spacer()
                            Text("\(viewModel.leftGoal)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                            
                            Text("ml left")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.trailing, 32)
                        }
                        .padding(.bottom, 42)
                        
                        // Circle grid
                        LazyVStack(spacing: 18) {
                            ForEach(0..<23) { row in
                                LazyHStack(spacing: dynamicSpacing) {
                                    ForEach(0..<15, id: \.self) { column in
                                        let index = row * 15 + column
                                        Circle()
                                            .fill(isCircleColored(row: row, column: column, percentageFilled: viewModel.percentageFilled)
                                                  ? (viewModel.circles[index].drinkType?.colorHighlight() ?? lastDrinkTypeColor)
                                                  : staticColors[row][column])
                                            .frame(width: 4)
                                    }
                                }
                            }
                        }
                        
                        // Bottom buttons
                        HStack {
                            Button(action: {
                                viewModel.chartViewEntry.toggle()
                            }) {
                                Image(systemName: "drop.fill")
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(Circle().fill(Color.white.opacity(0.07)))
                            }
                            .padding(.trailing, 44)
                            .padding(.leading, 32)
                            
                            Button(action: {
                                self.addScreen = true
                            }) {
                                Text("Add")
                                    .foregroundColor(.white)
                                    .frame( height: 20)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 44)
                                    .background(RoundedRectangle(cornerRadius: 24.5)
                                        .fill(Color(red: 0.15, green: 0.02, blue: 0.25)))
                                    
                            }
                            
                            NavigationLink(destination: ChartView(viewModel: viewModel, percentageFilled: viewModel.percentageFilled)
                                .transition(.move(edge: .trailing))
                                .animation(.easeInOut(duration: 0.3), value: true)
                                .navigationBarBackButtonHidden(true)) {
                                    Image("Tabview")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                        .padding(16)
                                        .background(Circle().fill(Color.white.opacity(0.07)))
                                        .shadow(color: .black, radius: 8)
                                }
                                .padding(.trailing, 32)
                                .padding(.leading, 44)
                        }
                        .padding(.top, 48)
                    }
                    
                    VStack {
                        CongratulationsToast(isVisible: $showCongratulations)
                            .padding(.top, 20)
                        Spacer()
                    }
                }
                
                SettingView(viewModel: viewModel)
                    .transition(.move(edge: .leading))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.chartViewEntry)
                    .offset(x: viewModel.chartViewEntry ? 0 : -UIScreen.main.bounds.width)
                    .frame(width: UIScreen.main.bounds.width)
            }
            .fullScreenCover(isPresented: $addScreen) {
                AddCircleView(volume: $volume,viewModel: viewModel)
            }
        }
        .onChange(of: waveMotion) { newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                startWaveAnimation()
            }
        }
        .onChange(of: viewModel.percentageFilled) { newValue in
            if newValue >= 100 && !viewModel.hasShownCongratulations {
                withAnimation {
                    showCongratulations = true
                    viewModel.hasShownCongratulations = true
                }
            }
        }
        .onAppear {
            startWaveAnimation()
            
            // Request notification permissions
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if success {
                    print("All set!")
                } else if let error {
                    print(error.localizedDescription)
                }
            }
            
            // Schedule notifications if needed
            if viewModel.goal > 0 {
                notificationManager.scheduleNotifications()
            }
        }
        .onDisappear {
            waveTimer?.invalidate()
            waveTimer = nil
        }
        .accentColor(.gray)
        .onChange(of: viewModel.goal) { newValue in
            if newValue <= 0 {
                notificationManager.removeAllNotifications()
            } else {
                notificationManager.scheduleNotifications()
            }
        }
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
            .frame(width: 4)
    }

    private func getCircleColor() -> Color {
        if let drinkType = circleData.drinkType {
            return drinkType.colorHighlight()
        }
        return Color.randomMetallicGray()
    }
}


struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DrinkViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("wavesEnabled") private var waveMotion = true
    @State private var temporaryGoal: String = ""
    @State private var showInvalidGoalAlert = false
    @State private var showConfirmationAlert = false
    @FocusState private var isGoalFieldFocused: Bool
    
    // Create an instance of NotificationManager
    @StateObject private var notificationManager = NotificationManager()

    var showCongratulations: Bool {
        viewModel.percentageFilled >= 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .lastTextBaseline) {
                Text("Settings")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.leading)
                Spacer()
                Button(action: {
                    viewModel.chartViewEntry = false
                    isGoalFieldFocused = false
                }) {
                    Image(systemName: "x.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Daily Goal")
                    .foregroundColor(.white)
                    .font(.headline)

                HStack {
                    TextField("Enter your goal in ml", text: $temporaryGoal)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .keyboardType(.numberPad)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
                        .focused($isGoalFieldFocused)

                    Button("Set") {
                        if let newGoal = Int(temporaryGoal), newGoal > 0 {
                            viewModel.goal = newGoal
                            temporaryGoal = ""
                            isGoalFieldFocused = false
                            dismiss()
                            
                            withAnimation(.easeInOut(duration: 1.5)){
                                viewModel.chartViewEntry = false
                            }
                        } else {
                            showInvalidGoalAlert = true
                        }
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.8))
                    .cornerRadius(10)
                }
                .alert("Invalid Goal", isPresented: $showInvalidGoalAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please enter a valid number greater than 0")
                }

                Text("Current goal: \(viewModel.goal) ml")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $notificationsEnabled) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.yellow)
                        Text("Notifications")
                            .foregroundColor(.white)
                    }
                }
                .onChange(of: notificationsEnabled) { newValue in
                    // Use the NotificationManager to toggle notifications
                    notificationManager.toggleNotifications(newValue)
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
            if showCongratulations {
                VStack {
                    Text("🎉 Congratulations!")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                    Text("You have completed your goal!!")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .padding()
                .frame(width: UIScreen.main.bounds.width)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: showCongratulations)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.hasShownCongratulations = true
                    }
                }
            }

            Button(action: {
                showConfirmationAlert = true
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
            .alert("Are you Sure?", isPresented: $showConfirmationAlert) {
                Button("OK", role: .cancel) {
                    viewModel.chartViewEntry = false
                    viewModel.reset()
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .background(Color.black
            .onTapGesture {
                isGoalFieldFocused = false
            })
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

        
        if success {
            let adjustedHue = (h + offset).truncatingRemainder(dividingBy: 1.0)
            return Color(hue: adjustedHue, saturation: Double(s), brightness: Double(b))
        } else {
            return self
        }
    }
}
extension String {
    func extractNumericValue() -> Double? {
        let numbers = self.components(separatedBy: CharacterSet.letters.union(CharacterSet.whitespaces))
            .joined()
            .replacingOccurrences(of: ",", with: ".")
        return Double(numbers)
    }
}

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

extension DrinkType {
    static func fromKeywords(_ keywords: [String]) -> DrinkType? {
        let lowercasedKeywords = keywords.map { $0.lowercased() }
        
        // Check for soda indicators
        if lowercasedKeywords.contains("soda") ||
           lowercasedKeywords.contains("carbonated") ||
           lowercasedKeywords.contains("cola") {
            return .soda
        }
        
        // Check for coffee indicators
        if lowercasedKeywords.contains("coffee") {
            return .coffee
        }
        
        // Check for tea indicators
        if lowercasedKeywords.contains("tea") {
            return .tea
        }
        
        // Check for water indicators
        if lowercasedKeywords.contains("water") &&
           !lowercasedKeywords.contains("carbonated") {
            return .water
        }
        
        return nil
    }
}
struct VolumeDisplayView: View {
    @AppStorage("wavesEnabled") private var waveMotion = true
    @Binding var volume: CGFloat
    @Binding var selectedType: DrinkType?
    var currentColor: Color
    var totalCircles: Int
    @ObservedObject var viewModel: DrinkViewModel
    @StateObject private var scanner = ProductScannerService()
    @State private var isShowCamera: Bool = false
    
    private var productInfoBinding: Binding<ProductInfo?> {
        Binding(
            get: { scanner.productInfo },
            set: { _ in }
        )
    }
    
    private func determineDrinkType(from productInfo: ProductInfo) -> DrinkType? {
        print("Determining drink type for product: \(productInfo.name)")
            
            if let keywords = productInfo.keywords {
                print("Checking keywords: \(keywords)")
                
                let lowercasedKeywords = keywords.map { $0.lowercased() }
                
                // Check for soda/carbonated drinks first
                let sodaIndicators = ["soda", "carbonated", "cola", "soft drink"]
                if lowercasedKeywords.contains(where: { keyword in
                    sodaIndicators.contains(where: { keyword.contains($0) })
                }) {
                    print("Detected as soda from keywords")
                    return .soda
                }
            
            // Check for coffee
            if lowercasedKeywords.contains("coffee") {
                print("Detected as coffee from keywords")
                return .coffee
            }
            
            // Check for tea
            if lowercasedKeywords.contains("tea") {
                print("Detected as tea from keywords")
                return .tea
            }
            
            // Check for water (only if not carbonated)
            if lowercasedKeywords.contains("water") &&
               !lowercasedKeywords.contains("carbonated") {
                print("Detected as water from keywords")
                return .water
            }
        }
        
        // If no type was determined from keywords, check the drink category
        if let category = productInfo.drinkCategory?.lowercased() {
            print("Checking drink category: \(category)")
            return DrinkType.fromKeywords([category])
        }
        
        print("No drink type detected, returning nil")
        return nil
    }
    var scannerVolume: CGFloat {
        guard let productInfo = scanner.productInfo else {
            print("No product info available")
            return 0
        }
        
        print("Raw volume string: \(productInfo.volume)")
      
        let volumeStr = productInfo.volume.lowercased()
        
        if volumeStr.contains("ml") {
            return CGFloat(volumeStr.extractNumericValue() ?? 0)
        } else if volumeStr.contains("cl") {
            return CGFloat(volumeStr.extractNumericValue() ?? 0) * 10
        } else if volumeStr.contains("l") {
            return CGFloat(volumeStr.extractNumericValue() ?? 0) * 1000
        }
        
        return 0
    }
    
    private func isCircleColored(row: Int, column: Int) -> Bool {
        let percentageFilled = (volume / 1000.0) * 100
        return viewModel.isCircleColored(row: row,
                                     column: column,
                                     percentageFilled: percentageFilled,
                                     totalRows: 15,
                                     waveMotion: waveMotion)
    }
    
    var body: some View {
        VStack {
            Text("\(Int(volume)) ml")
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            ZStack {
                Circle()
                    .strokeBorder()
                    .frame(width: 212, height: 212)
                
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 10)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .fill(isShowCamera ? Color.clear : Color.black)
                    .frame(width: 190, height: 190)
                
                ZStack {
                    if isShowCamera {
                        BarcodeScannerPreviewView(scannerService: scanner)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 190, height: 190)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(0..<15) { row in
                                LazyHStack {
                                    ForEach(0..<15, id: \.self) { column in
                                        let shouldFill = isCircleColored(row: row, column: column)
                                        CircleView(
                                            circleData: CircleData(
                                                id: row * 15 + column,
                                                drinkType: shouldFill ? selectedType : nil
                                            ), row: row, column: column, currentVolume: volume)
                                    }
                                }
                            }
                        }
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                    }
                }
                .frame(width: 190, height: 190)
                
                Circle()
                    .trim(from: 0, to: volume / 1000)
                    .stroke(currentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: volume)
                
                Button {
                    if isShowCamera {
                        scanner.stopScanning()
                        scanner.productInfo = nil
                    } else {
                        // Clear the cache before starting a new scan
                       // scanner.clearCache()
                        scanner.startScanning()
                    }
                    withAnimation {
                        isShowCamera.toggle()
                    }
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .frame(width: 35, height: 35)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3)))
                }
                .offset(x: 87.5, y: 80)
            }
        }
        .onChange(of: scanner.productInfo) { productInfo in
            if let productInfo = productInfo {
                print("Scanner product info received: \(productInfo)")
                print("Keywords: \(productInfo.keywords ?? [])")
                
                withAnimation {
                    // Directly assign values without using `wrappedValue`
                    volume = scannerVolume
                    
                    // Determine drink type from scanned product
                    if let detectedType = determineDrinkType(from: productInfo) {
                        print("Setting detected drink type: \(detectedType)")
                        selectedType = detectedType
                    } else {
                        print("No type detected, using default water type")
                        selectedType = .water
                    }
                    
                    isShowCamera = false
                }
                scanner.stopScanning()
            }
        }
        .onDisappear {
            scanner.stopScanning()
        }
    }
}
struct VolumeButtons: View {
    @Binding var volume: CGFloat
    var currentColor: Color
    var onDecrease: () -> Void
    var onIncrease: () -> Void
    
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 10) {
                Text("Drink Amount:  ")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                   
                Button(action: onDecrease) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(currentColor == .purple ? .gray : .white)
                        .opacity(currentColor == .purple || volume == 0 ? 0.5 : 1)
                        
                }
                .disabled(currentColor == .purple || volume == 0)
                Button(action: onIncrease) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(currentColor == .purple ? .gray : .white)
                        .opacity(currentColor == .purple || volume == 1000 ? 0.5 : 1)
                }
                .disabled(currentColor == .purple || volume == 1000)
            }
            .padding(.top, 20)
        }
    }
}

struct DrinkTypeButton: View {
    var type: DrinkType
    var selectedType: DrinkType?
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: type.icon)
                    .font(.system(size: 30))
                    .foregroundColor(selectedType == type ? .white : type.color)
                    .padding(15)
                    .background(
                        Circle()
                            .fill(selectedType == type ? type.color : Color.white.opacity(0.2))
                    )
                    .shadow(color: type.color.opacity(0.5), radius: 10, y: 5)
                
                Text(type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}


struct AddCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var volume: CGFloat
    let totalCircles = 15 * 15
    @State private var selectedType: DrinkType? = nil
    @State var viewModel: DrinkViewModel
    @State private var waveOffset: Double = 0
    @AppStorage("wavesEnabled") private var waveMotion = true
    @State private var staticColors: [[Color]] = Array(repeating: Array(repeating: Color.randomMetallicGray(), count: 15), count: 15)
    
    private var currentColor: Color {
        selectedType?.color ?? .purple
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [currentColor.opacity(0.8), Color.black]),
                           startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                VolumeDisplayView(volume: $volume,
                                selectedType: $selectedType,
                                currentColor: currentColor,
                                totalCircles: totalCircles,
                                viewModel: viewModel)
                    .padding(.bottom, 40)
                
                Spacer()
                
                HStack(spacing: 20) {
                    ForEach(DrinkType.allCases, id: \.self) { type in
                        DrinkTypeButton(type: type, selectedType: selectedType) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.5)) {
                                if selectedType == type {
                                    selectedType = nil
                                    volume = 0
                                } else {
                                    selectedType = type
                                    if volume == 0 {
                                        volume = 150
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                
                VolumeButtons(volume: $volume, currentColor: currentColor,
                onDecrease: {
                    withAnimation {
                        volume = max(0, volume - 50)
                    }
                }, onIncrease: {
                    withAnimation {
                        volume = min(1000, volume + 50)
                    }
                })
                
                Spacer()
                
                Button(action: {
                    if selectedType == nil || volume == 0 {
                        dismiss()
                    } else {
                        let circlesToFill = Int(volume / 1000 * CGFloat(totalCircles))
                        viewModel.fillCircles(count: circlesToFill,
                                              with: selectedType!,
                                              volume: Int(volume))
                        dismiss()
                    }
                }) {
                    Text(selectedType == nil || volume == 0 ? "Cancel" : "Add Drink")
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(currentColor)
                        .cornerRadius(15)
                }
                .opacity(selectedType == nil || volume == 0 ? 0.5 : 1)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
        }
    }
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
                    Text(" %")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
               

                VStack {

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

       
        let calendar = Calendar.current
        let currentDate = calendar.startOfDay(for: Date())

       
        var streak = 0
        var previousDate = currentDate

       
        for record in sortedRecords {
            let recordDate = calendar.startOfDay(for: record.timestamp)

          
            if recordDate == currentDate {
                streak = 1
                previousDate = recordDate
            }
           
            else if recordDate == calendar.date(byAdding: .day, value: -1, to: previousDate)! {
                streak += 1
                previousDate = recordDate
            }
            else {
                break
            }
        }

        return streak
    }

    var body: some View {
        VStack {
            
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
                        .foregroundColor(.gray)
                }


                HStack {
                    Image(systemName: "cup.and.saucer")
                        .foregroundColor(.blue)
                        .frame(width: 25)
                    Text("Total Drinks")
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(totalDrinksVolume))
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .frame(width: 25)

                    Text("Freq Drink")
                        .foregroundColor(.white)
                    Spacer()
                    Text(mostFrequentDrink)
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.red)
                        .frame(width: 25)
                    Text("Streak")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(streakCounter) d")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 8)
            Spacer()
        }
        .frame(width: UIScreen.main.bounds.width / 2, height: 250)
    }
}

struct ChartView: View {
    @Environment(\.dismiss) private var dismiss
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
                    
                    Button(action: {
                        withAnimation(.smooth(duration: 2.3)) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                selectedTimeframe = .hour
                            }
                            dismiss()
                        }
                    }, label: {
                        Image(systemName: "arrowtriangle.left")
                        Text("Back")
                        
                    }).padding(.leading).padding(.bottom,20).foregroundColor(Color(.systemGray))
                    
                    Spacer()
                    
                }
               // Spacer()
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(.purple)
                    Text("Drink Insights")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Spacer()
                HStack {
                   
                    DrinkPieChartView(viewModel: viewModel, percentageFilled: percentageFilled)
                        .padding(.leading,8)
                    TabletView(viewModel: viewModel)
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

