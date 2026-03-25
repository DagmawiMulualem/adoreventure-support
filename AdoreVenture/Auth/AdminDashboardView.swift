import SwiftUI
import Charts

struct AdminDashboardView: View {
    @StateObject private var dashboardService = AdminDashboardService.shared
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case day = "24 Hours"
        case week = "7 Days"
        case month = "30 Days"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Usage Statistics
                    if let stats = dashboardService.usageStats {
                        usageStatsSection(stats)
                    }
                    
                    // Billing Information
                    if let billing = dashboardService.billingInfo {
                        billingSection(billing)
                    }
                    
                    // User Analytics
                    if let analytics = dashboardService.userAnalytics {
                        userAnalyticsSection(analytics)
                    }
                    
                    // Error Display
                    if let errorMessage = dashboardService.errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    // Loading Indicator
                    if dashboardService.isLoading {
                        loadingSection
                    }
                }
                .padding()
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await dashboardService.refreshAllData()
                }
            }
            .onChange(of: selectedTimeRange) { _, _ in
                Task {
                    await dashboardService.refreshAllData()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Firebase Usage & Analytics")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Monitor your app's performance and costs")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
    
    // MARK: - Usage Statistics Section
    
    private func usageStatsSection(_ stats: UsageStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                AdminStatCard(
                    title: "Reads",
                    value: formatNumber(stats.reads),
                    icon: "eye.fill",
                    color: .blue
                )
                
                AdminStatCard(
                    title: "Writes",
                    value: formatNumber(stats.writes),
                    icon: "pencil.fill",
                    color: .orange
                )
                
                AdminStatCard(
                    title: "Deletes",
                    value: formatNumber(stats.deletes),
                    icon: "trash.fill",
                    color: .red
                )
            }
            
            // Estimated Cost
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                Text("Estimated Cost:")
                    .fontWeight(.medium)
                Spacer()
                Text("$\(String(format: "%.4f", stats.estimatedCost))")
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Billing Section
    
    private func billingSection(_ billing: BillingInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Billing Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.blue)
                    Text("Current Balance:")
                    Spacer()
                    Text("\(billing.currency) \(String(format: "%.2f", billing.currentBalance))")
                        .fontWeight(.bold)
                }
                
                if let lastPayment = billing.lastPaymentDate {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.green)
                        Text("Last Payment:")
                        Spacer()
                        Text(lastPayment, style: .date)
                            .font(.caption)
                    }
                }
                
                if let nextBilling = billing.nextBillingDate {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.orange)
                        Text("Next Billing:")
                        Spacer()
                        Text(nextBilling, style: .date)
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - User Analytics Section
    
    private func userAnalyticsSection(_ analytics: UserAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("User Analytics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                AdminStatCard(
                    title: "Total Users",
                    value: formatNumber(analytics.totalUsers),
                    icon: "person.3.fill",
                    color: .blue
                )
                
                AdminStatCard(
                    title: "Active Users",
                    value: formatNumber(analytics.activeUsers),
                    icon: "person.fill.checkmark",
                    color: .green
                )
                
                AdminStatCard(
                    title: "New This Week",
                    value: formatNumber(analytics.newUsersThisWeek),
                    icon: "person.badge.plus",
                    color: .orange
                )
                
                AdminStatCard(
                    title: "Avg Usage/User",
                    value: String(format: "%.1f", analytics.averageUsagePerUser),
                    icon: "chart.bar.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title2)
            
            Text("Error")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemRed).opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading dashboard data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
}

// MARK: - Admin Stat Card Component

struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    AdminDashboardView()
}
