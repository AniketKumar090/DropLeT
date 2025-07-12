import Combine
import Foundation
import SwiftUI
import UserNotifications
import UserNotificationsUI

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

