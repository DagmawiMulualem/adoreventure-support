//
//  TravelMapShareService.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
class TravelMapShareService: ObservableObject {
    static let shared = TravelMapShareService()
    
    private init() {}
    
    // MARK: - Share Data Generation
    
    /// Generate comprehensive travel data for sharing
    func generateShareData(from travelMapService: TravelMapService) -> [String: Any] {
        let visitedCountries = travelMapService.getCountries(by: .visited)
        let wishlistCountries = travelMapService.getCountries(by: .wishlist)
        let unlockedAchievements = travelMapService.achievements.filter { $0.isUnlocked }
        
        return [
            "visitedCountries": visitedCountries.map { $0.name },
            "wishlistCountries": wishlistCountries.map { $0.name },
            "worldProgress": travelMapService.travelStatistics.worldProgress,
            "continentProgress": travelMapService.travelStatistics.continentProgress.mapValues { $0 },
            "achievements": unlockedAchievements.map { $0.title },
            "totalVisited": visitedCountries.count,
            "totalCountries": travelMapService.travelStatistics.totalCountries,
            "exportDate": Date(),
            "appName": "AdoreVenture"
        ]
    }
    
    /// Generate a formatted text summary for sharing
    func generateTextSummary(from travelMapService: TravelMapService) -> String {
        let visitedCount = travelMapService.travelStatistics.visitedCountries
        let totalCount = travelMapService.travelStatistics.totalCountries
        let worldProgress = Int(travelMapService.travelStatistics.worldProgress * 100)
        let visitedCountries = travelMapService.getCountries(by: .visited)
        let achievements = travelMapService.achievements.filter { $0.isUnlocked }
        
        var summary = "🌍 My Travel Journey with AdoreVenture\n\n"
        summary += "📊 Progress: \(visitedCount)/\(totalCount) countries (\(worldProgress)% of the world)\n\n"
        
        if !visitedCountries.isEmpty {
            summary += "✅ Countries I've Visited:\n"
            for country in visitedCountries.prefix(10) {
                summary += "• \(country.name)\n"
            }
            if visitedCountries.count > 10 {
                summary += "• ... and \(visitedCountries.count - 10) more!\n"
            }
            summary += "\n"
        }
        
        if !achievements.isEmpty {
            summary += "🏆 Achievements Unlocked:\n"
            for achievement in achievements.prefix(5) {
                summary += "• \(achievement.title)\n"
            }
            if achievements.count > 5 {
                summary += "• ... and \(achievements.count - 5) more!\n"
            }
            summary += "\n"
        }
        
        summary += "Download AdoreVenture to start your own travel journey! 🚀"
        
        return summary
    }
    
    /// Generate a JSON export of travel data
    func generateJSONExport(from travelMapService: TravelMapService) -> String {
        let shareData = generateShareData(from: travelMapService)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: shareData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to generate JSON export\"}"
        }
    }
    
    /// Generate a CSV export of visited countries
    func generateCSVExport(from travelMapService: TravelMapService) -> String {
        let visitedCountries = travelMapService.getCountries(by: .visited)
        
        var csv = "Country,Continent,Visit Date,Notes\n"
        
        for country in visitedCountries {
            let visitDate = country.visitDate?.formatted(date: .abbreviated, time: .omitted) ?? ""
            let notes = (country.notes ?? "").replacingOccurrences(of: ",", with: ";")
            csv += "\"\(country.name)\",\"\(country.continent.displayName)\",\"\(visitDate)\",\"\(notes)\"\n"
        }
        
        return csv
    }
    
    // MARK: - Image Generation
    
    /// Generate a shareable image of the travel map
    func generateMapImage(from travelMapService: TravelMapService, size: CGSize = CGSize(width: 800, height: 600)) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background gradient
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemOrange.withAlphaComponent(0.95).cgColor,
                    UIColor.systemPink.withAlphaComponent(0.92).cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Title
            let titleText = "My Travel Journey"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let titleSize = titleText.size(withAttributes: titleAttributes)
            let titleRect = CGRect(
                x: (size.width - titleSize.width) / 2,
                y: 40,
                width: titleSize.width,
                height: titleSize.height
            )
            titleText.draw(in: titleRect, withAttributes: titleAttributes)
            
            // Progress circle
            let circleCenter = CGPoint(x: size.width / 2, y: 200)
            let circleRadius: CGFloat = 80
            
            // Background circle
            context.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            context.cgContext.setLineWidth(8)
            context.cgContext.addArc(center: circleCenter, radius: circleRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.cgContext.strokePath()
            
            // Progress arc (clamp so NaN/∞ never reach CoreGraphics)
            let progress = travelMapService.travelStatistics.worldProgress.avClampedUnitInterval
            let startAngle = -CGFloat.pi / 2
            let endAngle = startAngle + (CGFloat.pi * 2 * CGFloat(progress))
            
            context.cgContext.setStrokeColor(UIColor.systemGreen.cgColor)
            context.cgContext.setLineWidth(8)
            context.cgContext.setLineCap(.round)
            context.cgContext.addArc(center: circleCenter, radius: circleRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            context.cgContext.strokePath()
            
            // Progress text
            let progressText = "\(Int(progress * 100))%"
            let progressAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let progressSize = progressText.size(withAttributes: progressAttributes)
            let progressRect = CGRect(
                x: circleCenter.x - progressSize.width / 2,
                y: circleCenter.y - progressSize.height / 2,
                width: progressSize.width,
                height: progressSize.height
            )
            progressText.draw(in: progressRect, withAttributes: progressAttributes)
            
            // Stats
            let visitedCount = travelMapService.travelStatistics.visitedCountries
            let totalCount = travelMapService.travelStatistics.totalCountries
            let statsText = "\(visitedCount)/\(totalCount) Countries"
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
            let statsSize = statsText.size(withAttributes: statsAttributes)
            let statsRect = CGRect(
                x: (size.width - statsSize.width) / 2,
                y: circleCenter.y + 60,
                width: statsSize.width,
                height: statsSize.height
            )
            statsText.draw(in: statsRect, withAttributes: statsAttributes)
            
            // Recent countries
            let recentCountries = travelMapService.travelStatistics.recentVisits.prefix(5)
            if !recentCountries.isEmpty {
                let countriesTitle = "Recent Visits:"
                let countriesTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: UIColor.white
                ]
                let countriesTitleSize = countriesTitle.size(withAttributes: countriesTitleAttributes)
                let countriesTitleRect = CGRect(
                    x: 40,
                    y: 350,
                    width: countriesTitleSize.width,
                    height: countriesTitleSize.height
                )
                countriesTitle.draw(in: countriesTitleRect, withAttributes: countriesTitleAttributes)
                
                var yOffset: CGFloat = 380
                for country in recentCountries {
                    let countryText = "• \(country.name)"
                    let countryAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.9)
                    ]
                    let countrySize = countryText.size(withAttributes: countryAttributes)
                    let countryRect = CGRect(
                        x: 40,
                        y: yOffset,
                        width: countrySize.width,
                        height: countrySize.height
                    )
                    countryText.draw(in: countryRect, withAttributes: countryAttributes)
                    yOffset += 25
                }
            }
            
            // App branding
            let appText = "Created with AdoreVenture"
            let appAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]
            let appSize = appText.size(withAttributes: appAttributes)
            let appRect = CGRect(
                x: (size.width - appSize.width) / 2,
                y: size.height - 30,
                width: appSize.width,
                height: appSize.height
            )
            appText.draw(in: appRect, withAttributes: appAttributes)
        }
    }
    
    // MARK: - Share Options
    
    /// Get available share options
    func getShareOptions() -> [ShareOption] {
        return [
            ShareOption(
                id: "text",
                title: "Text Summary",
                description: "Share as formatted text",
                icon: "text.alignleft",
                color: .blue
            ),
            ShareOption(
                id: "image",
                title: "Map Image",
                description: "Share as image",
                icon: "photo",
                color: .green
            ),
            ShareOption(
                id: "json",
                title: "JSON Export",
                description: "Export as JSON data",
                icon: "doc.text",
                color: .orange
            ),
            ShareOption(
                id: "csv",
                title: "CSV Export",
                description: "Export as CSV file",
                icon: "tablecells",
                color: .purple
            )
        ]
    }
    
    /// Generate share content based on option
    func generateShareContent(for option: ShareOption, from travelMapService: TravelMapService) -> Any {
        switch option.id {
        case "text":
            return generateTextSummary(from: travelMapService)
        case "image":
            return generateMapImage(from: travelMapService) ?? UIImage()
        case "json":
            return generateJSONExport(from: travelMapService)
        case "csv":
            return generateCSVExport(from: travelMapService)
        default:
            return generateTextSummary(from: travelMapService)
        }
    }
}

// MARK: - Share Option Model
struct ShareOption: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
}

// MARK: - Share Options View
struct ShareOptionsView: View {
    @ObservedObject var travelMapService: TravelMapService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: ShareOption?
    @State private var showingShareSheet = false
    @State private var shareContent: Any?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                            
                            Text("Share Your Travel Journey")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text("Choose how you'd like to share your travel progress")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Share Options
                        LazyVStack(spacing: 16) {
                            ForEach(TravelMapShareService.shared.getShareOptions()) { option in
                                ShareOptionCard(
                                    option: option,
                                    isSelected: selectedOption?.id == option.id
                                ) {
                                    selectedOption = option
                                    shareContent = TravelMapShareService.shared.generateShareContent(for: option, from: travelMapService)
                                    showingShareSheet = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingShareSheet) {
            if let content = shareContent {
                ShareSheet(activityItems: [content])
            }
        }
    }
}

// MARK: - Share Option Card
struct ShareOptionCard: View {
    let option: ShareOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: option.icon)
                    .font(.title2)
                    .foregroundStyle(option.color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(option.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(20)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? option.color : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    ShareOptionsView(travelMapService: TravelMapService.shared)
}
