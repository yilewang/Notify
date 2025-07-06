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

    func applicationDidBecomeActive(_ application: UIApplication) {
        guard let store = notificationDelegate?.reminderStore else { return }
        NotificationManager.shared.logDeliveredNotifications(to: store)
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

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.identifier
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

