//
//  AccuracyCheckView.swift
//  WristScan
//
//  Purpose: Chronograph-style one-tap accuracy sync sheet. Fetches authoritative
//  network time from pool.ntp.org via AtomicClockManager, displays a live
//  ticking atomic clock, and lets the user tap SYNC the moment their watch's
//  second hand reaches 12 to calculate deviation in seconds/day.
//

import SwiftUI

struct AccuracyCheckView: View {

    // MARK: - Dependencies

    @Bindable var timepiece: WatchTimepiece
    @Environment(\.dismiss) private var dismiss

    // MARK: - NTP Manager

    @State private var atomicManager = AtomicClockManager()

    // MARK: - State

    /// Offset between atomic time and device clock, updated once NTP responds.
    @State private var localOffset: TimeInterval = 0

    /// Set when the user taps SYNC. `nil` = pre-sync state.
    @State private var calculatedDeviation: Double? = nil

    /// Resting position of the watch during the test.
    @State private var restingPosition: String = "Dial Up"

    /// Optional notes the user can add before saving.
    @State private var notes: String = ""

    // MARK: - Constants

    private let positions = [
        "Dial Up", "Dial Down",
        "Crown Up", "Crown Down", "Crown Left",
        "On Wrist"
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if atomicManager.isFetching {
                        fetchingView
                    } else if let error = atomicManager.lastError {
                        errorView(message: error)
                    } else if calculatedDeviation == nil {
                        syncReadyView
                    } else {
                        resultView
                    }
                }
            }
            .navigationTitle("Accuracy Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.amberGold)
                }
            }
        }
        // Kick off the NTP fetch as soon as the sheet appears.
        .task {
            atomicManager.fetchNetworkTime()
        }
        // Keep localOffset in sync whenever the atomic baseline updates.
        .onChange(of: atomicManager.atomicTime) { _, newTime in
            guard let newTime else { return }
            localOffset = newTime.timeIntervalSince(.now)
        }
    }

    // MARK: - Phase: Fetching

    private var fetchingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .progressViewStyle(.circular)
                .tint(.amberGold)
                .scaleEffect(1.6)

            Text("Syncing with Atomic Clock…")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            Text("Contacting pool.ntp.org")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phase: Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.red.opacity(0.8))

            Text("Connection Failed")
                .font(.title3.bold())
                .foregroundColor(.white)

            Text(message)
                .font(.callout)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                atomicManager.fetchNetworkTime()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.amberGold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.amberGold.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.amberGold.opacity(0.35), lineWidth: 1))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phase: Sync Ready (live ticking clock)

    private var syncReadyView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Live atomic clock display via TimelineView for sub-second smoothness
            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                let atomicNow = Date.now.addingTimeInterval(localOffset)

                VStack(spacing: 8) {
                    Text("ATOMIC TIME")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.amberGold)
                        .tracking(2.0)

                    Text(atomicNow.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().second()))
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    Text(atomicNow.formatted(.dateTime.day().month().year()))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            Spacer().frame(height: 40)

            // Instruction
            VStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.amberGold.opacity(0.7))

                Text("Wait for your watch's second hand")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))

                Text("to hit 12, then tap SYNC.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 48)

            // SYNC button — large and unmissable
            Button {
                performSync()
            } label: {
                Text("SYNC")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundColor(.black)
                    .frame(width: 180, height: 180)
                    .background(
                        Circle()
                            .fill(Color.amberGold)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.amberGold.opacity(0.4), lineWidth: 8)
                            .scaleEffect(1.12)
                    )
                    .shadow(color: Color.amberGold.opacity(0.4), radius: 24, x: 0, y: 0)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phase: Result + Save

    private var resultView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Deviation display
            if let deviation = calculatedDeviation {
                let isPositive = deviation >= 0
                let sign = isPositive ? "+" : ""
                let color: Color = isPositive ? .green : .red
                let description = isPositive ? "Running Fast" : "Running Slow"

                VStack(spacing: 10) {
                    Text("DEVIATION")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(2)

                    Text("\(sign)\(String(format: "%.1f", deviation))s")
                        .font(.system(size: 72, weight: .black, design: .monospaced))
                        .foregroundColor(color)
                        .monospacedDigit()

                    Text(description)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(color.opacity(0.8))

                    Text("per reading")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 40)

                // Position picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("RESTING POSITION")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(1.5)
                        .padding(.horizontal, 20)

                    Picker("Position", selection: $restingPosition) {
                        ForEach(positions, id: \.self) { pos in
                            Text(pos).tag(pos)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                }

                Spacer().frame(height: 16)

                // Notes field
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTES (OPTIONAL)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(1.5)

                    TextField("e.g. Full power reserve, 20°C", text: $notes)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 32)

                // Save button
                Button {
                    saveLog(deviation: deviation)
                } label: {
                    Text("Save Log")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.amberGold)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Logic

    /// Called the instant the user taps SYNC.
    /// Captures the exact atomic time, rounds to the nearest minute (the "12 o'clock"
    /// the physical watch is pointing to), and computes the signed deviation.
    private func performSync() {
        let exactAtomic = Date.now.addingTimeInterval(localOffset)

        // Round to nearest minute: what the physical watch is showing at the 12-mark.
        let rawSeconds = exactAtomic.timeIntervalSinceReferenceDate
        let nearestMinuteInterval = (rawSeconds / 60.0).rounded() * 60.0
        let nearestMinute = Date(timeIntervalSinceReferenceDate: nearestMinuteInterval)

        // Positive = watch is ahead (running fast); negative = behind (running slow).
        calculatedDeviation = nearestMinute.timeIntervalSince(exactAtomic)

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Appends a new `AccuracyLog` to the timepiece and dismisses the sheet.
    private func saveLog(deviation: Double) {
        let log = AccuracyLog(
            dateChecked: .now,
            deviationInSeconds: deviation,
            position: restingPosition,
            notes: notes
        )
        if timepiece.accuracyLogs == nil {
            timepiece.accuracyLogs = []
        }
        timepiece.accuracyLogs?.append(log)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
