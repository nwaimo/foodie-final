import Foundation
import SwiftUI
import SwiftData

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published private(set) var dailyCalories: Int = 0
    @Published private(set) var dailyWater: Double = 0
    @Published private(set) var waterTarget: Double = 2.0  // Default value
    @Published private(set) var calorieTarget: Int = 2000  // Default value
    @Published private(set) var categories: [MealCategory] = []
    
    // Notification thresholds
    private var lastCalorieNotificationThreshold: Double = 0.0
    private var lastWaterNotificationThreshold: Double = 0.0
    
    private let calendar = Calendar.current
    private let queue = DispatchQueue(label: "com.foodieapp.dataqueue")
    
    // SwiftData container reference
    var modelContainer: ModelContainer?
    var modelContext: ModelContext?
    
    private init() {
        setupSwiftData()
        
        // Load saved values after properties are initialized
        if let savedWaterTarget = UserDefaults.standard.object(forKey: "WaterTarget") as? Double {
            waterTarget = savedWaterTarget
        }
        
        if let savedCalorieTarget = UserDefaults.standard.object(forKey: "CalorieTarget") as? Int {
            calorieTarget = savedCalorieTarget
        }
        
        setupMidnightReset()
        loadTodayData()
        loadCategories()
    }
    
    private func setupSwiftData() {
        do {
            let schema = Schema([ConsumptionItem.self, MealCategory.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if let container = modelContainer {
                modelContext = ModelContext(container)
                createDefaultCategoriesIfNeeded()
            }
        } catch {
            print("Failed to set up SwiftData: \(error)")
        }
    }
    
    private func createDefaultCategoriesIfNeeded() {
        guard let context = modelContext else { return }
        
        // Check if we already have categories
        do {
            let descriptor = FetchDescriptor<MealCategory>()
            let existingCategories = try context.fetch(descriptor)
            
            if existingCategories.isEmpty {
                // Create default categories
                for category in DefaultMealCategory.allCases {
                    let newCategory = MealCategory(
                        name: category.rawValue,
                        icon: category.icon,
                        isDefault: true
                    )
                    context.insert(newCategory)
                }
                
                try context.save()
                loadCategories()
            }
        } catch {
            print("Failed to check or create default categories: \(error)")
        }
    }
    
    func loadCategories() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<MealCategory>(sortBy: [SortDescriptor(\.name)])
            let fetchedCategories = try context.fetch(descriptor)
            
            DispatchQueue.main.async {
                self.categories = fetchedCategories
            }
        } catch {
            print("Failed to load categories: \(error)")
        }
    }
    
    func addCategory(name: String, icon: String) -> MealCategory? {
        guard let context = modelContext else { return nil }
        
        // Check if category with this name already exists
        do {
            let descriptor = FetchDescriptor<MealCategory>(
                predicate: #Predicate<MealCategory> { category in
                    category.name.lowercased() == name.lowercased()
                }
            )
            
            let existingCategories = try context.fetch(descriptor)
            if !existingCategories.isEmpty {
                return nil // Category already exists
            }
            
            let newCategory = MealCategory(
                name: name,
                icon: icon,
                isDefault: false
            )
            
            context.insert(newCategory)
            try context.save()
            
            loadCategories()
            return newCategory
        } catch {
            print("Failed to add category: \(error)")
            return nil
        }
    }
    
    func deleteCategory(id: UUID) -> Bool {
        guard let context = modelContext else { return false }
        
        do {
            let descriptor = FetchDescriptor<MealCategory>(
                predicate: #Predicate<MealCategory> { category in
                    category.id == id && !category.isDefault
                }
            )
            
            let categoriesToDelete = try context.fetch(descriptor)
            guard let categoryToDelete = categoriesToDelete.first else {
                return false // Category not found or is a default category
            }
            
            // Check if there are consumption items using this category
            let itemsDescriptor = FetchDescriptor<ConsumptionItem>(
                predicate: #Predicate<ConsumptionItem> { item in
                    item.categoryId == id
                }
            )
            
            let itemsUsingCategory = try context.fetch(itemsDescriptor)
            if !itemsUsingCategory.isEmpty {
                return false // Category is in use
            }
            
            context.delete(categoryToDelete)
            try context.save()
            
            loadCategories()
            return true
        } catch {
            print("Failed to delete category: \(error)")
            return false
        }
    }
    
    var previousDayCalories: Int {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        return getCalories(for: yesterday)
    }
    
    var averageDailyCalories: Int {
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        guard let context = modelContext else { return 0 }
        
        do {
            let descriptor = FetchDescriptor<ConsumptionItem>(
                predicate: #Predicate<ConsumptionItem> { item in
                    item.timestamp >= thirtyDaysAgo
                }
            )
            
            let recentHistory = try context.fetch(descriptor)
            guard !recentHistory.isEmpty else { return 0 }
            
            let totalCalories = recentHistory.reduce(0) { $0 + $1.calories }
            return totalCalories / 30
        } catch {
            print("Failed to fetch average calories: \(error)")
            return 0
        }
    }
    
    func getConsumptionHistory(startDate: Date, endDate: Date) -> [ConsumptionItem] {
        guard let context = modelContext else { return [] }
        
        do {
            let descriptor = FetchDescriptor<ConsumptionItem>(
                predicate: #Predicate<ConsumptionItem> { item in
                    item.timestamp >= startDate && item.timestamp < endDate
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch consumption history: \(error)")
            return []
        }
    }
    
    func getWeeklyData(weeks: Int = 4) -> [(weekStart: Date, items: [ConsumptionItem])] {
        var result: [(weekStart: Date, items: [ConsumptionItem])] = []
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        
        // Calculate the number of days to go back based on the selected time range
        let daysToGoBack: Int
        switch weeks {
        case 1: // Week
            daysToGoBack = 7
        case 4: // Month
            daysToGoBack = 30
        case 12: // 3 Months
            daysToGoBack = 90
        default:
            daysToGoBack = 7 * weeks
        }
        
        // Calculate the start date (going back the appropriate number of days)
        let startDate = calendar.date(byAdding: .day, value: -daysToGoBack + 1, to: startOfToday)!
        
        // Group the data by week
        for i in 0..<weeks {
            let currentWeekStart = calendar.date(byAdding: .day, value: 7 * i, to: startDate)!
            let currentWeekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
            
            let items = getConsumptionHistory(startDate: currentWeekStart, endDate: currentWeekEnd)
            result.append((weekStart: currentWeekStart, items: items))
        }
        
        return result.reversed() // Return in reverse order so most recent week is first
    }
    
    var isOverCalorieTarget: Bool {
        dailyCalories > calorieTarget
    }
    
    var calorieProgress: Double {
        Double(dailyCalories) / Double(calorieTarget)
    }
    
    var waterProgress: Double {
        dailyWater / waterTarget
    }
    
    var healthStatus: HealthStatus {
        if calorieProgress >= 1.0 && waterProgress >= 1.0 {
            return .excellent
        } else if calorieProgress >= 1.0 {
            return .needsWater
        } else if waterProgress >= 1.0 {
            return .needsCalories
        }
        return .normal
    }
    
    func updateWaterTarget(_ newValue: Double) {
        waterTarget = newValue
        UserDefaults.standard.set(newValue, forKey: "WaterTarget")
        
        // Reset notification thresholds when target changes
        lastWaterNotificationThreshold = 0.0
        
        // Check if we need to send a notification based on the new target
        checkAndSendProgressNotifications()
    }
    
    func updateCalorieTarget(_ newValue: Int) {
        calorieTarget = newValue
        UserDefaults.standard.set(newValue, forKey: "CalorieTarget")
        
        // Reset notification thresholds when target changes
        lastCalorieNotificationThreshold = 0.0
        
        // Check if we need to send a notification based on the new target
        checkAndSendProgressNotifications()
    }
    
    func addConsumption(categoryId: UUID, categoryName: String, categoryIcon: String, calories: Int, waterAmount: Double? = nil) {
        guard let context = modelContext else { return }
        
        let item = ConsumptionItem(
            categoryId: categoryId,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            calories: calories,
            timestamp: Date(),
            waterAmount: waterAmount
        )
        
        queue.async {
            context.insert(item)
            
            do {
                try context.save()
                
                DispatchQueue.main.async {
                    if let water = item.waterAmount {
                        self.dailyWater += water
                    } else {
                        self.dailyCalories += item.calories
                    }
                    
                    // Check if we need to send a notification
                    self.checkAndSendProgressNotifications()
                }
            } catch {
                print("Failed to save consumption item: \(error)")
            }
        }
    }
    
    private func checkAndSendProgressNotifications() {
        let notificationManager = NotificationManager.shared
        
        // Define notification thresholds
        let thresholds: [Double] = [0.25, 0.5, 0.75, 1.0]
        
        // Check calorie progress
        let currentCalorieProgress = calorieProgress
        for threshold in thresholds {
            if currentCalorieProgress >= threshold && lastCalorieNotificationThreshold < threshold {
                notificationManager.scheduleProgressNotification(
                    progress: currentCalorieProgress,
                    type: "calorie"
                )
                lastCalorieNotificationThreshold = threshold
                break
            }
        }
        
        // Check water progress
        let currentWaterProgress = waterProgress
        for threshold in thresholds {
            if currentWaterProgress >= threshold && lastWaterNotificationThreshold < threshold {
                notificationManager.scheduleProgressNotification(
                    progress: currentWaterProgress,
                    type: "water"
                )
                lastWaterNotificationThreshold = threshold
                break
            }
        }
    }
    
    func validateIntake(calories: Int? = nil, water: Double? = nil) -> IntakeStatus {
        if let calories = calories {
            let newTotal = dailyCalories + calories
            let newProgress = Double(newTotal) / Double(calorieTarget)
            
            if newTotal > 5000 {
                return .dangerous
            } else if newProgress >= 1.5 {
                return .excessive
            } else if newProgress >= 1.0 {
                return .targetReached
            }
        }
        
        if let water = water {
            let newTotal = dailyWater + water
            let newProgress = newTotal / waterTarget
            
            if newProgress >= 2.0 {
                return .dangerous
            } else if newProgress >= 1.5 {
                return .excessive
            } else if newProgress >= 1.0 {
                return .targetReached
            }
        }
        
        return .normal
    }
    
    func resetDaily() {
        dailyCalories = 0
        dailyWater = 0
        
        // Reset notification thresholds
        lastCalorieNotificationThreshold = 0.0
        lastWaterNotificationThreshold = 0.0
    }
    
    private func setupMidnightReset() {
        // Use NotificationCenter for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Schedule a timer for midnight reset
        scheduleResetTimer()
    }
    
    private func scheduleResetTimer() {
        // Calculate time until next midnight
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: now.addingTimeInterval(86400))
        let timeInterval = tomorrow.timeIntervalSince(now)
        
        // Schedule a timer to reset at midnight
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) { [weak self] in
            guard let self = self else { return }
            
            // Reset the daily values
            self.resetDaily()
            
            // Schedule the next day's timer
            self.scheduleResetTimer()
        }
        
        // Also save the next reset time to UserDefaults
        UserDefaults.standard.set(tomorrow, forKey: "NextResetTime")
    }
    
    @objc private func appDidBecomeActive() {
        // Check if we need to reset data when app becomes active
        let now = Date()
        let currentDay = calendar.startOfDay(for: now)
        
        // Check if we missed a reset while the app was inactive
        if let nextResetTime = UserDefaults.standard.object(forKey: "NextResetTime") as? Date,
           nextResetTime < now {
            resetDaily()
            scheduleResetTimer() // Reschedule the timer
        } else if let lastActiveDay = UserDefaults.standard.object(forKey: "LastActiveDay") as? Date,
                  !calendar.isDate(lastActiveDay, inSameDayAs: currentDay) {
            resetDaily()
        }
        
        UserDefaults.standard.set(now, forKey: "LastActiveDay")
        loadTodayData()
    }
    
    private func getCalories(for date: Date) -> Int {
        guard let context = modelContext else { return 0 }
        
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            let descriptor = FetchDescriptor<ConsumptionItem>(
                predicate: #Predicate<ConsumptionItem> { item in
                    item.timestamp >= startOfDay && item.timestamp < endOfDay
                }
            )
            
            let items = try context.fetch(descriptor)
            return items.reduce(0) { $0 + $1.calories }
        } catch {
            print("Failed to fetch calories: \(error)")
            return 0
        }
    }
    
    private func loadTodayData() {
        guard let context = modelContext else { return }
        
        // Calculate today's totals
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        do {
            let descriptor = FetchDescriptor<ConsumptionItem>(
                predicate: #Predicate<ConsumptionItem> { item in
                    item.timestamp >= today && item.timestamp < tomorrow
                }
            )
            
            let todayItems = try context.fetch(descriptor)
            
            dailyCalories = todayItems.reduce(0) { total, item in
                total + (item.waterAmount == nil ? item.calories : 0)
            }
            
            dailyWater = todayItems.reduce(0.0) { total, item in
                total + (item.waterAmount ?? 0.0)
            }
            
            // Check if we need to send notifications based on current progress
            checkAndSendProgressNotifications()
        } catch {
            print("Failed to load today's data: \(error)")
        }
    }
}

enum CalorieStatus {
    case normal
    case aboveTarget
    case tooHigh
}

enum HealthStatus {
    case normal, excellent, needsWater, needsCalories
}

enum IntakeStatus {
    case normal, targetReached, excessive, dangerous
}
