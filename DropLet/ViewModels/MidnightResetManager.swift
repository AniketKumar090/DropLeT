import Foundation
import Combine

class MidnightResetManager: ObservableObject {
    private var resetTimer: Timer?
    private let resetCallback: () -> Void
    
    init(resetCallback: @escaping () -> Void) {
        self.resetCallback = resetCallback
        scheduleReset()
    }

    deinit {
        resetTimer?.invalidate()
    }

    private func scheduleReset() {
        // Invalidate any existing timer to avoid duplicates
        resetTimer?.invalidate()

        // Calculate the time until midnight (00:00)
        let calendar = Calendar.current
        let now = Date()
        
        // Get the start of tomorrow
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let startOfTomorrow = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            print("Failed to calculate next midnight")
            return
        }
        
        let timeUntilMidnight = startOfTomorrow.timeIntervalSince(now)
        
        print("Next midnight reset scheduled in \(timeUntilMidnight) seconds")
        
        // Schedule the timer to fire at midnight
        resetTimer = Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
            self?.performReset()
        }
    }
    
    private func performReset() {
        print("Midnight reset triggered at \(Date())")
        resetCallback()
        
        // Reschedule for the next midnight
        scheduleReset()
    }
    
    // Public method to manually trigger reset (for testing)
    func triggerReset() {
        performReset()
    }
    
    // Method to get time until next reset (for UI display if needed)
    func timeUntilNextReset() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let startOfTomorrow = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return 0
        }
        
        return startOfTomorrow.timeIntervalSince(now)
    }
}
