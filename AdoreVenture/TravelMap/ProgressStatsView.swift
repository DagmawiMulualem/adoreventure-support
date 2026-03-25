//
//  ProgressStatsView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI

struct ProgressStatsView: View {
    @ObservedObject var travelMapService: TravelMapService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Overall Progress
                        OverallProgressView(travelMapService: travelMapService)
                        
                        // Continent Breakdown
                        ContinentBreakdownView(travelMapService: travelMapService)
                        
                        // Status Distribution
                        StatusDistributionView(travelMapService: travelMapService)
                        
                        // Recent Activity
                        RecentActivityView(travelMapService: travelMapService)
                        
                        // Goals and Milestones
                        GoalsMilestonesView(travelMapService: travelMapService)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Progress Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Overall Progress View
struct OverallProgressView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Overall Progress")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            // World Progress Circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 12)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: travelMapService.travelStatistics.worldProgress.avClampedUnitInterval)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.5), value: travelMapService.travelStatistics.worldProgress)
                
                VStack(spacing: 4) {
                    Text("\(Int(travelMapService.travelStatistics.worldProgress.avClampedUnitInterval * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("World Explored")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            // Stats Grid
            HStack(spacing: 20) {
                StatItemView(
                    title: "Visited",
                    value: "\(travelMapService.travelStatistics.visitedCountries)",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                StatItemView(
                    title: "Wishlist",
                    value: "\(travelMapService.travelStatistics.wishlistCountries)",
                    color: .blue,
                    icon: "heart.fill"
                )
                
                StatItemView(
                    title: "Skipped",
                    value: "\(travelMapService.travelStatistics.skippedCountries)",
                    color: .red,
                    icon: "xmark.circle.fill"
                )
            }
        }
        .padding(24)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Stat Item View
struct StatItemView: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Continent Breakdown View
struct ContinentBreakdownView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Continent Breakdown")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            LazyVStack(spacing: 12) {
                ForEach(Continent.allCases, id: \.self) { continent in
                    ContinentProgressRowView(
                        continent: continent,
                        travelMapService: travelMapService
                    )
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Continent Progress Row View
struct ContinentProgressRowView: View {
    let continent: Continent
    @ObservedObject var travelMapService: TravelMapService
    
    var visitedCount: Int {
        travelMapService.getCountries(in: continent).filter { $0.travelStatus == .visited }.count
    }
    
    var totalCount: Int {
        travelMapService.getCountries(in: continent).count
    }
    
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCount)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Continent Icon
            Image(systemName: continent.icon)
                .font(.title3)
                .foregroundStyle(continent.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(continent.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                ProgressView(value: progress.avClampedUnitInterval)
                    .progressViewStyle(LinearProgressViewStyle(tint: continent.color))
                    .scaleEffect(y: 1.5)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(visitedCount)/\(totalCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("\(Int(progress.avClampedUnitInterval * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Status Distribution View
struct StatusDistributionView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var statusData: [StatusData] {
        [
            StatusData(status: .visited, count: travelMapService.travelStatistics.visitedCountries, color: .green),
            StatusData(status: .wishlist, count: travelMapService.travelStatistics.wishlistCountries, color: .blue),
            StatusData(status: .skipped, count: travelMapService.travelStatistics.skippedCountries, color: .red),
            StatusData(status: .untouched, count: travelMapService.travelStatistics.totalCountries - travelMapService.travelStatistics.visitedCountries - travelMapService.travelStatistics.wishlistCountries - travelMapService.travelStatistics.skippedCountries, color: .gray)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Status Distribution")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            // Simple bar chart representation
            VStack(spacing: 12) {
                ForEach(statusData, id: \.status) { data in
                    HStack(spacing: 12) {
                        Image(systemName: data.status.icon)
                            .font(.subheadline)
                            .foregroundStyle(data.color)
                            .frame(width: 20)
                        
                        Text(data.status.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(width: 80, alignment: .leading)
                        
                        // Bar representation (avoid division by zero / NaN)
                        GeometryReader { geometry in
                            let total = travelMapService.travelStatistics.totalCountries
                            let barWidth: CGFloat = {
                                guard total > 0, geometry.size.width.isFinite, !geometry.size.width.isNaN else { return 0 }
                                let ratio = Double(data.count) / Double(total)
                                let w = geometry.size.width * CGFloat(ratio)
                                return w.sanitizedForLayout
                            }()
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 8)
                                Rectangle()
                                    .fill(data.color)
                                    .frame(width: barWidth, height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        Text("\(data.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Status Data
struct StatusData {
    let status: TravelStatus
    let count: Int
    let color: Color
}

// MARK: - Recent Activity View
struct RecentActivityView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            if travelMapService.travelStatistics.recentVisits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("No recent visits")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(travelMapService.travelStatistics.recentVisits.prefix(5)) { country in
                        RecentActivityRowView(country: country)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Recent Activity Row View
struct RecentActivityRowView: View {
    let country: Country
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: country.continent.icon)
                .font(.subheadline)
                .foregroundStyle(country.continent.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(country.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                if let visitDate = country.formattedVisitDate {
                    Text("Visited \(visitDate)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        }
    }
}

// MARK: - Goals and Milestones View
struct GoalsMilestonesView: View {
    @ObservedObject var travelMapService: TravelMapService
    
    var upcomingMilestones: [Achievement] {
        travelMapService.achievements
            .filter { !$0.isUnlocked && $0.progress > 0 }
            .sorted { $0.progress > $1.progress }
            .prefix(3)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Milestones")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            if upcomingMilestones.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("No active milestones")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(upcomingMilestones) { achievement in
                        MilestoneRowView(achievement: achievement)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Milestone Row View
struct MilestoneRowView: View {
    let achievement: Achievement
    
    var progress: Double {
        guard achievement.requirement > 0 else { return 0 }
        return Double(achievement.progress) / Double(achievement.requirement)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.subheadline)
                .foregroundStyle(achievement.category.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                ProgressView(value: progress.avClampedUnitInterval)
                    .progressViewStyle(LinearProgressViewStyle(tint: achievement.category.color))
                    .scaleEffect(y: 1.2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(achievement.progress)/\(achievement.requirement)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Text("\(Int(progress.avClampedUnitInterval * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

#Preview {
    ProgressStatsView(travelMapService: TravelMapService.shared)
}
