import SwiftUI
import SwiftData

enum ReportPeriod: String, CaseIterable {
    case lastMonth = "Last Month"
    case lastYear = "Last Year"
    case thisYear = "This Year"
    case allTime = "All Time"
}

struct RewindView: View {
    @Query private var timepieces: [WatchTimepiece]
    @State private var selectedPeriod: ReportPeriod = .lastYear
    
    // Calculate precise calendar boundaries for the selected period
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .lastMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfThisMonth = calendar.date(from: components) ?? now
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? now
            let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfThisMonth) ?? now
            return (startOfLastMonth, endOfLastMonth)
            
        case .lastYear:
            let components = calendar.dateComponents([.year], from: now)
            let startOfThisYear = calendar.date(from: components) ?? now
            let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear) ?? now
            let endOfLastYear = calendar.date(byAdding: .second, value: -1, to: startOfThisYear) ?? now
            return (startOfLastYear, endOfLastYear)
            
        case .thisYear:
            let components = calendar.dateComponents([.year], from: now)
            let startOfYear = calendar.date(from: components) ?? now
            return (startOfYear, now)
            
        case .allTime:
            return (.distantPast, .distantFuture)
        }
    }
    
    // Instantiate the stateless analyzer with the dynamic date range
    var analyzer: RewindAnalyzer {
        RewindAnalyzer(timepieces: timepieces, startDate: dateRange.start, endDate: dateRange.end)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Period Selector
                        Picker("Time Period", selection: $selectedPeriod) {
                            ForEach(ReportPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // Hero Metric: Most Worn Watch
                        if let topWatch = analyzer.mostWornWatch {
                            VStack(spacing: 16) {
                                Text("MOST WORN WATCH")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.amberGold)
                                    .tracking(1.5)
                                
                                // Image Frame
                                if let imageData = topWatch.watch.imageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 220)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    // Fallback if no image is uploaded
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.16, green: 0.16, blue: 0.19))
                                            .frame(height: 220)
                                        
                                        Image(systemName: "clock")
                                            .font(.system(size: 40))
                                            .foregroundColor(.amberGold.opacity(0.3))
                                    }
                                }
                                
                                // Details Block
                                VStack(spacing: 6) {
                                    Text(topWatch.watch.manufacturer.uppercased())
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .tracking(1.0)
                                    
                                    Text(topWatch.watch.modelName)
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    
                                    Text("\(topWatch.count) Wrist Checks")
                                        .font(.headline)
                                        .foregroundColor(.amberGold)
                                        .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            )
                            .padding(.horizontal)
                        } else {
                            Text("No wear data in this period.")
                                .foregroundColor(.gray)
                                .padding()
                        }
                        
                        // Grid Metrics
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ReportMetricCard(title: "TOTAL WEARS", value: "\(analyzer.totalWristChecks)")
                            ReportMetricCard(title: "LONGEST STREAK", value: "\(analyzer.longestWearStreak) Days")
                            ReportMetricCard(title: "WATCHES WORN", value: "\(analyzer.distinctWatchesWorn)")
                            
                            if let brand = analyzer.favoriteBrand {
                                ReportMetricCard(title: "TOP BRAND", value: brand.name)
                            } else {
                                ReportMetricCard(title: "TOP BRAND", value: "—")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("The Rewind")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Reusable Metric Card matching the app's aesthetic
struct ReportMetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.amberGold)
                .tracking(1.0)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
}
