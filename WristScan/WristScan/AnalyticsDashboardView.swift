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

enum DistributionMetric: String, CaseIterable {
    case watch = "Individual Watch"
    case brand = "Brand"
    case watchType = "Watch Type"
    case movementType = "Movement Type"
    case dialColor = "Dial Color"
    case caseMaterial = "Case Material"
}

struct AnalyticsDashboardView: View {
    @Query private var timepieces: [WatchTimepiece]

    // MARK: - State

    @State private var selectedDistribution: DistributionMetric = .brand
    @State private var selectedFrequencyMetric: DistributionMetric = .watch

    // MARK: - Computed Metrics

    var totalValue: Double {
        timepieces.reduce(0) { $0 + $1.purchasePrice }
    }

    var dynamicDistribution: [(category: String, count: Int)] {
        let mappedValues: [String]
        
        switch selectedDistribution {
        case .watch: mappedValues = timepieces.map { $0.name }
        case .brand: mappedValues = timepieces.map { $0.manufacturer }
        case .watchType: mappedValues = timepieces.map { $0.watchType }
        case .movementType: mappedValues = timepieces.map { $0.movementType }
        case .dialColor: mappedValues = timepieces.map { $0.dialColor }
        case .caseMaterial: mappedValues = timepieces.map { $0.caseMaterial }
        }
        
        let filtered = mappedValues.filter { !$0.isEmpty }
        let counts = filtered.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.map { (category: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    var frequencyDistribution: [(category: String, count: Int)] {
        var aggregatedData: [String: Int] = [:]
        
        for timepiece in timepieces {
            let category: String
            switch selectedFrequencyMetric {
            case .watch: category = timepiece.name
            case .brand: category = timepiece.manufacturer
            case .watchType: category = timepiece.watchType
            case .movementType: category = timepiece.movementType
            case .dialColor: category = timepiece.dialColor
            case .caseMaterial: category = timepiece.caseMaterial
            }
            
            guard !category.isEmpty else { continue }
            
            // Use the existing timesWorn integer property
            aggregatedData[category, default: 0] += timepiece.timesWorn
        }
        
        return aggregatedData.map { (category: $0.key, count: $0.value) }
                             .sorted { $0.count > $1.count }
                             .prefix(5)
                             .map { $0 }
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
                            distributionChart
                            wearChart
                        }
                        .padding(16)
                    }
                    .onAppear {
                        for timepiece in timepieces {
                            if timepiece.timesWorn == 0 && !timepiece.wearHistory.isEmpty {
                                timepiece.timesWorn = timepiece.wearHistory.count
                            }
                        }
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

    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Collection Distribution")

            Menu {
                ForEach(DistributionMetric.allCases, id: \.self) { metric in
                    Button(action: { selectedDistribution = metric }) {
                        HStack {
                            Text(metric.rawValue)
                            if selectedDistribution == metric {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("By \(selectedDistribution.rawValue)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.amberGold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.bottom, 8)

            if dynamicDistribution.isEmpty {
                missingDataLabel("No data available for this metric.")
            } else {
                Chart(dynamicDistribution, id: \.category) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                    .cornerRadius(4)
                }
                .frame(height: 250)
                .chartLegend(position: .bottom, alignment: .center, spacing: 12)
                .chartForegroundStyleScale(
                    domain: dynamicDistribution.map(\.category),
                    range: Array(sectorColors.prefix(dynamicDistribution.count))
                )
                .animation(.easeInOut, value: selectedDistribution)

                // Breakdown list
                VStack(spacing: 8) {
                    ForEach(dynamicDistribution.prefix(6), id: \.category) { item in
                        HStack {
                            Text(item.category.uppercased())
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .tracking(1.0)
                            Spacer()
                            Text("\(item.count) watch\(item.count == 1 ? "" : "es")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        if item.category != dynamicDistribution.prefix(6).last?.category {
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
            sectionHeader("Top 5 Wrist Checks")

            Menu {
                ForEach(DistributionMetric.allCases, id: \.self) { metric in
                    Button(action: { selectedFrequencyMetric = metric }) {
                        HStack {
                            Text(metric.rawValue)
                            if selectedFrequencyMetric == metric {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("By \(selectedFrequencyMetric.rawValue)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.amberGold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.bottom, 8)

            if frequencyDistribution.isEmpty {
                missingDataLabel("No data available for this metric.")
            } else {
                Chart(frequencyDistribution, id: \.category) { item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(Color.amberGold.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 250)
                .animation(.easeInOut, value: selectedFrequencyMetric)
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
