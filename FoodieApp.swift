//  FoodieApp.swift
//  Foodie iOS App
//
//  Created by Nwaimo C P (FCES) on 11/02/2025.
//
import SwiftUI
import SwiftData

@main
struct FoodieApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(notificationManager)
                .onAppear {
                    // Schedule notifications if enabled
                    if notificationManager.isNotificationsEnabled {
                        notificationManager.scheduleNotifications()
                    }
                }
        }
        .modelContainer(for: [ConsumptionItem.self, MealCategory.self])
    }
}
