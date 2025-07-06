import UserNotifications

final class NotificationLogger {
    private let store: ReminderStore

    init(store: ReminderStore) {
        self.store = store
    }

    /// Reconciles any delivered notifications that have not yet been logged.
    func reconcileDeliveredNotifications(_ center: UNUserNotificationCenter = .current()) {
        center.getDeliveredNotifications { [weak self] delivered in
            guard let self = self else { return }
            let unlogged = delivered.filter { !self.store.hasLogged(id: $0.request.identifier) }
            guard !unlogged.isEmpty else { return }
            DispatchQueue.main.async {
                for note in unlogged {
                    self.store.addEntry(text: "Reminder delivered", date: note.date, notificationID: note.request.identifier)
                }
                center.removeDeliveredNotifications(withIdentifiers: unlogged.map { $0.request.identifier })
            }
        }
    }
}
