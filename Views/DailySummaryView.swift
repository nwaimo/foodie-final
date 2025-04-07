import SwiftUI
import SwiftData

struct DailySummaryView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var recentItems: [ConsumptionItem]
    
    init() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let predicate = #Predicate<ConsumptionItem> { item in
            item.timestamp >= today
        }
        
        _recentItems = Query(filter: predicate, sort: \ConsumptionItem.timestamp, order: .reverse)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Message
                StatusBanner(
                    icon: statusIcon,
                    color: statusColor,
                    message: statusMessage
                )
                .padding(.top, 10)
                
                // Progress Circles
                HStack(spacing: 30) {
                    // Water Progress
                    CircularProgressView(
                        progress: dataManager.waterProgress,
                        color: .blue,
                        title: "Water",
                        detail: String(format: "%.1f/%.1fL", dataManager.dailyWater, dataManager.waterTarget)
                    )
                    .frame(width: 150, height: 150)
                    
                    // Calorie Progress
                    CircularProgressView(
                        progress: dataManager.calorieProgress,
                        color: dataManager.isOverCalorieTarget ? .orange : .green,
                        title: "Calories",
                        detail: "\(dataManager.dailyCalories)/\(dataManager.calorieTarget)"
                    )
                    .frame(width: 150, height: 150)
                }
                .padding(.vertical)
                
                // Daily Statistics
                VStack(spacing: 15) {
                    StatisticRow(
                        icon: "clock.arrow.circlepath",
                        title: "Yesterday",
                        value: "\(dataManager.previousDayCalories) cal"
                    )
                    
                    StatisticRow(
                        icon: "chart.bar.fill",
                        title: "30-Day Average",
                        value: "\(dataManager.averageDailyCalories) cal"
                    )
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // Recent Entries
                if !recentItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today's Entries")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(recentItems) { item in
                            RecentEntryRow(item: item)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // Status properties based on health status
    private var statusIcon: String {
        switch dataManager.healthStatus {
        case .excellent: return "star.fill"
        case .needsWater: return "drop.fill"
        case .needsCalories: return "flame.fill"
        case .normal: return "heart.fill"
        }
    }
    
    private var statusColor: Color {
        switch dataManager.healthStatus {
        case .excellent: return .yellow
        case .needsWater: return .blue
        case .needsCalories: return .orange
        case .normal: return .green
        }
    }
    
    private var statusMessage: String {
        switch dataManager.healthStatus {
        case .excellent: return "Perfect Balance! 🌟"
        case .needsWater: return "Need more water!"
        case .needsCalories: return "Need more calories!"
        case .normal: return "Keep it up!"
        }
    }
}

struct RecentEntryRow: View {
    let item: ConsumptionItem
    
    var body: some View {
        HStack {
            Image(systemName: item.categoryIcon)
                .foregroundColor(getCategoryColor(icon: item.categoryIcon))
                .font(.headline)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(item.categoryName.capitalized)
                    .font(.headline)
                
                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let water = item.waterAmount {
                Text(String(format: "%.1f L", water))
                    .font(.headline)
                    .foregroundColor(.blue)
            } else {
                Text("\(item.calories) cal")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: item.timestamp)
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

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let title: String
    let detail: String
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: progress)
                
                VStack(spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(Int(progress * 100))%")
                        .font(.system(.title, design: .rounded))
                        .bold()
                }
            }
            
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
    }
}

struct StatusBanner: View {
    let icon: String
    let color: Color
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(message)
                .font(.headline)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct StatisticRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

struct DailySummaryView_Previews: PreviewProvider {
    static var previews: some View {
        DailySummaryView()
            .environmentObject(DataManager.shared)
    }
}
