//
//  StatsView.swift
//  pomadoro2
//
//  Redesigned with Duolingo-style calendar streak view
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var timerManager: TimerManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date?

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 20) {
                    // Header - more compact
                    VStack(spacing: 12) {
                        Text("📊")
                            .font(.system(size: DesignTokens.Typography.emojiSize))
                            .accessibilityHidden(true)

                        Text("Your Progress")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 10)

                    // Today's Stats Section - moved up
                    VStack(spacing: 16) {
                        HStack {
                            Text("Today's Stats")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()

                            Text(Date(), style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 12) {
                            TodayStatCard(
                                icon: "brain.head.profile",
                                value: "\(timerManager.todayFocusMinutes)",
                                unit: "min",
                                label: "Focus Time",
                                color: .red
                            )

                            TodayStatCard(
                                icon: "flame.fill",
                                value: "\(timerManager.currentStreak)",
                                unit: "days",
                                label: "Streak",
                                color: .orange
                            )

                            TodayStatCard(
                                icon: "trophy.fill",
                                value: "\(timerManager.totalFocusMinutes)",
                                unit: "total",
                                label: "All Time",
                                color: .yellow
                            )
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .cardStyle()
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    // Calendar Streak Section - more compact
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Streak Calendar")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)

                                Text("Keep the fire burning! 🔥")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Current streak badge
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)

                                Text("\(timerManager.currentStreak) day streak")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.1))
                            )
                            .accessibilityElement(children: .combine)
                        }

                        // Compact Calendar Grid
                        CompactStreakCalendarView(
                            currentStreak: timerManager.currentStreak,
                            lastCompletionDate: timerManager.lastCompletionDate,
                            selectedDate: $selectedDate
                        )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .cardStyle()
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    // Achievement Section - more compact
                    VStack(spacing: 12) {
                        HStack {
                            Text("Achievements")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Spacer()
                        }

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            AchievementBadge(
                                icon: "🎯",
                                title: "First Session",
                                subtitle: "Complete 1 session",
                                isUnlocked: timerManager.totalFocusMinutes > 0
                            )

                            AchievementBadge(
                                icon: "⚡",
                                title: "Speed Learner",
                                subtitle: "5 sessions/day",
                                isUnlocked: timerManager.todayFocusMinutes >= 125
                            )

                            AchievementBadge(
                                icon: "🔥",
                                title: "On Fire",
                                subtitle: "7 day streak",
                                isUnlocked: timerManager.currentStreak >= 7
                            )

                            AchievementBadge(
                                icon: "💎",
                                title: "Diamond Focus",
                                subtitle: "30 day streak",
                                isUnlocked: timerManager.currentStreak >= 30
                            )

                            AchievementBadge(
                                icon: "🏆",
                                title: "Century Club",
                                subtitle: "100 sessions",
                                isUnlocked: timerManager.totalFocusMinutes >= 2500
                            )

                            AchievementBadge(
                                icon: "🎖️",
                                title: "Master",
                                subtitle: "1000 minutes",
                                isUnlocked: timerManager.totalFocusMinutes >= 1000
                            )
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .cardStyle()
                    .padding(.horizontal, DesignTokens.Spacing.md)

                    // Extra bottom padding to ensure scrolling works
                    Color.clear
                        .frame(height: 50)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemGray6).opacity(0.3),
                        Color(.systemBackground)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }
}

struct TodayStatCard: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                .fill(color.opacity(0.1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit)")
    }
}

struct CompactStreakCalendarView: View {
    let currentStreak: Int
    let lastCompletionDate: Date?
    @Binding var selectedDate: Date?

    @State private var displayedMonth = Date()
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation - more compact
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(displayedMonth, formatter: monthYearFormatter)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            // Day labels - smaller
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid - more compact
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(calendarDates, id: \.self) { date in
                    CompactCalendarDayView(
                        date: date,
                        isInCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                        hasActivity: hasActivityOnDate(date),
                        isSelected: selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }

            // Legend - more compact
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)

                    Text("No activity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)

                    Text("Completed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    private var calendarDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let firstOfMonth = monthInterval.start
        let firstDayWeekday = calendar.component(.weekday, from: firstOfMonth)
        let startDate = calendar.date(byAdding: .day, value: -(firstDayWeekday - 1), to: firstOfMonth)!

        return (0..<42).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startDate)
        }
    }

    private func hasActivityOnDate(_ date: Date) -> Bool {
        // Shade the most recent `currentStreak` days ending on the last
        // completion. Shared with the streak math so the calendar and the
        // streak badge can never disagree.
        StreakCalculator.isActiveDay(
            date,
            currentStreak: currentStreak,
            lastCompletion: lastCompletionDate,
            calendar: calendar
        )
    }

    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        }
    }

    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        }
    }

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
}

struct CompactCalendarDayView: View {
    let date: Date
    let isInCurrentMonth: Bool
    let hasActivity: Bool
    let isSelected: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isInCurrentMonth ? .primary : .secondary)
        }
        .frame(width: 28, height: 28)
        .background(
            Circle()
                .fill(backgroundFill)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                )
        )
        .opacity(isInCurrentMonth ? 1.0 : 0.5)
        .accessibilityLabel("\(calendar.component(.day, from: date))")
        .accessibilityValue(hasActivity ? "Completed" : "No activity")
    }

    private var backgroundFill: Color {
        if hasActivity {
            return Color.orange
        } else if calendar.isDateInToday(date) {
            return Color.blue.opacity(0.3)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

struct AchievementBadge: View {
    let icon: String
    let title: String
    let subtitle: String
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.title3)
                .grayscale(isUnlocked ? 0 : 1)
                .opacity(isUnlocked ? 1 : 0.5)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isUnlocked ? .primary : .secondary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                .fill(isUnlocked ? Color.yellow.opacity(0.1) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                        .stroke(isUnlocked ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isUnlocked ? "Unlocked. \(subtitle)" : "Locked. \(subtitle)")
    }
}
