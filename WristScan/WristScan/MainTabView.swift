//
//  MainTabView.swift
//  WristScan
//
//  Purpose: Root TabView container. Owns the top-level navigation between the
//  Watch Box collection and the standalone Atomic Clock dashboard.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Tab 1: Watch Box ──────────────────────────────────────────
            ContentView()
                .tabItem {
                    Label("Watch Box", systemImage: "square.grid.3x3.fill")
                }
                .tag(0)

            // ── Tab 2: Atomic Clock Dashboard ─────────────────────────────
            AtomicClockDashboardView()
                .tabItem {
                    Label("Atomic Time", systemImage: "clock.arrow.2.circlepath")
                }
                .tag(1)
        }
        // Unify the tab bar appearance with the app's dark theme.
        .tint(.amberGold)
    }
}
