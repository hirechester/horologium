import SwiftUI

struct CalendarView: View {
    @ObservedObject var store: AppStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(ClockText.date(store.month, template: "MMMM yyyy"))
                    .font(.headline)
                Spacer()
                Button { store.shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Button("Today") { store.returnToNow() }
                    .font(.caption)
                Button { store.shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next month")
            }
            .buttonStyle(.borderless)
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.bottom, 4)
                }
                ForEach(store.engine.monthDays(containing: store.month), id: \.self) { day in
                    dayButton(day)
                }
            }
        }
    }

    private var weekdays: [String] {
        let symbols = store.engine.calendar.veryShortStandaloneWeekdaySymbols
        let start = store.engine.calendar.firstWeekday - 1
        return (0..<7).map { symbols[(start + $0) % 7] }
    }

    private func dayButton(_ day: Date) -> some View {
        let calendar = store.engine.calendar
        let selected = calendar.isDate(day, inSameDayAs: store.selectedDate)
        let today = calendar.isDate(day, inSameDayAs: store.now)
        let inMonth = calendar.isDate(day, equalTo: store.month, toGranularity: .month)
        return Button { store.select(day) } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 12, weight: selected || today ? .semibold : .regular, design: .rounded))
                .foregroundStyle(selected ? store.preferences.calendarSelectionForeground : (inMonth ? Color.primary : Color.secondary.opacity(0.55)))
                .frame(maxWidth: .infinity).frame(height: 29)
                .background {
                    if selected { RoundedRectangle(cornerRadius: 8).fill(Color.accentColor) }
                    else if today { RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: 1) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ClockText.date(day, template: "EEEE MMMM d yyyy") + (today ? ", today" : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
