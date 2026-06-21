//
//  WristCheckCalendarView.swift
//  WristScan
//
//  Purpose: Renders a dynamic, multi-month calendar heatmap visualizing an individual watch's wear history.
//

import SwiftUI

struct WristCheckCalendarView: View {
    let wearHistory: [Date]
    var onDateTapped: ((Date) -> Void)? = nil
    
    @State private var monthCount: Int = 6
    
    private let calendar = Calendar.current
    private let weekdayInitials = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    // MARK: - Date Math Helpers
    
    /// Returns an array of Dates representing the first day of each of the last `monthCount` months,
    /// ordered from oldest to most recent (ending at the current month).
    var months: [Date] {
        var result: [Date] = []
        let today = Date.now
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        
        for offset in stride(from: monthCount - 1, through: 0, by: -1) {
            if let month = calendar.date(byAdding: .month, value: -offset, to: startOfCurrentMonth) {
                result.append(month)
            }
        }
        return result
    }
    
    /// Returns the number of days in the month containing the given date.
    func daysInMonth(_ date: Date) -> Int {
        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.count
    }
    
    /// Returns the 0-indexed weekday of the first day of the month (0 = Sunday, 6 = Saturday).
    func firstWeekdayOffset(_ date: Date) -> Int {
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstDay = calendar.date(from: components)!
        // calendar.component(.weekday) returns 1-based (1 = Sunday)
        return calendar.component(.weekday, from: firstDay) - 1
    }
    
    /// Constructs a Date for a specific day number within the given month date.
    func date(day: Int, in month: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = day
        return calendar.date(from: components)
    }
    
    /// Returns true if the given date is worn (matches any entry in wearHistory).
    func isWorn(_ date: Date) -> Bool {
        wearHistory.contains { calendar.isDate(date, inSameDayAs: $0) }
    }
    
    /// Returns true if the given date is today.
    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    // MARK: - Month Header Label
    
    func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeframe segmented picker
            Picker("Timeframe", selection: $monthCount) {
                Text("3 Months").tag(3)
                Text("6 Months").tag(6)
                Text("12 Months").tag(12)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 30) {
                    ForEach(months.reversed(), id: \.self) { month in
                        MonthGridView(
                            month: month,
                            monthLabel: monthLabel(for: month),
                            weekdayInitials: weekdayInitials,
                            columns: columns,
                            daysInMonth: daysInMonth(month),
                            firstWeekdayOffset: firstWeekdayOffset(month),
                            isWorn: isWorn,
                            isToday: isToday,
                            date: { day in date(day: day, in: month) },
                            onDateTapped: onDateTapped
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Month Grid Subview

/// Renders a single month calendar block: heading, weekday initials, and the day cells grid.
private struct MonthGridView: View {
    let month: Date
    let monthLabel: String
    let weekdayInitials: [String]
    let columns: [GridItem]
    let daysInMonth: Int
    let firstWeekdayOffset: Int
    let isWorn: (Date) -> Bool
    let isToday: (Date) -> Bool
    let date: (Int) -> Date?
    var onDateTapped: ((Date) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Month + year heading
            Text(monthLabel)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.amberGold)
                .tracking(1.2)
            
            // Weekday initial headers
            HStack(spacing: 0) {
                ForEach(weekdayInitials.indices, id: \.self) { i in
                    Text(weekdayInitials[i])
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Day cell grid
            LazyVGrid(columns: columns, spacing: 6) {
                // Leading blank offset cells so day 1 lands on the correct weekday column
                ForEach(0 ..< firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 32)
                }
                
                // Actual day cells
                ForEach(1 ... daysInMonth, id: \.self) { day in
                    if let cellDate = date(day) {
                        Button {
                            onDateTapped?(cellDate)
                        } label: {
                            DayCellView(
                                day: day,
                                worn: isWorn(cellDate),
                                today: isToday(cellDate)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Day Cell

private struct DayCellView: View {
    let day: Int
    let worn: Bool
    let today: Bool
    
    var body: some View {
        ZStack {
            if worn {
                // Filled amber circle for a worn day
                Circle()
                    .fill(Color.amberGold)
                    .frame(width: 30, height: 30)
                Text("\(day)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            } else if today {
                // Subtle ring for today when not worn
                Circle()
                    .stroke(Color.amberGold.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 30, height: 30)
                Text("\(day)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text("\(day)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(height: 32)
    }
}
