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
    
    // MARK: - Midnight Reset Properties
    private var midnightResetManager: MidnightResetManager?
    private var lastResetDate: Date? {
        didSet {
            saveLastResetDate()
        }
    }
    
    // MARK: - Initialization
    init() {
        // Load data first
        self.circles = Self.loadCircles()
        self.drinkRecords = Self.loadDrinkRecords()
        self.goal = Self.loadGoal()
        self.consumed = Self.loadConsumed()
        self.hasShownCongratulations = Self.loadHasShownCongratulations()
        self.useOunces = Self.loadUseOunces()
        self.lastResetDate = Self.loadLastResetDate()
        
        // Calculate total drinks from circles
        self.totalDrinks = self.circles.filter { $0.drinkType != nil }.count
       
        setupKeyboardObservers()
        
        // Remove mock data first
        removeMockDataIfNeeded()
        
        // Then check for midnight reset
        checkForMidnightReset()
        
        // Finally setup the midnight reset manager
        setupMidnightReset()
                
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
    }
    
    // MARK: - Mock Data Removal
    private func removeMockDataIfNeeded() {
        // Check if we have existing data that looks like mock data
        let hasMockData = UserDefaults.standard.bool(forKey: "hasMockData")
        
        // If we have a lot of records from past days, it's likely mock data
        let calendar = Calendar.current
        let now = Date()
        let pastDayRecords = drinkRecords.filter { !calendar.isDate($0.timestamp, inSameDayAs: now) }
        
        // Remove mock data if flag is set OR if we have suspiciously many past records
        if hasMockData || pastDayRecords.count > 20 {
            print("Removing mock data...")
            
            // Clear all drink records
            drinkRecords = []
            
            // Reset circles completely
            circles = Array(0..<(23 * 15)).map { CircleData(id: $0, drinkType: nil) }
            totalDrinks = 0
            
            // Reset consumption for today
            consumed = 0
            
            // Reset congratulations flag
            hasShownCongratulations = false
            
            // Mark mock data as removed
            UserDefaults.standard.set(false, forKey: "hasMockData")
            
            // Force save all changes
            saveCircles()
            saveDrinkRecords()
            saveConsumed()
            saveHasShownCongratulations()
            
            print("Mock data removed successfully")
        }
    }
    
    // MARK: - Midnight Reset Management
    private func setupMidnightReset() {
        midnightResetManager = MidnightResetManager { [weak self] in
            self?.performMidnightReset()
        }
    }
    
    private func checkForMidnightReset() {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if we need to reset based on the last reset date
        if let lastReset = lastResetDate {
            if !calendar.isDate(lastReset, inSameDayAs: now) {
                // It's a new day, perform reset
                performMidnightReset()
            }
        } else {
            // First time running, set today as the reset date
            lastResetDate = now
        }
    }
    
    private func performMidnightReset() {
        print("Performing midnight reset...")
        
        
        let now = Date()
        
        // Only reset today's data, preserve historical records
        // Reset consumed volume to 0
        consumed = 0
        
        // Reset circles completely
        circles = Array(0..<(23 * 15)).map { CircleData(id: $0, drinkType: nil) }
        totalDrinks = 0
        
        // Reset congratulations flag
        hasShownCongratulations = false
        
        // Update last reset date
        lastResetDate = now
        
        // Force save all changes immediately
        saveCircles()
        saveConsumed()
        saveHasShownCongratulations()
        saveLastResetDate()
        
        print("Midnight reset completed - consumed: \(consumed), totalDrinks: \(totalDrinks)")
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
    
    private func saveLastResetDate() {
        saveQueue.async {
            if let date = self.lastResetDate {
                UserDefaults.standard.set(date, forKey: "lastResetDate")
            }
        }
    }
    
    private static func loadLastResetDate() -> Date? {
        let timestamp = UserDefaults.standard.object(forKey: "lastResetDate") as? Date
        return timestamp
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
        lastResetDate = nil

        UserDefaults.standard.removeObject(forKey: "hasShownCongratulations")
        UserDefaults.standard.removeObject(forKey: "lastResetDate")
        UserDefaults.standard.removeObject(forKey: "hasMockData")
        
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

    // MARK: - Public Methods for Testing/Debugging
    func forceReset() {
        print("Force resetting all data...")
        
        // Clear everything
        drinkRecords = []
        circles = Array(0..<(23 * 15)).map { CircleData(id: $0, drinkType: nil) }
        totalDrinks = 0
        consumed = 0
        hasShownCongratulations = false
        lastResetDate = Date()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "hasMockData")
        UserDefaults.standard.removeObject(forKey: "hasShownCongratulations")
        
        // Force save everything
        saveCircles()
        saveDrinkRecords()
        saveConsumed()
        saveHasShownCongratulations()
        saveLastResetDate()
        
        print("Force reset completed")
    }
    
    // MARK: - Deprecated Methods (kept for backward compatibility)
    @available(*, deprecated, message: "Use performMidnightReset() instead")
    func resetAtMidnight() {
        performMidnightReset()
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
        midnightResetManager = nil
    }
}
