import Foundation
import SwiftData

enum DefaultMealCategory: String, CaseIterable, Codable {
    case breakfast
    case lunch
    case dinner
    case snack
    case drink
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        case .drink: return "drop.fill"
        }
    }
    
    var displayName: String {
        self.rawValue.capitalized
    }
}

@Model
final class MealCategory {
    var id: UUID
    var name: String
    var icon: String
    var isDefault: Bool
    
    init(id: UUID = UUID(), name: String, icon: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isDefault = isDefault
    }
    
    var displayName: String {
        name.capitalized
    }
}

@Model
final class ConsumptionItem {
    var id: UUID
    var categoryId: UUID
    var categoryName: String // Store category name for display purposes
    var categoryIcon: String // Store icon for display purposes
    var calories: Int
    var timestamp: Date
    var waterAmount: Double?
    
    init(id: UUID = UUID(), categoryId: UUID, categoryName: String, categoryIcon: String, calories: Int, timestamp: Date, waterAmount: Double? = nil) {
        self.id = id
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.calories = calories
        self.timestamp = timestamp
        self.waterAmount = waterAmount
    }
}
