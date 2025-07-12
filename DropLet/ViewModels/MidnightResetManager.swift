import Combine
import Foundation
import SwiftUI
import UserNotifications
import UserNotificationsUI

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
