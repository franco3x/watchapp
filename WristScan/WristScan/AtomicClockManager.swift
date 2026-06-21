//
//  AtomicClockManager.swift
//  WristScan
//
//  Purpose: Zero-dependency NTP client that queries pool.ntp.org via UDP to
//  establish an authoritative atomic clock baseline entirely independent of
//  the device's local system clock. Used as the reference time source when
//  logging accuracy measurements for a watch.
//

import Foundation
import Network
import Observation

@Observable
final class AtomicClockManager {

    // MARK: - Public State

    /// The authoritative network time returned by the NTP server.
    /// `nil` until the first successful fetch, or after a fetch failure.
    var atomicTime: Date? = nil

    /// `true` while an NTP request is in-flight.
    var isFetching: Bool = false

    /// Human-readable error string set when a fetch fails; cleared on next attempt.
    var lastError: String? = nil

    // MARK: - Private Constants

    /// Number of seconds between the NTP epoch (1 Jan 1900) and the Unix epoch (1 Jan 1970).
    /// 70 years × 365.25 days/year × 86 400 s/day  =  2 208 988 800 s
    private static let ntpEpochOffset: UInt32 = 2_208_988_800

    /// NTP packet is always exactly 48 bytes.
    private static let packetLength = 48

    // MARK: - API

    /// Queries pool.ntp.org (port 123, UDP) and updates `atomicTime` on the main thread.
    /// Safe to call multiple times; concurrent calls are ignored while a fetch is in-flight.
    func fetchNetworkTime() {
        guard !isFetching else { return }

        isFetching  = true
        lastError   = nil
        atomicTime  = nil

        // Resolve endpoint — pool.ntp.org round-robins across a global pool of stratum-1/2 servers.
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("pool.ntp.org"),
            port: NWEndpoint.Port(rawValue: 123)!
        )

        let connection = NWConnection(to: endpoint, using: .udp)

        // ------------------------------------------------------------------ //
        //  State handler — fires on the NWConnection's internal queue.        //
        // ------------------------------------------------------------------ //
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                // Connection is live — send the 48-byte NTP request packet.
                self.sendRequest(over: connection)

            case .failed(let error):
                self.finish(connection: connection, error: "NTP connection failed: \(error.localizedDescription)")

            case .cancelled:
                // Normal shutdown path; nothing to do.
                break

            default:
                break
            }
        }

        // Start on a background queue so network I/O never touches the main thread.
        connection.start(queue: .global(qos: .userInitiated))
    }

    // MARK: - Private Helpers

    /// Builds and transmits a minimal 48-byte NTP client request.
    ///
    /// Packet layout (RFC 5905):
    ///   Byte 0 bits [7:6] = LI  (0 = no warning)
    ///   Byte 0 bits [5:3] = VN  (4 = NTP version 4)
    ///   Byte 0 bits [2:0] = Mode (3 = client)
    ///   → 0x00_10_011 = 0x23 for v4 client,  but the canonical shorthand is 0x1B (v3 client)
    ///   Both are accepted by modern servers; we use 0x1B as it is universally supported.
    private func sendRequest(over connection: NWConnection) {
        var packet = [UInt8](repeating: 0, count: Self.packetLength)
        packet[0] = 0x1B   // LI=0, VN=3, Mode=3 (client)

        let data = Data(packet)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else { return }

            if let error {
                self.finish(connection: connection, error: "NTP send failed: \(error.localizedDescription)")
                return
            }

            // Packet dispatched — now wait for the server's 48-byte response.
            self.receiveResponse(from: connection)
        })
    }

    /// Waits for the 48-byte NTP response and extracts the transmit timestamp.
    private func receiveResponse(from connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: Self.packetLength,
            maximumLength:           Self.packetLength
        ) { [weak self] data, _, _, error in
            guard let self else { return }

            if let error {
                self.finish(connection: connection, error: "NTP receive failed: \(error.localizedDescription)")
                return
            }

            guard
                let data,
                data.count >= Self.packetLength
            else {
                self.finish(connection: connection, error: "NTP response too short (\(data?.count ?? 0) bytes).")
                return
            }

            guard let date = Self.parseTransmitTimestamp(from: data) else {
                self.finish(connection: connection, error: "NTP transmit timestamp is zero — server may be unreachable.")
                return
            }

            // Deliver on the main thread so @Observable updates drive the UI safely.
            DispatchQueue.main.async {
                self.atomicTime = date
                self.isFetching = false
                self.lastError  = nil
            }

            connection.cancel()
        }
    }

    /// Extracts the 64-bit NTP transmit timestamp from bytes 40–47 of the response.
    ///
    /// Format: [seconds since 1900 — 32 bits big-endian] [fraction — 32 bits big-endian]
    /// We read the whole seconds field, subtract the NTP→Unix epoch offset, and return a `Date`.
    /// The fractional part gives sub-second precision but is omitted here for simplicity.
    private static func parseTransmitTimestamp(from data: Data) -> Date? {
        // Read the 32-bit big-endian seconds value at offset 40.
        let bytes = [UInt8](data)
        let secondsSince1900: UInt32 =
            (UInt32(bytes[40]) << 24) |
            (UInt32(bytes[41]) << 16) |
            (UInt32(bytes[42]) <<  8) |
             UInt32(bytes[43])

        // A zero value means the server returned an invalid timestamp.
        guard secondsSince1900 > 0 else { return nil }

        // Also read the 32-bit fractional field at offset 44 for sub-second precision.
        let fractionRaw: UInt32 =
            (UInt32(bytes[44]) << 24) |
            (UInt32(bytes[45]) << 16) |
            (UInt32(bytes[46]) <<  8) |
             UInt32(bytes[47])

        // Convert fraction to seconds: fraction / 2^32
        let fractionalSeconds = Double(fractionRaw) / 4_294_967_296.0

        let secondsSince1970 = Double(secondsSince1900) - Double(ntpEpochOffset) + fractionalSeconds
        return Date(timeIntervalSince1970: secondsSince1970)
    }

    /// Centralized failure handler — cancels the connection, logs the error, and resets state.
    private func finish(connection: NWConnection, error: String) {
        connection.cancel()
        DispatchQueue.main.async {
            self.lastError  = error
            self.isFetching = false
        }
    }
}
