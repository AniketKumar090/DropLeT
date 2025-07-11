import Foundation
import SwiftData
import SwiftUI
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


