//
//  EditWatchView.swift
//  WristScan
//
//  Purpose: The user configuration space hosting data mutation controls for individual watch timepieces, supporting in-memory and persistent edits.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditWatchView: View {
    @Bindable var timepiece: WatchTimepiece
    @Environment(\.dismiss) var dismiss
    
    @State private var priceInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    let movementOptions = ["Automatic", "Manual", "Quartz", "Solar", "Spring Drive", "Mecha-Quartz"]
    
    let watchTypeOptions = ["Pilot", "Chronograph", "Diver", "Dress", "Everyday", "Field", "GMT", "Sports", "Digital", "Calendar"]
    
    var body: some View {
        Form {
            Section(header: Text("Timepiece Photo")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.amberGold)
            ) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    if let data = timepiece.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                    } else {
                        HStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 16))
                                .foregroundColor(.amberGold)
                            Text("Add Photo")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.amberGold)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                .onChange(of: selectedPhotoItem) { oldValue, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data), let compressedData = uiImage.jpegData(compressionQuality: 0.8) {
                                timepiece.imageData = compressedData
                            }
                        }
                    }
                }
            }
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
