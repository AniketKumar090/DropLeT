import Foundation
import SwiftUI
import UserNotifications
import UserNotificationsUI

class NotificationManager: ObservableObject {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    static let midnightResetReceived = Notification.Name("midnightResetReceived")
        
    func scheduleNotifications() {
        guard notificationsEnabled else { return }
        
        // Define the notification times and messages
        let notificationTimes = [
            (hour: 7, minute: 0, message: "Drink your first glass of water after waking up!"),
            (hour: 9, minute: 0, message: "It’s time for your second glass of water! Start your work day refreshed."),
            (hour: 11, minute: 30, message: "Have a glass of water 30 minutes before lunch."),
            (hour: 13, minute: 30, message: "Drink a glass of water an hour after lunch to aid digestion."),
            (hour: 15, minute: 0, message: "Refresh your mind with a glass of water during your tea break."),
            (hour: 17, minute: 0, message: "Stay hydrated to prevent overeating during dinner."),
            (hour: 19, minute: 30, message: "Stay hydrated to prevent overeating during dinner."),
            (hour: 21, minute: 30, message: "Have a glass of water an hour after dinner."),
            (hour: 23, minute: 45, message: "Drink your last glass of water an hour before bedtime.")
        ]
        
        // Remove all existing notifications before scheduling new ones
        removeAllNotifications()
        
        let calendar = Calendar.current
        let now = Date()
        
        for (hour, minute, message) in notificationTimes {
            // Create a date component for the notification time
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            
            // Calculate the next occurrence of the notification time
            guard let triggerDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { continue }
            
            // Create the notification content
            let content = UNMutableNotificationContent()
            content.title = "DropLet"
            content.body = message
            content.sound = UNNotificationSound.default
            
            // Create the trigger for the notification
            let triggerDateComponents = calendar.dateComponents([.hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: true)
            
            // Create the notification request
            let request = UNNotificationRequest(
                identifier: "hydration_reminder_\(hour)_\(minute)",
                content: content,
                trigger: trigger
            )
            
            // Add the notification request
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification for \(hour):\(minute): \(error.localizedDescription)")
                } else {
                    print("Notification scheduled for \(hour):\(minute)")
                }
            }
        }
        
        // Schedule the midnight reset task
        scheduleMidnightReset()
    }

    func scheduleMidnightReset() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 0 // Changed to exactly midnight
        components.minute = 0
        
        guard let triggerDate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "It's a New Day"
        content.body = "Starting with fresh hydration goals!"
        content.sound = UNNotificationSound.default
        
        let triggerDateComponents = calendar.dateComponents([.hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "midnight_reset",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling midnight reset: \(error.localizedDescription)")
            } else {
                print("Midnight reset scheduled")
                // Post notification only if the scheduling is successful
               
            }
        }
    }
    // This method removes all scheduled notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // This method handles toggling notifications on/off
    func toggleNotifications(_ isEnabled: Bool) {
        notificationsEnabled = isEnabled
        if isEnabled {
            scheduleNotifications()
        } else {
            removeAllNotifications()
        }
    }
}
