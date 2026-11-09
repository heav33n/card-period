import Foundation

struct Purchase: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amountCents: Int
    var date: Date
}

enum ResetSchedule: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct SpendingCard: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var lastFour: String
    var limitCents: Int
    var currencyCode: String
    var schedule: ResetSchedule
    // Calendar weekday (1 = Sunday), or day of month (1...31).
    var resetDay: Int
    var purchases: [Purchase] = []
    // A nil date means rollover is disabled; older saved cards decode with nil.
    var rolloverStart: Date? = nil

    func period(containing date: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: date)
        if schedule == .weekly {
            let weekday = calendar.component(.weekday, from: today)
            let daysBack = (weekday - resetDay + 7) % 7
            let start = calendar.date(byAdding: .day, value: -daysBack, to: today)!
            return (start, calendar.date(byAdding: .day, value: 7, to: start)!)
        }
        func reset(in month: Date) -> Date {
            let interval = calendar.dateInterval(of: .month, for: month)!
            let days = calendar.range(of: .day, in: .month, for: interval.start)!.count
            return calendar.date(byAdding: .day, value: min(max(resetDay, 1), days) - 1, to: interval.start)!
        }
        let monthStart = calendar.dateInterval(of: .month, for: today)!.start
        let thisReset = reset(in: monthStart)
        let startMonth = today >= thisReset ? monthStart : calendar.date(byAdding: .month, value: -1, to: monthStart)!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startMonth)!
        return (reset(in: startMonth), reset(in: nextMonth))
    }

    func spent(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        let bounds = period(containing: date, calendar: calendar)
        return purchases.filter { $0.date >= bounds.start && $0.date < bounds.end && $0.date <= date }.reduce(0) { $0 + $1.amountCents }
    }
    func carriedOver(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let rolloverStart else { return 0 }
        let current = period(containing: date, calendar: calendar)
        var bounds = period(containing: rolloverStart, calendar: calendar)
        guard bounds.start < current.start else { return 0 }
        var carry = 0
        while bounds.start < current.start {
            let periodSpent = purchases.lazy.filter { $0.date >= bounds.start && $0.date < bounds.end }.reduce(0) { $0 + $1.amountCents }
            carry = max(0, limitCents + carry - periodSpent)
            bounds = period(containing: bounds.end, calendar: calendar)
        }
        return carry
    }
    func allowance(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        limitCents + carriedOver(at: date, calendar: calendar)
    }
    func remaining(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        allowance(at: date, calendar: calendar) - spent(at: date, calendar: calendar)
    }
}

func money(_ cents: Int, currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return formatter.string(from: NSDecimalNumber(decimal: Decimal(cents) / 100)) ?? "\(currency) \(Double(cents) / 100)"
}
