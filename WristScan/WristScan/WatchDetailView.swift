//
//  WatchDetailView.swift
//  WristScan
//

import SwiftUI
import SwiftData
import Charts

struct MonthlyWearLog: Identifiable {
    let id = UUID()
    let month: Date
    let count: Int
}

enum DetailSheet: Identifiable {
    case edit
    case modification
    case manualWristCheck
    case accuracy
    
    var id: Int { hashValue }
}

struct WatchDetailView: View {
    @Bindable var timepiece: WatchTimepiece
    var autoPresentEdit: Bool = false

    @State private var activeSheet: DetailSheet?
    @State private var hasAutoPresented = false
    @State private var selectedTab: String = "Overview"
    @State private var stableChartData: [MonthlyWearLog] = []
    
    // Cache the decoded image out of the layout loop
    @State private var localTimepieceImage: UIImage? = nil

    // MARK: - Safe Computed Properties
    private var sortedWearHistory: [Date] {
        timepiece.wearHistory.sorted(by: >)
    }

    private var safeModifications: [WatchModification] {
        timepiece.modifications ?? []
    }

    private var sortedAccuracyLogs: [AccuracyLog] {
        (timepiece.accuracyLogs ?? []).sorted { $0.dateChecked > $1.dateChecked }
    }

    func getMonthlyWearData() -> [MonthlyWearLog] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: timepiece.wearHistory) { date in
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? date
        }
        return grouped.map { MonthlyWearLog(month: $0.key, count: $0.value.count) }
                      .sorted { $0.month < $1.month }
    }

    private func reloadImage() {
        if let data = timepiece.imageData {
            Task {
                let decoded = await Task.detached(priority: .userInitiated) {
                    UIImage(data: data)
                }.value
                await MainActor.run { self.localTimepieceImage = decoded }
            }
        } else {
            self.localTimepieceImage = nil
        }
    }
    
    // MARK: - Main Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroImageView
                
                VStack(alignment: .leading, spacing: 20) {
                    headerBlockView
                    
                    Picker("View Selection", selection: $selectedTab) {
                        Image(systemName: "list.bullet.clipboard").tag("Overview")
                        Image(systemName: "chart.bar").tag("Stats")
                        Image(systemName: "clock.badge.checkmark").tag("Wrist Checks")
                        Image(systemName: "wrench.and.screwdriver").tag("Service Log")
                        Image(systemName: "stopwatch").tag("Accuracy")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical)
                    
                    // Segregated Subviews
                    Group {
                        if selectedTab == "Overview" {
                            overviewTab
                        } else if selectedTab == "Stats" {
                            statsTab
                        } else if selectedTab == "Wrist Checks" {
                            wristChecksTab
                        } else if selectedTab == "Service Log" {
                            serviceLogTab
                        } else if selectedTab == "Accuracy" {
                            accuracyTab
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .onAppear {
            if autoPresentEdit && !hasAutoPresented {
                hasAutoPresented = true
                activeSheet = .edit
            }
            stableChartData = getMonthlyWearData()
        }
        .task(id: timepiece.persistentModelID) {
            reloadImage()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    activeSheet = .edit
                }
                .foregroundColor(.amberGold)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit:
                EditWatchSheetContainer(timepiece: timepiece)
            case .modification:
                AddModificationView(timepiece: timepiece)
            case .manualWristCheck:
                ManualWristCheckView(timepiece: timepiece)
                    .presentationDetents([.medium])
            case .accuracy:
                AccuracyCheckView(timepiece: timepiece)
            }
        }
        .onChange(of: activeSheet) { oldValue, newValue in
            if newValue == nil {
                stableChartData = getMonthlyWearData()
                reloadImage() // Refresh the cache only when closing a sheet
            }
        }
    }

    // MARK: - Extracted Component Views
    @ViewBuilder
    private var heroImageView: some View {
        if let uiImage = localTimepieceImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(height: 300)
                .frame(maxWidth: .infinity)
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
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.amberGold.opacity(0.18))
                    .offset(y: -10)
                
                VStack {
                    Spacer()
                    Text("No Photo Uploaded")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(1.0)
                        .padding(.bottom, 16)
                }
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }

    @ViewBuilder
    private var headerBlockView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text((timepiece.manufacturer.isEmpty ? "Unknown Manufacturer" : timepiece.manufacturer).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.amberGold)
                    .tracking(1.5)
                
                Text(timepiece.modelName.isEmpty ? "New Watch" : timepiece.modelName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(timepiece.referenceNumber.isEmpty ? "—" : timepiece.referenceNumber)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Button(action: {
                    timepiece.timesWorn += 1
                    timepiece.lastWornDate = Date.now
                    timepiece.wearHistory.append(Date.now)
                    stableChartData = getMonthlyWearData()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Text("WRIST CHECK")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.0)
                        
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.amberGold.opacity(0.3))
                            .frame(width: 1, height: 12)
                        
                        Text("\(timepiece.timesWorn)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.amberGold.opacity(0.12))
                    .foregroundColor(.amberGold)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.amberGold.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                if let date = timepiece.lastWornDate {
                    Text("Last Worn: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    Text("Last Worn: Unworn")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Tab Panes
    @ViewBuilder
    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Core Identity")
                    .font(.headline)
                    .foregroundColor(.amberGold)
                
                VStack(spacing: 0) {
                    SpecRow(label: "Manufacturer", value: timepiece.manufacturer.isEmpty ? "Unknown Manufacturer" : timepiece.manufacturer)
                    Divider().background(Color.white.opacity(0.1))
                    SpecRow(label: "Model Name", value: timepiece.modelName.isEmpty ? "New Watch" : timepiece.modelName)
                    Divider().background(Color.white.opacity(0.1))
                    SpecRow(label: "Reference Number", value: timepiece.referenceNumber)
                    Divider().background(Color.white.opacity(0.1))
                    SpecRow(label: "Watch Type", value: timepiece.watchType)
                }
                .padding(14)
                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Case & Dimensions")
                    .font(.headline)
                    .foregroundColor(.amberGold)
                
                VStack(spacing: 0) {
                    SpecRow(label: "Case Material", value: timepiece.caseMaterial)
                    Divider().background(Color.white.opacity(0.1))
                    SpecRow(label: "Case Size", value: timepiece.caseSize > 0 ? "\(timepiece.caseSize.formatted()) mm" : "—")
                    Divider().background(Color.white.opacity(0.1))
                    SpecRow(label: "Lug to Lug", value: timepiece.lugToLug > 0 ? "\(timepiece.lugToLug.formatted()) mm" : "—")
                    Divider().background(Color.white.opacity(0.1))
                    SpecRow(label: "Lug Width", value: timepiece.lugWidth > 0 ? "\(timepiece.lugWidth.formatted()) mm" : "—")
                    Divider().background(Color.white.opacity(0.1))
                    SpecRow(label: "Water Resistance", value: timepiece.waterResistance)
                }
                .padding(14)
                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Notes")
                    .font(.headline)
                    .foregroundColor(.amberGold)
                
                TextField("Add notes here...", text: $timepiece.notes, axis: .vertical)
                    .lineLimit(5...15)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private var statsTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wear Frequency by Month")
                    .font(.headline)
                    .foregroundColor(.amberGold)
                
                if stableChartData.isEmpty {
                    Text("No wear data available.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Chart(stableChartData) { item in
                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Wears", item.count)
                        )
                        .foregroundStyle(Color.amberGold.gradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .cornerRadius(12)
            
            WristCheckCalendarView(wearHistory: timepiece.wearHistory) { tappedDate in
                if let index = timepiece.wearHistory.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: tappedDate) }) {
                    timepiece.wearHistory.remove(at: index)
                } else {
                    timepiece.wearHistory.append(tappedDate)
                }
                timepiece.timesWorn = timepiece.wearHistory.count
                timepiece.lastWornDate = timepiece.wearHistory.max()
                stableChartData = getMonthlyWearData()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .padding(.top)
        }
    }

    @ViewBuilder
    private var wristChecksTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Wear History")
                    .font(.headline)
                    .foregroundColor(.amberGold)
                Spacer()
                Button { activeSheet = .manualWristCheck } label: {
                    Image(systemName: "plus").foregroundColor(.amberGold)
                }
            }
            
            if sortedWearHistory.isEmpty {
                ContentUnavailableView("No Wrist Checks", systemImage: "clock.arrow.circlepath")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedWearHistory.enumerated()), id: \.offset) { index, date in
                        HStack {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Button {
                                timepiece.wearHistory.removeAll { $0 == date }
                                timepiece.timesWorn = timepiece.wearHistory.count
                                timepiece.lastWornDate = timepiece.wearHistory.max()
                                stableChartData = getMonthlyWearData()
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 12)
                        
                        if index < sortedWearHistory.count - 1 {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private var serviceLogTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Service & Modifications")
                    .font(.headline)
                    .foregroundColor(.amberGold)
                Spacer()
                Button { activeSheet = .modification } label: {
                    Image(systemName: "plus").foregroundColor(.amberGold)
                }
            }
            
            if safeModifications.isEmpty {
                Text("No modifications recorded.").italic().foregroundColor(.gray)
            } else {
                VStack(spacing: 12) {
                    ForEach(safeModifications) { modification in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(modification.componentType).foregroundColor(.white)
                                Spacer()
                                Button {
                                    timepiece.modifications?.removeAll { $0.id == modification.id }
                                } label: {
                                    Image(systemName: "trash").foregroundColor(.red)
                                }
                            }
                            Text(modification.modificationDetails).foregroundColor(.gray)
                        }
                        .padding(14)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accuracyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accuracy Ledger")
                    .font(.headline)
                    .foregroundColor(.amberGold)
                Spacer()
                Button { activeSheet = .accuracy } label: {
                    Image(systemName: "plus").foregroundColor(.amberGold)
                }
            }

            if sortedAccuracyLogs.isEmpty {
                Text("No logs available.").foregroundColor(.gray)
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedAccuracyLogs) { log in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(log.dateChecked.formatted(date: .abbreviated, time: .shortened))
                                Text(log.position).font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(log.deviationInSeconds >= 0 ? "+" : "")\(String(format: "%.1f", log.deviationInSeconds))s")
                            Button {
                                timepiece.accuracyLogs?.removeAll { $0.id == log.id }
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                        .padding(14)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Structs
struct MetricCard: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1.0)
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

struct SpecRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
    }
}

struct AddModificationView: View {
    @Environment(\.dismiss) private var dismiss
    var timepiece: WatchTimepiece
    
    @State private var componentType: String = ""
    @State private var details: String = ""
    @State private var cost: Double = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Modification Info")) {
                    TextField("Component Type (e.g., Bezel, Crystal)", text: $componentType)
                    TextField("Details", text: $details)
                    TextField("Cost", value: $cost, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Modification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let modification = WatchModification(
                            componentType: componentType,
                            modificationDetails: details,
                            cost: cost
                        )
                        if timepiece.modifications == nil {
                            timepiece.modifications = []
                        }
                        timepiece.modifications?.append(modification)
                        dismiss()
                    }
                    .disabled(componentType.isEmpty || details.isEmpty)
                }
            }
        }
    }
}

struct EditWatchSheetContainer: View {
    @Bindable var timepiece: WatchTimepiece
    
    var body: some View {
        NavigationStack {
            EditWatchView(timepiece: timepiece)
        }
    }
}