// ----------------------------------------------------------------
// MARK: - Data Model and Storage
// ----------------------------------------------------------------

// This struct defines what a single reminder entry looks like.
struct ReminderEntry: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let text: String
}

// This class manages loading and saving the reminder entries.
class ReminderStore: ObservableObject {
    @Published var entries: [ReminderEntry]
    private static let userDefaultsKey = "ReminderEntries"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) {
            if let decodedEntries = try? JSONDecoder().decode([ReminderEntry].self, from: data) {
                self.entries = decodedEntries
                return
            }
        }
        self.entries = []
    }

    func addEntry(text: String, date: Date) {
        let newEntry = ReminderEntry(date: date, text: text)
        entries.append(newEntry)
        save()
    }

    private func save() {
        if let encodedData = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encodedData, forKey: Self.userDefaultsKey)
        }
    }
}
