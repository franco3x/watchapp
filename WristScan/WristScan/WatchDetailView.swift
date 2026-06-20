//
//  WatchDetailView.swift
//  WristScan
//

import SwiftUI
import SwiftData

struct WatchDetailView: View {
    @Bindable var timepiece: WatchTimepiece
    @State private var showingAddModification = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(timepiece.manufacturer)
                        .font(.headline)
                        .foregroundColor(.amberGold)
                    Text(timepiece.name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(timepiece.referenceNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Watch Details")
            }
            
            Section {
                let modifications = timepiece.modifications ?? []
                if modifications.isEmpty {
                    Text("No modifications recorded.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(modifications) { modification in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(modification.componentType)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(modification.cost, format: .currency(code: "USD"))
                                    .fontWeight(.medium)
                            }
                            Text(modification.modificationDetails)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Applied: \(modification.dateApplied.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Modification History")
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
