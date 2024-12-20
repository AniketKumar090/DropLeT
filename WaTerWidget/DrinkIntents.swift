import AppIntents
import SwiftData
import WidgetKit

struct DrinkAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Drink"
    
    @Parameter(title: "Drink Type")
    var drinkType: DrinkTypeEnum
    
    @Parameter(title: "Amount")
    var amount: Int
    
    enum DrinkTypeEnum: String, AppEnum {
        case water
        case coffee
        case tea
        case soda
        
        static var typeDisplayRepresentation: TypeDisplayRepresentation = "Drink Type"
        
        static var caseDisplayRepresentations: [DrinkTypeEnum: DisplayRepresentation] = [
            .water: "Water",
            .coffee: "Coffee",
            .tea: "Tea",
            .soda: "Soda"
        ]
    }
    
    init() {
        self.drinkType = .water
        self.amount = 250
    }
    
    init(drinkType: DrinkType, amount: Double) {
        self.drinkType = DrinkTypeEnum(rawValue: drinkType.rawValue) ?? .water
        self.amount = Int(amount)
    }
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount)ml of \(\.$drinkType)")
    }
    
    func perform() async throws -> some IntentResult {
        let drink = DrinkRecord(
            amount: Double(amount),
            type: DrinkType(rawValue: drinkType.rawValue) ?? .water,
            isQuickAdd: true
        )
        
        let modelContainer = try ModelContainer(for: DrinkRecord.self)
        let context = ModelContext(modelContainer)
        context.insert(drink)
        try context.save()
        
        // Calculate new total for today
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<DrinkRecord>(
            predicate: #Predicate<DrinkRecord> { drink in
                drink.timestamp >= startOfDay && drink.timestamp < endOfDay
            }
        )
        
        let todayDrinks = try context.fetch(descriptor)
        let todayTotal = todayDrinks.reduce(0) { $0 + $1.amount }
        // Set a flag to indicate this update came from the widget
        UserDefaults.group.set(true, forKey: "isWidgetUpdate")
                
        // Update UserDefaults with new total
        UserDefaults.group.set(Int(todayTotal), forKey: UserDefaults.todayWaterAmountKey)
        
        // Refresh widget
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}
