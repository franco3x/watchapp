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
    @State private var showingAddModification = false
    @State private var showingEditSheet = false
    
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
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.15, green: 0.15, blue: 0.17),
                                    Color(red: 0.09, green: 0.09, blue: 0.10)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No Photo Uploaded")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                        )
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    // Header Block
                    VStack(alignment: .leading, spacing: 6) {
                        Text(timepiece.manufacturer.uppercased())
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.amberGold)
                            .tracking(1.5)
                        
                        Text(timepiece.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(timepiece.referenceNumber)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    // Section 1: Specifications
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Specifications")
                            .font(.headline)
                            .foregroundColor(.amberGold)
                        
                        VStack(spacing: 0) {
                            SpecRow(label: "Manufacturer", value: timepiece.manufacturer)
                            Divider().background(Color.white.opacity(0.1))
                            SpecRow(label: "Model Name", value: timepiece.modelName)
                            Divider().background(Color.white.opacity(0.1))
                            SpecRow(label: "Reference Number", value: timepiece.referenceNumber)
                            Divider().background(Color.white.opacity(0.1))
                            SpecRow(label: "Watch Type", value: timepiece.watchType)
                            Divider().background(Color.white.opacity(0.1))
                            SpecRow(label: "Movement Type", value: timepiece.movementType)
                            Divider().background(Color.white.opacity(0.1))
                            SpecRow(label: "Caliber", value: timepiece.movement)
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
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
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
