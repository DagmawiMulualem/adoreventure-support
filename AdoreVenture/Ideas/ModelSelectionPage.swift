import SwiftUI

struct ModelSelectionPage: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedModel: String
    @State private var showingSubscriptionPrompt = false
    @State private var animateCards = false
    
    init() {
        // Initialize with current selection
        self._selectedModel = State(initialValue: SubscriptionManager.shared.selectedModel.displayName)
    }
    
    var body: some View {
        ZStack {
            AVTheme.gradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    // Brain icon
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Choose AI Model")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("Select the AI model that will generate your adventure ideas")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 20)
                
                // Separator
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                
                // Model Sections
                ScrollView {
                    VStack(spacing: 24) {
                        // Available Models Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Available Models")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    
                                    Text("Free to use")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                // GPT-4o Mini
                                AvailableModelCard(
                                    title: "GPT-4o Mini",
                                    description: "Fast & efficient",
                                    icon: "bolt.fill",
                                    iconColor: .blue,
                                    isSelected: selectedModel == "GPT-4o Mini",
                                    tags: [("Fast", .blue, "bolt.fill"), ("Good", .purple, "brain.fill")],
                                    onTap: { 
                                        selectedModel = "GPT-4o Mini"
                                        subscriptionManager.selectedModel = .gpt4oMini
                                        dismiss()
                                    }
                                )
                                
                                // GPT-3.5 Turbo
                                AvailableModelCard(
                                    title: "GPT-3.5 Turbo",
                                    description: "Quick responses",
                                    icon: "bolt.fill",
                                    iconColor: .green,
                                    isSelected: selectedModel == "GPT-3.5 Turbo",
                                    tags: [("Quick", .blue, "bolt.fill"), ("Fast", .purple, "brain.fill")],
                                    onTap: { 
                                        selectedModel = "GPT-3.5 Turbo"
                                        subscriptionManager.selectedModel = .gpt35Turbo
                                        dismiss()
                                    }
                                )
                                
                                // Gemini 1.5 Flash
                                AvailableModelCard(
                                    title: "Gemini 1.5 Flash",
                                    description: "Google Gemini – fast & experimental",
                                    icon: "sparkles",
                                    iconColor: .purple,
                                    isSelected: selectedModel == "Gemini 1.5 Flash",
                                    tags: [("Experimental", .purple, "wand.and.stars"), ("Google", .blue, "g.circle.fill")],
                                    onTap: {
                                        selectedModel = "Gemini 1.5 Flash"
                                        subscriptionManager.selectedModel = .geminiFlash
                                        dismiss()
                                    }
                                )
                            }
                        }
                        
                        // Premium Models Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Premium Models")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    
                                    Text("Upgrade to unlock")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                }
                                
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                // GPT-4o
                                PremiumModelCard(
                                    title: "GPT-4o",
                                    description: "Most advanced",
                                    icon: "star.fill",
                                    iconColor: .yellow,
                                    tags: [("Pro", .orange, "plus"), ("Premium", .yellow, "crown.fill")],
                                    onTap: { showingSubscriptionPrompt = true }
                                )
                                
                                // GPT-4 Turbo
                                PremiumModelCard(
                                    title: "GPT-4",
                                    subtitle: "Turbo",
                                    description: "Ultimate performance",
                                    icon: "crown.fill",
                                    iconColor: .yellow,
                                    tags: [("Pro", .orange, "plus"), ("Premium", .yellow, "crown.fill")],
                                    onTap: { showingSubscriptionPrompt = true }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 50)
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSubscriptionPrompt) {
            SubscriptionPromptView()
                .environmentObject(subscriptionManager)
        }
        .onAppear {
            // Update local state with current selection
            selectedModel = subscriptionManager.selectedModel.displayName
            
            withAnimation(.easeOut(duration: 0.6)) {
                animateCards = true
            }
        }
    }
}

struct AvailableModelCard: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let tags: [(String, Color, String)]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Tags
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.0) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: tag.2)
                                    .font(.caption2)
                                    .foregroundStyle(tag.1)
                                
                                Text(tag.0)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(tag.1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.1.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? .orange : .white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PremiumModelCard: View {
    let title: String
    var subtitle: String?
    let description: String
    let icon: String
    let iconColor: Color
    let tags: [(String, Color, String)]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title row with premium badge
                    HStack {
                        HStack(spacing: 4) {
                            Text(title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        Spacer()
                        
                        // Premium badge
                        Text("PREMIUM")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.orange)
                            .clipShape(Capsule())
                    }
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Tags
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.0) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: tag.2)
                                    .font(.caption2)
                                    .foregroundStyle(tag.1)
                                
                                Text(tag.0)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(tag.1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.1.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Upgrade indicator
                VStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                    
                    Text("Upgrade")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ModelSelectionPage()
        .environmentObject(SubscriptionManager.shared)
}
