//
//  ContentView.swift
//  Notify
//
//  Created by Yile Wang on 7/4/25.
//

import SwiftUI
import UserNotifications


struct CalendarHistoryView: View {
    @AppStorage("logDefaultDelivery") private var logDefaultDelivery: Bool = true
    @EnvironmentObject var reminderStore: ReminderStore
    @State private var selectedDate: Date = Date()
    @State private var showingManualLog = false
    @State private var manualLogText = ""
    // Editing state
    @State private var editingEntry: ReminderEntry?
    @State private var editText: String = ""
    @State private var showingEditSheet = false

    var entriesForSelectedDate: [ReminderEntry] {
        reminderStore.entries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }.sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar view
                DatePicker(
                    "Selected Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                // 🧠 Toggle placed directly after the calendar
                Toggle("Log Default Delivery", isOn: $logDefaultDelivery)
                    .padding(.horizontal)

                // Entry list below the toggle
                List {
                    if entriesForSelectedDate.isEmpty {
                        Text("No entries for this day.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(entriesForSelectedDate) { entry in
                            VStack(alignment: .leading) {
                                Text(entry.text)
                                Text(entry.date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .onTapGesture {
                                editingEntry = entry
                                editText = entry.text
                                showingEditSheet = true
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
                .onAppear {
                    // Print to confirm storage state
                    let val = UserDefaults.standard.object(forKey: "logDefaultDelivery") as? Bool
                    print("🔧 CalendarAppearance — stored logDefaultDelivery:", val ?? "nil")
                    if val == nil {
                        UserDefaults.standard.set(true, forKey: "logDefaultDelivery")
                        print("✅ Initialized logDefaultDelivery to true")
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manual Log") {
                        showingManualLog = true
                    }
                }
            }
            .sheet(isPresented: $showingManualLog) {
                NavigationView {
                    VStack(alignment: .leading) {
                        TextEditor(text: $manualLogText)
                            .padding()
                            .frame(minHeight: 200)
                        Spacer()
                    }
                    .navigationTitle("Manual Log")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingManualLog = false
                        },
                        trailing: Button("Save") {
                            saveManualEntry()
                            showingManualLog = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                NavigationView {
                    VStack(alignment: .leading) {
                        TextEditor(text: $editText)
                            .padding()
                            .frame(minHeight: 200)
                        Spacer()
                    }
                    .navigationTitle("Edit Entry")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingEditSheet = false
                            editingEntry = nil
                        },
                        trailing: Button("Save") {
                            if let entry = editingEntry {
                                reminderStore.updateEntry(id: entry.id, newText: editText)
                            }
                            showingEditSheet = false
                            editingEntry = nil
                        }
                    )
                }
            }
        }
    }

    private func saveManualEntry() {
        let trimmed = manualLogText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        reminderStore.addEntry(text: trimmed, date: Date(), notificationID: UUID().uuidString)
        manualLogText = ""
    }

    private func deleteEntries(at offsets: IndexSet) {
        let currentEntries = entriesForSelectedDate
        for index in offsets {
            let entry = currentEntries[index]
            reminderStore.removeEntry(id: entry.id)
        }
    }
}

struct ContentView: View {
    @State private var reminderText: String = "Don't let TIME slide."
//    @State private var timeIntervalInMinutes: String = "60"
    // Add these state variables:
    @State private var selectedHours: Int = 1
    @State private var selectedMinutes: Int = 0
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    
    @State private var remindersAreActive: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showingCalendar: Bool = false
    
    let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminder Message")) {
                    TextField("Enter your reminder message", text: $reminderText)
                }
                .disabled(remindersAreActive)

                Section(header: Text("Notification Frequency, Every")) {
                    HStack {
                        Picker("Hours", selection: $selectedHours) {
                            ForEach(0..<24) { hour in
                                Text("\(hour) hr").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker("Minutes", selection: $selectedMinutes) {
                            ForEach(0..<60) { minute in
                                Text(String(format: "%02d min", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .frame(height: 120)
                }
                .disabled(remindersAreActive)
                
                // *** UPDATED ORDER ***
                Section(header: Text("Active Time Range")) {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                .disabled(remindersAreActive)
                
                // *** UPDATED ORDER ***
                Section(header: Text("Repeat on Days")) {
                    HStack(spacing: 10) {
                        ForEach(0..<7, id: \.self) { index in
                            Button(action: {
                                toggleDaySelection(dayIndex: index + 1)
                            }) {
                                Text(weekdays[index])
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .foregroundColor(selectedDays.contains(index + 1) ? .white : .blue)
                                    .background(selectedDays.contains(index + 1) ? Color.blue : Color.clear)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .disabled(remindersAreActive)

                Section {
                    if remindersAreActive {
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Reminders are active")
                                    .font(.headline)
                            }
                            
                            Button(action: cancelReminders) {
                                Text("Cancel Reminders")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    } else {
                        Button(action: startReminders) {
                            Text("Start Reminders")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("Notify Me Every...")
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Invalid Time Range"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCalendar = true
                    }) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarHistoryView()
            }
        }
    }
    
    func toggleDaySelection(dayIndex: Int) {
        if selectedDays.contains(dayIndex) {
            selectedDays.remove(dayIndex)
        } else {
            selectedDays.insert(dayIndex)
        }
    }

    func startReminders() {
        if endTime <= startTime {
            alertMessage = "The end time should be later than the start time."
            showingAlert = true
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                scheduleNotifications()
                DispatchQueue.main.async {
                    remindersAreActive = true
                }
            } else {
                print("Notification permission denied.")
            }
        }
    }
    
    func cancelReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        remindersAreActive = false
    }
    
    func scheduleNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Time for a check-in!"
        content.body = reminderText
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "REMINDER_CATEGORY"

        let intervalMinutes = selectedHours * 60 + selectedMinutes
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
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request)
                    notificationCount += 1
                    
                    if let nextTime = calendar.date(byAdding: .minute, value: intervalMinutes, to: notificationTime) {
                        notificationTime = nextTime
                    } else {
                        break
                    }
                }
            }
        }
        print("\(notificationCount) notifications scheduled for the next 7 days (iOS limit is 64).")
    }
}
