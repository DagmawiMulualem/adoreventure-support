//
//  CountryDetailView.swift
//  AdoreVenture
//
//  Created by Dagmawi Mulualem on 8/23/25.
//

import SwiftUI
import PhotosUI

struct CountryDetailView: View {
    let country: Country
    @ObservedObject var travelMapService: TravelMapService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: TravelStatus
    @State private var notes: String
    @State private var showingPhotoPicker = false
    @State private var photos: [String] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingConfetti = false
    @State private var photoUploadErrorMessage: String?
    
    init(country: Country, travelMapService: TravelMapService) {
        self.country = country
        self.travelMapService = travelMapService
        self._selectedStatus = State(initialValue: country.travelStatus)
        self._notes = State(initialValue: country.notes ?? "")
        self._photos = State(initialValue: country.photos)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AVTheme.gradient.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Country Header
                        CountryHeaderView(country: country)
                        
                        // Status Selection
                        StatusSelectionView(selectedStatus: $selectedStatus)
                        
                        // Notes Section
                        NotesSectionView(notes: $notes)
                        
                        // Photos Section
                        PhotosSectionView(photos: $photos, showingPhotoPicker: $showingPhotoPicker)
                        
                        // Country Info
                        CountryInfoView(country: country)
                        
                        // Save Button
                        SaveButtonView(
                            country: country,
                            selectedStatus: selectedStatus,
                            notes: notes,
                            photos: photos,
                            travelMapService: travelMapService,
                            showingConfetti: $showingConfetti
                        )
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(country.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { oldItems, newItems in
            Task {
                await handleSelectedPhotos(newItems)
            }
        }
        .overlay {
            if showingConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .alert("Photo Upload Failed", isPresented: Binding(
            get: { photoUploadErrorMessage != nil },
            set: { if !$0 { photoUploadErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { photoUploadErrorMessage = nil }
        } message: {
            Text(photoUploadErrorMessage ?? "Unable to attach this photo right now.")
        }
    }
}

// MARK: - Country Header View
struct CountryHeaderView: View {
    let country: Country
    
    var body: some View {
        VStack(spacing: 16) {
            // Country Flag/Icon
            Image(systemName: country.continent.icon)
                .font(.system(size: 60))
                .foregroundStyle(country.continent.color)
                .frame(width: 100, height: 100)
                .background(Color.black.opacity(0.2))
                .clipShape(Circle())
            
            VStack(spacing: 8) {
                Text(country.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text(country.continent.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(country.code)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Status Selection View
struct StatusSelectionView: View {
    @Binding var selectedStatus: TravelStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Travel Status")
                .font(.headline)
                .foregroundStyle(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(TravelStatus.allCases, id: \.self) { status in
                    StatusButton(
                        status: status,
                        isSelected: selectedStatus == status
                    ) {
                        selectedStatus = status
                    }
                }
            }
        }
    }
}

// MARK: - Status Button
struct StatusButton: View {
    let status: TravelStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : status.color)
                
                Text(status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : status.color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ? status.color : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(status.color, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Notes Section View
struct NotesSectionView: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(.white)
            
            TextField("Add your travel notes...", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(16)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(3...6)
        }
    }
}

// MARK: - Photos Section View
struct PhotosSectionView: View {
    @Binding var photos: [String]
    @Binding var showingPhotoPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    showingPhotoPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
            
            if photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("No photos added yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Button("Add Photos") {
                        showingPhotoPicker = true
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos, id: \.self) { photo in
                            PhotoThumbnailView(photoURL: photo) {
                                photos.removeAll { $0 == photo }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Photo Thumbnail View
struct PhotoThumbnailView: View {
    let photoURL: String
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: photoURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .background(Color.white, in: Circle())
            }
            .offset(x: 8, y: -8)
        }
    }
}

// MARK: - Country Info View
struct CountryInfoView: View {
    let country: Country
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Country Information")
                .font(.headline)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                InfoRowView(
                    icon: "globe",
                    title: "Continent",
                    value: country.continent.displayName
                )
                
                InfoRowView(
                    icon: "location",
                    title: "Coordinates",
                    value: "\(String(format: "%.2f", country.coordinates.latitude)), \(String(format: "%.2f", country.coordinates.longitude))"
                )
                
                if let population = country.population {
                    InfoRowView(
                        icon: "person.3",
                        title: "Population",
                        value: formatNumber(population)
                    )
                }
                
                if let area = country.area {
                    InfoRowView(
                        icon: "square.grid.3x3",
                        title: "Area",
                        value: "\(String(format: "%.0f", area)) km²"
                    )
                }
            }
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Info Row View
struct InfoRowView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Save Button View
struct SaveButtonView: View {
    let country: Country
    let selectedStatus: TravelStatus
    let notes: String
    let photos: [String]
    @ObservedObject var travelMapService: TravelMapService
    @Binding var showingConfetti: Bool
    @Environment(\.dismiss) private var dismiss
    
    var hasChanges: Bool {
        return selectedStatus != country.travelStatus ||
               notes != (country.notes ?? "") ||
               photos != country.photos
    }
    
    var body: some View {
        Button {
            Task {
                await saveChanges()
            }
        } label: {
            HStack {
                if travelMapService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                
                Text(hasChanges ? "Save Changes" : "No Changes")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                hasChanges ? AVTheme.accent : Color.gray.opacity(0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!hasChanges || travelMapService.isLoading)
    }
    
    private func saveChanges() async {
        await travelMapService.updateCountryStatus(
            country,
            status: selectedStatus,
            notes: notes.isEmpty ? nil : notes,
            photos: photos
        )
        
        // Show confetti if status changed to visited
        if selectedStatus == .visited && country.travelStatus != .visited {
            showingConfetti = true
            
            // Hide confetti after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                showingConfetti = false
            }
        }
        
        dismiss()
    }
}

private extension CountryDetailView {
    func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let urlString = try await travelMapService.uploadCountryPhoto(country: country, imageData: data)
                    if !photos.contains(urlString) {
                        photos.append(urlString)
                    }
                }
            } catch {
                print("❌ CountryDetailView: Failed to load selected photo - \(error.localizedDescription)")
                photoUploadErrorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { _ in
                ConfettiPiece()
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Confetti Piece
struct ConfettiPiece: View {
    @State private var animate = false
    
    private let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
    private let shapes = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill"]
    
    var body: some View {
        Image(systemName: shapes.randomElement() ?? "circle.fill")
            .foregroundStyle(colors.randomElement() ?? .blue)
            .font(.caption)
            .offset(
                x: animate ? CGFloat.random(in: -200...200) : 0,
                y: animate ? CGFloat.random(in: -300...300) : 0
            )
            .rotationEffect(.degrees(animate ? 360 : 0))
            .opacity(animate ? 0 : 1)
            .animation(
                .easeOut(duration: Double.random(in: 2...4)),
                value: animate
            )
            .onAppear {
                animate = true
            }
    }
}

#Preview {
    CountryDetailView(
        country: CountryData.allCountries.first!,
        travelMapService: TravelMapService.shared
    )
}
