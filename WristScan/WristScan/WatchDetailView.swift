//
//  WatchDetailView.swift
//  WristScan
//
//  Purpose: Overhauled detailed view displaying an individual timepiece's hero image, critical stats, and modification history list with access to edit controls.
//

import SwiftUI
import SwiftData

struct WatchDetailView: View {
    @Bindable var timepiece: WatchTimepiece
    var autoPresentEdit: Bool = false

    @State private var showingAddModification = false
    @State private var showingEditSheet = false
    /// One-shot guard: ensures autoPresentEdit only fires once per view lifetime.
    @State private var hasAutoPresented = false
    @State private var selectedTab: String = "Overview"
    @State private var showingManualWristCheck = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Image
                if let data = timepiece.imageData, let uiImage = UIImage(data: data) {
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
                
                VStack(alignment: .leading, spacing: 20) {
                    // Header Block
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
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }) {
                                HStack(spacing: 8) {
                                    Text("WRIST CHECK")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .tracking(1.0)
                                    
                                    // A small vertical divider
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
                    
                    Picker("View Selection", selection: $selectedTab) {
                        Text("Overview").tag("Overview")
                        Text("Stats").tag("Stats")
                        Text("Wrist Checks").tag("Wrist Checks")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical)
                    
                    if selectedTab == "Overview" {
                        // Section 1: Specifications (Core Identity)
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        
                        // Section 1b: Case & Dimensions
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        
                        // Section 1c: Dial & Movement
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Dial & Movement")
                                .font(.headline)
                                .foregroundColor(.amberGold)
                            
                            VStack(spacing: 0) {
                                SpecRow(label: "Dial Color", value: timepiece.dialColor)
                                Divider().background(Color.white.opacity(0.1))
                                SpecRow(label: "Lume Type", value: timepiece.lumeType)
                                Divider().background(Color.white.opacity(0.1))
                                SpecRow(label: "Movement Type", value: timepiece.movementType)
                                Divider().background(Color.white.opacity(0.1))
                                SpecRow(label: "Caliber", value: timepiece.movement)
                                Divider().background(Color.white.opacity(0.1))
                                SpecRow(label: "Complications", value: timepiece.complications)
                            }
                            .padding(14)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        
                        // Section 1d: Band & Integrity
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Band & Integrity")
                                .font(.headline)
                                .foregroundColor(.amberGold)
                            
                            VStack(spacing: 0) {
                                SpecRow(label: "Strap/Bracelet", value: timepiece.strapMaterial)
                                Divider().background(Color.white.opacity(0.1))
                                SpecRow(label: "Crystal Type", value: timepiece.crystalType)
                            }
                            .padding(14)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        
                        // Section 2: Acquisition
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Acquisition")
                                .font(.headline)
                                .foregroundColor(.amberGold)
                            
                            VStack(spacing: 0) {
                                SpecRow(label: "Purchase Date", value: timepiece.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                                Divider().background(Color.white.opacity(0.1))
                                SpecRow(label: "Purchase Price", value: timepiece.purchasePrice.formatted(.currency(code: "USD")))
                                Divider().background(Color.white.opacity(0.1))
                                SpecRow(label: "Times Worn", value: "\(timepiece.timesWorn) \(timepiece.timesWorn == 1 ? "wear" : "wears")")
                            }
                            .padding(14)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        
                        // Section 3: Modifications
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Modification History")
                                .font(.headline)
                                .foregroundColor(.amberGold)
                            
                            let modifications = timepiece.modifications ?? []
                            if modifications.isEmpty {
                                Text("No modifications recorded.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .italic()
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(modifications) { modification in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(modification.componentType)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Text(modification.cost, format: .currency(code: "USD"))
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.amberGold)
                                            }
                                            
                                            Text(modification.modificationDetails)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            
                                            Text("Applied: \(modification.dateApplied.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption)
                                                .foregroundColor(.gray.opacity(0.6))
                                        }
                                        .padding(14)
                                        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Inline Notes Scratchpad
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.headline)
                                .foregroundColor(.amberGold)
                            
                            TextEditor(text: $timepiece.notes)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(minHeight: 150)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        }
                    } else if selectedTab == "Stats" {
                        WristCheckCalendarView(wearHistory: timepiece.wearHistory) { tappedDate in
                            // Check if the date already exists in the history (comparing by exact day)
                            if let index = timepiece.wearHistory.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: tappedDate) }) {
                                // If it exists, toggle it OFF (remove it)
                                timepiece.wearHistory.remove(at: index)
                            } else {
                                // If it doesn't exist, toggle it ON (add it)
                                timepiece.wearHistory.append(tappedDate)
                            }
                            // Recalibrate derived stats
                            timepiece.timesWorn = timepiece.wearHistory.count
                            timepiece.lastWornDate = timepiece.wearHistory.max()
                            // Light haptic so the user feels the tap
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        .padding(.top)
                    } else if selectedTab == "Wrist Checks" {

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Wear History")
                                    .font(.headline)
                                    .foregroundColor(.amberGold)
                                Spacer()
                                Button {
                                    showingManualWristCheck = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.body.weight(.bold))
                                        .foregroundColor(.amberGold)
                                }
                            }
                            
                            if timepiece.wearHistory.isEmpty {
                                ContentUnavailableView("No Wrist Checks", systemImage: "clock.arrow.circlepath", description: Text("Tap the Wrist Check button to log your first wear."))
                                    .padding(.vertical, 40)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(timepiece.wearHistory.sorted(by: >).enumerated()), id: \.offset) { index, date in
                                        HStack {
                                            Label {
                                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                            } icon: {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.amberGold)
                                                    .font(.system(size: 14))
                                            }
                                            
                                            Spacer()
                                            
                                            Text("Check #\(timepiece.wearHistory.count - index)")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 8)
                                            
                                            Button {
                                                timepiece.wearHistory.removeAll { $0 == date }
                                                timepiece.timesWorn = timepiece.wearHistory.count
                                                if let maxDate = timepiece.wearHistory.max() {
                                                    timepiece.lastWornDate = maxDate
                                                } else {
                                                    timepiece.lastWornDate = nil
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 12)
                                        
                                        if index < timepiece.wearHistory.count - 1 {
                                            Divider().background(Color.white.opacity(0.1))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
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
                showingEditSheet = true
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
                .foregroundColor(.amberGold)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showingAddModification = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.amberGold)
                }
            }
        }
        .sheet(isPresented: $showingAddModification) {
            AddModificationView(timepiece: timepiece)
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                EditWatchView(timepiece: timepiece)
            }
        }
        .sheet(isPresented: $showingManualWristCheck) {
            ManualWristCheckView(timepiece: timepiece)
                .presentationDetents([.medium])
        }
    }
}

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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
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
                    Button("Cancel") {
                        dismiss()
                    }
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
