import Foundation

struct RewindAnalyzer {
    let timepieces: [WatchTimepiece]
    let startDate: Date
    let endDate: Date

    // Helper: Isolate wear dates to strictly the target period
    private func wearsInPeriod(for timepiece: WatchTimepiece) -> [Date] {
        return timepiece.wearHistory.filter { $0 >= startDate && $0 <= endDate }
    }

    // 1. Total Wears in Period
    var totalWristChecks: Int {
        timepieces.reduce(0) { $0 + wearsInPeriod(for: $1).count }
    }

    // 2. Most Worn Watch (The MVP)
    var mostWornWatch: (watch: WatchTimepiece, count: Int)? {
        timepieces.map { (watch: $0, count: wearsInPeriod(for: $0).count) }
            .filter { $0.count > 0 }
            .max { $0.count < $1.count }
    }

    // 3. Most Worn Brand
    var favoriteBrand: (name: String, count: Int)? {
        var brandCounts: [String: Int] = [:]
        for watch in timepieces {
            let count = wearsInPeriod(for: watch).count
            if count > 0 {
                brandCounts[watch.manufacturer.uppercased(), default: 0] += count
            }
        }
        return brandCounts.map { (name: $0.key, count: $0.value) }
            .max { $0.count < $1.count }
    }

    // 4. Longest Continuous Wear Streak
    var longestWearStreak: Int {
        let calendar = Calendar.current
        
        // Flatten all valid wear dates across the entire collection
        let allDates = timepieces.flatMap { wearsInPeriod(for: $0) }
        
        // Strip out times to get pure distinct calendar days, sorted chronologically
        let distinctDays = Set(allDates.map { calendar.startOfDay(for: $0) }).sorted()

        guard !distinctDays.isEmpty else { return 0 }

        var currentStreak = 1
        var maxStreak = 1

        for i in 1..<distinctDays.count {
            let daysBetween = calendar.dateComponents([.day], from: distinctDays[i-1], to: distinctDays[i]).day
            
            if daysBetween == 1 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        return maxStreak
    }
    
    // 5. Total Distinct Watches Worn
    var distinctWatchesWorn: Int {
        timepieces.filter { wearsInPeriod(for: $0).count > 0 }.count
    }
}
