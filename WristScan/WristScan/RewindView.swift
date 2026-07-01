import SwiftUI
import SwiftData

struct RewindView: View {
    @Query private var timepieces: [WatchTimepiece]
    @State private var selectedPeriod: ReportPeriod = .lastYear

    @State private var engine = RewindEngine()

    @State private var cachedWinnerImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            // KEY FIX: Picker is OUTSIDE the ScrollView.
            // When metrics load, the ScrollView becomes scrollable and its pan gesture
            // recognizer starts winning the conflict against the UISegmentedControl inside it.
            // The first tap works because the content is just a ProgressView (not scrollable).
            // Pulling the Picker out eliminates the gesture conflict entirely.
            VStack(spacing: 0) {
                Picker("Time Period", selection: $selectedPeriod) {
                    ForEach(ReportPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                ScrollView {
                    VStack(spacing: 20) {
                        if let metrics = engine.metrics {
                            VStack(spacing: 20) {
                                // Hero Metric: Most Worn Watch
                                if metrics.mostWornWatchIndex != nil {
                                    VStack(spacing: 16) {
                                        Text("MOST WORN WATCH")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(.amberGold)
                                            .tracking(1.5)
                                        
                                        if let uiImage = cachedWinnerImage {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 220)
                                                .frame(maxWidth: .infinity)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        } else {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(red: 0.16, green: 0.16, blue: 0.19))
                                                    .frame(height: 220)
                                                
                                                Image(systemName: "clock")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.amberGold.opacity(0.3))
                                            }
                                        }
                                        
                                        VStack(spacing: 6) {
                                            Text(engine.winningWatchManufacturer.uppercased())
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .tracking(1.0)
                                            
                                            Text(engine.winningWatchModelName)
                                                .font(.title2.weight(.bold))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                            
                                            Text("\(metrics.mostWornCount) Wrist Checks")
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
                                    ReportMetricCard(title: "TOTAL WEARS", value: "\(metrics.totalWristChecks)")
                                    ReportMetricCard(title: "LONGEST STREAK", value: "\(metrics.longestWearStreak) Days")
                                    ReportMetricCard(title: "WATCHES WORN", value: "\(metrics.distinctWatchesWorn)")
                                    
                                    if let brand = metrics.favoriteBrand {
                                        ReportMetricCard(title: "TOP BRAND", value: brand.name)
                                    } else {
                                        ReportMetricCard(title: "TOP BRAND", value: "—")
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .opacity(engine.isCalculating ? 0.3 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: engine.isCalculating)
                            .disabled(engine.isCalculating)
                            
                        } else {
                            ProgressView()
                                .tint(.amberGold)
                                .padding(.top, 50)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea())
            .navigationTitle("The Rewind")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: selectedPeriod) {
                let dateRange = selectedPeriod.dateRange
                await engine.generateReport(for: timepieces, start: dateRange.start, end: dateRange.end)
                // Decode image on a background thread — UIImage(data:) is thread-safe
                // and can block the main thread for large photos if run inline.
                if let data = engine.winningWatchImage {
                    cachedWinnerImage = await Task.detached(priority: .userInitiated) {
                        UIImage(data: data)
                    }.value
                } else {
                    cachedWinnerImage = nil
                }
            }
        }
    }
}

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
