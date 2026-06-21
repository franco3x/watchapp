//
//  ManualWristCheckView.swift
//  WristScan
//
//  Purpose: Allows logging a wrist check from a past date with a graphical calendar selector.
//

import SwiftUI
import SwiftData

struct ManualWristCheckView: View {
    @Bindable var timepiece: WatchTimepiece
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate: Date = Date.now
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Select Date")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.amberGold)
                ) {
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accentColor(.amberGold)
                }
            }
            .navigationTitle("Log Past Wear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.amberGold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        timepiece.wearHistory.append(selectedDate)
                        timepiece.timesWorn = timepiece.wearHistory.count
                        
                        // Keep lastWornDate updated to the most recent date in wear history
                        if let maxDate = timepiece.wearHistory.max() {
                            timepiece.lastWornDate = maxDate
                        }
                        
                        dismiss()
                    }
                    .foregroundColor(.amberGold)
                }
            }
        }
    }
}
