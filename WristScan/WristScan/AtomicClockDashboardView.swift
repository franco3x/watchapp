//
//  AtomicClockDashboardView.swift
//  WristScan
//
//  Purpose: Standalone instrumentation dashboard for the atomic clock baseline.
//  Fetches authoritative network time from pool.ntp.org via AtomicClockManager
//  and renders a high-precision digital clock at 100 Hz alongside device drift
//  telemetry and a Force Resync action.
//

import SwiftUI

struct AtomicClockDashboardView: View {

    // MARK: - State

    @State private var clockManager = AtomicClockManager()

    /// Signed offset between the NTP-derived atomic time and the local device clock.
    /// Positive = device is behind atomic time; negative = device is ahead.
    @State private var localOffset: TimeInterval = 0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Background ────────────────────────────────────────────
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Status Card ───────────────────────────────────
                        statusCard

                        // ── Main Clock Display ────────────────────────────
                        clockCard

                        // ── Device Drift Card ─────────────────────────────
                        driftCard

                        // ── Force Resync ──────────────────────────────────
                        resyncButton

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Atomic Time")
            .navigationBarTitleDisplayMode(.large)
            // Custom navigation bar appearance to match dark theme
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.08), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        // Kick off the NTP query as soon as the tab appears.
        .task {
            clockManager.fetchNetworkTime()
        }
        // Lock in localOffset the moment the atomic baseline is established.
        .onChange(of: clockManager.atomicTime) { _, newAtomicTime in
            guard let newAtomicTime else { return }
            localOffset = newAtomicTime.timeIntervalSince(.now)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 16) {
            // Icon column
            ZStack {
                Circle()
                    .fill(syncIconBackground)
                    .frame(width: 44, height: 44)

                if clockManager.isFetching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.amberGold)
                        .scaleEffect(0.85)
                } else if clockManager.lastError != nil {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
            }

            // Text column
            VStack(alignment: .leading, spacing: 4) {
                Text(syncStatusTitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(syncStatusSubtitle)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(14)
        .overlay(cardBorder)
    }

    // MARK: - Main Clock Display

    private var clockCard: some View {
        VStack(spacing: 12) {
            // Section label
            Text("NETWORK TIME")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.amberGold)
                .tracking(2.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            if clockManager.isFetching {
                // Pre-sync placeholder
                VStack(spacing: 8) {
                    Text("--:--:--.---")
                        .font(.system(size: 52, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.15))
                        .monospacedDigit()

                    Text("Awaiting sync…")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

            } else {
                // 100 Hz ticking clock
                TimelineView(.periodic(from: .now, by: 0.01)) { _ in
                    let atomicNow = Date.now.addingTimeInterval(localOffset)

                    VStack(spacing: 6) {
                        // HH:MM:SS — large
                        Text(atomicNow.formatted(
                            .dateTime
                                .hour(.twoDigits(amPM: .omitted))
                                .minute()
                                .second()
                        ))
                        .font(.system(size: 58, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()

                        // Milliseconds — smaller, dimmer
                        Text(".\(milliseconds(of: atomicNow))")
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .foregroundColor(.amberGold)
                            .monospacedDigit()

                        // Date line
                        Text(atomicNow.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(14)
        .overlay(cardBorder)
    }

    // MARK: - Device Drift Card

    private var driftCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("DEVICE DRIFT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(2)

                Text(driftLabel)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(driftColor)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("SOURCE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(2)

                Text("pool.ntp.org")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(14)
        .overlay(cardBorder)
    }

    // MARK: - Resync Button

    private var resyncButton: some View {
        Button {
            clockManager.fetchNetworkTime()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .rotationEffect(.degrees(clockManager.isFetching ? 360 : 0))
                    .animation(
                        clockManager.isFetching
                            ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                            : .default,
                        value: clockManager.isFetching
                    )

                Text("Force Resync")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(clockManager.isFetching ? .gray : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                clockManager.isFetching
                    ? Color.amberGold.opacity(0.3)
                    : Color.amberGold
            )
            .cornerRadius(14)
        }
        .disabled(clockManager.isFetching)
        .animation(.easeInOut(duration: 0.2), value: clockManager.isFetching)
    }

    // MARK: - Helpers

    /// Three-digit millisecond component of a date, zero-padded.
    private func milliseconds(of date: Date) -> String {
        let ms = Int((date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%03d", abs(ms))
    }

    private var syncStatusTitle: String {
        if clockManager.isFetching    { return "Syncing…" }
        if clockManager.lastError != nil { return "Sync Failed" }
        return "Synced with pool.ntp.org"
    }

    private var syncStatusSubtitle: String {
        if clockManager.isFetching       { return "Contacting NTP server…" }
        if let err = clockManager.lastError { return err }
        if clockManager.atomicTime != nil   { return "Atomic baseline established" }
        return "No data yet"
    }

    private var syncIconBackground: Color {
        if clockManager.lastError != nil { return Color.red.opacity(0.15) }
        if clockManager.isFetching       { return Color.amberGold.opacity(0.1) }
        return Color.green.opacity(0.15)
    }

    private var driftLabel: String {
        guard clockManager.atomicTime != nil else { return "—" }
        let sign = localOffset >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.3f", localOffset))s"
    }

    private var driftColor: Color {
        guard clockManager.atomicTime != nil else { return .gray }
        return abs(localOffset) < 1.0 ? .green : (abs(localOffset) < 3.0 ? .amberGold : .red)
    }

    // MARK: - Shared Card Style Helpers

    private var cardBackground: Color {
        Color(red: 0.12, green: 0.12, blue: 0.14)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
    }
}
