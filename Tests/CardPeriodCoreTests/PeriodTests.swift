import XCTest
@testable import CardPeriod

final class PeriodTests: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
    func card(_ schedule: ResetSchedule, _ day: Int) -> SpendingCard { SpendingCard(name: "Card", lastFour: "1234", limitCents: 10000, currencyCode: "USD", schedule: schedule, resetDay: day) }
    func testMonthlyClampsShortMonthAndRecovers() {
        let c = card(.monthly, 31)
        let feb = c.period(containing: date(2025, 2, 28), calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: feb.start), 28)
        XCTAssertEqual(calendar.component(.month, from: feb.end), 3)
        XCTAssertEqual(calendar.component(.day, from: feb.end), 31)
        let before = c.period(containing: date(2025, 2, 27), calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: before.start), 1)
        XCTAssertEqual(calendar.component(.day, from: before.end), 28)
    }
    func testWeeklyBoundaryAndSpending() {
        var c = card(.weekly, 2)
        c.purchases = [Purchase(title: "old", amountCents: 1000, date: date(2025, 3, 2)), Purchase(title: "new", amountCents: 2500, date: date(2025, 3, 3)), Purchase(title: "future", amountCents: 900, date: date(2025, 3, 5))]
        XCTAssertEqual(c.spent(at: date(2025, 3, 4), calendar: calendar), 2500)
        XCTAssertEqual(c.remaining(at: date(2025, 3, 4), calendar: calendar), 7500)
        XCTAssertEqual(calendar.component(.day, from: c.period(containing: date(2025, 3, 4), calendar: calendar).end), 10)
    }
    func testRolloverAccumulatesUnusedAllowanceAndIncludesPastPurchases() {
        var c = card(.monthly, 1)
        c.rolloverStart = date(2025, 1, 15)
        c.purchases = [Purchase(title: "January", amountCents: 9900, date: date(2025, 1, 2)), Purchase(title: "February", amountCents: 5000, date: date(2025, 2, 2))]
        XCTAssertEqual(c.carriedOver(at: date(2025, 2, 5), calendar: calendar), 100)
        XCTAssertEqual(c.allowance(at: date(2025, 2, 5), calendar: calendar), 10100)
        XCTAssertEqual(c.remaining(at: date(2025, 3, 5), calendar: calendar), 15100)
        XCTAssertEqual(c.carriedOver(at: date(2025, 1, 20), calendar: calendar), 0)
    }
    func testOverspendingDoesNotCarryAsDebt() {
        var c = card(.weekly, 2)
        c.rolloverStart = date(2025, 3, 3)
        c.purchases = [Purchase(title: "Overspend", amountCents: 12000, date: date(2025, 3, 4))]
        XCTAssertEqual(c.remaining(at: date(2025, 3, 5), calendar: calendar), -2000)
        XCTAssertEqual(c.remaining(at: date(2025, 3, 10), calendar: calendar), 10000)
    }
    func testOldSavedCardsHaveRolloverDisabled() throws {
        let json = """
        {"name":"Card","lastFour":"1234","limitCents":10000,"currencyCode":"USD","schedule":"monthly","resetDay":1,"purchases":[],"id":"00000000-0000-0000-0000-000000000001"}
        """
        let c = try JSONDecoder().decode(SpendingCard.self, from: Data(json.utf8))
        XCTAssertNil(c.rolloverStart)
        XCTAssertEqual(c.carriedOver(at: date(2025, 3, 1), calendar: calendar), 0)
    }
}
