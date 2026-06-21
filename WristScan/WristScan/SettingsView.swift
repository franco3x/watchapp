//
//  SettingsView.swift
//  WristScan
//
//  Created by Antigravity.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var timepieces: [WatchTimepiece]
    
    @State private var csvURL: URL?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Data Management")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.amberGold)
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Collection")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Generate a portable CSV file containing your watch details, purchase history, and modification records.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button(action: {
                            withAnimation {
                                csvURL = generateCSV()
                            }
                        }) {
                            HStack {
                                Spacer()
                                Label("Generate Export", systemImage: "doc.text.fill")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color.amberGold.opacity(0.15))
                            .foregroundColor(.amberGold)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.amberGold.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if let url = csvURL {
                            ShareLink(item: url) {
                                HStack {
                                    Spacer()
                                    Label("Export CSV", systemImage: "square.and.arrow.up.fill")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.07, green: 0.07, blue: 0.08))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .fontWeight(.medium)
                            .foregroundColor(.amberGold)
                    }
                }
            }
        }
    }
    
    private func generateCSV() -> URL? {
        var csvString = "Manufacturer,Model,Reference Number,Purchase Date,Purchase Price,Times Worn,Modification History\n"
        
        for timepiece in timepieces {
            let manufacturer = escape(timepiece.manufacturer)
            let model = escape(timepiece.name)
            let referenceNumber = escape(timepiece.referenceNumber)
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let formattedDate = formatter.string(from: timepiece.purchaseDate)
            let purchaseDateEscaped = escape(formattedDate)
            
            let purchasePriceEscaped = escape(String(format: "%.2f", timepiece.purchasePrice))
            let timesWornEscaped = escape(String(timepiece.timesWorn))
            
            let modificationsList = timepiece.modifications ?? []
            let modificationHistory: String
            if modificationsList.isEmpty {
                modificationHistory = "None"
            } else {
                let modStrings = modificationsList.map { mod in
                    let costString: String
                    if mod.cost.truncatingRemainder(dividingBy: 1) == 0 {
                        costString = String(format: "$%.0f", mod.cost)
                    } else {
                        costString = String(format: "$%.2f", mod.cost)
                    }
                    return "\(mod.componentType) (\(costString))"
                }
                modificationHistory = modStrings.joined(separator: " | ")
            }
            let modificationHistoryEscaped = escape(modificationHistory)
            
            let line = "\(manufacturer),\(model),\(referenceNumber),\(purchaseDateEscaped),\(purchasePriceEscaped),\(timesWornEscaped),\(modificationHistoryEscaped)\n"
            csvString.append(line)
        }
        
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("WristScan_Collection.csv")
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write CSV: \(error)")
            return nil
        }
    }
    
    private func escape(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: WatchTimepiece.self, inMemory: true)
}
