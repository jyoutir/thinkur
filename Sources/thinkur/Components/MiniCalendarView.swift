import SwiftUI

struct MiniCalendarView: View {
    let activeDateStrings: Set<String>
    @Binding var selectedDay: Date?

    @State private var displayedMonth: Date = .now

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols

    var body: some View {
        VStack(spacing: Spacing.xs) {
            // Month header with navigation
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(Typography.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(dayCells, id: \.id) { cell in
                    if let date = cell.date {
                        DayCellView(
                            date: date,
                            hasActivity: activeDateStrings.contains(dateFormatter.string(from: date)),
                            isSelected: isSameDay(date, selectedDay),
                            isToday: calendar.isDateInToday(date)
                        )
                        .onTapGesture {
                            if isSameDay(date, selectedDay) {
                                selectedDay = nil
                            } else {
                                selectedDay = date
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 24)
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .glassCard()
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func isSameDay(_ a: Date, _ b: Date?) -> Bool {
        guard let b else { return false }
        return calendar.isDate(a, inSameDayAs: b)
    }

    private var dayCells: [DayCell] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [DayCell] = []
        for _ in 0..<leadingBlanks {
            cells.append(DayCell(id: "blank-\(cells.count)", date: nil))
        }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                cells.append(DayCell(id: dateFormatter.string(from: date), date: date))
            }
        }
        return cells
    }
}

private struct DayCell: Identifiable {
    let id: String
    let date: Date?
}

private struct DayCellView: View {
    let date: Date
    let hasActivity: Bool
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 1) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(Typography.caption2)
                .foregroundStyle(isSelected ? .white : isToday ? .blue : ColorTokens.textPrimary)
                .frame(width: 22, height: 22)
                .background {
                    if isSelected {
                        Circle().fill(.blue)
                    } else if isToday {
                        Circle().strokeBorder(.blue, lineWidth: 1)
                    }
                }

            Circle()
                .fill(.blue)
                .frame(width: 4, height: 4)
                .opacity(hasActivity ? 1 : 0)
        }
        .frame(height: 28)
    }
}
