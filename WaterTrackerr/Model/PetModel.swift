import Foundation
import SwiftUI

struct Pet: Codable {
    var name: String
    var birthday = Date()
    var lastDrink: Date
    
    var happinessLevel: String {
        thirst == "Thirsty" ? "Unhappy" : "Happy"
    }
    
    var thirst: String {
        let timeSince = calcTimeSince(date: lastDrink)
        var string = ""
        switch timeSince {
        case 0..<30: string = "Satiated"
        case 30..<60: string = "Getting Thirsy..."
        case 60...: string = "Thirsty"
        default: string = "Idk"
        }
        return string
    }
    
    func calcTimeSince(date: Date) -> Double {
        return Date().timeIntervalSince(date)
    }
}
