import SwiftUI
import SwiftData

struct AddConsumptionView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @State private var selectedCategoryId: UUID?
    @State private var calories: String = ""
    @State private var waterAmount: String = ""
    @State private var showingAlert = false
    @State private var alertType: AlertType? = nil
    @State private var intakeStatus: IntakeStatus = .normal
    @State private var showingAddCategory = false
    
    enum AlertType: Identifiable {
        case success, overTarget, tooHigh, invalid
        
        var id: Int {
            switch self {
            case .success: return 0
            case .overTarget: return 1
            case .tooHigh: return 2
            case .invalid: return 3
            }
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Category")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(dataManager.categories, id: \.id) { category in
                            CategoryButton(
                                category: category,
                                isSelected: category.id == selectedCategoryId,
                                action: {
                                    selectedCategoryId = category.id
                                }
                            )
                        }
                        
                        Button(action: {
                            showingAddCategory = true
                        }) {
                            VStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Add New")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .frame(width: 80, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .padding(.vertical, 5)
            }
            
            Section(header: Text("Amount")) {
                if let category = selectedCategory, category.name.lowercased() != "drink" {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        TextField("Calories", text: $calories)
                            .keyboardType(.numberPad)
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                } else if selectedCategory != nil {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.blue)
                        TextField("Water Amount", text: $waterAmount)
                            .keyboardType(.decimalPad)
                        Text("L")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Select a category first")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button(action: addConsumption) {
                    HStack {
                        Spacer()
                        Text("Add")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(!isValidInput)
            }
            
            if let category = selectedCategory, category.name.lowercased() != "drink" {
                Section(header: Text("Quick Add")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach([50, 100, 200, 300, 500], id: \.self) { value in
                                Button(action: {
                                    calories = "\(value)"
                                }) {
                                    Text("\(value)")
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            } else if let category = selectedCategory, category.name.lowercased() == "drink" {
                Section(header: Text("Quick Add")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach([0.25, 0.5, 0.75, 1.0, 1.5], id: \.self) { value in
                                Button(action: {
                                    waterAmount = String(format: "%.2f", value)
                                }) {
                                    Text(String(format: "%.2f", value))
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .alert(item: $alertType) { type in
            let (title, message) = getAlertContent(for: type)
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView { success in
                if success {
                    dataManager.loadCategories()
                }
            }
        }
    }
    
    private var selectedCategory: MealCategory? {
        guard let id = selectedCategoryId else { return nil }
        return dataManager.categories.first { $0.id == id }
    }
    
    private var isValidInput: Bool {
        guard let category = selectedCategory else { return false }
        
        if category.name.lowercased() == "drink" {
            return !waterAmount.isEmpty && (Double(waterAmount) ?? 0) > 0
        } else {
            return !calories.isEmpty && (Int(calories) ?? 0) > 0
        }
    }
    
    private func addConsumption() {
        guard let category = selectedCategory else { return }
        
        let isDrink = category.name.lowercased() == "drink"
        let newCalories = isDrink ? 0 : (Int(calories) ?? 0)
        let newWater = isDrink ? (Double(waterAmount) ?? 0) : nil
        
        intakeStatus = dataManager.validateIntake(
            calories: isDrink ? nil : newCalories,
            water: isDrink ? newWater : nil
        )
        
        switch intakeStatus {
        case .dangerous:
            alertType = .tooHigh
            return
        case .excessive:
            alertType = .overTarget
        case .targetReached:
            alertType = .success
        case .normal:
            break
        }
        
        dataManager.addConsumption(
            categoryId: category.id,
            categoryName: category.name,
            categoryIcon: category.icon,
            calories: newCalories,
            waterAmount: newWater
        )
        
        clearForm()
    }
    
    private func getAlertContent(for type: AlertType) -> (String, String) {
        switch type {
        case .success:
            return ("Target Reached! 🎯", "Great job hitting your daily goal!")
        case .overTarget:
            return ("Watch Out! ⚠️", "You're well over your daily target. Consider slowing down.")
        case .tooHigh:
            return ("Health Warning! ⚠️", "This amount might be unsafe. Please reconsider.")
        case .invalid:
            return ("Invalid Input", "Please enter a valid amount.")
        }
    }
    
    private func clearForm() {
        calories = ""
        waterAmount = ""
    }
}

struct CategoryButton: View {
    let category: MealCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.displayName)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : getCategoryColor(icon: category.icon))
            .frame(width: 80, height: 80)
            .background(isSelected ? getCategoryColor(icon: category.icon) : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private func getCategoryColor(icon: String) -> Color {
        switch icon {
        case "sunrise.fill": return .orange
        case "sun.max.fill": return .yellow
        case "moon.stars.fill": return .purple
        case "leaf.fill": return .green
        case "drop.fill": return .blue
        default: return .gray
        }
    }
}

struct AddCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var dataManager = DataManager.shared
    @State private var categoryName: String = ""
    @State private var selectedIcon: String = "fork.knife"
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onComplete: (Bool) -> Void
    
    private let availableIcons = [
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "carrot.fill", "leaf.fill", "fish.fill", "birthday.cake.fill",
        "popcorn.fill", "wineglass.fill", "mug.fill", "drop.fill"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category Name", text: $categoryName)
                }
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 20) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.title)
                                    .foregroundColor(selectedIcon == icon ? .blue : .gray)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Add Category")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                    onComplete(false)
                },
                trailing: Button("Save") {
                    saveCategory()
                }
                .disabled(categoryName.isEmpty)
            )
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func saveCategory() {
        if categoryName.isEmpty {
            showingError = true
            errorMessage = "Please enter a category name"
            return
        }
        
        if let _ = dataManager.addCategory(name: categoryName, icon: selectedIcon) {
            dismiss()
            onComplete(true)
        } else {
            showingError = true
            errorMessage = "A category with this name already exists"
        }
    }
}

struct AddConsumptionView_Previews: PreviewProvider {
    static var previews: some View {
        AddConsumptionView()
            .environmentObject(DataManager.shared)
    }
}
