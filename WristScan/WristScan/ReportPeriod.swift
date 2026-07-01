//
//  ReportPeriod.swift
//  WristScan
//
//  Purpose: Shared time-window selector (Last Month, Last Year, This Year, All Time)
//  used anywhere wear data needs to be scoped to a period — currently RewindView's
//  report picker and AnalyticsDashboardView's Top 5 Wrist Checks chart.
//

import Foundation

enum ReportPeriod: String, CaseIterable {
    case lastMonth = "Last Month"
    case lastYear = "Last Year"
    case thisYear = "This Year"
    case allTime = "All Time"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
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
}
