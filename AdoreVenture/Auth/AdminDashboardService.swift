import Foundation
import FirebaseFirestore
import FirebaseFunctions

struct UsageStats {
    let reads: Int
    let writes: Int
    let deletes: Int
    let date: Date
    let estimatedCost: Double
}

struct BillingInfo {
    let currentBalance: Double
    let currency: String
    let lastPaymentDate: Date?
    let nextBillingDate: Date?
}

struct UserAnalytics {
    let totalUsers: Int
    let activeUsers: Int
    let newUsersThisWeek: Int
    let averageUsagePerUser: Double
}

class AdminDashboardService: ObservableObject {
    static let shared = AdminDashboardService()
    
    @Published var usageStats: UsageStats?
    @Published var billingInfo: BillingInfo?
    @Published var userAnalytics: UserAnalytics?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Fetch Usage Statistics
    
    func fetchUsageStats() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data: [String: Any] = ["timeRange": "week"]
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await Functions.functions(region: "us-central1").httpsCallable("getUsageStats").call(data).data
            }
            guard let response = raw as? [String: Any] else {
                throw NSError(domain: "AdminDashboardError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            let stats = UsageStats(
                reads: response["reads"] as? Int ?? 0,
                writes: response["writes"] as? Int ?? 0,
                deletes: response["deletes"] as? Int ?? 0,
                date: Date(),
                estimatedCost: calculateEstimatedCost(
                    reads: response["reads"] as? Int ?? 0,
                    writes: response["writes"] as? Int ?? 0,
                    deletes: response["deletes"] as? Int ?? 0
                )
            )
            
            await MainActor.run {
                self.usageStats = stats
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                print("Error fetching usage stats: \(error)")
                self.errorMessage = "Failed to load usage statistics"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Fetch Billing Information
    
    func fetchBillingInfo() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await Functions.functions(region: "us-central1").httpsCallable("getBillingInfo").call().data
            }
            guard let response = raw as? [String: Any] else {
                throw NSError(domain: "AdminDashboardError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            let billing = BillingInfo(
                currentBalance: response["balance"] as? Double ?? 0.0,
                currency: response["currency"] as? String ?? "USD",
                lastPaymentDate: response["lastPaymentDate"] as? Date,
                nextBillingDate: response["nextBillingDate"] as? Date
            )
            
            await MainActor.run {
                self.billingInfo = billing
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                print("Error fetching billing info: \(error)")
                self.errorMessage = "Failed to load billing information"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Fetch User Analytics
    
    func fetchUserAnalytics() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let raw = try await FirebaseHTTPSCallableGate.shared.performCallableDataOnMainActor {
                try await Functions.functions(region: "us-central1").httpsCallable("getUserAnalytics").call().data
            }
            guard let response = raw as? [String: Any] else {
                throw NSError(domain: "AdminDashboardError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            let analytics = UserAnalytics(
                totalUsers: response["totalUsers"] as? Int ?? 0,
                activeUsers: response["activeUsers"] as? Int ?? 0,
                newUsersThisWeek: response["newUsersThisWeek"] as? Int ?? 0,
                averageUsagePerUser: response["averageUsagePerUser"] as? Double ?? 0.0
            )
            
            await MainActor.run {
                self.userAnalytics = analytics
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                print("Error fetching user analytics: \(error)")
                self.errorMessage = "Failed to load user analytics"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Refresh All Data
    
    func refreshAllData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            async let usageTask = fetchUsageStats()
            async let billingTask = fetchBillingInfo()
            async let analyticsTask = fetchUserAnalytics()
            
            // Wait for all tasks to complete
            _ = try await (usageTask, billingTask, analyticsTask)
            
            await MainActor.run {
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                print("Error refreshing dashboard data: \(error)")
                self.errorMessage = "Failed to refresh dashboard data"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateEstimatedCost(reads: Int, writes: Int, deletes: Int) -> Double {
        // Firebase pricing (as of 2024):
        // Firestore: $0.18 per 100K reads, $0.18 per 100K writes, $0.02 per 100K deletes
        let readCost = Double(reads) * 0.18 / 100000
        let writeCost = Double(writes) * 0.18 / 100000
        let deleteCost = Double(deletes) * 0.02 / 100000
        
        return readCost + writeCost + deleteCost
    }
}
