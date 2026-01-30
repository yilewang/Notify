//
//  NotificationManager.swift
//  Notify
//
//  Created by Yile Wang on 7/4/25.
//

import Foundation
import UserNotifications
import BackgroundTasks


class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    private enum Keys {
        static let reminderText = "ReminderText"
        static let reminderInterval = "ReminderInterval"
        static let reminderStartTime = "ReminderStartTime"
        static let reminderEndTime = "ReminderEndTime"
        static let reminderDays = "ReminderDays"
    }

    struct StoredSettings {
        let reminderText: String
        let intervalMinutes: Int
        let selectedDays: Set<Int>
        let startTime: Date
        let endTime: Date
    }

    /// Schedules notifications for the next 7 days based on user preferences
    func scheduleReminders(reminderText: String,
                           intervalMinutes: Int,
                           selectedDays: Set<Int>,
                           startTime: Date,
                           endTime: Date) {
        guard intervalMinutes > 0 else {
            print("❌ Invalid interval; must be greater than 0 minutes.")
            return
        }
        guard !selectedDays.isEmpty else {
            print("❌ No days selected for scheduling.")
            return
        }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Time for a check-in!"
        content.body = reminderText
        content.sound = .default
        content.categoryIdentifier = "REMINDER_CATEGORY"

        let calendar = Calendar.current
        var notificationCount = 0
        let maxNotifications = 64

        for dayOffset in 0..<7 {
            guard notificationCount < maxNotifications else { break }

            let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
            let weekday = calendar.component(.weekday, from: targetDate)

            if selectedDays.contains(weekday) {
                let startHour = calendar.component(.hour, from: startTime)
                let startMinute = calendar.component(.minute, from: startTime)
                let endHour = calendar.component(.hour, from: endTime)
                let endMinute = calendar.component(.minute, from: endTime)

                var notificationTime = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: targetDate)!
                let endTimeOnDay = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: targetDate)!

                if dayOffset == 0 {
                    while notificationTime < Date() {
                        notificationTime = calendar.date(byAdding: .minute, value: intervalMinutes, to: notificationTime)!
                    }
                }

                while notificationTime <= endTimeOnDay && notificationCount < maxNotifications {
                    let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request)

                    notificationCount += 1
                    notificationTime = calendar.date(byAdding: .minute, value: intervalMinutes, to: notificationTime)!
                }
            }
        }

        print("✅ Scheduled \(notificationCount) notifications.")
    }

    /// Call this from your background task to keep notifications fresh
    func rescheduleNextNotifications() {
        let defaults = UserDefaults.standard

        guard let settings = loadUserSettings() else {
            print("❌ Missing user settings for rescheduling.")
            return
        }

        scheduleReminders(reminderText: settings.reminderText,
                          intervalMinutes: settings.intervalMinutes,
                          selectedDays: settings.selectedDays,
                          startTime: settings.startTime,
                          endTime: settings.endTime)
    }

    /// Optional: persist user preferences when they start reminders
    func saveUserSettings(reminderText: String,
                          intervalMinutes: Int,
                          selectedDays: Set<Int>,
                          startTime: Date,
                          endTime: Date) {
        let defaults = UserDefaults.standard
        defaults.set(reminderText, forKey: Keys.reminderText)
        defaults.set(intervalMinutes, forKey: Keys.reminderInterval)
        defaults.set(startTime, forKey: Keys.reminderStartTime)
        defaults.set(endTime, forKey: Keys.reminderEndTime)
        defaults.set(Array(selectedDays), forKey: Keys.reminderDays)
    }

    func loadUserSettings() -> StoredSettings? {
        let defaults = UserDefaults.standard
        guard let reminderText = defaults.string(forKey: Keys.reminderText),
              let interval = defaults.object(forKey: Keys.reminderInterval) as? Int,
              let start = defaults.object(forKey: Keys.reminderStartTime) as? Date,
              let end = defaults.object(forKey: Keys.reminderEndTime) as? Date,
              let daysRaw = defaults.object(forKey: Keys.reminderDays) as? [Int] else {
            return nil
        }

        return StoredSettings(reminderText: reminderText,
                              intervalMinutes: interval,
                              selectedDays: Set(daysRaw),
                              startTime: start,
                              endTime: end)
    }
}

extension NotificationManager {
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yourcompany.reminder.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour later

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📆 Background task scheduled.")
        } catch {
            print("❌ Failed to schedule app refresh: \(error)")
        }
    }

}
