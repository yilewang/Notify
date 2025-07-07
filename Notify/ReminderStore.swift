//
//  defines.swift
//  Notify
//
//  Created by Yile Wang on 7/4/25.
//
import SwiftUI
import UserNotifications

// ----------------------------------------------------------------
// MARK: - FILE: ReminderStore.swift
// ----------------------------------------------------------------

// This struct defines what a single reminder entry looks like.
struct ReminderEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var text: String
    let notificationID: String
}

// This class manages loading and saving the reminder entries.
class ReminderStore: ObservableObject {
    @Published var entries: [ReminderEntry]
    private static let userDefaultsKey = "ReminderEntries"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let decodedEntries = try? JSONDecoder().decode([ReminderEntry].self, from: data) {
            self.entries = decodedEntries
        } else {
            self.entries = []
        }
    }

    func addEntry(text: String, date: Date, notificationID: String) {
        // Prevent duplicate entries for the same notificationID
        guard !entries.contains(where: { $0.notificationID == notificationID }) else {
            print("⚠️ Duplicate entry ignored for ID:", notificationID)
            return
        }

        let newEntry = ReminderEntry(date: date, text: text, notificationID: notificationID)
        entries.append(newEntry)
        save()
    }

    /// Removes the entry with the specified identifier and persists the change.
    func removeEntry(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries.remove(at: index)
            save()
        }
    }

    /// Updates the text and optionally the date for a given entry identifier.
    func updateEntry(id: UUID, newText: String, newDate: Date? = nil) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        entries[index].text = newText
        if let date = newDate {
            entries[index].date = date
        }
        save()
    }

    /// Returns true if an entry already exists for the given notification ID.
    func hasLogged(id: String) -> Bool {
        entries.contains { $0.notificationID == id }
    }

    private func save() {
        if let encodedData = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encodedData, forKey: Self.userDefaultsKey)
        }
    }
}
