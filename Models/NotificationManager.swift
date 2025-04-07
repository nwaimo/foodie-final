import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isNotificationsEnabled: Bool = false
    @Published var reminderFrequency: ReminderFrequency = .medium
    @Published var notificationTime: Date = Calendar.current.date(
        from: DateComponents(hour: 18, minute: 0)
    ) ?? Date()
    
    enum ReminderFrequency: String, CaseIterable, Identifiable {
        case low = "Low (1-2 per day)"
        case medium = "Medium (3-4 per day)"
        case high = "High (5-6 per day)"
        
        var id: String { self.rawValue }
        
        var notificationsPerDay: Int {
            switch self {
            case .low: return 2
            case .medium: return 4
            case .high: return 6
            }
        }
        
        var intervalHours: Int {
            switch self {
            case .low: return 8
            case .medium: return 4
            case .high: return 2
            }
        }
    }
    
    private init() {
        loadSettings()
        
        // Check if notifications are authorized
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = granted
                if granted {
                    self.saveSettings()
                    self.scheduleNotifications()
                }
            }
        }
    }
    
    func scheduleNotifications() {
        guard isNotificationsEnabled else { return }
        
        // Remove existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule daily summary notification
        if let components = calendar.dateComponents([.hour, .minute], from: notificationTime).date {
            let dailySummaryTime = calendar.date(bySettingHour: calendar.component(.hour, from: components),
                                                minute: calendar.component(.minute, from: components),
                                                second: 0,
                                                of: now) ?? now
            
            var triggerDate = dailySummaryTime
            if dailySummaryTime < now {
                triggerDate = calendar.date(byAdding: .day, value: 1, to: dailySummaryTime) ?? now
            }
            
            let triggerComponents = calendar.dateComponents([.hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            
            let content = UNMutableNotificationContent()
            content.title = "Daily Summary"
            content.body = "Time to check your daily nutrition progress!"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "dailySummary",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
        
        // Schedule progress reminders throughout the day
        let startHour = 9 // 9 AM
        let endHour = 21  // 9 PM
        let hoursRange = endHour - startHour
        
        let notificationsCount = reminderFrequency.notificationsPerDay
        let interval = hoursRange / notificationsCount
        
        for i in 0..<notificationsCount {
            let hour = startHour + (i * interval)
            
            let components = DateComponents(hour: hour, minute: 0)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let content = UNMutableNotificationContent()
            content.title = "Nutrition Reminder"
            content.body = getRandomReminderMessage()
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "reminder-\(i)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func scheduleProgressNotification(progress: Double, type: String) {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        
        if progress < 0.5 {
            content.title = "You're falling behind!"
            content.body = "You've only reached \(Int(progress * 100))% of your \(type) target today."
        } else if progress < 0.8 {
            content.title = "Keep going!"
            content.body = "You're at \(Int(progress * 100))% of your \(type) target. Almost there!"
        } else if progress < 1.0 {
            content.title = "Almost there!"
            content.body = "Just a little more to reach your \(type) target for today."
        } else {
            content.title = "Target reached! 🎉"
            content.body = "Great job! You've reached your \(type) target for today."
        }
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "progress-\(type)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func getRandomReminderMessage() -> String {
        let messages = [
            "Don't forget to log your meals and water intake!",
            "How's your nutrition going today?",
            "Time to check your progress toward your daily goals!",
            "Have you had enough water today?",
            "Remember to maintain a balanced diet throughout the day.",
            "Take a moment to track your nutrition progress.",
            "Stay on track with your nutrition goals!",
            "A quick reminder to log your recent meals.",
            "Staying hydrated? Log your water intake now.",
            "Your body will thank you for tracking your nutrition!"
        ]
        
        return messages.randomElement() ?? messages[0]
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isNotificationsEnabled, forKey: "NotificationsEnabled")
        UserDefaults.standard.set(reminderFrequency.rawValue, forKey: "ReminderFrequency")
        UserDefaults.standard.set(notificationTime, forKey: "NotificationTime")
    }
    
    private func loadSettings() {
        if let isEnabled = UserDefaults.standard.object(forKey: "NotificationsEnabled") as? Bool {
            isNotificationsEnabled = isEnabled
        }
        
        if let frequencyRaw = UserDefaults.standard.string(forKey: "ReminderFrequency"),
           let frequency = ReminderFrequency(rawValue: frequencyRaw) {
            reminderFrequency = frequency
        }
        
        if let time = UserDefaults.standard.object(forKey: "NotificationTime") as? Date {
            notificationTime = time
        }
    }
}
