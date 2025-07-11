import SwiftUI
import Charts
import Combine
import Foundation
import UserNotifications
import UserNotificationsUI
import AVFoundation

struct DrinkTypeData {
    let type: String
    let amount: Double
}

struct CircleData: Identifiable, Codable, Equatable {
    let id: Int
    var drinkType: DrinkType?
}


struct DrinkRecords: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let timestamp: Date
    let drinkType: DrinkType
    let quantity: Int
}
class MidnightResetManager: ObservableObject {
    private var resetTimer: Timer?

    init() {
        scheduleReset()
    }

    deinit {
        resetTimer?.invalidate()
    }

    func scheduleReset() {
        // Invalidate any existing timer to avoid duplicates
        resetTimer?.invalidate()

        // Calculate the time until the next 04:30
        let calendar = Calendar.current
        let now = Date()
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.second = 0

        guard let nextResetTime = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return }
        let timeUntilReset = nextResetTime.timeIntervalSince(now)

        // Schedule the timer to fire at 04:30
        resetTimer = Timer.scheduledTimer(withTimeInterval: timeUntilReset, repeats: false) { _ in
            self.resetAt0()
            // Reschedule for the next day
            self.scheduleReset()
        }
    }

    func resetAt0() {
        print("Resetting data..")
        // Call your reset logic here
        DrinkViewModel().resetAtMidnight()
    }
}
class NotificationManager: ObservableObject {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    static let midnightResetReceived = Notification.Name("midnightResetReceived")
        
    func scheduleNotifications() {
        guard notificationsEnabled else { return }
        
        // Define the notification times and messages
        let notificationTimes = [
            (hour: 7, minute: 0, message: "Drink your first glass of water after waking up!"),
            (hour: 9, minute: 0, message: "It’s time for your second glass of water! Start your work day refreshed."),
            (hour: 11, minute: 30, message: "Have a glass of water 30 minutes before lunch."),
            (hour: 13, minute: 30, message: "Drink a glass of water an hour after lunch to aid digestion."),
            (hour: 15, minute: 0, message: "Refresh your mind with a glass of water during your tea break."),
            (hour: 17, minute: 0, message: "Stay hydrated to prevent overeating during dinner."),
            (hour: 19, minute: 30, message: "Stay hydrated to prevent overeating during dinner."),
            (hour: 21, minute: 30, message: "Have a glass of water an hour after dinner."),
            (hour: 23, minute: 45, message: "Drink your last glass of water an hour before bedtime.")
        ]
        
        // Remove all existing notifications before scheduling new ones
        removeAllNotifications()
        
        let calendar = Calendar.current
        let now = Date()
        
        for (hour, minute, message) in notificationTimes {
            // Create a date component for the notification time
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            
            // Calculate the next occurrence of the notification time
            guard let triggerDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { continue }
            
            // Create the notification content
            let content = UNMutableNotificationContent()
            content.title = "DropleT"
            content.body = message
            content.sound = UNNotificationSound.default
            
            // Create the trigger for the notification
            let triggerDateComponents = calendar.dateComponents([.hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: true)
            
            // Create the notification request
            let request = UNNotificationRequest(
                identifier: "hydration_reminder_\(hour)_\(minute)",
                content: content,
                trigger: trigger
            )
            
            // Add the notification request
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification for \(hour):\(minute): \(error.localizedDescription)")
                } else {
                    print("Notification scheduled for \(hour):\(minute)")
                }
            }
        }
        
        // Schedule the midnight reset task
        scheduleMidnightReset()
    }

    func scheduleMidnightReset() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 0 // Changed to exactly midnight
        components.minute = 0
        
        guard let triggerDate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "It's a New Day"
        content.body = "Starting with fresh hydration goals!"
        content.sound = UNNotificationSound.default
        
        let triggerDateComponents = calendar.dateComponents([.hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "midnight_reset",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling midnight reset: \(error.localizedDescription)")
            } else {
                print("Midnight reset scheduled")
                // Post notification only if the scheduling is successful
               
            }
        }
    }
    // This method removes all scheduled notifications
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
   
    // MARK: - Properties
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
    var addScreen: Bool = false

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
        guard goal > 0 else { return 0 }
        return (Double(consumed) / Double(goal)) * 100
    }

    var leftGoal: Int {
        let leftInMl = max((goal - consumed), 0)
        return useOunces ? Int(mlToOz(Double(leftInMl))) : leftInMl
    }

    var hasShownCongratulations: Bool = false {
        didSet {
            saveHasShownCongratulations()
        }
    }

    var useOunces: Bool = false {
        didSet {
            saveUseOunces()
        }
    }

    private let queue = DispatchQueue(label: "com.drink.fillCircles", qos: .userInitiated)
    var waveOffset: Double = 0 {
        didSet {
            if waveOffset >= 2 * .pi {
                waveOffset = 0
            }
        }
    }
    

    var plusRotation: Double = 0
    var contentOffset: CGFloat = 0
    var keyboardOffset: CGFloat = 0
    var customVolume: String = ""
    var selectedVolume: CGFloat? = nil
    private var cancellables = Set<AnyCancellable>()
    var selectedQuickSelections: [QuickSelection] = []
    var isScanning = false
    var displayedText: String = ""
    
    // MARK: - Initialization
    init() {
        self.circles = Self.loadCircles()
        self.drinkRecords = Self.loadDrinkRecords()
        self.goal = Self.loadGoal()
        self.consumed = Self.loadConsumed()
        self.totalDrinks = self.circles.filter { $0.drinkType != nil }.count
        self.hasShownCongratulations = Self.loadHasShownCongratulations()
        self.useOunces = Self.loadUseOunces()
       
        setupKeyboardObservers()
                
        let initialSelections = [
            QuickSelection(icon: "wineglass.fill", label: "Half Glass", volume: 150, isSelected: true),
            QuickSelection(icon: "cup.and.saucer.fill", label: "Cup", volume: 200, isSelected: true),
            QuickSelection(icon: "bubbles.and.sparkles.fill", label: "Glass", volume: 250, isSelected: true),
            QuickSelection(icon: "waterbottle.fill", label: "Bottle", volume: 500, isSelected: true),
            QuickSelection(icon: "drop.fill", label: "Small Sip", volume: 50, isSelected: true),
            QuickSelection(icon: "drop.triangle.fill", label: "Medium Sip", volume: 100, isSelected: true),
            QuickSelection(icon: "drop.circle.fill", label: "Large Sip", volume: 350, isSelected: true),
            QuickSelection(icon: "flame.fill", label: "Shot", volume: 30, isSelected: true)
        ]
        selectedQuickSelections = initialSelections
        
        // Add mock data if no records exist
        if drinkRecords.isEmpty {
            generateMockData()
        }
    }
    
    private func generateMockData() {
        let calendar = Calendar.current
        let now = Date()
        
        // Generate data for the past 7 days
        for dayOffset in 1..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // Generate between 5-15 drinks per day
            let drinkCount = Int.random(in: 5...15)
            var dailyTotal = 0
            
            for _ in 0..<drinkCount {
                // Random time during waking hours (6AM-11PM)
                let randomHour = Int.random(in: 6...23)
                let randomMinute = Int.random(in: 0...59)
                let drinkTime = calendar.date(bySettingHour: randomHour % 24, minute: randomMinute, second: 0, of: date) ?? date
                
                // Random drink type with higher probability for water
                let drinkType: DrinkType = {
                    let rand = Int.random(in: 1...10)
                    switch rand {
                    case 1...7: return .water
                    case 8: return .tea
                    case 9: return .coffee
                    default: return .soda
                    }
                }()
                
                // Random volume (common sizes with different probabilities)
                let volume: Int = {
                    let options = [
                        (volume: 50, weight: 1),   // Small sip
                        (volume: 100, weight: 2),  // Medium sip
                        (volume: 150, weight: 3),  // Half glass
                        (volume: 200, weight: 4),  // Cup
                        (volume: 250, weight: 5),  // Glass
                        (volume: 350, weight: 3),  // Large glass
                        (volume: 500, weight: 2)   // Bottle
                    ]
                    
                    let totalWeight = options.reduce(0) { $0 + $1.weight }
                    let random = Int.random(in: 1...totalWeight)
                    var runningSum = 0
                    
                    for option in options {
                        runningSum += option.weight
                        if random <= runningSum {
                            return option.volume
                        }
                    }
                    return 200
                }()
                
                let record = DrinkRecords(
                    id: UUID(),
                    timestamp: drinkTime,
                    drinkType: drinkType,
                    quantity: volume
                )
                
                drinkRecords.append(record)
                dailyTotal += volume
            }
            
            // Update consumed if it's today
            if dayOffset == 0 {
                consumed = dailyTotal
            }
        }
        
        // Sort all records by date
        drinkRecords.sort { $0.timestamp < $1.timestamp }
        
        // Fill circles based on today's consumption
        updateCirclesForToday()
        
        saveDrinkRecords()
    }
    
    private func updateCirclesForToday() {
        let calendar = Calendar.current
        let now = Date()
        guard let today = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now) else { return }
        
        let todayRecords = drinkRecords.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        let todayTotal = todayRecords.reduce(0) { $0 + $1.quantity }
        
        let circlesToFill = Int(Double(23 * 15) * (Double(todayTotal) / Double(goal)))
        
        var updatedCircles = circles
        for i in 0..<min(circlesToFill, updatedCircles.count) {
            updatedCircles[i].drinkType = .water
        }
        circles = updatedCircles
        totalDrinks = circlesToFill
    }
                                
    // MARK: - Persistence Methods
    private func saveCircles() {
        saveQueue.async {
            if let encoded = try? JSONEncoder().encode(self.circles) {
                UserDefaults.standard.set(encoded, forKey: "circles")
            }
        }
    }

    private static func loadCircles() -> [CircleData] {
        if let data = UserDefaults.standard.data(forKey: "circles"),
           let decoded = try? JSONDecoder().decode([CircleData].self, from: data) {
            return decoded
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

    private static func loadDrinkRecords() -> [DrinkRecords] {
        if let data = UserDefaults.standard.data(forKey: "drinkRecords"),
           let decoded = try? JSONDecoder().decode([DrinkRecords].self, from: data) {
            return decoded
        }
        return []
    }

    private func saveGoal() {
        saveQueue.async {
            UserDefaults.standard.set(self.goal, forKey: "goal")
        }
    }

    private static func loadGoal() -> Int {
        let savedGoal = UserDefaults.standard.integer(forKey: "goal")
        return savedGoal == 0 ? 3000 : savedGoal
    }

    private func saveConsumed() {
        saveQueue.async {
            UserDefaults.standard.set(self.consumed, forKey: "consumed")
        }
    }

    private static func loadConsumed() -> Int {
        return UserDefaults.standard.integer(forKey: "consumed")
    }

    private func saveHasShownCongratulations() {
        saveQueue.async {
            UserDefaults.standard.set(self.hasShownCongratulations, forKey: "hasShownCongratulations")
        }
    }

    private static func loadHasShownCongratulations() -> Bool {
        return UserDefaults.standard.bool(forKey: "hasShownCongratulations")
    }

    private func saveUseOunces() {
        saveQueue.async {
            UserDefaults.standard.set(self.useOunces, forKey: "useOunces")
        }
    }

    private static func loadUseOunces() -> Bool {
        return UserDefaults.standard.bool(forKey: "useOunces")
    }

    // MARK: - Helper Methods
    func mlToOz(_ ml: Double) -> Double {
        return ml * 0.033814
    }

    func ozToMl(_ oz: Double) -> Double {
        return oz / 0.033814
    }

    func fillCircles(count: Int, with drinkType: DrinkType, volume: Int) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            var updatedCircles = self.circles
            var newTotalDrinks = self.totalDrinks
            let newConsumed = self.consumed + volume

            if let firstEmptyIndex = updatedCircles.lastIndex(where: { $0.drinkType == nil }) {
                for i in 0..<min(count, updatedCircles.count - firstEmptyIndex) {
                    let index = firstEmptyIndex + i
                    updatedCircles[index].drinkType = drinkType
                    newTotalDrinks += 1
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
                self.consumed = newConsumed
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
        useOunces = false

        UserDefaults.standard.removeObject(forKey: "hasShownCongratulations")
        saveDrinkRecords()
        saveCircles()
        saveGoal()
        saveConsumed()
        saveUseOunces()

        selectedQuickSelections = [
            QuickSelection(icon: "wineglass.fill", label: "Half Glass", volume: 150, isSelected: true),
            QuickSelection(icon: "cup.and.saucer.fill", label: "Cup", volume: 200, isSelected: true),
            QuickSelection(icon: "bubbles.and.sparkles.fill", label: "Glass", volume: 250, isSelected: true),
            QuickSelection(icon: "waterbottle.fill", label: "Bottle", volume: 500, isSelected: true),
            QuickSelection(icon: "drop.fill", label: "Small Sip", volume: 50, isSelected: true),
            QuickSelection(icon: "drop.triangle.fill", label: "Medium Sip", volume: 100, isSelected: true),
            QuickSelection(icon: "drop.circle.fill", label: "Large Sip", volume: 350, isSelected: true),
            QuickSelection(icon: "flame.fill", label: "Shot", volume: 30, isSelected: true)
        ]
    }

    // MARK: - Midnight Reset
    func resetAtMidnight() {
        // Reset consumed volume to 0
        consumed = 0
        var updatedCircles = circles
        for i in updatedCircles.indices {
            updatedCircles[i].drinkType = nil
        }
        circles = updatedCircles
        hasShownCongratulations = false
        print("Resetting data at midnight...")
    }

    // MARK: - Keyboard Observers
    private func setupKeyboardObservers() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                self?.keyboardWillShow(notification: notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                self?.keyboardWillHide(notification: notification)
            }
            .store(in: &cancellables)
    }

    private func removeKeyboardObservers() {
        cancellables.forEach { $0.cancel() }
    }

    private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = keyboardFrame.height

        withAnimation(.spring()) {
            self.keyboardOffset = -keyboardHeight / 2
        }
    }

    private func keyboardWillHide(notification: Notification) {
        withAnimation(.spring()) {
            self.keyboardOffset = 0
        }
    }

    deinit {
        removeKeyboardObservers()
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
                    .background(Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5))
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

struct Home: View {
    @StateObject var viewModel: DrinkViewModel
    let totalCircles = 23.0 * 15.0
    @State private var volume: CGFloat = 0
    @State private var showCongratulations = false
    @State private var staticColors: [[Color]] = Array(repeating: Array(repeating: Color.randomMetallicGray(), count: 15), count: 24)
    @GestureState private var dragOffset = CGSize.zero
    @StateObject private var notificationManager = NotificationManager()
    @FocusState var isCustomVolumeFieldFocused: Bool
   // @StateObject private var scannerService = ProductScannerService()
    
    // Track keyboard height
    @State private var keyboardHeight: CGFloat = 0
    func isCircleColored(row: Int, column: Int, percentageFilled: Double, totalRows: Int, totalColumns: Int) -> Bool {
            let totalCircles = totalRows * totalColumns
            let circlesToFill = Int(Double(totalCircles) * (percentageFilled / 100))
            
            // Convert the 2D grid position (row, column) into a 1D index, starting from the bottom
            let reversedRow = totalRows - row - 1 // Reverse the row index
            let index = reversedRow * totalColumns + column
            
            return index < circlesToFill
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
                                .foregroundColor(.white)
                            
                            Text(viewModel.useOunces ? "oz left" : "ml left")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.trailing, 32)
                        }
                        .padding(.bottom, 42)
                        
                        // Circle grid with simplified coloring
                        ScrollView {
                            VStack(spacing: 18) {
                                ForEach(0..<23) { row in
                                    HStack(spacing: dynamicSpacing) {
                                        ForEach(0..<15, id: \.self) { column in
                                            Circle()
                                                .fill(isCircleColored(row: row, column: column, percentageFilled: viewModel.percentageFilled, totalRows: 23, totalColumns: 15)
                                                ? Color(red: 0.00, green: 0.63, blue: 1.00)
                                                : staticColors[row][column])
                                                .frame(width: 4)
                                        }
                                    }
                                }
                            }
                        }.disabled(true)
                        .frame(height: geometry.size.height * 0.6) // Limit the height of the circle grid
                        
                        // Bottom buttons
                        HStack {
                            Button(action: {
                                viewModel.chartViewEntry.toggle()
                                isCustomVolumeFieldFocused = false
                                viewModel.isScanning = false
                            }) {
                                Image(systemName: "drop.fill")
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(Circle().fill(Color.white.opacity(0.07)))
                            }
                            .padding(.trailing, 40)
                            .padding(.leading, 20)
                            
                            Button(action: {
                                isCustomVolumeFieldFocused = false
                                viewModel.isScanning = false
                               // scannerService.stopScanning()
                                withAnimation(.spring()) {
                                    viewModel.addScreen.toggle()
                                    viewModel.plusRotation += 45
                                    viewModel.contentOffset = viewModel.addScreen ? -geometry.size.height * 0.4 : 0
                                    volume = 0
                                    viewModel.customVolume = ""
                                    viewModel.selectedVolume = nil
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 24.5)
                                        .fill(viewModel.addScreen ? Color.white : Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5))
                                        .frame(width: 138, height: 52)
                                    
                                    Image(systemName: "plus")
                                        .bold()
                                        .foregroundColor(viewModel.addScreen ? .black : .white)
                                        .frame(width: 50, height: 20)
                                        .rotationEffect(.degrees(viewModel.plusRotation))
                                }
                            }.sensoryFeedback(.success, trigger: viewModel.addScreen)
                            
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
                                .padding(.trailing, 20)
                                .padding(.leading, 40)
                        }
                        .padding(.top, 48)
                    }
                    .offset(y: viewModel.contentOffset)
                    .offset(y: -keyboardHeight / 8) // Adjust the offset based on keyboard height
                    .animation(.snappy(), value: keyboardHeight)
                    
                    VStack {
                        CongratulationsToast(isVisible: $showCongratulations)
                            .padding(.top, 20)
                        Spacer()
                    }
                    
                    // Bottom Sheet
                    AddView(viewModel: viewModel, volume: $volume, isCustomVolumeFieldFocused: $isCustomVolumeFieldFocused)//, scannerService: scannerService)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.35)
                        .transition(.move(edge: .bottom))
                        .animation(.spring(), value: viewModel.addScreen)
                        .offset(y: viewModel.addScreen ? geometry.size.height * 0.3 : geometry.size.height)
                }
                .overlay {
                    VStack {
                        Color.black.frame(height: 50).ignoresSafeArea()
                        Spacer()
                    }
                }
                
                SettingView(viewModel: viewModel)
                    .transition(.move(edge: .leading))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.chartViewEntry)
                    .offset(x: viewModel.chartViewEntry ? 0 : -UIScreen.main.bounds.width)
                    .frame(width: UIScreen.main.bounds.width)
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
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if success {
                    print("All set!")
                } else if let error {
                    print(error.localizedDescription)
                }
            }
            if viewModel.goal > 0 {
                notificationManager.scheduleNotifications()
            }
        }
        .accentColor(.gray)
        .onChange(of: viewModel.goal) { newValue in
            if newValue <= 0 {
                notificationManager.removeAllNotifications()
            } else {
                notificationManager.scheduleNotifications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
}

// MARK: - Models
struct OpenFoodFactsResponse: Codable {
    let product: OpenFoodFactsProduct?
    let status: Int?
    let status_verbose: String?
}

struct OpenFoodFactsProduct: Codable {
    let product_name: String?
    let quantity: String?
    let image_url: String?
    let categories: String?
    let generic_name: String?
    let _keywords: [String]?

    private enum CodingKeys: String, CodingKey {
        case product_name, quantity, image_url, categories, generic_name
        case _keywords = "_keywords"
    }
}

// MARK: - AddView Controller
class AddViewController: NSObject, AVCaptureMetadataOutputObjectsDelegate, ObservableObject {
    var isProcessingBarcode = false
    var lastScannedBarcode: String?
    var lastScanTime: Date?
    let scanCooldown: TimeInterval = 2.0
    var onBarcodeScanned: ((String) -> Void)?
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = metadataObject.stringValue else {
            return
        }
        
        guard !isProcessingBarcode else { return }
        
        if let lastBarcode = lastScannedBarcode,
           let lastTime = lastScanTime,
           lastBarcode == barcode && Date().timeIntervalSince(lastTime) < scanCooldown {
            return
        }
        
        isProcessingBarcode = true
        lastScannedBarcode = barcode
        lastScanTime = Date()
        
        onBarcodeScanned?(barcode)
    }
}
class CameraService: ObservableObject {
    @Published var isSessionConfigured = false
    let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    init() {
        // Configure session on a background thread for better performance
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Use the default video device for better initialization speed
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back) else {
            session.commitConfiguration()
            return
        }
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            guard let videoInput = videoDeviceInput,
                  session.canAddInput(videoInput) else {
                session.commitConfiguration()
                return
            }
            session.addInput(videoInput)
            DispatchQueue.main.async { [weak self] in
                self?.isSessionConfigured = true
            }
        } catch {
            print("Error setting up video input: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    func startCamera() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopCamera() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = cameraService.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - AddView
struct AddView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DrinkViewModel
    @Binding var volume: CGFloat
    @FocusState.Binding var isCustomVolumeFieldFocused: Bool
    @StateObject private var cameraService = CameraService()
    private let gridHeight: CGFloat = 140
    @State private var onTapSelection = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingScanResult = false
    
    // Create a controller instance for handling barcode scanning
    @StateObject private var barcodeController = AddViewController()
    private let metadataOutput = AVCaptureMetadataOutput()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 24) {
                    // TextField section
                    HStack(spacing: 20) { // Increased spacing for better visual balance
                        // Custom Volume TextField
                        TextField(viewModel.useOunces ? "Custom Volume (oz)" : "Custom Volume (ml)",
                                  text: $viewModel.customVolume)
                            .keyboardType(.decimalPad)
                            .focused($isCustomVolumeFieldFocused)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced)) // Slightly larger, modern font
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.15)))
                            .onChange(of: viewModel.customVolume) { newValue in
                                if let convertedVolume = viewModel.useOunces
                                    ? viewModel.ozToMl(Double(newValue) ?? 0)
                                    : Double(newValue) {
                                    volume = CGFloat(convertedVolume)
                                }
                            }
                        
                        // Barcode Scan Button
                        Button(action: {
                            isCustomVolumeFieldFocused = false
                            viewModel.isScanning.toggle()
                            if viewModel.isScanning {
                                setupBarcodeScanning()
                                print("Starting camera...")
                                cameraService.startCamera()
                            } else {
                                print("Stopping camera...")
                                cameraService.stopCamera()
                            }
                        }, label: {
                            Image(systemName: viewModel.isScanning ? "xmark" : "barcode.viewfinder")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28) // Slightly larger, better fit
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.25)) // Different color based on scan state
                                        .frame(width: 50, height: 50)
                                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3) // Subtle shadow for depth
                                )
                                .padding(.trailing, 12) // Reduced padding to balance
                        }).sensoryFeedback(.impact, trigger: viewModel.isScanning)
                    }
                    .padding(.horizontal, 20)
                   // .padding(.vertical, 10) // Extra vertical padding for better spacing

                    // Camera/Grid section
                    if viewModel.isScanning {
                        CameraPreviewView(cameraService: cameraService)
                            .frame(height: gridHeight)
                            .overlay(ScannerShimmerView())
                            .mask(
                                RoundedRectangle(cornerRadius: 12)
                                    .padding(.horizontal, 24)
                            )
                            .overlay(
                                Group {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.5)
                                    }
                                }
                            )
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 0) {
                            ForEach(viewModel.selectedQuickSelections, id: \.id) { selection in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if viewModel.selectedVolume == CGFloat(selection.volume) {
                                            viewModel.selectedVolume = nil
                                            volume = 0
                                            viewModel.customVolume = ""
                                        } else {
                                            viewModel.selectedVolume = CGFloat(selection.volume)
                                            volume = CGFloat(selection.volume)
                                            viewModel.customVolume = String(viewModel.useOunces ? Int(viewModel.mlToOz(Double(selection.volume))) : selection.volume)
                                        }
                                        isCustomVolumeFieldFocused = false
                                        onTapSelection.toggle()
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: selection.icon)
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .frame(width: 45, height: 45)
                                            .background(
                                                Circle()
                                                    .fill(viewModel.selectedVolume == CGFloat(selection.volume) ? Color.blue.opacity(0.5) : Color.gray.opacity(0.15))
                                            )
                                        
                                        Text("\(viewModel.useOunces ? Int(viewModel.mlToOz(Double(selection.volume))) : selection.volume) \(viewModel.useOunces ? "oz" : "ml")")
                                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    }
                                }.sensoryFeedback(.selection, trigger: onTapSelection)
                                .padding(.vertical, 2)
                            }
                        }
                        .frame(height: gridHeight)
                        .padding(.horizontal, 8)
                    }
                                            
                    // Add button
                    Button(action: {
                        isCustomVolumeFieldFocused = false
                        cameraService.stopCamera()
                        viewModel.addScreen = false
                        viewModel.plusRotation += 45
                        viewModel.contentOffset = viewModel.addScreen ? -geometry.size.height * 0.5 : 0
                        viewModel.fillCircles(
                            count: Int(volume / 1000 * CGFloat(23 * 15)),
                            with: .water,
                            volume: Int(volume)
                        )
                        volume = 0
                        viewModel.customVolume = ""
                        viewModel.selectedVolume = nil
                        dismiss()
                    }) {
                        Text(volume == 0 ? "Input Volume" : viewModel.useOunces ? String(format: "Add %.0f oz", viewModel.mlToOz(Double(volume)))
                            : "Add \(Int(volume)) ml")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                // Add ShimmerView here
                                ZStack {
                                    if volume == 0 {
                                        ShimmerView()// Apply shimmer effect when volume is 0
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5))
                                    }
                                }
                            )
                    }
                    .disabled(volume == 0)
                    .padding(.horizontal, 20)
                    
                }
                .padding(.vertical, 24)
                .background(Color.black)
                .offset(y: viewModel.keyboardOffset * 0.6)
            }
        }
        .onAppear {
            setupBarcodeScanning()
            barcodeController.onBarcodeScanned = { barcode in
                lookupProductInformation(barcode: barcode)
            }
        }
        .onDisappear {
            cameraService.stopCamera()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onTapGesture {
            isCustomVolumeFieldFocused = false
        }
    }
    
    private func setupBarcodeScanning() {
        guard cameraService.isSessionConfigured else { return }
        
        DispatchQueue.main.async {
            cameraService.session.beginConfiguration()
            metadataOutput.setMetadataObjectsDelegate(barcodeController, queue: .main)
            if cameraService.session.canAddOutput(metadataOutput) {
                cameraService.session.addOutput(metadataOutput)
                metadataOutput.metadataObjectTypes = [.ean8, .ean13, .qr, .code128, .code39, .code93, .upce]
            }
            cameraService.session.commitConfiguration()
        }
    }
    
    private func lookupProductInformation(barcode: String) {
        isLoading = true
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json"
        guard let url = URL(string: urlString) else {
            handleError("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    handleError(error.localizedDescription)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    handleError("No product data received")
                }
                return
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
                guard let product = apiResponse.product else {
                    DispatchQueue.main.async {
                        handleError("No product found")
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    if let volumeString = product.quantity,
                       let extractedVolume = extractVolume(from: volumeString) {
                        if viewModel.useOunces {
                            let volumeInOz = viewModel.mlToOz(Double(extractedVolume))
                            viewModel.customVolume = String(Int(volumeInOz))
                            volume = CGFloat(extractedVolume)
                        } else {
                            viewModel.customVolume = String(extractedVolume)
                            volume = CGFloat(extractedVolume)
                        }
                        viewModel.isScanning = false
                        cameraService.stopCamera()
                    } else {
                        handleError("Could not determine volume from product")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    handleError("Failed to decode product information")
                }
            }
            
            DispatchQueue.main.async {
                isLoading = false
                barcodeController.isProcessingBarcode = false
            }
        }.resume()
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        isLoading = false
        barcodeController.isProcessingBarcode = false
        viewModel.isScanning = false
        cameraService.stopCamera()
    }
    private func extractVolume(from volumeString: String) -> Int? {
        let cleanInput = volumeString.lowercased().trimmingCharacters(in: .whitespaces)
        let regex = try? NSRegularExpression(pattern: "([0-9.]+)\\s*(ml|l|cl|oz|fl oz|floz)")
        if let match = regex?.firstMatch(in: cleanInput, range: NSRange(cleanInput.startIndex..., in: cleanInput)) {
            if let numberRange = Range(match.range(at: 1), in: cleanInput),
               let unitRange = Range(match.range(at: 2), in: cleanInput) {
                let numberStr = String(cleanInput[numberRange])
                let unit = String(cleanInput[unitRange])
                if let number = Double(numberStr) {
                    switch unit {
                    case "l": return Int(number * 1000)
                    case "cl": return Int(number * 10)
                    case "oz", "fl oz", "floz": return Int(number * 29.5735)
                    case "ml": return Int(number)
                    default: return nil
                    }
                }
            }
        }
        if let number = Double(cleanInput) {
            return Int(number)
        }
        return nil
    }
}
struct ScannerShimmerView: View {
    @State private var yOffset: CGFloat = -200
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Static grid pattern
                GridPattern(density: 20)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                
                // Animated scanning section with dense grid
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 50)
                    .background(
                        GridPattern(density: 120) // Much denser grid
                            .stroke(Color.blue.opacity(0.4), lineWidth: 0.25)
                    )
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0),
                                Color.blue.opacity(0.4),
                                Color.blue.opacity(0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                   // .clipped()
                    .offset(y: yOffset)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 2.0)
                            .repeatForever(autoreverses: false)
                        ) {
                            yOffset = geometry.size.height
                        }
                    }
            }
            .mask(
                RoundedRectangle(cornerRadius: 12)
                    .padding(.horizontal, 24)
            )
        }
    }
}

struct GridPattern: Shape {
    var density: CGFloat // Grid density parameter
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let gridSize = density // Grid cell size
        
        // Vertical lines
        stride(from: 0, through: rect.width, by: gridSize).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal lines
        stride(from: 0, through: rect.height, by: gridSize).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}
struct ShimmerView: View {
    @State private var startPoint: UnitPoint = .init(x: -1.8, y: -1.2)
    @State private var endPoint: UnitPoint = .init(x: 0, y: -0.2)
    
    private var gradientColors = [Color.gray.opacity(0.2),
                                  Color.white.opacity(0.2), Color.gray.opacity (0.2)]
    var body: some View {
        LinearGradient(colors: gradientColors, startPoint: startPoint, endPoint: endPoint)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear{
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses:false)) {
                startPoint = .init(x: 1, y: 1)
                endPoint = .init(x: 2.2, y: 2.2)
            }
        }
    }
}
struct QuickSelection: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let volume: Int
    var isSelected: Bool
}

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DrinkViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("wavesEnabled") private var waveMotion = true
    @State private var temporaryGoal: String = ""
    @State private var showInvalidGoalAlert = false
    @State private var showConfirmationAlert = false
    @State private var resetbuttonTapped = false
    @FocusState private var isGoalFieldFocused: Bool
    @State private var showCongratulations = false
    @State private var showAlert = false
    @State private var showError = false
    @State private var alertMessage = ""
    @StateObject private var notificationManager = NotificationManager()
    @State private var quickSelections: [QuickSelection] = [
        QuickSelection(icon: "wineglass.fill", label: "Half Glass", volume: 150, isSelected: true),
        QuickSelection(icon: "cup.and.saucer.fill", label: "Cup", volume: 200, isSelected: true),
        QuickSelection(icon: "bubbles.and.sparkles.fill", label: "Glass", volume: 250, isSelected: true),
        QuickSelection(icon: "waterbottle.fill", label: "Bottle", volume: 500, isSelected: true),
        QuickSelection(icon: "drop.fill", label: "Small Sip", volume: 50, isSelected: true),
        QuickSelection(icon: "drop.triangle.fill", label: "Medium Sip", volume: 100, isSelected: true),
        QuickSelection(icon: "drop.circle.fill", label: "Large Sip", volume: 350, isSelected: true),
        QuickSelection(icon: "flame.fill", label: "Shot", volume: 30, isSelected: true),
        QuickSelection(icon: "mug.fill", label: "Mug", volume: 400, isSelected: false),
        QuickSelection(icon: "thermometer.snowflake", label: "Cold Drink", volume: 200, isSelected: false),
        QuickSelection(icon: "thermometer.sun.fill", label: "Hot Drink", volume: 250, isSelected: false),
        QuickSelection(icon: "staroflife.fill", label: "Energy Drink", volume: 300, isSelected: false),
        QuickSelection(icon: "leaf.fill", label: "Herbal Tea", volume: 200, isSelected: false),
        QuickSelection(icon: "cloud.fill", label: "Smoothie", volume: 350, isSelected: false),
        QuickSelection(icon: "drop.circle.fill", label: "Juice", volume: 250, isSelected: false),
        QuickSelection(icon: "fork.knife", label: "Soup", volume: 300, isSelected: false),
        QuickSelection(icon: "snowflake", label: "Ice Water", volume: 150, isSelected: false),
        QuickSelection(icon: "sun.max.fill", label: "Lemonade", volume: 200, isSelected: false),
        QuickSelection(icon: "moon.fill", label: "Nightcap", volume: 50, isSelected: false),
        QuickSelection(icon: "heart.fill", label: "Health Drink", volume: 100, isSelected: false)
    ]
    
    // State variables to track section expansion
    @State private var isDailyGoalExpanded = false
    @State private var isPreferencesExpanded = false
    @State private var isQuickSelectionsExpanded = false
    @State private var isAboutExpanded = false

    private func handleSelectionChange(for selection: QuickSelection) {
        let currentlySelected = quickSelections.filter { $0.isSelected }.count
        if !selection.isSelected && currentlySelected >= 8 {
            alertMessage = "You can only select up to 8 items. Please deselect an item before selecting a new one."
            showAlert = true
            showError.toggle()
            return
        }
        if let index = quickSelections.firstIndex(where: { $0.id == selection.id }) {
            quickSelections[index].isSelected.toggle()
        }
    }

    var body: some View {
        ZStack{
            VStack{
                // Header
                HStack(alignment: .lastTextBaseline) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        viewModel.chartViewEntry = false
                        isGoalFieldFocused = false
                        dismiss()
                        isDailyGoalExpanded = false
                        isPreferencesExpanded = false
                        isAboutExpanded =  false
                        isQuickSelectionsExpanded = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            
            
            
            VStack(alignment: .leading,spacing: 24) {
                
                Spacer().frame(height: 30)
                Section(header: Text("General")
                    .foregroundColor(.gray)
                    .textCase(nil)
                    .font(.system(size: 16))
                    .padding(.leading)) {
                        // Daily Goal Section
                        SectionHeader(title: "Daily Goal", icon: "target", isExpanded: $isDailyGoalExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isDailyGoalExpanded.toggle()
                                    isPreferencesExpanded = false
                                    isQuickSelectionsExpanded = false
                                    isAboutExpanded = false
                                }
                            }
                        if isDailyGoalExpanded {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        TextField(viewModel.useOunces ? "Enter goal (oz)" : "Enter goal (ml)", text: $temporaryGoal)
                                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                                            .keyboardType(.decimalPad)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.white.opacity(0.15))
                                            .cornerRadius(12)
                                            .focused($isGoalFieldFocused)
                                        Button(action: {
                                            if let newGoal = Int(temporaryGoal), newGoal > 0 {
                                                viewModel.goal = viewModel.useOunces ? Int(viewModel.ozToMl(Double(newGoal))) : newGoal
                                                temporaryGoal = ""
                                                isGoalFieldFocused = false
                                                dismiss()
                                                withAnimation(.easeInOut(duration: 1.5)) {
                                                    viewModel.chartViewEntry = false
                                                }
                                            } else {
                                                showInvalidGoalAlert = true
                                                showCongratulations.toggle()
                                            }
                                        }) {
                                            Text("Set")
                                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 24)
                                                .padding(.vertical, 12)
                                                .background(Color.blue.opacity(0.6))
                                                .cornerRadius(12)
                                        }.sensoryFeedback(.error, trigger: showCongratulations)
                                    }
                                    Text("Current goal: \(viewModel.useOunces ? Int(viewModel.mlToOz(Double(viewModel.goal))) : viewModel.goal) \(viewModel.useOunces ? "oz" : "ml")")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.08).onTapGesture { isGoalFieldFocused = false })
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Preferences Section
                        SectionHeader(title: "Preferences", icon: "slider.horizontal.3", isExpanded: $isPreferencesExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isDailyGoalExpanded = false
                                    isPreferencesExpanded.toggle()
                                    isQuickSelectionsExpanded = false
                                    isAboutExpanded = false
                                }
                            }
                        if isPreferencesExpanded {
                            VStack(alignment: .leading, spacing: 16) {
                                SettingsToggle(isOn: $notificationsEnabled,
                                               icon: "bell.fill",
                                               title: "Notifications",
                                               onChange: { newValue in
                                    notificationManager.toggleNotifications(newValue)
                                }).onTapGesture { isGoalFieldFocused = false }
                                SettingsToggle(isOn: $viewModel.useOunces,
                                               icon: "scalemass.fill",
                                               title: "Use Ounces").onTapGesture { isGoalFieldFocused = false }
                            }
                            .padding()
                            .background(Color.white.opacity(0.08).onTapGesture { isGoalFieldFocused = false })
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Quick Selections Section
                        SectionHeader(title: "Quick Selections", icon: "bolt.fill", isExpanded: $isQuickSelectionsExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isDailyGoalExpanded = false
                                    isPreferencesExpanded = false
                                    isQuickSelectionsExpanded.toggle()
                                    isAboutExpanded = false
                                }
                            }
                        if isQuickSelectionsExpanded {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Select from the list below")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    Spacer()
                                    SaveButton {
                                        let selectedCount = quickSelections.filter { $0.isSelected }.count
                                        if selectedCount != 8 {
                                            alertMessage = "Please select exactly 8 items"
                                            showError.toggle()
                                            showAlert = true
                                        } else {
                                            viewModel.selectedQuickSelections = quickSelections.filter { $0.isSelected }
                                            viewModel.chartViewEntry = false
                                            isGoalFieldFocused = false
                                            dismiss()
                                        }
                                    }
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHGrid(rows: Array(repeating: GridItem(.flexible()), count: 2),
                                              alignment: .center,
                                              spacing: 10) {
                                        ForEach($quickSelections) { $selection in
                                            QuickSelectionButton(selection: selection) {
                                                handleSelectionChange(for: selection)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 150)
                            }
                            .padding()
                            .background(Color.white.opacity(0.08).onTapGesture {
                                isGoalFieldFocused = false
                            })
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        SectionHeader(title: "About", icon: "info.circle", isExpanded: $isAboutExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isDailyGoalExpanded = false
                                    isPreferencesExpanded = false
                                    isAboutExpanded.toggle()
                                    isQuickSelectionsExpanded = false
                                }
                            }
                        
                        if isAboutExpanded {
                            ScrollView{
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Why Hydration is Important")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    
                                    Text("""
                                        Staying hydrated is crucial for maintaining overall health. Water helps regulate body temperature, \
                                        supports digestion, flushes out toxins, and keeps your skin healthy. Proper hydration also improves \
                                        cognitive function, boosts energy levels, and prevents fatigue.
                                        """)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                    
                                    Text("How to Use This App")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    
                                    Text("""
                                        This app helps you track your daily water intake and reminds you to stay hydrated. You can set a daily hydration goal, log your drinks using quick selections or even scan your drinks barcodes for custom volumes, and view insights into your drinking habits. The app will reset your data at midnight every day to help you start fresh.
                                        """)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                }
                                
                                
                            }
                            .scrollIndicators(.hidden)
                            .padding()
                            .frame(maxHeight: 425)
                            .background(Color.white.opacity(0.08).onTapGesture { isGoalFieldFocused = false })
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                    }
                // Other Section
                Section(header: Text("Other")
                    .foregroundColor(.gray)
                    .textCase(nil)
                    .font(.system(size: 16))
                    .padding(.leading)) {
                        
                        // Write a Review
                        HStack {
                            Text("Write A Review")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            
                            Spacer()
                            Button(action: {
                                // Handle review action
                            }) {
                                Image(systemName: "star")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                            }
                        } .padding(.horizontal)
                        // Share App
                        
                        HStack {
                            Text("Share App")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                // Handle share action
                            }) {
                                
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                            }
                        } .padding(.horizontal)
                    }
                Spacer()
                
            }.padding(.bottom,40)
            
            
            VStack{
                Spacer()
                HoldDownButton(text: "Delete All Recorded Data",duration: 2, background: Color.gray.opacity(0.5), loadingTint: .red){
                    showConfirmationAlert = true
                    resetbuttonTapped.toggle()
                    
                }
                .sensoryFeedback(.warning, trigger: resetbuttonTapped)
                
            }
        }
       
        .background(Color.black.ignoresSafeArea()
            .onTapGesture {
                isGoalFieldFocused = false
            })
        .ignoresSafeArea(.keyboard)
        .alert("Invalid Goal", isPresented: $showInvalidGoalAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a valid number greater than 0")
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }.sensoryFeedback(.error, trigger: showError)
        .alert("Are you sure?", isPresented: $showConfirmationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.chartViewEntry = false
                viewModel.reset()
            }
        }
    }
}

struct HoldDownButton: View {
    var text: String
    var paddingHorizontal: CGFloat = 25
    var paddingVertical: CGFloat = 18
    var duration: CGFloat = 1
    var scale: CGFloat = 0.95
    var background: Color
    var loadingTint: Color
    var shape: AnyShape = .init(.rect(cornerRadius: 12))
    var action: () -> ()
    
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .common).autoconnect()
    @State private var timeCount: CGFloat = 0
    @State private var progress: CGFloat = 0
    @State private var isHolding: Bool = false
    @State private var isCompleted: Bool = false
    
    // Haptic feedback generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        HStack {
            Image(systemName: "trash.fill")
                .foregroundColor(.white)
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.vertical, paddingVertical)
        .padding(.horizontal, paddingHorizontal)
        .frame(maxWidth: .infinity)
        .background {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(background.gradient)
                
                GeometryReader {
                    let size = $0.size
                    
                    if !isCompleted {
                        Rectangle()
                            .fill(loadingTint)
                            .frame(width: size.width * progress)
                            .transition(.opacity)
                    }
                }
            }
        }
        .clipShape(shape)
        .contentShape(shape)
        .scaleEffect(isHolding ? scale : 1)
        .animation(.snappy, value: isHolding)
        .onLongPressGesture(minimumDuration: duration, perform: {
            isHolding = false
            cancelTimer()
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompleted = true
            }
            action()
        }, onPressingChanged: { status in
            if status {
                isCompleted = false
                reset()
                isHolding = true
                addTimer()
            }
        })
        .simultaneousGesture(dragGesture)
        .onReceive(timer) { _ in
            if isHolding && progress != 1 {
                timeCount += 0.01
                progress = max(min(timeCount / duration, 1), 0)
                triggerHapticFeedback()
            }
        }
        .onAppear(perform: cancelTimer)
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { _ in
                guard !isCompleted else { return }
                cancelTimer()
                withAnimation(.snappy) {
                    reset()
                }
            }
    }
    
    func addTimer() {
        timer = Timer.publish(every: 0.01, on: .current, in: .common).autoconnect()
    }
    
    func cancelTimer() {
        timer.upstream.connect().cancel()
    }
    
    func reset() {
        isHolding = false
        progress = 0
        timeCount = 0
    }
    
    func triggerHapticFeedback() {
        let intensity = CGFloat(progress)
        feedbackGenerator.impactOccurred(intensity: intensity)
    }
}
// MARK: - Supporting Views
struct SectionHeader: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.title3)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle()) // Make the entire row tappable
        .padding(.horizontal)
    }
}

struct SettingsToggle: View {
    @Binding var isOn: Bool
    let icon: String
    let title: String
    var onChange: ((Bool) -> Void)? = nil
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .font(.title3)
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.blue.opacity(0.6)))
        .onChange(of: isOn) { newValue in
            onChange?(newValue)
        }
    }
}

struct SaveButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Save")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.6))
                .cornerRadius(8)
        }
    }
}

struct QuickSelectionButton: View {
    let selection: QuickSelection
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: selection.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(selection.isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.15))
                    )
                Text(selection.label)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .sensoryFeedback(.selection, trigger: selection.isSelected)
    }
}



struct ResetButton: View {
    @Binding var showConfirmationAlert: Bool
    @Binding var resetButtonTapped: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            showConfirmationAlert = true
            resetButtonTapped.toggle()
        }) {
            Text("Reset All Data")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
        }
        .sensoryFeedback(.warning, trigger: resetButtonTapped)
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

struct CustomSegmentedControl: View {
    @Binding var preselectedIndex: Int
    var options: [String]
    // this color is coming theme library
    let color = Color.gray

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id:\.self) { index in
                ZStack {
                    Rectangle()
                        .fill(color.opacity(0.2))

                    Rectangle()
                        .fill(color)
                        .cornerRadius(20)
                        .padding(2)
                        .opacity(preselectedIndex == index ? 0.2 : 0.01)
                        .onTapGesture {
                                withAnimation(.interactiveSpring()) {
                                    preselectedIndex = index
                                }
                            }
                }
                .overlay(
                    Text(options[index])
                        .font(.system(size: 16,weight: .regular,design: .monospaced))
                )
            }
        }
        .frame(height: 40)
        .cornerRadius(20)
    }
}

struct ChartView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DrinkViewModel
    var percentageFilled: Double
    @State private var selectedTimeframeIndex: Int = 0
    @State private var isShowingAllData: Bool = false
    @State private var responseText: String = ""
    @State private var fullResponse: String = ""
    @State private var typingIndex: Int = 0
    
    let responses: [String] = [
        "Drinking water helps maintain hydration, which is essential for overall health. It also supports digestion and improves skin health.",
        "Water supports digestion by helping break down food and absorb nutrients. Staying hydrated also boosts energy levels and prevents fatigue.",
        "Staying hydrated improves skin health, making it look more radiant and youthful. It also helps regulate body temperature during exercise.",
        "Water boosts energy levels by preventing dehydration, which can cause fatigue. It also aids in weight loss by increasing satiety.",
        "Drinking water aids in weight loss by increasing satiety and reducing calorie intake. It also helps flush out toxins from the body.",
        "Water helps flush out toxins from the body through urine and sweat. Proper hydration also improves cognitive function and concentration.",
        "Proper hydration improves cognitive function and concentration. It also lubricates joints, reducing the risk of joint pain and arthritis.",
        "Water lubricates joints, reducing the risk of joint pain and arthritis. It also regulates body temperature, especially during exercise.",
        "Drinking water regulates body temperature, especially during exercise. It also prevents headaches and migraines caused by dehydration.",
        "Water prevents headaches and migraines, which are often caused by dehydration. Staying hydrated also improves physical performance.",
        "Staying hydrated improves physical performance during workouts. It also supports kidney function by helping filter waste from the blood.",
        "Water supports kidney function by helping filter waste from the blood. Drinking water can also improve mood and reduce stress levels.",
        "Drinking water can improve mood and reduce stress levels. It also helps maintain blood pressure by keeping blood volume stable.",
        "Water helps maintain blood pressure by keeping blood volume stable. Hydration is crucial for maintaining electrolyte balance in the body.",
        "Hydration is crucial for maintaining electrolyte balance in the body. Water also reduces the risk of urinary tract infections.",
        "Water reduces the risk of urinary tract infections by flushing out bacteria. It can also prevent constipation by keeping the digestive system active.",
        "Drinking water can prevent constipation by keeping the digestive system active. It also helps transport nutrients and oxygen to cells.",
        "Water helps transport nutrients and oxygen to cells throughout the body. Staying hydrated can also reduce the risk of kidney stones.",
        "Staying hydrated can reduce the risk of kidney stones. Water also improves circulation, ensuring organs receive adequate oxygen.",
        "Water improves circulation, ensuring organs receive adequate oxygen. Drinking water can also help reduce acne and improve skin clarity.",
        "Drinking water can help reduce acne and improve skin clarity. It also supports the immune system by keeping mucous membranes moist.",
        "Water supports the immune system by keeping mucous membranes moist. Hydration can also reduce the risk of muscle cramps and spasms.",
        "Hydration can reduce the risk of muscle cramps and spasms. Water also helps maintain a healthy metabolism, aiding in weight management.",
        "Water helps maintain a healthy metabolism, aiding in weight management. It also improves skin elasticity and reduces signs of aging."
    ]
    
    enum Timeframe: String, CaseIterable {
        case hour = "Hourly"
        case daily = "Daily"
        case week = "Weekly"
    }

    private var selectedTimeframe: Timeframe {
        Timeframe.allCases[selectedTimeframeIndex]
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
    
    // Simplified askAI function
    private func askAI() {
        // Randomly select a response
        fullResponse = responses.randomElement() ?? "No response available."
        
        // Start the typing effect
        startTypingEffect()
    }
    
    private func startTypingEffect() {
        typingIndex = 0
        viewModel.displayedText = ""
        
        // Create a timer to simulate typing
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if typingIndex < fullResponse.count {
                viewModel.displayedText += String(fullResponse[fullResponse.index(fullResponse.startIndex, offsetBy: typingIndex)])
                typingIndex += 1
            } else {
                timer.invalidate() // Stop the timer when typing is complete
            }
        }
    }
    private var yAxisConfig: (max: Double, stride: Double) {
        if filteredRecords.isEmpty {
            if viewModel.useOunces {
                // Convert the default ml values to oz for empty state
                return (viewModel.mlToOz(100), viewModel.mlToOz(25))
            } else {
                return (100, 25) // Default ml values
            }
        }
        
        let maxQuantity = filteredRecords.map { $0.quantity }.max() ?? 0
        var maxValue = Double(maxQuantity)
        
        if viewModel.useOunces {
            // Convert maxValue to ounces
            maxValue = viewModel.mlToOz(maxValue)
        }
        
        let paddedMax = ceil(maxValue * 1.1)
        let roundedMax = ceil(paddedMax / 4) * 4
        let stride = roundedMax / 4
        
        return (roundedMax, stride)
    }

    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.smooth(duration: 2.3)) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                selectedTimeframeIndex = 0 // Reset to hourly view
                            }
                            dismiss()
                        }
                    }, label: {
                        Image(systemName: "arrowtriangle.left.circle.fill")
                            .font(.title2)
                    })
                    .padding(.leading)
                    .padding(.bottom, 20)
                    .foregroundColor(Color(.systemGray))
                    
                    Spacer()
                }
                HStack {
                    Text("Drink Insights Trends")
                        .font(.system(size: 22,weight: .semibold,design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.leading)
                    Spacer()
                }
                
                Chart(filteredRecords) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", viewModel.useOunces ? viewModel.mlToOz(Double(record.quantity)) : Double(record.quantity))
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Color.gray)
                    
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", viewModel.useOunces ? viewModel.mlToOz(Double(record.quantity)) : Double(record.quantity))
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
                        y: .value("Quantity", viewModel.useOunces ? viewModel.mlToOz(Double(record.quantity)) : Double(record.quantity))
                    )
                    .symbol(.circle)
                    .foregroundStyle(Color.white)
                }
                .chartXAxis {
                    switch selectedTimeframe {
                    case .hour:
                        AxisMarks(values: .stride(by: .minute, count: 5)) { value in
                            AxisValueLabel(format: .dateTime.hour().minute(), anchor: .top)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color.gray)
                        }
                    case .daily:
                        AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                            AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                                .font(.system(size: 14, weight: .thin, design: .monospaced))
                                .foregroundStyle(Color.gray)
                        }
                    case .week:
                        AxisMarks(values: .stride(by: .day, count: 1)) { value in
                            AxisValueLabel {
                                Text(value.as(Date.self)?.formatted(.dateTime.weekday(.abbreviated)) ?? "")
                            }
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.gray)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: yAxisConfig.stride)) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(viewModel.useOunces
                                     ? String(format: "%.1f oz", doubleValue)
                                     : "\(Int(doubleValue)) ml")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color.gray)
                            }
                        }
                        
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
                .padding(.leading)
                .chartXScale(domain: xAxisDomain)
                .chartScrollPosition(x: .constant(Date()))
                .chartScrollableAxes(.horizontal)
                .chartYScale(domain: 0...yAxisConfig.max)
                .frame(width: UIScreen.main.bounds.width, height: 350)
                .padding(.bottom, 25)
                
                CustomSegmentedControl(
                    preselectedIndex: $selectedTimeframeIndex,
                    options: Timeframe.allCases.map { $0.rawValue }
                )
                .foregroundColor(.white)
                .padding(.horizontal,40)
                .padding(.bottom, 30)
                
                Button(action: {
                    isShowingAllData = true
                }, label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24.5)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height:50)
                        
                        HStack{
                            Image(systemName: "widget.large")
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.2)))
                            Text("Show All Data")
                                .font(.system(size: 16,weight: .regular,design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrowtriangle.right.circle.fill")
                                .font(.title2)
                        }.padding(.horizontal)
                    }
                }).sensoryFeedback(.selection, trigger: isShowingAllData)
                .padding(.horizontal)
                .fullScreenCover(isPresented: $isShowingAllData, content: {
                        DrinkLogSheet(viewModel: viewModel)
                    })
                
                Text(viewModel.displayedText)
                    .font(.system(size: 16,weight: .semibold,design: .monospaced))
                    .padding(.top,30)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .ignoresSafeArea()
                    .lineLimit(nil)
                Spacer()
            }
        }
        .onAppear {
            askAI() // Call the simplified askAI function
            viewModel.isScanning = false
        }
    }
}
struct DrinkLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DrinkViewModel
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleRecords = Set<UUID>() // Track individual records instead of dates
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yy, h:mm a"
        return formatter.string(from: date)
    }
    
    private var groupedRecords: [(String, [DrinkRecords])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.drinkRecords) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        return grouped.map { (date, records) in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            return (dateFormatter.string(from: date), records.sorted { $0.timestamp > $1.timestamp })
        }.sorted { $0.0 > $1.0 }
    }
    
    private func findQuickSelection(for volume: Int) -> QuickSelection? {
        return viewModel.selectedQuickSelections.first { $0.volume == volume }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Drink Log")
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                    }
                    .padding()
                    
                    if viewModel.drinkRecords.isEmpty {
                        VStack(alignment: .center, spacing: 10) {
                            Spacer()
                            Image("Sphera")
                                .resizable()
                                .opacity(0.5)
                                .frame(width: 60, height: 60)
                                .transition(.scale.combined(with: .opacity))
                            Text("No drinks logged yet")
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                ForEach(groupedRecords, id: \.0) { date, records in
                                    VStack(alignment: .leading, spacing: 16) {
                                        ForEach(records) { record in
                                            HStack {
                                                if let quickSelection = findQuickSelection(for: record.quantity) {
                                                    Image(systemName: quickSelection.icon)
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white)
                                                        .frame(width: 40, height: 40)
                                                } else {
                                                    Image(systemName: record.drinkType.icon)
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white)
                                                        .frame(width: 40, height: 40)
                                                }
                                                
                                                HStack(alignment: .lastTextBaseline) {
                                                    Text(viewModel.useOunces ? String(format: "%.1f", viewModel.mlToOz(Double(record.quantity))) : "\(record.quantity)")
                                                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(.white)

                                                    Text(viewModel.useOunces ? "oz" : "ml")
                                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                                        .foregroundColor(.white)

                                                    Spacer()
                                                    Text(formatDate(record.timestamp))
                                                        .font(.system(size: 12, design: .monospaced))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                            .padding(.horizontal)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(12)
                                            .padding(.horizontal)
                                            .scaleEffect(visibleRecords.contains(record.id) ? 1.0 : 0.8)
                                            .opacity(visibleRecords.contains(record.id) ? 1.0 : 0.5)
                                            .onScrollVisibilityChange { isVisible in
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if isVisible {
                                                        visibleRecords.insert(record.id)
                                                    } else {
                                                        visibleRecords.remove(record.id)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .animation(.bouncy, value: visibleRecords)
                        .scrollTargetLayout()
                        .onScrollTargetVisibilityChange(idType: UUID.self, threshold: 0.3) { records in
                            visibleRecords = Set(records)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
    }
}
#Preview{
    SettingView(viewModel: DrinkViewModel())
}
