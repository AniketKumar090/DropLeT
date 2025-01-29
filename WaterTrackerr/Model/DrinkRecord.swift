import Foundation
import SwiftData
import SwiftUI
import AppIntents
@Model
class DrinkRecord {
    var id: UUID
    var amount: Double
    var type: DrinkType
    var timestamp: Date
    var isQuickAdd: Bool?
    
    init(amount: Double, type: DrinkType, timestamp: Date = Date(), isQuickAdd: Bool = false) {
        self.id = UUID()
        self.amount = amount
        self.type = type
        self.timestamp = timestamp
        self.isQuickAdd = isQuickAdd
    }
}


struct DefaultDrinks {
    static let sampleDrinks: [DrinkRecord] = [
        DrinkRecord(
            amount: 300,
            type: .water,
            timestamp: Date(),
            isQuickAdd: false
        ),
        DrinkRecord(
            amount: 250,
            type: .tea,
            timestamp: Date(),
            isQuickAdd: false
        ),
        DrinkRecord(
            amount: 400,
            type: .coffee,
            timestamp: Date(),
            isQuickAdd: false
        )
    ]
}
