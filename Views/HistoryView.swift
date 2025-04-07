import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedTimeRange: TimeRange = .week
    @State private var weeklyData: [(weekStart: Date, items: [ConsumptionItem])] = []
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedTimeRange) { _, newValue in
                    loadData(for: newValue)
                }
                
                // Charts
                VStack(spacing: 15) {
                    // Calories Chart
                    VStack(alignment: .leading) {
                        Text("Calories")
                            .font(.headline)
                        
                        Chart {
                            ForEach(getDailyCalorieData(), id: \.date) { item in
                                BarMark(
                                    x: .value("Day", item.date, unit: .day),
                                    y: .value("Calories", item.calories)
                                )
                                .foregroundStyle(Color.orange.gradient)
                            }
                            
                            RuleMark(y: .value("Target", dataManager.calorieTarget))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                .foregroundStyle(.red)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Target")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Water Chart
                    VStack(alignment: .leading) {
                        Text("Water")
                            .font(.headline)
                        
                        Chart {
                            ForEach(getDailyWaterData(), id: \.date) { item in
                                BarMark(
                                    x: .value("Day", item.date, unit: .day),
                                    y: .value("Water (L)", item.water)
                                )
                                .foregroundStyle(Color.blue.gradient)
                            }
                            
                            RuleMark(y: .value("Target", dataManager.waterTarget))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                .foregroundStyle(.red)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Target")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
                
                // Recent History List
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Entries")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(getRecentItems()) { item in
                        HistoryItemRow(item: item)
                    }
                }
                .padding(.vertical)
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadData(for: selectedTimeRange)
        }
    }
    
    private func loadData(for timeRange: TimeRange) {
        let weeksToLoad: Int
        
        switch timeRange {
        case .week:
            weeksToLoad = 1
        case .month:
            weeksToLoad = 4
        case .threeMonths:
            weeksToLoad = 12
        }
        
        weeklyData = dataManager.getWeeklyData(weeks: weeksToLoad)
    }
    
    private func getDailyCalorieData() -> [(date: Date, calories: Int)] {
        let calendar = Calendar.current
        var result: [(date: Date, calories: Int)] = []
        
        // Get the date range based on selected time range
        let endDate = Date()
        let startDate: Date
        
        switch selectedTimeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate))!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: endDate))!
        case .threeMonths:
            startDate = calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: endDate))!
        }
        
        // Create a date for each day in the range
        var currentDate = startDate
        while currentDate <= endDate {
            let dayItems = weeklyData.flatMap { $0.items }.filter { item in
                calendar.isDate(item.timestamp, inSameDayAs: currentDate)
            }
            
            let totalCalories = dayItems.reduce(0) { total, item in
                // Only count food items (where waterAmount is nil)
                total + (item.waterAmount == nil ? item.calories : 0)
            }
            
            result.append((date: currentDate, calories: totalCalories))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return result
    }
    
    private func getDailyWaterData() -> [(date: Date, water: Double)] {
        let calendar = Calendar.current
        var result: [(date: Date, water: Double)] = []
        
        // Get the date range based on selected time range
        let endDate = Date()
        let startDate: Date
        
        switch selectedTimeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate))!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: endDate))!
        case .threeMonths:
            startDate = calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: endDate))!
        }
        
        // Create a date for each day in the range
        var currentDate = startDate
        while currentDate <= endDate {
            let dayItems = weeklyData.flatMap { $0.items }.filter { item in
                calendar.isDate(item.timestamp, inSameDayAs: currentDate)
            }
            
            let totalWater = dayItems.reduce(0.0) { total, item in
                // Only count water items (where waterAmount is not nil)
                total + (item.waterAmount ?? 0.0)
            }
            
            result.append((date: currentDate, water: totalWater))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return result
    }
    
    private func getRecentItems() -> [ConsumptionItem] {
        // Get the most recent 10 items
        return Array(weeklyData.flatMap { $0.items }.prefix(10))
    }
}

struct HistoryItemRow: View {
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
                
                Text(formattedDate)
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
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
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
        default: return .gray
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(DataManager.shared)
    }
}
