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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var rawSelectedImage: UIImage? = nil
    @State private var showCropper: Bool = false
    @State private var showImageOptions: Bool = false
    @State private var showPicker: Bool = false
    
    let movementOptions = ["Automatic", "Manual", "Quartz", "Solar", "Spring Drive", "Mecha-Quartz"]
    
    let watchTypeOptions = ["Pilot", "Chronograph", "Diver", "Dress", "Everyday", "Field", "GMT", "Sports", "Digital", "Calendar"]
    
    let caseMaterials = ["Stainless Steel", "Titanium", "Bronze", "Two-Tone", "Yellow Gold", "Rose Gold", "Ceramic", "Resin/Plastic"]
    
    let crystalTypes = ["Sapphire", "Mineral", "Acrylic / Hesalite"]
    
    var body: some View {
        Form {
            Section(header: Text("Timepiece Photo")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.amberGold)
            ) {
                IsolatedPhotoPickerView(
                    hasExistingImage: timepiece.imageData != nil,
                    selection: $selectedPhotoItem,
                    showPicker: $showPicker,
                    showImageOptions: $showImageOptions
                )
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    
                    Task {
                        // Load raw data
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            
                            // Move completely off the main thread to decode the massive image
                            let decodedImage = await Task.detached(priority: .userInitiated) {
                                UIImage(data: data)
                            }.value
                            
                            // Hop back to the main thread to update UI state
                            await MainActor.run {
                                if let decodedImage {
                                    self.rawSelectedImage = decodedImage
                                    self.showCropper = true
                                }
                                // Clear so the same image can be re-picked if needed
                                self.selectedPhotoItem = nil
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
                    DecimalTextField(title: "0.00", value: $timepiece.purchasePrice)
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
            
            Section(header: Text("Case & Dial Architecture")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.amberGold)
            ) {
                Picker("Case Material", selection: $timepiece.caseMaterial) {
                    Text("Select").tag("")
                    ForEach(caseMaterials, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                Picker("Crystal Type", selection: $timepiece.crystalType) {
                    Text("Select").tag("")
                    ForEach(crystalTypes, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .foregroundColor(.white)
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                HStack {
                    Text("Dial Color")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("e.g. Black, Blue", text: $timepiece.dialColor)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                HStack {
                    Text("Lume Type")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("e.g. Super-LumiNova", text: $timepiece.lumeType)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
            }
            
            Section(header: Text("Dimensions (mm)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.amberGold)
            ) {
                HStack {
                    Text("Case Size")
                        .foregroundColor(.white)
                    Spacer()
                    DecimalTextField(title: "e.g. 40.0", value: $timepiece.caseSize)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                HStack {
                    Text("Lug to Lug")
                        .foregroundColor(.white)
                    Spacer()
                    DecimalTextField(title: "e.g. 47.0", value: $timepiece.lugToLug)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                HStack {
                    Text("Lug Width")
                        .foregroundColor(.white)
                    Spacer()
                    DecimalTextField(title: "e.g. 20.0", value: $timepiece.lugWidth)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
            }
            
            Section(header: Text("Band & Capabilities")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.amberGold)
            ) {
                HStack {
                    Text("Strap/Bracelet Material")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("e.g. Oyster, Leather", text: $timepiece.strapMaterial)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                HStack {
                    Text("Water Resistance")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("e.g. 200m", text: $timepiece.waterResistance)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                HStack {
                    Text("Complications")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("e.g. Day-Date, GMT", text: $timepiece.complications)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .navigationTitle("Edit Watch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    timepiece.name = timepiece.modelName
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundColor(.amberGold)
            }
        }
        .confirmationDialog("Watch Photo", isPresented: $showImageOptions, titleVisibility: .visible) {
            Button("Adjust Current Photo") {
                if let data = timepiece.imageData, let currentImage = UIImage(data: data) {
                    rawSelectedImage = currentImage
                    showCropper = true
                }
            }
            Button("Choose New Photo") {
                showPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let rawImage = rawSelectedImage {
                ImageAdjusterView(originalImage: rawImage) { croppedImage in
                    if let finalData = croppedImage?.jpegData(compressionQuality: 0.8) {
                        // Write the flattened, cropped data to the database
                        timepiece.imageData = finalData
                        // Force SwiftData to notify parent views of the change
                        try? modelContext.save()
                    }
                    rawSelectedImage = nil
                    showCropper = false
                } onCancel: {
                    rawSelectedImage = nil
                    showCropper = false
                }
            }
        }
    }
}

// MARK: - Isolated Photo Picker
// Strict isolation: receives only primitive bindings, no SwiftData model.
// Prevents EditWatchView redraws (triggered by timepiece changes) from
// corrupting the PhotosPicker's internal scroll position.
struct IsolatedPhotoPickerView: View {
    let hasExistingImage: Bool
    @Binding var selection: PhotosPickerItem?
    @Binding var showPicker: Bool
    @Binding var showImageOptions: Bool
    
    var body: some View {
        Button {
            if hasExistingImage {
                showImageOptions = true
            } else {
                showPicker = true
            }
        } label: {
            // Note: label shows the placeholder only — image preview is rendered
            // by the parent which owns timepiece. This view is intentionally
            // ignorant of imageData to avoid being redrawn on model changes.
            if hasExistingImage {
                HStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.amberGold)
                    Text("Change Photo")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.amberGold)
                    Spacer()
                }
                .padding(.vertical, 12)
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
        .photosPicker(isPresented: $showPicker, selection: $selection, matching: .images)
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
