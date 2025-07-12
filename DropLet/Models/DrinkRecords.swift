import Foundation
import SwiftData
import SwiftUI

struct DrinkRecords: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let timestamp: Date
    let drinkType: DrinkType
    let quantity: Int
}


