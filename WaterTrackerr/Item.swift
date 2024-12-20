//
//  Item.swift
//  WaterTrackerr
//
//  Created by Aniket Kumar on 20/12/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
