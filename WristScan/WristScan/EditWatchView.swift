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
    
    let movementOptions = ["Automatic", "Manual", "Quartz", "Solar", "Spring Drive", "Mecha-Quartz"]
    
    let watchTypeOptions = ["Pilot", "Chronograph", "Diver", "Dress", "Everyday", "Field", "GMT", "Sports", "Digital", "Calendar"]
    
    var body: some View {
        Form {
            Section(header: Text("Core Identity")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.amberGold)
            ) {
                HStack {
                    Text("Manufacturer")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("Unknown Manufacturer", text: $timepiece.manufacturer)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                        .textInputAutocapitalization(.words)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                HStack {
                    Text("Model Name")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("New Watch", text: $timepiece.modelName)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                        .textInputAutocapitalization(.words)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
            }
            
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
            
            Section(header: Text("Specifications")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.amberGold)
            ) {
                
                HStack {
                    Text("Reference Number")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("e.g. SPB121", text: $timepiece.referenceNumber)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                Picker("Watch Type", selection: $timepiece.watchType) {
                    Text("Select").tag("")
                    ForEach(watchTypeOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                Picker("Movement Type", selection: $timepiece.movementType) {
                    Text("Select").tag("") 
                    ForEach(movementOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                HStack {
                    Text("Caliber")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("e.g. 6R35", text: $timepiece.movement)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
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
                    timepiece.name = timepiece.modelName
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
