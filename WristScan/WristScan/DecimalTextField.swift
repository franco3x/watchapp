import SwiftUI

struct DecimalTextField: View {
    let title: String
    @Binding var value: Double
    @State private var textValue: String = ""
    
    var body: some View {
        TextField(title, text: $textValue)
            .keyboardType(.decimalPad)
            .onChange(of: textValue) { _, newValue in
                // Filter the input to allow only numbers and a single decimal point
                let filtered = newValue.filter { "0123456789.".contains($0) }
                let components = filtered.split(separator: ".", omittingEmptySubsequences: false)
                
                let processed: String
                if components.count > 2 {
                    let firstPart = components[0]
                    let remainingParts = components.dropFirst().joined()
                    processed = firstPart + "." + remainingParts
                } else {
                    processed = filtered
                }
                
                // Update textValue if filtering changed it
                if processed != newValue {
                    textValue = processed
                }
                
                // Attempt to cast the filtered string to a Double. If successful, assign it to value. If empty, assign 0.0.
                if processed.isEmpty {
                    value = 0.0
                } else if let doubleVal = Double(processed) {
                    value = doubleVal
                }
            }
            .onAppear {
                if value == 0.0 {
                    textValue = ""
                } else {
                    // Avoid unnecessary trailing zeros if it's an exact integer, otherwise show string representation
                    if value.truncatingRemainder(dividingBy: 1) == 0 {
                        textValue = String(format: "%.0f", value)
                    } else {
                        textValue = String(value)
                    }
                }
            }
    }
}
