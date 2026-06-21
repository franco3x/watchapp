//
//  AnalyticsDashboardView.swift
//  WristScan
//
//  Purpose: Epic 1 — The Analytics & Insights Engine. A global instrument-dashboard
//  view showing collection value, brand distribution, and wear frequency analytics.
//

import SwiftUI
import SwiftData
import Charts

struct AnalyticsDashboardView: View {
    @Query private var timepieces: [WatchTimepiece]

    // MARK: - Computed Metrics

    var totalValue: Double {
        timepieces.reduce(0) { $0 + $1.purchasePrice }
    }

    var brandDistribution: [(brand: String, count: Int)] {
        let grouped = Dictionary(grouping: timepieces.filter { !$0.manufacturer.isEmpty }, by: \.manufacturer)
        return grouped
            .map { (brand: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var mostWorn: [WatchTimepiece] {
        timepieces
            .sorted { $0.wearHistory.count > $1.wearHistory.count }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Palette for chart sectors
    private let sectorColors: [Color] = [
        Color(hue: 0.11, saturation: 0.85, brightness: 0.85),  // amberGold
        Color(hue: 0.58, saturation: 0.6,  brightness: 0.75),  // steel blue
        Color(hue: 0.35, saturation: 0.55, brightness: 0.65),  // patina green
        Color(hue: 0.72, saturation: 0.5,  brightness: 0.70),  // violet
        Color(hue: 0.05, saturation: 0.70, brightness: 0.80),  // copper
        Color(hue: 0.48, saturation: 0.45, brightness: 0.65),  // teal
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                if timepieces.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            summaryCards
                            brandChart
                            wearChart
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.08), for: .navigationBar)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundColor(.gray)
            Text("No Data Yet")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
            Text("Add watches to your collection to see insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            // Total Collection Value
            VStack(alignment: .leading, spacing: 6) {
                Text("Collection Value")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.0)
                    .textCase(.uppercase)
                Text(totalValue, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(cardBackground)

            // Total Timepieces
            VStack(alignment: .leading, spacing: 6) {
                Text("Timepieces")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.0)
                    .textCase(.uppercase)
                Text("\(timepieces.count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(cardBackground)
        }
    }

    private var brandChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Collection by Brand")

            if brandDistribution.isEmpty {
                missingDataLabel("No manufacturer data available.")
            } else {
                Chart(brandDistribution, id: \.brand) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Brand", item.brand))
                    .cornerRadius(4)
                }
                .frame(height: 250)
                .chartLegend(position: .bottom, alignment: .center, spacing: 12)
                .chartForegroundStyleScale(
                    domain: brandDistribution.map(\.brand),
                    range: Array(sectorColors.prefix(brandDistribution.count))
                )

                // Brand breakdown list
                VStack(spacing: 8) {
                    ForEach(brandDistribution.prefix(6), id: \.brand) { item in
                        HStack {
                            Text(item.brand.uppercased())
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .tracking(1.0)
                            Spacer()
                            Text("\(item.count) watch\(item.count == 1 ? "" : "es")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        if item.brand != brandDistribution.prefix(6).last?.brand {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var wearChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Wear Frequency (Top 5)")

            if mostWorn.isEmpty || mostWorn.first?.wearHistory.isEmpty == true {
                missingDataLabel("No wear data recorded yet.")
            } else {
                Chart(mostWorn) { watch in
                    BarMark(
                        x: .value("Watch", watch.modelName.isEmpty ? watch.name : watch.modelName),
                        y: .value("Wears", watch.wearHistory.count)
                    )
                    .foregroundStyle(Color.amberGold.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.amberGold)
            .tracking(1.5)
    }

    private func missingDataLabel(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }

    private var cardBackground: some View {
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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}
