import Foundation

/// Cosmetic reward rules for the gate: XP, combo, levels and the daily
/// streak. Nothing here touches pass length, and nothing is authoritative.
/// Until the backend stores it, this lives in UserDefaults and a reinstall
/// wipes it (CLAUDE.md: pass_state is the only server-authoritative state
/// that matters for entry; this is presentation).
///
/// XP scales with question difficulty and the combo, never with speed:
/// the gate is about engagement and `PassRules` already discards guesses.
struct RewardState: Codable, Equatable {
    var totalXP = 0
    var dailyXP = 0
    /// Start of the local day `dailyXP` belongs to.
    var dailyDay: Date?
    /// Consecutive correct answers. A miss resets it; it never resets the
    /// day streak, since a considered miss still counts as showing up.
    var combo = 0
    var bestCombo = 0
    var dayStreak = 0
    /// Start of the last local day with a counted answer.
    var lastActiveDay: Date?
}

struct AnswerReward: Equatable {
    let correct: Bool
    let xp: Int
    let multiplier: Double
    let combo: Int
    let newLevel: Int?
    let dayStreakExtended: Bool
    let dailyGoalReached: Bool
}

enum RewardRules {
    static let dailyGoalXP = 100

    /// Combo thresholds, checked from the top. Capped at 2x so a long run
    /// feels good without making hard-question XP meaningless.
    static let comboSteps: [(combo: Int, multiplier: Double)] = [
        (10, 2.0), (8, 1.75), (5, 1.5), (3, 1.25),
    ]

    static func baseXP(difficulty: Int) -> Int {
        10 + 5 * (min(max(difficulty, 1), 5) - 1)
    }

    static func multiplier(forCombo combo: Int) -> Double {
        comboSteps.first { combo >= $0.combo }?.multiplier ?? 1.0
    }

    /// Total XP needed to reach `level`: 100, 300, 600, 1000, ... so each
    /// level costs 100 more than the last.
    static func xpThreshold(level: Int) -> Int { 50 * (level - 1) * level }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xp >= xpThreshold(level: level + 1) { level += 1 }
        return level
    }

    /// 0...1 progress through the current level.
    static func levelProgress(forXP xp: Int) -> Double {
        let level = level(forXP: xp)
        let lo = xpThreshold(level: level)
        let hi = xpThreshold(level: level + 1)
        return Double(xp - lo) / Double(hi - lo)
    }

    /// Pure transition so it can be unit-tested without UserDefaults or a
    /// clock. `.tooFast` answers never reach here; they are discarded
    /// before scoring.
    static func apply(
        to state: RewardState,
        correct: Bool,
        difficulty: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> (RewardState, AnswerReward) {
        var s = state
        let today = calendar.startOfDay(for: now)

        if s.dailyDay != today {
            s.dailyDay = today
            s.dailyXP = 0
        }

        var extended = false
        if s.lastActiveDay != today {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            s.dayStreak = (s.lastActiveDay == yesterday) ? s.dayStreak + 1 : 1
            s.lastActiveDay = today
            extended = true
        }

        let levelBefore = level(forXP: s.totalXP)
        let goalBefore = s.dailyXP >= dailyGoalXP

        var xp = 0
        var mult = 1.0
        if correct {
            s.combo += 1
            s.bestCombo = max(s.bestCombo, s.combo)
            mult = multiplier(forCombo: s.combo)
            xp = Int((Double(baseXP(difficulty: difficulty)) * mult).rounded())
        } else {
            s.combo = 0
        }
        s.totalXP += xp
        s.dailyXP += xp

        let levelAfter = level(forXP: s.totalXP)
        let reward = AnswerReward(
            correct: correct,
            xp: xp,
            multiplier: mult,
            combo: s.combo,
            newLevel: levelAfter > levelBefore ? levelAfter : nil,
            dayStreakExtended: extended,
            dailyGoalReached: !goalBefore && s.dailyXP >= dailyGoalXP
        )
        return (s, reward)
    }

    /// The streak to show now: a streak whose last active day is older than
    /// yesterday has lapsed, even if nothing has reset the stored value yet.
    static func displayedDayStreak(_ state: RewardState, now: Date, calendar: Calendar = .current) -> Int {
        guard let last = state.lastActiveDay else { return 0 }
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        return (last == today || last == yesterday) ? state.dayStreak : 0
    }

    static func displayedDailyXP(_ state: RewardState, now: Date, calendar: Calendar = .current) -> Int {
        state.dailyDay == calendar.startOfDay(for: now) ? state.dailyXP : 0
    }
}

@MainActor
final class RewardStore: ObservableObject {
    @Published private(set) var state: RewardState
    private let defaults: UserDefaults
    private static let key = "strolle.rewards.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(RewardState.self, from: data) {
            state = saved
        } else {
            state = RewardState()
        }
    }

    var level: Int { RewardRules.level(forXP: state.totalXP) }
    var levelProgress: Double { RewardRules.levelProgress(forXP: state.totalXP) }
    var dayStreak: Int { RewardRules.displayedDayStreak(state, now: .now) }
    var dailyXP: Int { RewardRules.displayedDailyXP(state, now: .now) }
    var dailyProgress: Double { min(1, Double(dailyXP) / Double(RewardRules.dailyGoalXP)) }

    @discardableResult
    func record(correct: Bool, difficulty: Int) -> AnswerReward {
        let (next, reward) = RewardRules.apply(to: state, correct: correct, difficulty: difficulty, now: .now)
        state = next
        if let data = try? JSONEncoder().encode(next) {
            defaults.set(data, forKey: Self.key)
        }
        return reward
    }
}
