import Foundation

/// Swift port of `app/lib/services/pass_service.dart`. Keep the two in step.
enum AnswerResult {
    case correct, incorrect, tooFast
}

struct PassRules {
    var passLengthMinutes = 5
    var guessThresholdSeconds: TimeInterval = 2
    var freeEntriesPerHour = 1
    var escalationCurve = [1, 2, 3]

    /// iOS floor: DeviceActivityEvent thresholds under ~5 minutes are
    /// unreliable, so the Android 90-second wrong-answer pass doesn't exist
    /// here. A wrong answer gets the floor, and the shorter review interval
    /// is the penalty instead (README, iOS platform notes).
    static let iosFloorMinutes = 5

    /// `entryNumberThisHour` is 1-indexed. First entry free, then the
    /// curve, plateauing at its last value.
    func costForEntry(_ entryNumberThisHour: Int) -> Int {
        let index = entryNumberThisHour - freeEntriesPerHour - 1
        if index < 0 { return 0 }
        return index >= escalationCurve.count ? escalationCurve.last! : escalationCurve[index]
    }

    func classify(correct: Bool, answeredAfter seconds: TimeInterval) -> AnswerResult {
        if seconds < guessThresholdSeconds { return .tooFast }
        return correct ? .correct : .incorrect
    }

    /// Never call with `.tooFast`: a discarded attempt grants nothing.
    func passLength(for result: AnswerResult) -> TimeInterval {
        precondition(result != .tooFast, "tooFast answers are discarded, not scored.")
        return TimeInterval(max(passLengthMinutes, Self.iosFloorMinutes) * 60)
    }
}
