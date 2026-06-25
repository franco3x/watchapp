import Foundation
import SwiftData
import SwiftUI

// 1. Extremely lightweight struct - NO heavy image data here!
struct WatchSnapshot {
    let index: Int
    let manufacturer: String
    let modelName: String
    let wearHistory: [Date]
}

struct RewindMetrics {
    let totalWristChecks: Int
    let mostWornWatchIndex: Int?
    let favoriteBrand: (name: String, count: Int)?
    let longestWearStreak: Int
    let distinctWatchesWorn: Int
    let mostWornCount: Int
}

@Observable
class RewindEngine {
    var metrics: RewindMetrics? = nil
    var isCalculating: Bool = false
    
    // Held state for the winning watch so the UI doesn't have to guess
    var winningWatchImage: Data? = nil
    var winningWatchManufacturer: String = ""
    var winningWatchModelName: String = ""
    
    @MainActor
    func generateReport(for timepieces: [WatchTimepiece], start: Date, end: Date) async {
        self.isCalculating = true
        
        // Yield thread to allow Picker animation to finish.
        // CRITICAL: use do/catch, NOT try? — try? swallows CancellationError and lets
        // the task keep running as a zombie even after SwiftUI cancels it via .task(id:).
        // Multiple zombie tasks stacking up disk reads on the main thread is what freezes UI.
        do {
            try await Task.sleep(for: .milliseconds(250))
        } catch {
            // Task was cancelled — exit cleanly so no zombie work accumulates.
            self.isCalculating = false
            return
        }
        
        // 1. Extract ONLY lightweight data (Dates and Strings).
        // We specifically avoid `imageData` here to prevent Main Thread BLOB locks.
        var snapshots: [WatchSnapshot] = []
        for (index, watch) in timepieces.enumerated() {
            snapshots.append(WatchSnapshot(
                index: index,
                manufacturer: watch.manufacturer,
                modelName: watch.modelName,
                wearHistory: watch.wearHistory
            ))
        }
        
        // 2. Offload purely mathematical work to a detached background thread.
        let result = await Task.detached(priority: .userInitiated) {
            return self.crunchNumbers(snapshots: snapshots, start: start, end: end)
        }.value
        
        // Guard after every suspension point — a newer task may have started while
        // we were in the background, making this result stale.
        guard !Task.isCancelled else {
            self.isCalculating = false
            return
        }
        
        // 3. Back on Main Thread: Safely fetch the heavy image for ONLY the winning watch.
        // imageData is @Attribute(.externalStorage) — one synchronous disk read is acceptable
        // here because zombie tasks are now prevented, so this never stacks up.
        if let winningIndex = result.mostWornWatchIndex, timepieces.indices.contains(winningIndex) {
            let winningWatch = timepieces[winningIndex]
            self.winningWatchImage = winningWatch.imageData
            self.winningWatchManufacturer = winningWatch.manufacturer
            self.winningWatchModelName = winningWatch.modelName
        } else {
            self.winningWatchImage = nil
            self.winningWatchManufacturer = ""
            self.winningWatchModelName = ""
        }
        
        self.metrics = result
        self.isCalculating = false
    }
    
    nonisolated private func crunchNumbers(snapshots: [WatchSnapshot], start: Date, end: Date) -> RewindMetrics {
        func wearsInPeriod(for watch: WatchSnapshot) -> [Date] {
            return watch.wearHistory.filter { $0 >= start && $0 <= end }
        }
        
        let totalChecks = snapshots.reduce(0) { $0 + wearsInPeriod(for: $1).count }
        
        let mostWorn = snapshots.map { (watch: $0, count: wearsInPeriod(for: $0).count) }
            .filter { $0.count > 0 }
            .max { $0.count < $1.count }
            
        var brandCounts: [String: Int] = [:]
        for watch in snapshots {
            let count = wearsInPeriod(for: watch).count
            if count > 0 {
                brandCounts[watch.manufacturer.uppercased(), default: 0] += count
            }
        }
        let favBrand = brandCounts.map { (name: $0.key, count: $0.value) }
            .max { $0.count < $1.count }
            
        let calendar = Calendar.current
        let allDates = snapshots.flatMap { wearsInPeriod(for: $0) }
        let distinctDays = Set(allDates.map { calendar.startOfDay(for: $0) }).sorted()

        var maxStreak = 0
        if !distinctDays.isEmpty {
            var currentStreak = 1
            maxStreak = 1
            for i in 1..<distinctDays.count {
                let daysBetween = calendar.dateComponents([.day], from: distinctDays[i-1], to: distinctDays[i]).day
                if daysBetween == 1 {
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                } else {
                    currentStreak = 1
                }
            }
        }
        
        let distinctWorn = snapshots.filter { wearsInPeriod(for: $0).count > 0 }.count
        
        return RewindMetrics(
            totalWristChecks: totalChecks,
            mostWornWatchIndex: mostWorn?.watch.index,
            favoriteBrand: favBrand,
            longestWearStreak: maxStreak,
            distinctWatchesWorn: distinctWorn,
            mostWornCount: mostWorn?.count ?? 0
        )
    }
}
