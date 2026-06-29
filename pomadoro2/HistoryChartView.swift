//
//  HistoryChartView.swift
//  pomadoro2
//
//  Weekly / monthly focus-minutes history, drawn with Swift Charts from the
//  local DailyHistoryStore.
//

import SwiftUI
import Charts

struct HistoryChartView: View {
    let data: [DailyFocus]
    let accent: Color

    private var maxMinutes: Int { max(data.map(\.minutes).max() ?? 0, 1) }

    var body: some View {
        Chart(data) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Minutes", day.minutes)
            )
            .foregroundStyle(accent.gradient)
            .cornerRadius(3)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, data.count / 6))) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Focus history chart")
        .accessibilityValue(
            "\(data.reduce(0) { $0 + $1.minutes }) total minutes over \(data.count) days"
        )
    }
}
