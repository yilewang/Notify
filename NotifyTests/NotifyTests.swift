//
//  NotifyTests.swift
//  NotifyTests
//
//  Created by Yile Wang on 7/4/25.
//

import Testing

struct NotifyTests {

    @Test func example() async throws {
        let store = ReminderStore()
        // Clear any persisted entries to ensure a clean slate
        store.entries.removeAll()

        // Add a sample entry
        let id = UUID()
        let entry = ReminderEntry(id: id, date: Date(), text: "Initial", notificationID: "test")
        store.entries.append(entry)

        // Update the entry
        store.updateEntry(id: id, newText: "Updated")

        // Verify the update
        #expect(store.entries.first?.text == "Updated")
    }

}
