//
//  ShareCardExporter.swift
//  WristScan
//
//  Purpose: Shared "share as image" plumbing (render a SwiftUI card off-screen,
//  preview it, share via the system sheet, or save to Photos) so screens only need
//  to build their own card View and call one coordinator — originally built for
//  RewindView, now reused by WatchDetailView and AnalyticsDashboardView.
//

import SwiftUI
import UIKit
import Photos

enum ShareFeedback: Identifiable, Equatable {
    case success(String)
    case failure(String)

    var id: String {
        switch self {
        case .success: return "success"
        case .failure: return "failure"
        }
    }
}

@Observable
final class ShareCardCoordinator {
    var shareImage: UIImage? = nil
    var shareURL: URL? = nil
    var isPreparing = false
    var isSavingToPhotos = false
    var showPreview = false
    var feedback: ShareFeedback? = nil
    var prepError: String? = nil

    func prepareAndShare<Card: View>(card: Card, exportSize: CGSize, filenamePrefix: String) async {
        await MainActor.run {
            isPreparing = true
            prepError = nil
        }

        let image = await MainActor.run {
            let exportView = card.frame(width: exportSize.width, height: exportSize.height)
            let renderer = ImageRenderer(content: exportView)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        }

        await MainActor.run {
            isPreparing = false
            if let image, let url = makeShareURL(from: image, filenamePrefix: filenamePrefix) {
                shareImage = image
                shareURL = url
                showPreview = true
            } else {
                prepError = "Unable to create the share snapshot right now."
            }
        }
    }

    func saveCurrentImageToPhotos() {
        guard let image = shareImage else { return }
        isSavingToPhotos = true
        saveImageToPhotos(image) { [weak self] err in
            guard let self else { return }
            self.isSavingToPhotos = false
            if let err {
                self.feedback = .failure(err)
            } else {
                self.feedback = .success("Saved to Photos")
            }
        }
    }

    func resetAfterDismiss() {
        cleanupShareTempFile(url: shareURL)
        shareImage = nil
        shareURL = nil
        isSavingToPhotos = false
        feedback = nil
    }
}

private struct ShareCardPresentationModifier: ViewModifier {
    @Bindable var coordinator: ShareCardCoordinator

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $coordinator.showPreview, onDismiss: {
                coordinator.resetAfterDismiss()
            }) {
                if let image = coordinator.shareImage {
                    ShareCardPreviewSheet(
                        image: image,
                        shareURL: coordinator.shareURL,
                        isSaving: coordinator.isSavingToPhotos,
                        feedback: $coordinator.feedback,
                        onSave: { coordinator.saveCurrentImageToPhotos() }
                    )
                }
            }
            .alert("Share issue", isPresented: Binding(
                get: { coordinator.prepError != nil },
                set: { _ in coordinator.prepError = nil }
            )) {
                Button("OK") {}
            } message: {
                Text(coordinator.prepError ?? "")
            }
    }
}

extension View {
    func shareCardPresentation(_ coordinator: ShareCardCoordinator) -> some View {
        modifier(ShareCardPresentationModifier(coordinator: coordinator))
    }
}

struct ShareCardPreviewSheet: View {
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

                        Text("This snapshot uses your current data and can be shared instantly.")
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

func makeShareURL(from image: UIImage, filenamePrefix: String) -> URL? {
    guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
    let tempDir = FileManager.default.temporaryDirectory
    let filename = "\(filenamePrefix)_\(UUID().uuidString).jpg"
    let url = tempDir.appendingPathComponent(filename)
    do {
        try data.write(to: url, options: .atomic)
        return url
    } catch {
        print("[ShareCardExporter] Failed to write share image: \(error)")
        return nil
    }
}

func cleanupShareTempFile(url: URL?) {
    guard let url = url else { return }
    try? FileManager.default.removeItem(at: url)
}

func saveImageToPhotos(_ image: UIImage, completion: @escaping (String?) -> Void) {
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

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Dark radial-gradient canvas background shared by the redesigned share cards.
struct ShareCardBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.08)

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.098, green: 0.098, blue: 0.125), location: 0),
                    .init(color: Color(red: 0.075, green: 0.075, blue: 0.09), location: 0.46),
                    .init(color: Color(red: 0.059, green: 0.059, blue: 0.071), location: 1.0)
                ]),
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 0,
                endRadius: 1300
            )
        }
        .ignoresSafeArea()
    }
}

/// The amber capsule pill (glowing dot + uppercased label) used in the Rewind and
/// Top Wrist Checks card headers to show the current report period.
struct SharePeriodPill: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.amberGold)
                .frame(width: 7, height: 7)
                .shadow(color: .amberGold.opacity(0.7), radius: 5)

            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(.amberGold)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 20)
        .background(
            Capsule()
                .fill(Color.amberGold.opacity(0.07))
                .overlay(Capsule().stroke(Color.amberGold.opacity(0.38), lineWidth: 1))
        )
    }
}

/// The small stroked-circle-and-hand "watch mark" glyph used in every share card's footer,
/// next to "Captured with WristScan" — drawn with primitives, no image asset.
struct ShareCardWatermark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.amberGold, lineWidth: 2)
                .frame(width: 22, height: 22)

            Capsule()
                .fill(Color.amberGold)
                .frame(width: 2, height: 6)
                .offset(y: -3)
        }
    }
}

/// A labeled stat cell (amber label + big value, with an optional smaller unit suffix and
/// an optional leading divider) used in the multi-column stat strips across share cards.
struct ShareStatCell: View {
    let label: String
    let value: String
    let unit: String?
    let valueFontSize: CGFloat
    let showsDivider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(.amberGold)

            valueText
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            if showsDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
            }
        }
    }

    private var valueText: Text {
        let number = Text(value)
            .font(.system(size: valueFontSize, weight: .heavy))
            .foregroundColor(.white)

        guard let unit else { return number }

        let unitText = Text(" " + unit)
            .font(.system(size: 21, weight: .bold))
            .foregroundColor(Color(red: 0.545, green: 0.545, blue: 0.573))

        return number + unitText
    }
}
