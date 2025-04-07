import SwiftUI
import SwiftData

struct SettingsView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var waterTarget: Double
    @State private var calorieTarget: Int
    @State private var showingWaterPicker = false
    @State private var showingCaloriePicker = false
    @State private var showingResetAlert = false
    @State private var showingAddCategory = false
    @State private var showingDeleteCategoryAlert = false
    @State private var showingTimePicker = false
    @State private var categoryToDelete: MealCategory?
    
    init() {
        _waterTarget = State(initialValue: dataManager.waterTarget)
        _calorieTarget = State(initialValue: dataManager.calorieTarget)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Daily Targets")) {
                HStack {
                    Label("Water Target", systemImage: "drop.fill")
                        .foregroundColor(.blue)
                    Spacer()
                    Text("\(waterTarget, specifier: "%.1f") L")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingWaterPicker = true
                }
                
                HStack {
                    Label("Calorie Target", systemImage: "flame.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(calorieTarget) cal")
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingCaloriePicker = true
                }
            }
            
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $notificationManager.isNotificationsEnabled)
                    .onChange(of: notificationManager.isNotificationsEnabled) { _, newValue in
                        if newValue {
                            notificationManager.requestAuthorization()
                        } else {
                            notificationManager.saveSettings()
                        }
                    }
                
                if notificationManager.isNotificationsEnabled {
                    HStack {
                        Label("Daily Summary Time", systemImage: "clock.fill")
                        Spacer()
                        Text(formattedTime)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingTimePicker = true
                    }
                    
                    Picker("Reminder Frequency", selection: $notificationManager.reminderFrequency) {
                        ForEach(NotificationManager.ReminderFrequency.allCases) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    .onChange(of: notificationManager.reminderFrequency) { _, _ in
                        notificationManager.saveSettings()
                        notificationManager.scheduleNotifications()
                    }
                }
            }
            
            Section(header: Text("Categories")) {
                ForEach(dataManager.categories.filter { !$0.isDefault }, id: \.id) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(getCategoryColor(icon: category.icon))
                            .frame(width: 30)
                        
                        Text(category.displayName)
                        
                        Spacer()
                        
                        Button(action: {
                            categoryToDelete = category
                            showingDeleteCategoryAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Button(action: {
                    showingAddCategory = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add New Category")
                    }
                }
            }
            
            Section(header: Text("Data Management")) {
                Button(action: {
                    showingResetAlert = true
                }) {
                    HStack {
                        Label("Reset Today's Data", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            
            Section(header: Text("About")) {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    HStack {
                        Label("Privacy Policy", systemImage: "lock.shield")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
                
                Link(destination: URL(string: "https://example.com/terms")!) {
                    HStack {
                        Label("Terms of Use", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
        }
        .sheet(isPresented: $showingWaterPicker) {
            WaterTargetPickerView(waterTarget: $waterTarget, onSave: {
                dataManager.updateWaterTarget(waterTarget)
            })
        }
        .sheet(isPresented: $showingCaloriePicker) {
            CalorieTargetPickerView(calorieTarget: $calorieTarget, onSave: {
                dataManager.updateCalorieTarget(calorieTarget)
            })
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView { success in
                if success {
                    dataManager.loadCategories()
                }
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            TimePickerView(selectedTime: $notificationManager.notificationTime) {
                notificationManager.saveSettings()
                notificationManager.scheduleNotifications()
            }
        }
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("Reset Today's Data"),
                message: Text("This will reset your calorie and water intake for today. This action cannot be undone."),
                primaryButton: .destructive(Text("Reset")) {
                    dataManager.resetDaily()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showingDeleteCategoryAlert) {
            Alert(
                title: Text("Delete Category"),
                message: Text("Are you sure you want to delete this category? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let category = categoryToDelete {
                        _ = dataManager.deleteCategory(id: category.id)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: notificationManager.notificationTime)
    }
    
    private func getCategoryColor(icon: String) -> Color {
        switch icon {
        case "sunrise.fill": return .orange
        case "sun.max.fill": return .yellow
        case "moon.stars.fill": return .purple
        case "leaf.fill": return .green
        case "drop.fill": return .blue
        case "fork.knife": return .brown
        case "cup.and.saucer.fill": return .brown
        case "takeoutbag.and.cup.and.straw.fill": return .brown
        case "carrot.fill": return .orange
        case "fish.fill": return .blue
        case "birthday.cake.fill": return .pink
        case "popcorn.fill": return .yellow
        case "wineglass.fill": return .purple
        case "mug.fill": return .brown
        default: return .gray
        }
    }
}

struct TimePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTime: Date
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Notification Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                Text("This is when you'll receive your daily summary notification")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationTitle("Notification Time")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                    dismiss()
                }
            )
        }
    }
}

struct WaterTargetPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var waterTarget: Double
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Water Target", selection: $waterTarget) {
                    ForEach(Array(stride(from: 0.5, through: 5.0, by: 0.1)), id: \.self) { value in
                        Text("\(value, specifier: "%.1f") L")
                    }
                }
                .pickerStyle(.wheel)
                
                Text("Recommended: 2.0L for women, 2.5L for men")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationTitle("Water Target")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                    dismiss()
                }
            )
        }
    }
}

struct CalorieTargetPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var calorieTarget: Int
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Calorie Target", selection: $calorieTarget) {
                    ForEach(Array(stride(from: 1000, through: 4000, by: 50)), id: \.self) { value in
                        Text("\(value) cal")
                    }
                }
                .pickerStyle(.wheel)
                
                Text("Recommended: 1800-2400 cal for women, 2200-3000 cal for men")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationTitle("Calorie Target")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                    dismiss()
                }
            )
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(DataManager.shared)
    }
}
