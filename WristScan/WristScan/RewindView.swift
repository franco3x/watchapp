import SwiftUI
import SwiftData
import UIKit

struct RewindView: View {
    @Query private var timepieces: [WatchTimepiece]
    @State private var selectedPeriod: ReportPeriod = .lastYear

    @State private var engine = RewindEngine()
    @State private var shareCoordinator = ShareCardCoordinator()

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await shareRewindReport()
                        }
                    }) {
                        if shareCoordinator.isPreparing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.amberGold)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.amberGold)
                        }
                    }
                    .disabled(engine.metrics == nil || shareCoordinator.isPreparing || engine.isCalculating)
                }
            }
            .shareCardPresentation(shareCoordinator)
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

    private func shareRewindReport() async {
        guard let metrics = engine.metrics else {
            shareCoordinator.prepError = "The report is still loading."
            return
        }

        let card = RewindShareCard(
            periodLabel: selectedPeriod.rawValue,
            metrics: metrics,
            winningWatchManufacturer: engine.winningWatchManufacturer,
            winningWatchModelName: engine.winningWatchModelName,
            winningWatchImage: cachedWinnerImage,
            favoriteBrand: metrics.favoriteBrand?.name
        )
        await shareCoordinator.prepareAndShare(card: card, exportSize: CGSize(width: 1080, height: 1350), filenamePrefix: "WristScan_Rewind")
    }
}

private struct RewindShareCard: View {
    let periodLabel: String
    let metrics: RewindMetrics
    let winningWatchManufacturer: String
    let winningWatchModelName: String
    let winningWatchImage: UIImage?
    let favoriteBrand: String?

    private var hasWinner: Bool {
        !winningWatchManufacturer.isEmpty || !winningWatchModelName.isEmpty
    }

    var body: some View {
        ZStack {
            ShareCardBackground()

            VStack(alignment: .leading, spacing: 0) {
                header

                heroSection
                    .padding(.top, 36)

                Spacer(minLength: 24)

                statSection

                footer
                    .padding(.top, 34)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 72)
            .padding(.top, 64)
            .padding(.bottom, 56)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("COLLECTION INSIGHT")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(3.5)
                    .foregroundColor(Color(red: 0.498, green: 0.498, blue: 0.529))

                Text("WristScan Rewind")
                    .font(.system(size: 50, weight: .heavy, design: .rounded))
                    .tracking(-0.8)
                    .foregroundColor(.white)
            }

            Spacer()

            SharePeriodPill(label: periodLabel.uppercased())
                .padding(.top, 6)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MOST WORN WATCH")
                .font(.system(size: 27, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundColor(.amberGold)

            if hasWinner {
                RewindFeaturedCard(
                    manufacturer: winningWatchManufacturer,
                    modelName: winningWatchModelName,
                    image: winningWatchImage,
                    wristChecks: metrics.mostWornCount
                )
            } else {
                RewindEmptyFeaturedCard()
            }
        }
    }

    private var statSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THE NUMBERS")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundColor(Color(red: 0.498, green: 0.498, blue: 0.529))

            HStack(spacing: 0) {
                ShareStatCell(label: "TOTAL WEARS", value: "\(metrics.totalWristChecks)", unit: nil, valueFontSize: 46, showsDivider: false)
                ShareStatCell(label: "LONGEST STREAK", value: "\(metrics.longestWearStreak)", unit: "days", valueFontSize: 46, showsDivider: true)
                ShareStatCell(label: "WATCHES WORN", value: "\(metrics.distinctWatchesWorn)", unit: nil, valueFontSize: 46, showsDivider: true)
                ShareStatCell(label: "TOP BRAND", value: (favoriteBrand?.isEmpty == false) ? favoriteBrand! : "—", unit: nil, valueFontSize: 38, showsDivider: true)
            }
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            ShareCardWatermark()
            Text("CAPTURED WITH WRISTSCAN")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color(red: 0.435, green: 0.435, blue: 0.467))
        }
    }
}

private struct RewindFeaturedCard: View {
    let manufacturer: String
    let modelName: String
    let image: UIImage?
    let wristChecks: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
                .frame(height: 626)
                .clipped()
                .overlay(scrim)
                .overlay(alignment: .topLeading) {
                    RewindMedalBadge()
                        .padding(24)
                }

            caption
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.amberGold.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 30, y: 30)
    }

    @ViewBuilder
    private var photo: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(red: 0.16, green: 0.16, blue: 0.19)
                Image(systemName: "clock")
                    .font(.system(size: 40))
                    .foregroundColor(.amberGold.opacity(0.3))
            }
        }
    }

    private var scrim: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0), location: 0.55),
                .init(color: Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.55), location: 0.82),
                .init(color: Color(red: 0.12, green: 0.12, blue: 0.14), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var caption: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(manufacturer.uppercased())
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .tracking(2.5)
                    .foregroundColor(Color(red: 0.545, green: 0.545, blue: 0.573))

                Text(modelName.isEmpty ? "No winner yet" : modelName)
                    .font(.system(size: 74, weight: .heavy))
                    .tracking(-1.5)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.4)
                    .layoutPriority(1)
            }

            Spacer(minLength: 16)

            VStack(spacing: 4) {
                Text("\(wristChecks)")
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundColor(.amberGold)

                Text("WRIST CHECKS")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(.amberGold.opacity(0.85))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 22)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.amberGold.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.amberGold.opacity(0.22), lineWidth: 1)
                    )
            )
            .fixedSize()
        }
        .padding(.top, 30)
        .padding(.horizontal, 44)
        .padding(.bottom, 40)
    }
}

private struct RewindMedalBadge: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.078, green: 0.078, blue: 0.086))
                    .frame(width: 34, height: 34)
                Text("1")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(.amberGold)
            }

            Text("TOP PICK")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(Color(red: 0.090, green: 0.082, blue: 0.071))
        }
        .padding(.leading, 9)
        .padding(.trailing, 18)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.amberGold))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
    }
}

private struct RewindEmptyFeaturedCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .frame(height: 320)
            .overlay(
                VStack(spacing: 14) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.435, green: 0.435, blue: 0.467))

                    Text("No wear data in this period.")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0.545, green: 0.545, blue: 0.573))
                }
            )
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
