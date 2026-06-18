//
//  CatalogSelectionView.swift
//  WristScan
//

import SwiftUI
import SwiftData

struct CatalogSelectionView: View {

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WatchCatalogItem.manufacturer) private var allItems: [WatchCatalogItem]

    /// Called when the user confirms a selection. Caller handles persistence.
    var onSelect: (WatchCatalogItem) -> Void

    @State private var searchText = ""

    // MARK: - Filtering

    private var filteredItems: [WatchCatalogItem] {
        guard !searchText.isEmpty else { return allItems }
        let query = searchText.lowercased()
        return allItems.filter { item in
            let q = query
            let matchesManufacturer  = item.manufacturer.lowercased().contains(q)
            let matchesModel         = item.modelName.lowercased().contains(q)
            let matchesRef           = item.referenceNumber.lowercased().contains(q)
            let matchesAlias         = item.aliases.contains(where: { $0.lowercased().contains(q) })
            return matchesManufacturer || matchesModel || matchesRef || matchesAlias
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                Group {
                    if filteredItems.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 44, weight: .ultraLight))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No results for \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        List(filteredItems) { watch in
                            Button {
                                onSelect(watch)
                                dismiss()
                            } label: {
                                CatalogRowLabel(watch: watch)
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .padding(.vertical, 3)
                            )
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Select Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.amberGold)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.08), for: .navigationBar)
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Manufacturer, model, or reference…"
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - Row label

private struct CatalogRowLabel: View {
    let watch: WatchCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(watch.manufacturer.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.4)
                Spacer()
                Text(watch.priceTier)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(watch.modelName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text(watch.referenceNumber)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
            if !watch.aliases.isEmpty {
                Text(watch.aliases.joined(separator: "  ·  "))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    CatalogSelectionView(onSelect: { _ in })
        .modelContainer(for: WatchCatalogItem.self, inMemory: true)
}
