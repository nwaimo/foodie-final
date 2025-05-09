import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            NavigationView {
                DailySummaryView()
                    .navigationTitle("Summary")
            }
            .tabItem {
                Label("Summary", systemImage: "chart.bar.fill")
            }
            
            NavigationView {
                AddConsumptionView()
                    .navigationTitle("Add Consumption")
            }
            .tabItem {
                Label("Add", systemImage: "plus.circle.fill")
            }
            
            NavigationView {
                HistoryView()
                    .navigationTitle("History")
            }
            .tabItem {
                Label("History", systemImage: "clock.fill")
            }
            
            NavigationView {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .accentColor(.blue)
        .onAppear {
            // Ensure the DataManager has access to the SwiftData context
            if dataManager.modelContext == nil {
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    // Use the modelContext from the environment
                    // The container property is not optional, so we don't need to unwrap it
                    dataManager.modelContainer = modelContext.container
                    dataManager.modelContext = modelContext
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataManager.shared)
            .environmentObject(NotificationManager.shared)
            .modelContainer(for: [ConsumptionItem.self, MealCategory.self])
    }
}
