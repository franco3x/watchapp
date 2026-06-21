//
//  EditWatchView.swift
//  WristScan
//
//  Purpose: The user configuration space hosting data mutation controls for individual watch timepieces, supporting in-memory and persistent edits.
//

import SwiftUI
import SwiftData

struct EditWatchView: View {
    @Bindable var timepiece: WatchTimepiece
    @Environment(\.dismiss) var dismiss
    
    @State private var priceInput: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Details")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.amberGold)
            ) {
                HStack {
                    Text("Purchase Price")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("0.00", text: $priceInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                DatePicker(
                    "Purchase Date",
                    selection: $timepiece.purchaseDate,
                    displayedComponents: .date
                )
                .foregroundColor(.white)
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                Stepper(value: $timepiece.timesWorn, in: 0...1000000) {
                    HStack {
                        Text("Times Worn")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(timepiece.timesWorn)")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .onAppear {
            priceInput = timepiece.purchasePrice == 0.0 ? "" : String(format: "%.2f", timepiece.purchasePrice)
        }
        .navigationTitle("Edit Watch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    timepiece.purchasePrice = Double(priceInput) ?? 0.0
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundColor(.amberGold)
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditWatchView(timepiece: WatchTimepiece(
            manufacturer: "Seiko",
            name: "Prospex Alpinist",
            referenceNumber: "SPB121",
            purchaseDate: Date(),
            purchasePrice: 725.0
        ))
        .modelContainer(for: WatchTimepiece.self, inMemory: true)
    }
}
