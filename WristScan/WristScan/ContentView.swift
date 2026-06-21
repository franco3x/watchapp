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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchTimepiece.purchaseDate, order: .reverse) private var timepieces: [WatchTimepiece]

    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var selectedSort: SortOption = .dateAdded
    @State private var sortAscending: Bool = false

    var sortedTimepieces: [WatchTimepiece] {
        switch selectedSort {
        case .dateAdded:
            return timepieces.sorted { sortAscending ? $0.purchaseDate < $1.purchaseDate : $0.purchaseDate > $1.purchaseDate }
        case .manufacturer:
            return timepieces.sorted { sortAscending ? $0.manufacturer < $1.manufacturer : $0.manufacturer > $1.manufacturer }
        case .price:
            return timepieces.sorted { sortAscending ? $0.purchasePrice < $1.purchasePrice : $0.purchasePrice > $1.purchasePrice }
        case .timesWorn:
            return timepieces.sorted { sortAscending ? $0.timesWorn < $1.timesWorn : $0.timesWorn > $1.timesWorn }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
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
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(sortedTimepieces) { timepiece in
                                NavigationLink(destination: WatchDetailView(timepiece: timepiece)) {
                                    WatchCardView(timepiece: timepiece)
                                }
                                .buttonStyle(.plain)
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
                        Image(systemName: "line.3.horizontal.decrease.circle")
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
        }
        .fullScreenCover(isPresented: $showingScanner) {
            WatchScannerView(showingScanner: $showingScanner)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
                Rectangle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Manufacturer label (minimalist, small caps/uppercase)
                Text(timepiece.manufacturer.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.5)
                
                // Watch Name
                Text(timepiece.name)
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
                    .padding(8)
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            timepiece.timesWorn += 1
                        }
                    )
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
