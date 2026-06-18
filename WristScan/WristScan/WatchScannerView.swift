//
//  WatchScannerView.swift
//  WristScan
//
//  Created by Frank Coleman on 6/17/26.
//

import SwiftUI
import SwiftData
import AVFoundation
import Vision

// MARK: - AVFoundation Camera Preview + Photo Capture

@Observable
final class CameraPreviewLayer: NSObject {
    let session = AVCaptureSession()
    private(set) var photoOutput = AVCapturePhotoOutput()

    // Callback invoked on the main thread with raw OCR lines after capture
    var onRawLines: (([String]) -> Void)?

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.sessionPreset = .photo

        // Prefer triple-camera → dual-camera → wide-angle for best macro capability
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        guard
            let device = discovery.devices.first,
            let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        // Configure continuous autofocus for close-up watch dial scanning
        if device.isFocusModeSupported(.continuousAutoFocus) {
            try? device.lockForConfiguration()
            device.focusMode = .continuousAutoFocus
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            device.unlockForConfiguration()
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraPreviewLayer: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage
        else {
            DispatchQueue.main.async { [weak self] in
                self?.onRawLines?([])   // empty array signals capture failure
            }
            return
        }

        recognizeText(in: cgImage)
    }
}

// MARK: - AVFoundation OCR

private extension CameraPreviewLayer {

    func recognizeText(in cgImage: CGImage) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil
            else {
                DispatchQueue.main.async {
                    // Deliver an empty array so the view can show a failure state.
                    self?.onRawLines?([])
                }
                return
            }

            let lines = observations.compactMap { $0.topCandidates(1).first?.string }

            DispatchQueue.main.async {
                self?.onRawLines?(lines)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.customWords = [
            "GMT", "Rolex", "Orient", "Bulova", "Seiko",
            "Chronograph", "Automatic", "Master",
            "Omega", "Tudor", "Patek", "Breitling", "IWC",
            "Submariner", "Datejust", "Speedmaster", "Seamaster"
        ]
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

// MARK: - Scan Result

enum ScanResult {
    case success(ParsedWatchDetails)
    case failure(String)
}

struct ParsedWatchDetails {
    var manufacturer: String
    var name: String
    var referenceNumber: String
    /// Raw OCR lines for debugging / display
    var rawLines: [String]
}

// MARK: - Vision OCR + custom words are handled inside CameraPreviewLayer above.

// MARK: - Watch Text Parser (Levenshtein Fuzzy Engine)

enum WatchTextParser {

    // MARK: - Sanitization

    /// Corrects known OCR hallucinations before any parsing occurs.
    private static func sanitize(_ lines: [String]) -> [String] {
        lines.map {
            $0.replacingOccurrences(of: "GOURMET", with: "GMT", options: .caseInsensitive)
        }
    }

    // MARK: - Levenshtein Distance

    /// Classic DP Levenshtein edit distance between two strings.
    /// Operates on Character arrays so Unicode grapheme clusters are handled correctly.
    nonisolated static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        let m = a.count, n = b.count
        guard m > 0 else { return n }
        guard n > 0 else { return m }

        // Rolling two-row DP — O(m*n) time, O(n) space
        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = 1 + min(prev[j],       // deletion
                                      curr[j - 1],   // insertion
                                      prev[j - 1])   // substitution
                }
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    // MARK: - Token-level fuzzy check

    /// Returns true if any whitespace-separated token in `line` fuzzy-matches `target`
    /// within the given edit-distance `threshold`.
    nonisolated private static func tokenMatches(
        _ line: String,
        target: String,
        threshold: Int
    ) -> Bool {
        let lowerTarget = target.lowercased()
        // Also check the whole line — OCR may merge words
        let lowerLine = line.lowercased()
        if levenshtein(lowerLine, lowerTarget) <= threshold { return true }
        return lowerLine
            .components(separatedBy: .whitespacesAndNewlines)
            .contains { levenshtein($0, lowerTarget) <= threshold }
    }

    // MARK: - Scoring

    /// Scores a single catalog entry against sanitized OCR lines using fuzzy matching.
    /// Scoring weights:
    ///   +1  manufacturer match   (distance ≤ 2)
    ///   +2  alias match          (distance ≤ 1)
    ///   +5  reference number     (distance ≤ 1  — high precision required)
    nonisolated private static func score(
        watch: WatchCatalogItem,
        lines: [String]
    ) -> Int {
        var total = 0
        for line in lines {
            // Manufacturer: forgiving threshold (handles glare-dropped letters)
            if tokenMatches(line, target: watch.manufacturer, threshold: 2) {
                total += 1
            }
            // Aliases: tight threshold (short tokens, 1 typo max)
            for alias in watch.aliases where tokenMatches(line, target: alias, threshold: 1) {
                total += 2
            }
            // Reference number: tight threshold (alphanumeric, 1 transposition max)
            if tokenMatches(line, target: watch.referenceNumber, threshold: 1) {
                total += 5
            }
        }
        return total
    }

    // MARK: - Parse  (nonisolated — safe to call from detached Tasks)

    /// Scores every catalog entry against the OCR lines and returns the best match.
    /// Marked `nonisolated` so callers can run this inside `Task.detached` without
    /// inheriting any actor context.
    nonisolated static func parse(
        lines: [String],
        catalog: [WatchCatalogItem]
    ) -> ParsedWatchDetails {
        let clean = sanitize(lines)

        if !catalog.isEmpty {
            let scored = catalog.map { (score: score(watch: $0, lines: clean), item: $0) }
            if let best = scored.max(by: { $0.score < $1.score }), best.score > 0 {
                return ParsedWatchDetails(
                    manufacturer:    best.item.manufacturer,
                    name:            best.item.modelName,
                    referenceNumber: best.item.referenceNumber,
                    rawLines:        clean
                )
            }
        }

        return ParsedWatchDetails(
            manufacturer:    "Unknown",
            name:            "Unknown",
            referenceNumber: "—",
            rawLines:        clean
        )
    }
}


// MARK: - Scanner View

struct WatchScannerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Binding var showingScanner: Bool

    /// Live catalog — passed to the scoring engine on every scan.
    @Query(sort: \WatchCatalogItem.manufacturer) private var catalog: [WatchCatalogItem]

    @State private var camera = CameraPreviewLayer()
    @State private var isProcessing = false
    @State private var scanPhase: ScanPhase = .ready
    @State private var rawOCRLines: [String] = []
    @State private var showingManualSearch = false

    private let cutoutDiameter: CGFloat = 260

    enum ScanPhase {
        case ready
        case capturing
        case recognizing
        case failed(String)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Live Camera Feed
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()

                // 2. Dark frosted overlay with circular cutout + single amberGold ring
                OverlayWithCutout(cutoutDiameter: cutoutDiameter, isProcessing: isProcessing)
                    .ignoresSafeArea()

                // 3. Content column
                VStack {
                    Spacer()
                        .frame(height: geo.size.height / 2 - cutoutDiameter / 2 - 56)

                    VStack(spacing: 6) {
                        instructionLabel
                    }

                    Spacer()

                    // 4. Bottom control area
                    bottomControl
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: scanPhase.stateId)

                    Spacer().frame(height: geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom + 10 : 30)
                }

                // 5. Close button (top-right)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showingScanner = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, geo.safeAreaInsets.top > 0 ? geo.safeAreaInsets.top + 10 : 16)
                    }
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            camera.start()
            camera.onRawLines = handleRawLines
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showingManualSearch) {
            CatalogSelectionView { selectedItem in
                saveFromCatalog(selectedItem)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var instructionLabel: some View {
        switch scanPhase {
        case .ready:
            Text("Align watch bezel here")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .tracking(0.5)
        case .capturing:
            Text("Hold steady…")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.amberGold.opacity(0.9))
                .tracking(0.5)
        case .recognizing:
            Text("Reading dial text…")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.amberGold.opacity(0.9))
                .tracking(0.5)
        case .failed(let msg):
            Text(msg)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.red.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }


    @ViewBuilder
    private var bottomControl: some View {
        switch scanPhase {
        case .ready:
            ShutterButton(action: handleCapture)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        case .capturing, .recognizing:
            ProcessingPill(label: { if case .capturing = scanPhase { return "Capturing image…" } else { return "Identifying timepiece…" } }())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        case .failed:
            // Retry button
            VStack(spacing: 12) {
                Button(action: resetToReady) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.amberGold)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.amberGold.opacity(0.4), lineWidth: 1))
                }
                // Manual search fallback
                Button(action: { showingManualSearch = true }) {
                    Label("Search Catalog Manually", systemImage: "text.magnifyingglass")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - Capture Logic

    private func handleCapture() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            scanPhase = .capturing
            isProcessing = true
        }
        camera.capturePhoto()
    }

    /// Called on the main thread with raw OCR lines from the camera layer.
    /// Offloads the Levenshtein comparison matrix to a detached background task
    /// to avoid blocking the main thread / dropping frames.
    private func handleRawLines(_ lines: [String]) {
        withAnimation { scanPhase = .recognizing }

        guard !lines.isEmpty else {
            withAnimation {
                scanPhase = .failed("Could not read dial text.\nTry better lighting or move closer.")
                isProcessing = false
            }
            return
        }

        // Capture catalog as a plain array — value type, safe to send across concurrency domains.
        let catalogSnapshot = catalog

        Task.detached(priority: .userInitiated) {
            // Levenshtein scoring runs entirely off the main thread.
            let details = WatchTextParser.parse(lines: lines, catalog: catalogSnapshot)

            // Brief pause so the "Reading dial text…" label is visible to the user.
            try? await Task.sleep(nanoseconds: 600_000_000)   // 0.6 s

            await MainActor.run {
                if details.manufacturer == "Unknown" {
                    withAnimation {
                        scanPhase = .failed("No catalog match found.\nTry better lighting or move closer.")
                        isProcessing = false
                    }
                    return
                }

                let timepiece = WatchTimepiece(
                    manufacturer:    details.manufacturer,
                    name:            details.name,
                    referenceNumber: details.referenceNumber,
                    purchaseDate:    Date(),
                    purchasePrice:   0.0
                )
                context.insert(timepiece)
                withAnimation { isProcessing = false }
                showingScanner = false
            }
        }
    }

    private func resetToReady() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            scanPhase = .ready
            isProcessing = false
        }
    }

    /// Saves a manually-selected catalog item and closes both the sheet and the scanner.
    private func saveFromCatalog(_ item: WatchCatalogItem) {
        let newWatch = WatchTimepiece(
            manufacturer:    item.manufacturer,
            name:            item.modelName,
            referenceNumber: item.referenceNumber,
            purchaseDate:    Date(),
            purchasePrice:   0.0
        )
        context.insert(newWatch)
        try? context.save()
        print("[Database] Manually added \(newWatch.name) to collection.")
        showingManualSearch = false
        dismiss()
    }
}

// MARK: - ScanPhase helpers

private extension WatchScannerView.ScanPhase {
    /// A simple comparable value for SwiftUI animation triggers.
    var stateId: Int {
        switch self {
        case .ready: return 0
        case .capturing: return 1
        case .recognizing: return 2
        case .failed: return 3
        }
    }
}

// MARK: - Overlay with Cutout

struct OverlayWithCutout: View {
    let cutoutDiameter: CGFloat
    var isProcessing: Bool = false

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.black.opacity(0.62))
                )
                let circleRect = CGRect(
                    x: size.width / 2 - cutoutDiameter / 2,
                    y: size.height / 2 - cutoutDiameter / 2,
                    width: cutoutDiameter,
                    height: cutoutDiameter
                )
                context.blendMode = .destinationOut
                context.fill(Path(ellipseIn: circleRect), with: .color(.black))
            }
            .compositingGroup()

            // Single amberGold bezel ring — absolutely centered over the cutout
            Circle()
                .stroke(Color.amberGold, lineWidth: 2)
                .frame(width: cutoutDiameter, height: cutoutDiameter)
                .scaleEffect(isProcessing ? 1.06 : 1.0)
                .animation(
                    isProcessing
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: isProcessing
                )
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

// MARK: - Shutter Button

struct ShutterButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.amberGold.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(Color.amberGold, lineWidth: 2))

                Circle()
                    .fill(Color.amberGold)
                    .frame(width: 58, height: 58)
                    .scaleEffect(isPressed ? 0.88 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
    }
}

// MARK: - Processing Pill

struct ProcessingPill: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.amberGold)
                .scaleEffect(0.85)

            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.amberGold.opacity(0.35), lineWidth: 1))
        .shimmer()
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: Color.white.opacity(0.5), location: phase),
                        .init(color: .clear, location: phase + 0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }

    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // No updates needed
    }
}

#Preview {
    WatchScannerView(showingScanner: .constant(true))
        .modelContainer(for: WatchTimepiece.self, inMemory: true)
}
