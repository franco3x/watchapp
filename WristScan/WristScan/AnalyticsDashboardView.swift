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

struct SheetDate: Identifiable {
    let id = UUID()
    let date: Date
}

enum DistributionMetric: String, CaseIterable {
    case watch = "Watch"
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
    @State private var selectedFrequencyPeriod: ReportPeriod = .allTime
    @State private var selectedCalendarDate: SheetDate? = nil
    @State private var selectedWatchesForLog: Set<WatchTimepiece> = []
    @State private var distributionShareCoordinator = ShareCardCoordinator()
    @State private var wearChartShareCoordinator = ShareCardCoordinator()

    // MARK: - Computed Metrics

    var totalValue: Double {
        timepieces.reduce(0) { $0 + $1.purchasePrice }
    }

    var totalWristChecks: Int {
        timepieces.reduce(0) { $0 + $1.timesWorn }
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
        let range = selectedFrequencyPeriod.dateRange

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

            // Count wear-history entries inside the selected window rather than the
            // all-time timesWorn counter, so the time-window picker actually filters.
            let checksInPeriod = timepiece.wearHistory.filter { $0 >= range.start && $0 <= range.end }.count
            guard checksInPeriod > 0 else { continue }
            aggregatedData[category, default: 0] += checksInPeriod
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

    var globalWearHistory: [Date] {
        // Flatten all wearHistory arrays from all timepieces into a single, unique array of dates
        let allDates = timepieces.flatMap { $0.wearHistory }
        return Array(Set(allDates)).sorted()
    }

    private var globalWearComponents: Set<DateComponents> {
        let components = globalWearHistory.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) }
        return Set(components)
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
                            calendarSection
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: RewindView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Rewind")
                                .padding(.trailing,3)
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.amberGold)
                    }
                }
            }
        }
        .shareCardPresentation(distributionShareCoordinator)
        .shareCardPresentation(wearChartShareCoordinator)
    }

    private func shareDistributionChart() async {
        let card = DistributionShareCard(
            metricLabel: "By \(selectedDistribution.rawValue)",
            distribution: dynamicDistribution,
            sectorColors: sectorColors
        )
        await distributionShareCoordinator.prepareAndShare(card: card, exportSize: CGSize(width: 1080, height: 1350), filenamePrefix: "WristScan_Distribution")
    }

    private func shareWearChart() async {
        let entries = frequencyDistribution.map { item -> LeaderboardEntry in
            let secondary: String?
            if selectedFrequencyMetric == .watch {
                secondary = timepieces.first(where: { $0.name == item.category })?.manufacturer
            } else {
                secondary = nil
            }
            return LeaderboardEntry(name: item.category, secondary: secondary, count: item.count)
        }
        let card = WearChartShareCard(periodLabel: selectedFrequencyPeriod.rawValue, entries: entries)
        await wearChartShareCoordinator.prepareAndShare(card: card, exportSize: CGSize(width: 1080, height: 1350), filenamePrefix: "WristScan_WearChart")
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
            VStack(alignment: .center, spacing: 6) {
                Text("Value")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.0)
                    .textCase(.uppercase)
                Text(totalValue, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 20, weight: .bold)) // Slightly scaled down to fit 3 cols
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(14)
            .background(cardBackground)

            // Total Timepieces
            VStack(alignment: .center, spacing: 6) {
                Text("Watches")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.0)
                    .textCase(.uppercase)
                Text("\(timepieces.count)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(14)
            .background(cardBackground)

            // Total Wrist Checks
            VStack(alignment: .center, spacing: 6) {
                Text("Wrist Checks")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.0)
                    .textCase(.uppercase)
                Text("\(totalWristChecks)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(14)
            .background(cardBackground)
        }
    }

    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Collection Distribution")
                Spacer()
                Button(action: { Task { await shareDistributionChart() } }) {
                    if distributionShareCoordinator.isPreparing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.amberGold)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.amberGold)
                    }
                }
                .disabled(dynamicDistribution.isEmpty || distributionShareCoordinator.isPreparing)
            }

            Menu {
                // "Individual Watch" is excluded here — every watch is its own
                // category, so the distribution is always 1 per slice, which isn't
                // a meaningful breakdown for a pie chart.
                ForEach(DistributionMetric.allCases.filter { $0 != .watch }, id: \.self) { metric in
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
            HStack {
                sectionHeader("Top 5 Wrist Checks")
                Spacer()
                Button(action: { Task { await shareWearChart() } }) {
                    if wearChartShareCoordinator.isPreparing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.amberGold)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.amberGold)
                    }
                }
                .disabled(frequencyDistribution.isEmpty || wearChartShareCoordinator.isPreparing)
            }

            HStack(spacing: 10) {
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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

                Menu {
                    ForEach(ReportPeriod.allCases, id: \.self) { period in
                        Button(action: { selectedFrequencyPeriod = period }) {
                            HStack {
                                Text(period.rawValue)
                                if selectedFrequencyPeriod == period {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedFrequencyPeriod.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
            }
            .padding(.bottom, 8)

            if frequencyDistribution.isEmpty {
                missingDataLabel("No wear data for this metric in the selected time window.")
            } else {
                Chart(frequencyDistribution, id: \.category) { item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(Color.amberGold.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 290)
                .animation(.easeInOut, value: selectedFrequencyMetric)
                .animation(.easeInOut, value: selectedFrequencyPeriod)
                .chartXAxis {
                    // Long watch names collide when laid out horizontally under narrow
                    // bars, so labels run vertically instead — each gets its own lane
                    // regardless of name length.
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(orientation: .verticalReversed)
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

    private var calendarBinding: Binding<Set<DateComponents>> {
        Binding(
            get: { globalWearComponents },
            set: { newValue in
                let added = newValue.subtracting(globalWearComponents)
                let removed = globalWearComponents.subtracting(newValue)
                
                if let target = added.first ?? removed.first,
                   let date = Calendar.current.date(from: target) {
                    selectedCalendarDate = SheetDate(date: date)
                }
            }
        )
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Collection Wear Calendar")

            if globalWearHistory.isEmpty {
                missingDataLabel("No wear data recorded yet. Tap any date to begin.")
                    .padding(.bottom, 8)
            }
            
            MultiDatePicker("Wear Dates", selection: calendarBinding)
                .datePickerStyle(.graphical)
                .tint(.amberGold)
        }
        .padding(16)
        .background(cardBackground)
        .sheet(item: $selectedCalendarDate) { sheetItem in
            let date = sheetItem.date
            NavigationStack {
                List(timepieces) { timepiece in
                    Button(action: {
                        if selectedWatchesForLog.contains(timepiece) {
                            selectedWatchesForLog.remove(timepiece)
                        } else {
                            selectedWatchesForLog.insert(timepiece)
                        }
                    }) {
                        HStack {
                            Text("\(timepiece.manufacturer) \(timepiece.name)")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: selectedWatchesForLog.contains(timepiece) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedWatchesForLog.contains(timepiece) ? .amberGold : .secondary)
                        }
                    }
                }
                .navigationTitle("Log Wrist Check")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            selectedCalendarDate = nil
                            selectedWatchesForLog.removeAll()
                        }
                        .foregroundColor(.amberGold)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            for watch in selectedWatchesForLog {
                                watch.wearHistory.append(date)
                                watch.timesWorn += 1
                                if let lastWorn = watch.lastWornDate {
                                    if date > lastWorn { watch.lastWornDate = date }
                                } else {
                                    watch.lastWornDate = date
                                }
                            }
                            selectedCalendarDate = nil
                            selectedWatchesForLog.removeAll()
                        }
                        .foregroundColor(selectedWatchesForLog.isEmpty ? .gray : .amberGold)
                        .disabled(selectedWatchesForLog.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
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

private struct DistributionShareCard: View {
    let metricLabel: String
    let distribution: [(category: String, count: Int)]
    let sectorColors: [Color]

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.08)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WristScan Insights")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Collection Distribution — \(metricLabel)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }

                Chart(distribution, id: \.category) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                    .cornerRadius(4)
                }
                .frame(height: 420)
                .chartLegend(position: .bottom, alignment: .center, spacing: 12)
                .chartForegroundStyleScale(
                    domain: distribution.map(\.category),
                    range: Array(sectorColors.prefix(distribution.count))
                )

                VStack(spacing: 8) {
                    ForEach(distribution.prefix(6), id: \.category) { item in
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
                        if item.category != distribution.prefix(6).last?.category {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }

                Text("Captured with WristScan")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .padding(28)
        }
    }
}

private struct LeaderboardEntry {
    let name: String
    let secondary: String?
    let count: Int
}

private struct WearChartShareCard: View {
    let periodLabel: String
    let entries: [LeaderboardEntry]

    private var maxCount: Int {
        entries.map(\.count).max() ?? 1
    }

    private var totalCount: Int {
        entries.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ZStack {
            ShareCardBackground()

            VStack(alignment: .leading, spacing: 0) {
                header

                leaderboardCard
                    .padding(.top, 40)
                    .frame(maxHeight: .infinity)

                footer
                    .padding(.top, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 72)
            .padding(.top, 64)
            .padding(.bottom, 56)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("WRISTSCAN INSIGHTS")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(3.5)
                    .foregroundColor(Color(red: 0.498, green: 0.498, blue: 0.529))

                Text("Top Wrist Checks")
                    .font(.system(size: 50, weight: .heavy, design: .rounded))
                    .tracking(-0.8)
                    .foregroundColor(.white)
            }

            Spacer()

            SharePeriodPill(label: periodLabel.uppercased())
                .padding(.top, 6)
        }
    }

    private var leaderboardCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                LeaderboardRow(
                    rank: index + 1,
                    name: entry.name,
                    secondary: entry.secondary?.uppercased(),
                    count: entry.count,
                    maxCount: maxCount,
                    showsDivider: index != entries.count - 1
                )
                if index != entries.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 44)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 30, y: 30)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 12) {
                ShareCardWatermark()
                Text("CAPTURED WITH WRISTSCAN")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Color(red: 0.435, green: 0.435, blue: 0.467))
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("TOTAL")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(Color(red: 0.498, green: 0.498, blue: 0.529))
                Text("\(totalCount)")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.amberGold)
                Text("CHECKS")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(Color(red: 0.498, green: 0.498, blue: 0.529))
            }
        }
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let name: String
    let secondary: String?
    let count: Int
    let maxCount: Int
    let showsDivider: Bool

    private var rankColor: Color {
        rank == 1 ? .amberGold : Color(red: 0.333, green: 0.333, blue: 0.364)
    }

    private var barFill: AnyShapeStyle {
        switch rank {
        case 1:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.659, green: 0.494, blue: 0.247), Color(red: 0.94, green: 0.824, blue: 0.604)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case 2: return AnyShapeStyle(Color.amberGold)
        case 3: return AnyShapeStyle(Color(red: 0.784, green: 0.604, blue: 0.325))
        case 4: return AnyShapeStyle(Color(red: 0.690, green: 0.525, blue: 0.247))
        default: return AnyShapeStyle(Color(red: 0.561, green: 0.427, blue: 0.204))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 30) {
            Text("\(rank)")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 62, alignment: .leading)
                .shadow(color: rank == 1 ? Color.amberGold.opacity(0.4) : .clear, radius: 12)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(name)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if let secondary {
                        Text(secondary)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(Color(red: 0.545, green: 0.545, blue: 0.573))
                            .lineLimit(1)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                        Capsule()
                            .fill(barFill)
                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(max(maxCount, 1)))
                            .shadow(color: rank == 1 ? Color.amberGold.opacity(0.5) : .clear, radius: 9)
                    }
                }
                .frame(height: 14)
            }

            Text("\(count)")
                .font(.system(size: 44, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, 22)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }
        }
    }
}

//#Preview {
//    NavigationStack {
//        AnalyticsDashboardView()
//    }
    // This gives the Canvas a temporary, blank database so it doesn't crash
    //.modelContainer(for: WatchTimepiece.self, inMemory: true)
//}

//#Preview {
  //  let config = ModelConfiguration(isStoredInMemoryOnly: true)
 //   let container = try! ModelContainer(for: WatchTimepiece.self, configurations: config)
    
    // Create a fake watch for the preview
 //   let mockWatch = WatchTimepiece(
  //      manufacturer: "Seiko",
  //      name: "5 GMT", // Ensure the argument name matches your model's requirement
   //     referenceNumber: "SSK001", // Placeholder
 //       purchaseDate: Date(), // Placeholder
  //      purchasePrice: 0.0, // Placeholder
 //       wearHistory: [Date(), Date().addingTimeInterval(-86400)]
 //   )
//    container.mainContext.insert(mockWatch)
    
    // REMOVED 'return' keyword here
 //   NavigationStack {
 //       AnalyticsDashboardView()
 //   }
 //   .modelContainer(container)
//}
