
import SwiftUI
import UserNotifications

// ----------------------------------------------------------------
// MARK: - FILE: ReminderApp.swift
// ----------------------------------------------------------------
// This is the entry point of the app. It sets up the shared data store
// and the notification delegate.
@main
struct NotifyApp: App {
    // The delegate for handling app lifecycle events.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // The single, shared data store for the entire app.
    @StateObject private var reminderStore = ReminderStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Make the shared store available to all views.
                .environmentObject(reminderStore)
                .onAppear {
                    // Pass the store to the AppDelegate so the notification
                    // handler knows which data to update.
                    appDelegate.setReminderStore(reminderStore)
                }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active {
                appDelegate.logger?.reconcileDeliveredNotifications()
            }
        }
    }
}
