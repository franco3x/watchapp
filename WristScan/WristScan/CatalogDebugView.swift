//
//  CatalogDebugView.swift
//  WristScan
//
//  Temporary debug view — remove before App Store submission.
//

import SwiftUI
import SwiftData

struct CatalogDebugView: View {

    @Query(sort: \WatchCatalogItem.manufacturer) private var items: [WatchCatalogItem]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    catalogList
                }
            }
            .navigationTitle("Catalog Registry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Catalog Registry")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text("\(items.count) Item\(items.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.amberGold)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.08), for: .navigationBar)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundColor(.gray.opacity(0.5))
            Text("Catalog is empty.")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            Text("Check Xcode logs for hydration status.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - List

    private var catalogList: some View {
        List {
            ForEach(items) { item in
                CatalogRowView(item: item)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .padding(.vertical, 4)
                    )
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Row View

private struct CatalogRowView: View {
    let item: WatchCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Headline: manufacturer + model
            VStack(alignment: .leading, spacing: 3) {
                Text(item.manufacturer.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.5)
                Text(item.modelName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }

            // Reference number
            Text(item.referenceNumber)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Style chips: primaryStyle · dialColor · priceTier
            HStack(spacing: 6) {
                StyleChip(label: item.primaryStyle, color: .blue)
                StyleChip(label: item.dialColor,    color: .purple)
                StyleChip(label: item.priceTier,    color: tierColor(item.priceTier))
            }

            // Aliases sub-row
            if !item.aliases.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("Aliases:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(item.aliases.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier.lowercased() {
        case "budget":      return .green
        case "mid-range":   return .cyan
        case "luxury":      return Color.amberGold
        case "ultra-luxury": return .orange
        default:            return .gray
        }
    }
}

// MARK: - Style Chip

private struct StyleChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Preview

#Preview {
    CatalogDebugView()
        .modelContainer(for: WatchCatalogItem.self, inMemory: true)
}
