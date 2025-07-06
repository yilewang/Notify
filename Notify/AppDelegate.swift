//
//  AppDelegate.swift
//  Notify
//
//  Created by Yile Wang on 7/4/25.
//

import SwiftUI
import UserNotifications
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    var notificationDelegate: NotificationDelegate?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourcompany.reminder.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }

        return true
    }

    func setReminderStore(_ store: ReminderStore) {
        let delegate = NotificationDelegate(reminderStore: store)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate

        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Respond",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type your reply..."
        )

        let category = UNNotificationCategory(
            identifier: "REMINDER_CATEGORY",
            actions: [replyAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])

        // Log any notifications that may have been delivered while the app was
        // not running.
        delegate.logMissedDeliveries()
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        print("📡 Background task triggered")
        NotificationManager.shared.scheduleAppRefresh()
        NotificationManager.shared.rescheduleNextNotifications()
        task.setTaskCompleted(success: true)
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let reminderStore: ReminderStore

    init(reminderStore: ReminderStore) {
        self.reminderStore = reminderStore
    }

    /// Removes all previously delivered notifications except the one currently
    /// being presented.
    private func clearPreviousNotifications(except id: String) {
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let idsToRemove = delivered.map { $0.request.identifier }.filter { $0 != id }
            if !idsToRemove.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: idsToRemove)
            }
        }
    }

    /// Logs any delivered notifications that weren't handled while the app was
    /// inactive and removes them so they're not logged again.
    func logMissedDeliveries() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notes in
            let shouldLog = UserDefaults.standard.bool(forKey: "logDefaultDelivery")
            guard shouldLog, !notes.isEmpty else { return }

            for note in notes {
                self.reminderStore.addEntry(text: "Reminder delivered", date: note.date, notificationID: note.request.identifier)
            }

            let ids = notes.map { $0.request.identifier }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.identifier
        clearPreviousNotifications(except: id)
        let shouldLog = UserDefaults.standard.bool(forKey: "logDefaultDelivery")
        print("🛎 willPresent triggered — ID: \(id)")
        print("🧠 willPresent — shouldLog =", shouldLog)

        if shouldLog {
            reminderStore.addEntry(text: "Reminder delivered", date: Date(), notificationID: id)
            print("📌 willPresent — Logged default delivery: \(id)")
        } else {
            print("🚫 willPresent — Skipped default logging: \(id)")
        }

        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let now = Date()
        let id = response.notification.request.identifier
        clearPreviousNotifications(except: id)

        DispatchQueue.main.async {
            if let textResponse = response as? UNTextInputNotificationResponse,
               response.actionIdentifier == "REPLY_ACTION" {
                self.reminderStore.addEntry(text: textResponse.userText, date: now, notificationID: id)
                print("💬 Reply saved for ID: \(id)")
            } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                let shouldLog = UserDefaults.standard.bool(forKey: "logDefaultDelivery")
                print("🛎 didReceive triggered — ID: \(id)")
                print("🧠 didReceive — shouldLog =", shouldLog)

                if shouldLog {
                    self.reminderStore.addEntry(text: "Reminder delivered", date: now, notificationID: id)
                    print("📌 didReceive — Logged default delivery: \(id)")
                } else {
                    print("🚫 didReceive — Skipped default logging: \(id)")
                }
            }
        }

        completionHandler()
    }
}

