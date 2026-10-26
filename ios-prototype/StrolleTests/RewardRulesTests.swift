import XCTest
@testable import Strolle

final class RewardRulesTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private func day(_ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour))!
    }

    func testXPScalesWithDifficulty() {
        XCTAssertEqual(RewardRules.baseXP(difficulty: 1), 10)
        XCTAssertEqual(RewardRules.baseXP(difficulty: 5), 30)
        XCTAssertEqual(RewardRules.baseXP(difficulty: 99), 30)
    }

    func testComboMultiplierSteps() {
        XCTAssertEqual(RewardRules.multiplier(forCombo: 1), 1.0)
        XCTAssertEqual(RewardRules.multiplier(forCombo: 3), 1.25)
        XCTAssertEqual(RewardRules.multiplier(forCombo: 5), 1.5)
        XCTAssertEqual(RewardRules.multiplier(forCombo: 12), 2.0)
    }

    func testMissResetsComboButEarnsNoXP() {
        var s = RewardState()
        for _ in 0..<3 { (s, _) = RewardRules.apply(to: s, correct: true, difficulty: 3, now: day(1), calendar: cal) }
        let xpBefore = s.totalXP
        let (after, r) = RewardRules.apply(to: s, correct: false, difficulty: 3, now: day(1), calendar: cal)
        XCTAssertEqual(after.combo, 0)
        XCTAssertEqual(r.xp, 0)
        XCTAssertEqual(after.totalXP, xpBefore)
        XCTAssertEqual(after.dayStreak, 1)
    }

    func testDayStreakExtendsAndLapses() {
        var s = RewardState()
        (s, _) = RewardRules.apply(to: s, correct: true, difficulty: 1, now: day(1), calendar: cal)
        (s, _) = RewardRules.apply(to: s, correct: true, difficulty: 1, now: day(1, hour: 20), calendar: cal)
        XCTAssertEqual(s.dayStreak, 1)
        (s, _) = RewardRules.apply(to: s, correct: true, difficulty: 1, now: day(2), calendar: cal)
        XCTAssertEqual(s.dayStreak, 2)
        XCTAssertEqual(RewardRules.displayedDayStreak(s, now: day(3), calendar: cal), 2)
        XCTAssertEqual(RewardRules.displayedDayStreak(s, now: day(4), calendar: cal), 0)
        (s, _) = RewardRules.apply(to: s, correct: true, difficulty: 1, now: day(5), calendar: cal)
        XCTAssertEqual(s.dayStreak, 1)
    }

    func testDailyXPResetsAndGoalFiresOnce() {
        var s = RewardState()
        var goalHits = 0
        for _ in 0..<12 {
            let (next, r) = RewardRules.apply(to: s, correct: true, difficulty: 5, now: day(1), calendar: cal)
            s = next
            if r.dailyGoalReached { goalHits += 1 }
        }
        XCTAssertEqual(goalHits, 1)
        XCTAssertEqual(RewardRules.displayedDailyXP(s, now: day(2), calendar: cal), 0)
    }

    func testLevels() {
        XCTAssertEqual(RewardRules.level(forXP: 0), 1)
        XCTAssertEqual(RewardRules.level(forXP: 99), 1)
        XCTAssertEqual(RewardRules.level(forXP: 100), 2)
        XCTAssertEqual(RewardRules.level(forXP: 300), 3)
        XCTAssertEqual(RewardRules.levelProgress(forXP: 200), 0.5, accuracy: 0.001)
    }
}
