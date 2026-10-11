import DeviceActivity
import Foundation

/// Brings the shield back when a pass runs out. Runs in a ~6 MB budget
/// with no reliable network, so it only reads the App Group and writes
/// the shield.
final class PassMonitorExtension: DeviceActivityMonitor {
    /// Threshold callbacks can fire early. One that arrives well before the
    /// stored wall-clock expiry is treated as spurious; `intervalDidEnd`
    /// and the app's foreground recheck still cover that pass.
    private let earlyFireTolerance: TimeInterval = 30

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == .pass, event == .passUsed else { return }
        let now = Date.now
        if let exp = SharedState.passExpiresAt, exp.timeIntervalSince(now) > earlyFireTolerance {
            return
        }
        endPass()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // A new grant restarts monitoring, which can end the previous
        // interval; don't let that tear down the pass that replaced it.
        guard activity == .pass, !SharedState.hasActivePass() else { return }
        endPass()
    }

    private func endPass() {
        SharedState.passExpiresAt = nil
        ShieldController.shieldSelectedApps()
    }
}
