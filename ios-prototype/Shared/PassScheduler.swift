import Foundation
import DeviceActivity
import FamilyControls

/// Grants a pass: lifts the shield, records the expiry, and arms the
/// monitor so the shield comes back.
///
/// Two things bring the shield back, whichever fires first:
/// - `eventDidReachThreshold` once the selected apps have been *used* for
///   the pass length. Monitoring restarts at every grant so the usage
///   count starts from zero.
/// - `intervalDidEnd`, a wall-clock backstop at the end of the schedule.
///   Apple's minimum interval is 15 minutes, so this is the latest a pass
///   can outlive its expiry if the user leaves the app idle and never
///   opens Strolle (opening Strolle re-shields immediately via
///   `ShieldController.reconcile`).
enum PassScheduler {
    static let minimumIntervalMinutes = 15

    static func grantPass(length: TimeInterval, now: Date = .now) throws {
        let selection = SharedState.selection
        let center = DeviceActivityCenter()
        center.stopMonitoring([.pass])

        let cal = Calendar.current
        // One minute of slack so the schedule never lands just under the minimum.
        let end = now.addingTimeInterval(max(length, TimeInterval(minimumIntervalMinutes * 60 + 60)))
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: cal.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(second: Int(length))
        )

        try center.startMonitoring(.pass, during: schedule, events: [.passUsed: event])
        SharedState.passExpiresAt = now.addingTimeInterval(length)
        ShieldController.liftShield()
    }

    /// Ends any pass early (used by "lock now" in the app).
    static func revoke() {
        DeviceActivityCenter().stopMonitoring([.pass])
        SharedState.passExpiresAt = nil
        ShieldController.shieldSelectedApps()
    }
}
