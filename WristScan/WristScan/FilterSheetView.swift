import SwiftUI

struct FilterSheetView: View {
    @Environment(\.dismiss) var dismiss
    
    let timepieces: [WatchTimepiece]
    
    @Binding var selectedManufacturer: String
    @Binding var selectedWatchType: String
    @Binding var selectedCaseMaterial: String
    @Binding var selectedDialColor: String
    @Binding var selectedMovementType: String
    
    var manufacturers: [String] {
        let unique = Set(timepieces.map(\.manufacturer).filter { !$0.isEmpty })
        return ["All"] + unique.sorted()
    }
    
    var watchTypes: [String] {
        let unique = Set(timepieces.map(\.watchType).filter { !$0.isEmpty })
        return ["All"] + unique.sorted()
    }
    
    var caseMaterials: [String] {
        let unique = Set(timepieces.map(\.caseMaterial).filter { !$0.isEmpty })
        return ["All"] + unique.sorted()
    }
    
    var dialColors: [String] {
        let unique = Set(timepieces.map(\.dialColor).filter { !$0.isEmpty })
        return ["All"] + unique.sorted()
    }
    
    var movementTypes: [String] {
        let unique = Set(timepieces.map(\.movementType).filter { !$0.isEmpty })
        return ["All"] + unique.sorted()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Manufacturer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.amberGold)
                ) {
                    Picker("Manufacturer", selection: $selectedManufacturer) {
                        ForEach(manufacturers, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                }
                
                Section(header: Text("Watch Type")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.amberGold)
                ) {
                    Picker("Watch Type", selection: $selectedWatchType) {
                        ForEach(watchTypes, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                }
                
                Section(header: Text("Case Material")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.amberGold)
                ) {
                    Picker("Case Material", selection: $selectedCaseMaterial) {
                        ForEach(caseMaterials, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                }
                
                Section(header: Text("Dial Color")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.amberGold)
                ) {
                    Picker("Dial Color", selection: $selectedDialColor) {
                        ForEach(dialColors, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                }
                
                Section(header: Text("Movement Type")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.amberGold)
                ) {
                    Picker("Movement Type", selection: $selectedMovementType) {
                        ForEach(movementTypes, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.14))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.07, green: 0.07, blue: 0.08))
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        selectedManufacturer = "All"
                        selectedWatchType = "All"
                        selectedCaseMaterial = "All"
                        selectedDialColor = "All"
                        selectedMovementType = "All"
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.amberGold)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.08), for: .navigationBar)
        }
    }
}
