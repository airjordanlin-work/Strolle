import Foundation
import ManagedSettings
import DeviceActivity

/// Identifiers every target must agree on. A mismatched App Group across
/// targets is the most common cause of a shield that looks applied but
/// never takes effect, so they live in one file compiled into all four.
enum AppGroup {
    /// Change this (and the entitlements) to your own team's group.
    static let id = "group.com.strolle.prototype"

    static var defaults: UserDefaults {
        guard let d = UserDefaults(suiteName: id) else {
            fatalError("App Group \(id) is missing from this target's entitlements.")
        }
        return d
    }
}

extension ManagedSettingsStore.Name {
    static let strolle = Self("strolle")
}

extension DeviceActivityName {
    /// Restarted on every grant so usage counts from the moment of the grant.
    static let pass = Self("strolle.pass")
}

extension DeviceActivityEvent.Name {
    static let passUsed = Self("strolle.pass.used")
}
