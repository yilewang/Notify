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

    /// Schedules notifications for the next 7 days based on user preferences
    func scheduleReminders(reminderText: String,
                           intervalMinutes: Int,
                           selectedDays: Set<Int>,
                           startTime: Date,
                           endTime: Date) {
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

        guard let reminderText = defaults.string(forKey: "ReminderText"),
              let interval = defaults.object(forKey: "ReminderInterval") as? Int,
              let start = defaults.object(forKey: "ReminderStartTime") as? Date,
              let end = defaults.object(forKey: "ReminderEndTime") as? Date,
              let daysRaw = defaults.object(forKey: "ReminderDays") as? [Int] else {
            print("❌ Missing user settings for rescheduling.")
            return
        }

        let selectedDays = Set(daysRaw)
        scheduleReminders(reminderText: reminderText,
                          intervalMinutes: interval,
                          selectedDays: selectedDays,
                          startTime: start,
                          endTime: end)
    }

    /// Optional: persist user preferences when they start reminders
    func saveUserSettings(reminderText: String,
                          intervalMinutes: Int,
                          selectedDays: Set<Int>,
                          startTime: Date,
                          endTime: Date) {
        let defaults = UserDefaults.standard
        defaults.set(reminderText, forKey: "ReminderText")
        defaults.set(intervalMinutes, forKey: "ReminderInterval")
        defaults.set(startTime, forKey: "ReminderStartTime")
        defaults.set(endTime, forKey: "ReminderEndTime")
        defaults.set(Array(selectedDays), forKey: "ReminderDays")
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

    func logMissedDeliveries(since exitTime: Date, using store: ReminderStore) {
        let defaults = UserDefaults.standard
        guard let interval = defaults.object(forKey: "ReminderInterval") as? Int,
              let start = defaults.object(forKey: "ReminderStartTime") as? Date,
              let end = defaults.object(forKey: "ReminderEndTime") as? Date,
              let daysRaw = defaults.object(forKey: "ReminderDays") as? [Int] else {
            return
        }

        let selectedDays = Set(daysRaw)
        let calendar = Calendar.current
        let now = Date()

        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)

        var currentDay = calendar.startOfDay(for: exitTime)
        while currentDay <= now {
            let weekday = calendar.component(.weekday, from: currentDay)
            if selectedDays.contains(weekday) {
                var time = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: currentDay)!
                let endTimeOnDay = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: currentDay)!
                if time < exitTime {
                    while time < exitTime {
                        time = calendar.date(byAdding: .minute, value: interval, to: time)!
                    }
                }
                while time <= endTimeOnDay && time <= now {
                    if time > exitTime {
                        store.addEntry(text: "Reminder delivered", date: time, notificationID: UUID().uuidString)
                    }
                    time = calendar.date(byAdding: .minute, value: interval, to: time)!
                }
            }
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
        }
    }
}
