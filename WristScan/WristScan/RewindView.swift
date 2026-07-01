import SwiftUI
import SwiftData
import UIKit
import Photos

struct RewindView: View {
    @Query private var timepieces: [WatchTimepiece]
    @State private var selectedPeriod: ReportPeriod = .lastYear

    @State private var engine = RewindEngine()

    @State private var cachedWinnerImage: UIImage? = nil
    @State private var shareImage: UIImage? = nil
    @State private var shareURL: URL? = nil
    @State private var isPreparingShare = false
    @State private var isSavingToPhotos = false
    @State private var showSharePreview = false
    @State private var shareFeedback: ShareFeedback? = nil
    @State private var sharePrepError: String? = nil

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
                            await prepareAndShareReport()
                        }
                    }) {
                        if isPreparingShare {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.amberGold)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.amberGold)
                        }
                    }
                    .disabled(engine.metrics == nil || isPreparingShare || engine.isCalculating)
                }
            }
            .sheet(isPresented: $showSharePreview, onDismiss: {
                cleanupShareTempFile(url: shareURL)
                shareImage = nil
                shareURL = nil
                isSavingToPhotos = false
                shareFeedback = nil
            }) {
                if let image = shareImage {
                    SharePreviewSheet(image: image, shareURL: shareURL, isSaving: isSavingToPhotos, feedback: $shareFeedback, onSave: {
                        isSavingToPhotos = true
                        saveImageToPhotos(image) { err in
                            isSavingToPhotos = false
                            if let err {
                                shareFeedback = .failure(err)
                            } else {
                                shareFeedback = .success("Saved to Photos")
                            }
                        }
                    })
                }
            }
            .alert("Share issue", isPresented: Binding(
                get: { sharePrepError != nil },
                set: { _ in sharePrepError = nil }
            )) {
                Button("OK") {}
            } message: {
                Text(sharePrepError ?? "")
            }
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

    private func prepareAndShareReport() async {
        guard let metrics = engine.metrics else {
            await MainActor.run {
                sharePrepError = "The report is still loading."
            }
            return
        }

        await MainActor.run {
            isPreparingShare = true
            sharePrepError = nil
        }

        let image = await MainActor.run {
            let exportView = RewindShareCard(
                periodLabel: selectedPeriod.rawValue,
                metrics: metrics,
                winningWatchManufacturer: engine.winningWatchManufacturer,
                winningWatchModelName: engine.winningWatchModelName,
                winningWatchImage: cachedWinnerImage,
                favoriteBrand: metrics.favoriteBrand?.name
            )
            .frame(width: 1080, height: 1350)

            let renderer = ImageRenderer(content: exportView)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        }

        await MainActor.run {
            isPreparingShare = false
            if let image, let url = makeShareURL(from: image) {
                shareImage = image
                shareURL = url
                showSharePreview = true
            } else {
                sharePrepError = "Unable to create the share snapshot right now."
            }
        }
    }
}

private enum ShareFeedback: Identifiable, Equatable {
    case success(String)
    case failure(String)

    var id: String {
        switch self {
        case .success: return "success"
        case .failure: return "failure"
        }
    }
}

private struct RewindShareCard: View {
    let periodLabel: String
    let metrics: RewindMetrics
    let winningWatchManufacturer: String
    let winningWatchModelName: String
    let winningWatchImage: UIImage?
    let favoriteBrand: String?

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.08)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WristScan Rewind")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Collection insight for \(periodLabel)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }

                if !winningWatchManufacturer.isEmpty || !winningWatchModelName.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Most Worn Watch")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.amberGold)
                            .tracking(1.2)

                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .overlay(
                                VStack(alignment: .leading, spacing: 14) {
                                    if let image = winningWatchImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 240)
                                            .frame(maxWidth: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(Color(red: 0.16, green: 0.16, blue: 0.19))
                                            Image(systemName: "clock")
                                                .font(.system(size: 40))
                                                .foregroundColor(.amberGold.opacity(0.3))
                                        }
                                        .frame(height: 240)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(winningWatchManufacturer.uppercased())
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.gray)
                                            .tracking(1.1)

                                        Text(winningWatchModelName.isEmpty ? "No winner yet" : winningWatchModelName)
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(2)

                                        Text("\(metrics.mostWornCount) wrist checks")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.amberGold)
                                    }
                                }
                                .padding(16)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ShareMetricPill(title: "Total Wears", value: "\(metrics.totalWristChecks)")
                        ShareMetricPill(title: "Longest Streak", value: "\(metrics.longestWearStreak) days")
                    }

                    HStack(spacing: 12) {
                        ShareMetricPill(title: "Watches Worn", value: "\(metrics.distinctWatchesWorn)")
                        if let favoriteBrand, !favoriteBrand.isEmpty {
                            ShareMetricPill(title: "Top Brand", value: favoriteBrand)
                        } else {
                            ShareMetricPill(title: "Top Brand", value: "—")
                        }
                    }
                }

                Text("Captured with WristScan")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .padding(28)
        }
    }
}

private struct SharePreviewSheet: View {
    let image: UIImage
    let shareURL: URL?
    let isSaving: Bool
    @Binding var feedback: ShareFeedback?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hasSaved = false
    @State private var showActivitySheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)

                    VStack(spacing: 8) {
                        Text("Ready to share")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("This snapshot uses your current Rewind data and can be shared instantly.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: { showActivitySheet = true }) {
                        HStack {
                            Spacer()
                            Label("Share Snapshot", systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(Color.amberGold.opacity(0.16))
                        .foregroundColor(.amberGold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    Button(action: onSave) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else if hasSaved {
                                Label("Saved to Photos", systemImage: "checkmark")
                                    .fontWeight(.semibold)
                            } else {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || hasSaved)
                }
                .padding(20)
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.amberGold)
                }
            }
            .alert(item: $feedback) { feedback in
                switch feedback {
                case .success(let message):
                    Alert(title: Text("Saved"), message: Text(message), dismissButton: .default(Text("OK")))
                case .failure(let message):
                    Alert(title: Text("Share issue"), message: Text(message), dismissButton: .default(Text("OK")))
                }
            }
            .onChange(of: feedback) { _, newValue in
                if case .success = newValue {
                    hasSaved = true
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                let items: [Any] = shareURL.map { [$0] } ?? [image]
                ActivityViewController(activityItems: items)
            }
        }
    }
}

private func makeShareURL(from image: UIImage) -> URL? {
    guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
    let tempDir = FileManager.default.temporaryDirectory
    let filename = "WristScan_Rewind_\(UUID().uuidString).jpg"
    let url = tempDir.appendingPathComponent(filename)
    do {
        try data.write(to: url, options: .atomic)
        return url
    } catch {
        print("[RewindView] Failed to write share image: \(error)")
        return nil
    }
}

private func cleanupShareTempFile(url: URL?) {
    guard let url = url else { return }
    try? FileManager.default.removeItem(at: url)
}

private func saveImageToPhotos(_ image: UIImage, completion: @escaping (String?) -> Void) {
    // Request permission and save using Photos framework
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        switch status {
        case .authorized, .limited:
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(nil)
                    } else {
                        completion(error?.localizedDescription ?? "Failed to save image to Photos.")
                    }
                }
            }
        case .denied, .restricted, .notDetermined:
            DispatchQueue.main.async {
                completion("Photos permission not granted.")
            }
        @unknown default:
            DispatchQueue.main.async {
                completion("Unable to access Photos.")
            }
        }
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ShareMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.amberGold)
                .tracking(1.0)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
