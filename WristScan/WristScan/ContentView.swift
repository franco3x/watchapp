//
//  ContentView.swift
//  WristScan
//
//  Purpose: The main dashboard UI that renders the user's Watch Box grid, handles dynamic sorting selections, and houses navigation entry points.
//

import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case manufacturer = "Manufacturer"
    case price = "Price"
    case timesWorn = "Times Worn"
}

enum AppRoute: Hashable {
    case detail(PersistentIdentifier)
    case detailWithEdit(PersistentIdentifier)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchTimepiece.purchaseDate, order: .reverse) private var timepieces: [WatchTimepiece]

    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var showingFilters = false
    @State private var filterManufacturer: String = "All"
    @State private var filterWatchType: String = "All"
    @State private var filterCaseMaterial: String = "All"
    @State private var filterDialColor: String = "All"
    @State private var filterMovementType: String = "All"
    @State private var selectedSort: SortOption = .dateAdded
    @State private var sortAscending: Bool = false
    @State private var navPath: [AppRoute] = []

    var filteredAndSortedTimepieces: [WatchTimepiece] {
        var filtered = timepieces

        if filterManufacturer != "All" {
            filtered = filtered.filter { $0.manufacturer == filterManufacturer }
        }
        if filterWatchType != "All" {
            filtered = filtered.filter { $0.watchType == filterWatchType }
        }
        if filterCaseMaterial != "All" {
            filtered = filtered.filter { $0.caseMaterial == filterCaseMaterial }
        }
        if filterDialColor != "All" {
            filtered = filtered.filter { $0.dialColor == filterDialColor }
        }
        if filterMovementType != "All" {
            filtered = filtered.filter { $0.movementType == filterMovementType }
        }

        switch selectedSort {
        case .dateAdded:
            return filtered.sorted { sortAscending ? $0.purchaseDate < $1.purchaseDate : $0.purchaseDate > $1.purchaseDate }
        case .manufacturer:
            return filtered.sorted { sortAscending ? $0.manufacturer < $1.manufacturer : $0.manufacturer > $1.manufacturer }
        case .price:
            return filtered.sorted { sortAscending ? $0.purchasePrice < $1.purchasePrice : $0.purchasePrice > $1.purchasePrice }
        case .timesWorn:
            return filtered.sorted { sortAscending ? $0.timesWorn < $1.timesWorn : $0.timesWorn > $1.timesWorn }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                // Background dark theme
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                if timepieces.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundColor(.gray)
                        Text("Your Watch Box is Empty")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                        Text("Tap + to add a timepiece.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if filteredAndSortedTimepieces.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundColor(.gray)
                        Text("No Matching Watches")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                        Text("Try adjusting your filter options.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            filterManufacturer = "All"
                            filterWatchType = "All"
                            filterCaseMaterial = "All"
                        }) {
                            Text("Reset Filters")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.amberGold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.amberGold.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredAndSortedTimepieces) { timepiece in
                                WatchCardView(timepiece: timepiece)
                                    .onTapGesture {
                                        navPath.append(.detail(timepiece.persistentModelID))
                                    }
                                    .contextMenu {
                                    Button(role: .destructive) {
                                        modelContext.delete(timepiece)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Watch Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.amberGold)
                            .padding(8)
                            .background(Color.amberGold.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    let filtersActive = filterManufacturer != "All" || filterWatchType != "All" || filterCaseMaterial != "All" || filterDialColor != "All" || filterMovementType != "All"
                    Button(action: { showingFilters = true }) {
                        Image(systemName: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(filtersActive ? .black : .amberGold)
                            .padding(8)
                            .background(filtersActive ? Color.amberGold : Color.amberGold.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: {
                                if selectedSort == option {
                                    sortAscending.toggle()
                                } else {
                                    selectedSort = option
                                    if option == .manufacturer {
                                        sortAscending = true
                                    } else {
                                        sortAscending = false
                                    }
                                }
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if selectedSort == option {
                                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.amberGold)
                            .padding(8)
                            .background(Color.amberGold.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.amberGold)
                            .padding(8)
                            .background(Color.amberGold.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.08), for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                WatchDetailResolver(route: route)
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            WatchScannerView(showingScanner: $showingScanner) { savedWatch in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    navPath.append(.detailWithEdit(savedWatch.persistentModelID))
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingFilters) {
            FilterSheetView(
                timepieces: timepieces,
                selectedManufacturer: $filterManufacturer,
                selectedWatchType: $filterWatchType,
                selectedCaseMaterial: $filterCaseMaterial,
                selectedDialColor: $filterDialColor,
                selectedMovementType: $filterMovementType
            )
        }
    }

}

struct WatchCardView: View {
    let timepiece: WatchTimepiece
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let data = timepiece.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
            } else {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.16, green: 0.16, blue: 0.19),
                            Color(red: 0.08, green: 0.08, blue: 0.09)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "clock")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.amberGold.opacity(0.18))
                }
                .frame(height: 120)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Manufacturer label (minimalist, small caps/uppercase)
                Text((timepiece.manufacturer.isEmpty ? "Unknown Manufacturer" : timepiece.manufacturer).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.5)
                
                // Watch Name
                Text(timepiece.modelName.isEmpty ? "New Watch" : timepiece.modelName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Reference Number
                Text(timepiece.referenceNumber)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Spacer(minLength: 8)
                
                // Footer: price and wear counter button
                HStack {
                    Text("$\(timepiece.purchasePrice, specifier: "%.0f")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    // Wear counter visual pill
                    Button(action: {
                        timepiece.timesWorn += 1
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 9))
                            Text("\(timepiece.timesWorn)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.amberGold.opacity(0.15))
                        .foregroundColor(.amberGold)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.amberGold.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
            .padding(14)
        }
        .frame(height: 240)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.12, green: 0.12, blue: 0.14),
                            Color(red: 0.09, green: 0.09, blue: 0.10)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle()) // Ensures the whole tile is tappable
        .sensoryFeedback(.impact(weight: .light), trigger: timepiece.timesWorn)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WatchTimepiece.self, inMemory: true)
}

struct WatchDetailResolver: View {
    let route: AppRoute
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        switch route {
        case .detail(let id):
            // The colon explicitly tells Swift what 'T' is, no 'as?' needed
            if let watch: WatchTimepiece = modelContext.registeredModel(for: id) {
                WatchDetailView(timepiece: watch)
            } else {
                ProgressView()
            }
        case .detailWithEdit(let id):
            // Same explicit declaration here
            if let watch: WatchTimepiece = modelContext.registeredModel(for: id) {
                WatchDetailView(timepiece: watch, autoPresentEdit: true)
            } else {
                ProgressView()
            }
        }
    }
}