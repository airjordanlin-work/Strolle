import Foundation
import ManagedSettings
import FamilyControls

/// The only code that writes the shield. Used by the app (grant, re-arm)
/// and by the monitor extension (re-shield when a pass runs out), so both
/// sides go through the same named store.
enum ShieldController {
    private static var store: ManagedSettingsStore { ManagedSettingsStore(named: .strolle) }

    static func shieldSelectedApps() {
        let s = SharedState.selection
        let store = self.store
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.applicationCategories = s.categoryTokens.isEmpty
            ? nil : .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
        store.shield.webDomainCategories = s.categoryTokens.isEmpty
            ? nil : .specific(s.categoryTokens)
    }

    static func liftShield() {
        store.clearAllSettings()
    }

    /// Foreground backstop: threshold callbacks are a wake-up signal, not
    /// proof time elapsed, so whenever the app comes forward it re-derives
    /// the shield from the stored expiry.
    static func reconcile(now: Date = .now) {
        if SharedState.hasActivePass(now: now) {
            liftShield()
        } else {
            shieldSelectedApps()
        }
    }
}
