//
//  IdeasListView.swift
//  AdoreVenture
//

//
//  IdeaDetailView.swift
//  AdoreVenture
//

import SwiftUI

// MARK: - Checklist Models

struct ChecklistItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var category: ChecklistCategory
    var order: Int
    
    enum ChecklistCategory: String, Codable, CaseIterable {
        case preparation = "Preparation"
        case booking = "Booking"
        case logistics = "Logistics"
        case personal = "Personal"
        case safety = "Safety"
        case enjoyment = "Enjoyment"
        
        var icon: String {
            switch self {
            case .preparation: return "checklist"
            case .booking: return "calendar.badge.plus"
            case .logistics: return "car.fill"
            case .personal: return "person.fill"
            case .safety: return "shield.fill"
            case .enjoyment: return "heart.fill"
            }
        }
        
        var color: String {
            switch self {
            case .preparation: return "blue"
            case .booking: return "green"
            case .logistics: return "orange"
            case .personal: return "purple"
            case .safety: return "red"
            case .enjoyment: return "pink"
            }
        }
    }
}

struct IdeaDetailView: View {
    let idea: AVIdea
    var locationContext: String? = nil
    @EnvironmentObject var firebaseManager: FirebaseManager
    @State private var checklistItems: [ChecklistItem] = []
    @State private var lastSavedDate: Date?
    @State private var isSaving = false
    @State private var showSaveConfirmation = false
    @State private var showCustomItemDialog = false
    @State private var customItemText = ""
    @Environment(\.openURL) private var openURL
    
    private let autoSaveDelay: TimeInterval = 2.0

    var body: some View {
        ZStack {
            // Background gradient
            AVTheme.gradient.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Hero Header Section
                    heroHeaderSection
                    
                    // Quick Stats Row
                    quickStatsRow
                    
                    // Description Card
                    descriptionCard
                    
                    // Details section
                    detailsSection

                    // Quick actions
                    quickActions

                    // Tags
                    if !idea.tags.isEmpty {
                        tagsSection
                    }

                    // Activity Checklist
                    checklistSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChecklist()
        }
        .sheet(isPresented: $showCustomItemDialog) {
            customItemDialog
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task {
                        await firebaseManager.toggleBookmark(for: idea)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: firebaseManager.isBookmarked(idea) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(firebaseManager.isBookmarked(idea) ? .yellow : .primary)
                        .font(.title2)
                }

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.primary)
                        .font(.title2)
                }
            }
        }
    }

    // MARK: - Sections
    
    @ViewBuilder
    private var heroHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(idea.title)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            
            HStack(spacing: 20) {
                Label(String(format: "%.1f", idea.rating), systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                
                Label(idea.place, systemImage: "mappin.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var quickStatsRow: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "clock.fill",
                title: "Duration",
                value: idea.duration,
                color: .blue
            )
            
            StatCard(
                icon: "dollarsign.circle.fill",
                title: "Price",
                value: idea.priceRange,
                color: .green
            )
            
            if let bestTime = idea.bestTime, !bestTime.isEmpty {
                StatCard(
                    icon: "sun.max.fill",
                    title: "Best Time",
                    value: bestTime,
                    color: .orange
                )
            }
        }
    }
    
    @ViewBuilder
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.quote")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("About This Activity")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            
            Text(idea.blurb)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("Tags")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80, maximum: 140), spacing: 10)
            ], spacing: 10) {
                ForEach(idea.tags, id: \.self) { tag in
                    AVTag(text: tag)
                }
            }
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("Activity Checklist")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Progress indicator
                let completedCount = checklistItems.filter { $0.isCompleted }.count
                let totalCount = checklistItems.count
                if totalCount > 0 {
                    HStack(spacing: 4) {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text("completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Quick checklist templates
            if checklistItems.isEmpty {
                quickChecklistTemplates
            }
            
            // Checklist items
            if !checklistItems.isEmpty {
                VStack(spacing: 12) {
                    ForEach(ChecklistItem.ChecklistCategory.allCases, id: \.self) { category in
                        let categoryItems = checklistItems.filter { $0.category == category }
                        if !categoryItems.isEmpty {
                            checklistCategorySection(category: category, items: categoryItems)
                        }
                    }
                }
                
                // Action buttons
                HStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Add custom item button
                        Button {
                            addCustomChecklistItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AVTheme.accent)
                        }
                        .buttonStyle(.plain)
                        
                        // Reset button
                        Button {
                            resetChecklist()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        
                        // Share button
                        ShareLink(item: createShareableChecklist()) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundStyle(AVTheme.accent)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            loadChecklist()
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("Contact & Information")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 12) {
                if let address = idea.address, !address.isEmpty {
                    detailRow(icon: "map.fill", text: address)
                }

                if let phone = idea.phone, !phone.isEmpty {
                    Button {
                        if let url = URL(string: "tel://\(digits(from: phone))") { openURL(url) }
                    } label: {
                        detailRow(icon: "phone.fill", text: phone, isLink: true)
                    }
                    .buttonStyle(.plain)
                }

                if let hours = idea.hours, !hours.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .frame(width: 20)
                                .foregroundStyle(AVTheme.accent)
                            Text("Hours")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(hours, id: \.self) { line in
                                Text(line)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 28)
                    }
                }

                if let website = idea.website, let url = URL(string: normalizeURL(website)) {
                    Button {
                        openURL(url)
                    } label: {
                        detailRow(icon: "globe", text: "Visit Website", isLink: true)
                    }
                    .buttonStyle(.plain)
                }

                if let booking = idea.bookingURL, let url = URL(string: normalizeURL(booking)) {
                    Button {
                        openURL(url)
                    } label: {
                        detailRow(icon: "ticket.fill", text: "Book Reservations", isLink: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func detailRow(icon: String, text: String, isLink: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(AVTheme.accent)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isLink ? AVTheme.accent : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isLink {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(AVTheme.accent)
            }
        }
        .padding(12)
        .background(isLink ? AVTheme.accent.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(AVTheme.accent)
                Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 12) {
                // Maps (search query)
                Button {
                    let q = mapsQuery()
                    if let url = URL(string: "http://maps.apple.com/?q=\(q)") {
                        openURL(url)
                    }
                } label: {
                    actionLabel(
                        title: "Open in Maps",
                        subtitle: "Get directions or view nearby",
                        systemImage: "map.fill"
                    )
                }

                // Google search for site/booking if missing
                if idea.website == nil && idea.bookingURL == nil {
                    Button {
                        let query = webQuery()
                        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
                            openURL(url)
                        }
                    } label: {
                        actionLabel(
                            title: "Search on the Web",
                            subtitle: "Find official site or reservations",
                            systemImage: "safari.fill"
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func actionLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(AVTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.8), lineWidth: 1)
        )
        }
    
    @ViewBuilder
    private var quickChecklistTemplates: some View {
        VStack(spacing: 12) {
            Text("Quick Start Checklists")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                // Smart checklist
                Button {
                    generateChecklistForCategory()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundStyle(.pink)
                        Text("Smart Checklist")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // Custom checklist
                Button {
                    addCustomChecklistItem()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text("Add Custom")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helpers

    private func mapsQuery() -> String {
        // Prefer address; else use "title place location"
        let base = idea.address?.isEmpty == false
            ? idea.address!
            : "\(idea.title) \(idea.place) \(locationContext ?? "")"
        return base.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? base
    }

    private func webQuery() -> String {
        let base = "\(idea.title) \(idea.place) \(locationContext ?? "") reservations"
        return base.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? base
    }

    private func digits(from phone: String) -> String {
        phone.filter("0123456789".contains)
    }

    private func normalizeURL(_ s: String) -> String {
        if s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://") {
            return s
        }
        return "https://\(s)"
    }

    private var shareText: String {
        """
        \(idea.title)
        \(idea.blurb)

        Where: \(idea.place)\(idea.address != nil ? " • \(idea.address!)" : "")
        Duration: \(idea.duration) • Price: \(idea.priceRange)
        \(idea.bestTime != nil ? "Best time: \(idea.bestTime!)" : "")
        """
    }
    
    // MARK: - Checklist Methods
    
    private func saveChecklist() async {
        isSaving = true
        // Save to UserDefaults with idea ID as key
        if let data = try? JSONEncoder().encode(checklistItems) {
            UserDefaults.standard.set(data, forKey: "checklist_\(idea.id)")
        }
        lastSavedDate = Date()
        isSaving = false
    }
    
    private func loadChecklist() {
        if let data = UserDefaults.standard.data(forKey: "checklist_\(idea.id)"),
           let items = try? JSONDecoder().decode([ChecklistItem].self, from: data) {
            checklistItems = items
        }
    }
    
    private func generateChecklistForCategory() {
        checklistItems = []
        var order = 0
        
        // Get category from idea tags or use a default
        let category = getCategoryFromTags()
        
        switch category {
        case .date:
            checklistItems = generateDateChecklist(order: &order)
        case .birthday:
            checklistItems = generateBirthdayChecklist(order: &order)
        case .travel:
            checklistItems = generateTravelChecklist(order: &order)
        case .local:
            checklistItems = generateLocalChecklist(order: &order)
        case .special:
            checklistItems = generateSpecialChecklist(order: &order)
        case .group:
            checklistItems = generateGroupChecklist(order: &order)
        }
        
        Task { await saveChecklist() }
    }
    

    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Checklist Generation Methods
    
    private func getCategoryFromTags() -> AVCategory {
        let tags = idea.tags.map { $0.lowercased() }
        
        if tags.contains("date") || tags.contains("romantic") || tags.contains("couple") {
            return .date
        } else if tags.contains("birthday") || tags.contains("celebration") {
            return .birthday
        } else if tags.contains("travel") || tags.contains("tourist") || tags.contains("sightseeing") {
            return .travel
        } else if tags.contains("group") || tags.contains("friends") || tags.contains("family") {
            return .group
        } else if tags.contains("special") || tags.contains("holiday") || tags.contains("seasonal") {
            return .special
        } else {
            return .local
        }
    }
    
    private func generateDateChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Research the activity", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Check reviews and ratings", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Make reservation", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        items.append(ChecklistItem(title: "Confirm date and time", isCompleted: false, category: .booking, order: order))
        order += 1
        
        // Logistics
        items.append(ChecklistItem(title: "Plan transportation", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Check parking availability", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Plan outfit", isCompleted: false, category: .personal, order: order))
        order += 1
        items.append(ChecklistItem(title: "Charge phone", isCompleted: false, category: .personal, order: order))
        order += 1
        items.append(ChecklistItem(title: "Bring payment method", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Safety
        items.append(ChecklistItem(title: "Share location with friend", isCompleted: false, category: .safety, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan conversation topics", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        items.append(ChecklistItem(title: "Think of backup plan", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateBirthdayChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Plan guest list", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Send invitations", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Book venue/activity", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        items.append(ChecklistItem(title: "Confirm group size", isCompleted: false, category: .booking, order: order))
        order += 1
        
        // Logistics
        items.append(ChecklistItem(title: "Plan transportation for group", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Arrange decorations", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Plan birthday outfit", isCompleted: false, category: .personal, order: order))
        order += 1
        items.append(ChecklistItem(title: "Prepare camera/phone", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan birthday activities", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        items.append(ChecklistItem(title: "Prepare thank you notes", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateTravelChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Research destination", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Check travel requirements", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        items.append(ChecklistItem(title: "Book transportation", isCompleted: false, category: .booking, order: order))
        order += 1
        items.append(ChecklistItem(title: "Book accommodation", isCompleted: false, category: .booking, order: order))
        order += 1
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Book activity", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        
        // Logistics
        items.append(ChecklistItem(title: "Pack essentials", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Plan itinerary", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Safety
        items.append(ChecklistItem(title: "Check travel insurance", isCompleted: false, category: .safety, order: order))
        order += 1
        items.append(ChecklistItem(title: "Share travel plans", isCompleted: false, category: .safety, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Download offline maps", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        items.append(ChecklistItem(title: "Research local customs", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateLocalChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Check opening hours", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Read recent reviews", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Make reservation", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        
        // Logistics
        items.append(ChecklistItem(title: "Plan route", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Check parking", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Dress appropriately", isCompleted: false, category: .personal, order: order))
        order += 1
        items.append(ChecklistItem(title: "Bring essentials", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan backup activity", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateSpecialChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Check event details", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Plan special outfit", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Get tickets", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        
        // Logistics
        items.append(ChecklistItem(title: "Plan arrival time", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Arrange transportation", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Prepare for photos", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan special moments", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    private func generateGroupChecklist(order: inout Int) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        
        // Preparation
        items.append(ChecklistItem(title: "Confirm group size", isCompleted: false, category: .preparation, order: order))
        order += 1
        items.append(ChecklistItem(title: "Create group chat", isCompleted: false, category: .preparation, order: order))
        order += 1
        
        // Booking
        if idea.bookingURL != nil {
            items.append(ChecklistItem(title: "Book group reservation", isCompleted: false, category: .booking, order: order))
            order += 1
        }
        items.append(ChecklistItem(title: "Check group discounts", isCompleted: false, category: .booking, order: order))
        order += 1
        
        // Logistics
        items.append(ChecklistItem(title: "Plan meeting point", isCompleted: false, category: .logistics, order: order))
        order += 1
        items.append(ChecklistItem(title: "Coordinate arrival times", isCompleted: false, category: .logistics, order: order))
        order += 1
        
        // Personal
        items.append(ChecklistItem(title: "Plan group activities", isCompleted: false, category: .personal, order: order))
        order += 1
        
        // Enjoyment
        items.append(ChecklistItem(title: "Plan group photos", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        items.append(ChecklistItem(title: "Split costs fairly", isCompleted: false, category: .enjoyment, order: order))
        order += 1
        
        return items
    }
    
    // MARK: - Checklist UI Methods
    
    @ViewBuilder
    private func checklistCategorySection(category: ChecklistItem.ChecklistCategory, items: [ChecklistItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(Color(category.color))
                    .font(.headline)
                Text(category.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            ForEach(items.sorted(by: { $0.order < $1.order })) { item in
                checklistItemRow(item: item)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func checklistItemRow(item: ChecklistItem) -> some View {
        HStack {
            Button {
                toggleChecklistItem(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            Text(item.title)
                .font(.subheadline)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
    
    private func toggleChecklistItem(_ item: ChecklistItem) {
        if let index = checklistItems.firstIndex(where: { $0.id == item.id }) {
            checklistItems[index].isCompleted.toggle()
            Task { await saveChecklist() }
        }
    }
    
    private func addCustomChecklistItem() {
        customItemText = ""
        showCustomItemDialog = true
    }
    
    private func addCustomItemFromDialog() {
        guard !customItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newItem = ChecklistItem(
            title: customItemText.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: false,
            category: .personal,
            order: checklistItems.count
        )
        checklistItems.append(newItem)
        showCustomItemDialog = false
        customItemText = ""
        Task { await saveChecklist() }
    }
    
    private func resetChecklist() {
        for index in checklistItems.indices {
            checklistItems[index].isCompleted = false
        }
        Task { await saveChecklist() }
    }
    
    private func createShareableChecklist() -> String {
        var shareableText = "📋 **CHECKLIST FOR \(idea.title.uppercased())**\n\n"
        
        for category in ChecklistItem.ChecklistCategory.allCases {
            let categoryItems = checklistItems.filter { $0.category == category }
            if !categoryItems.isEmpty {
                shareableText += "**\(category.rawValue):**\n"
                for item in categoryItems.sorted(by: { $0.order < $1.order }) {
                    let status = item.isCompleted ? "✅" : "□"
                    shareableText += "\(status) \(item.title)\n"
                }
                shareableText += "\n"
            }
        }
        
        shareableText += "📍 \(idea.place)"
        if let locationContext = locationContext {
            shareableText += " • \(locationContext)"
        }
        
        return shareableText
    }
    
    // MARK: - Custom Item Dialog
    
    @ViewBuilder
    private var customItemDialog: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Custom Checklist Item")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text("Type your custom task or plan for this activity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 12) {
                    TextField("Enter your custom task...", text: $customItemText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .onSubmit {
                            addCustomItemFromDialog()
                        }
                    
                    HStack {
                        Text("\(customItemText.count)/100")
                            .font(.caption)
                            .foregroundStyle(customItemText.count > 80 ? .orange : .secondary)
                        
                        Spacer()
                        
                        if !customItemText.isEmpty {
                            Button("Clear") {
                                customItemText = ""
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                }
                
                Spacer()
                
                // Example suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Suggestions:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Check weather forecast")
                        Text("• Bring camera/phone")
                        Text("• Research parking options")
                        Text("• Plan backup activity")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .navigationTitle("Custom Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCustomItemDialog = false
                        customItemText = ""
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCustomItemFromDialog()
                    }
                    .disabled(customItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}



struct IdeasListView: View {
    let location: String
    let category: AVCategory
    let ideas: [AVIdea]
    var autoFetch: Bool = false

    @State private var items: [AVIdea] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var hasFetchedOnce = false
    @State private var showingSubscriptionPrompt = false
    @State private var allShownIdeaIds: Set<UUID> = []
    @State private var shownIdeaIds: Set<UUID> = []

    @EnvironmentObject var subscriptionManager: SubscriptionManager

    init(location: String, category: AVCategory, ideas: [AVIdea], autoFetch: Bool = false) {
        self.location = location
        self.category = category
        self.ideas = ideas
        self.autoFetch = autoFetch
        _items = State(initialValue: ideas)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Perfect \(category.headerTitle) in \(location)")
                            .font(.system(size: 28, weight: .bold))
                        Text("Handpicked suggestions tailored to your interests")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                                            HStack(spacing: 8) {
                            Button {
                                Task { await fetchMoreIdeas() }
                            } label: {
                                HStack(spacing: 6) { 
                                    Text(isLoading ? "Loading..." : "More Ideas")
                                    Text("✨") 
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(AVTheme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .disabled(isLoading)
                            

                        }
                }
                
                // Search limit indicator
                HStack {
                    Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "magnifyingglass")
                        .foregroundStyle(subscriptionManager.isSubscribed ? .yellow : .secondary)
                    Text(subscriptionManager.searchLimitMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)

                if let errorMsg {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Something went wrong")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task { await fetchFromAI() }
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AVTheme.accent)
                    }
                    .padding(16)
                    .background(AVTheme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 8)
                }

                if isLoading {
                    VStack(spacing: 12) {
                        HStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Generating ideas...").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        
                        Text("This may take a few moments. We're finding the best activities for you!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 16)
                }

                LazyVStack(spacing: 18) {
                    ForEach(items) { idea in
                        IdeaCard(idea: idea, locationContext: location)
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if autoFetch && !hasFetchedOnce {
                hasFetchedOnce = true
                await fetchFromAI()
            }
        }
        .sheet(isPresented: $showingSubscriptionPrompt) {
            SubscriptionPromptView()
                .environmentObject(subscriptionManager)
        }
    }

    private func fetchFromAI() async {
        isLoading = true
        errorMsg = nil
        
        print("📱 UI: Starting fetchFromAI for \(location) - \(category.rawValue)")
        
        // Reset shown IDs for new search to avoid conflicts
        allShownIdeaIds.removeAll()
        shownIdeaIds.removeAll()
        
        print("📱 UI: Reset shown IDs - starting fresh search")
        
        // Clear existing cards first for better UX
        withAnimation(.easeInOut) { 
            items.removeAll()
        }
        
        // Always start fresh - no cache system
        allShownIdeaIds.removeAll()
        shownIdeaIds.removeAll()
        
        // Get current user ID for personalization
        let userId = FirebaseManager.shared.currentUser?.uid
        
        // Call AI directly for fresh ideas
        print("📱 UI: Calling AI for fresh ideas...")
        
        do {
            let result = try await AIIdeasService.fetchIdeas(
                location: location,
                category: category
            )
            
            if result.isEmpty {
                errorMsg = "No ideas returned. Try again."
            } else {
                // Update shown IDs and set new items
                let newIds = Set(result.map { $0.id })
                allShownIdeaIds = allShownIdeaIds.union(newIds)
                shownIdeaIds = newIds
                
                withAnimation(.easeInOut) { 
                    items = result
                }
                hasFetchedOnce = true
            }
        } catch {
            if (error as NSError).code == -3 {
                // Subscription limit reached
                showingSubscriptionPrompt = true
            } else {
                errorMsg = error.localizedDescription
            }
        }
        isLoading = false
    }
    

    
    private func fetchMoreIdeas() async {
        isLoading = true
        errorMsg = nil
        
        print("📱 UI: Starting fetchMoreIdeas for \(location) - \(category.rawValue)")
        print("📱 UI: All shown idea IDs: \(allShownIdeaIds.count)")
        
        // Clear existing cards first for better UX
        withAnimation(.easeInOut) { 
            items.removeAll()
        }
        
        // Always start fresh - no cache system
        allShownIdeaIds.removeAll()
        shownIdeaIds.removeAll()
        
        // Get current user ID for personalization
        let userId = FirebaseManager.shared.currentUser?.uid
        
        // Call AI directly for fresh ideas
        print("📱 UI: Calling AI for fresh ideas...")
        
        do {
            let result = try await AIIdeasService.fetchIdeas(
                location: location,
                category: category
            )
            
            if result.isEmpty {
                errorMsg = "No new ideas returned. Try again."
                print("📱 UI: ❌ AI returned empty result")
            } else {
                print("📱 UI: ✅ AI generated \(result.count) new ideas")
                
                // Update shown IDs and set new items
                let newIds = Set(result.map { $0.id })
                allShownIdeaIds = allShownIdeaIds.union(newIds)
                shownIdeaIds = newIds
                
                withAnimation(.easeInOut) { 
                    items = result
                }
            }
        } catch {
            print("📱 UI: ❌ Error generating new ideas: \(error.localizedDescription)")
            if (error as NSError).code == -3 {
                // Subscription limit reached
                showingSubscriptionPrompt = true
            } else {
                errorMsg = error.localizedDescription
            }
        }
        isLoading = false
    }
    

}



struct IdeaCard: View {
    let idea: AVIdea
    var locationContext: String? = nil   // ← pass the city (e.g., "Washington DC") if you have it
    @EnvironmentObject var firebaseManager: FirebaseManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(String(format: "%.1f", idea.rating), systemImage: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
                Spacer()
                Button {
                    Task {
                        await firebaseManager.toggleBookmark(for: idea)
                    }
                } label: {
                    Image(systemName: firebaseManager.isBookmarked(idea) ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(firebaseManager.isBookmarked(idea) ? AVTheme.accent : .secondary)
                }
                .buttonStyle(.plain)
            }

            Text(idea.title)
                .font(.title3).fontWeight(.semibold)
            Text(idea.blurb)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label(idea.place, systemImage: "mappin.circle")
                Label(idea.duration, systemImage: "clock")
                Label(idea.priceRange, systemImage: "dollarsign.circle")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Wrap(tags: idea.tags)

            // Navigate to the rich details page (address/phone/hours/website/etc.)
            NavigationLink {
                IdeaDetailView(idea: idea, locationContext: locationContext)
            } label: {
                Text("Learn More")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AVTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .avCard()
    }
}


struct Wrap: View {
    let tags: [String]
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        VStack { GeometryReader { geo in content(in: geo) } }
            .frame(height: totalHeight)
    }

    private func content(in g: GeometryProxy) -> some View {
        var w = CGFloat.zero
        var h = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(tags, id: \.self) { t in
                AVTag(text: t)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .alignmentGuide(.leading) { d in
                        if (w + d.width) > g.size.width { w = 0; h -= d.height + 4 }
                        let result = w
                        w += d.width + 4
                        return result
                    }
                    .alignmentGuide(.top) { _ in h }
            }
        }
        .background(GeometryReader { geo -> Color in
            DispatchQueue.main.async { totalHeight = geo.size.height }
            return .clear
        })
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
