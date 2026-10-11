import Foundation
import FamilyControls

/// State shared between the app and its extensions through the App Group.
///
/// Local stand-in for the server's `pass_state`. CLAUDE.md makes pass state
/// server-authoritative; this prototype keeps it on-device so the Screen
/// Time mechanics can be tested before the backend is wired in.
enum SharedState {
    private enum Key {
        static let selection = "selection"
        static let passExpiresAt = "passExpiresAt"
        static let entryLog = "entryLog"
        static let gateRequestedAt = "gateRequestedAt"
        static let gateRequestedApp = "gateRequestedApp"
    }

    private static var d: UserDefaults { AppGroup.defaults }

    // MARK: Chosen apps

    static var selection: FamilyActivitySelection {
        get {
            guard let data = d.data(forKey: Key.selection),
                  let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return s
        }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: Key.selection) }
    }

    // MARK: Pass

    static var passExpiresAt: Date? {
        get { d.object(forKey: Key.passExpiresAt) as? Date }
        set { d.set(newValue, forKey: Key.passExpiresAt) }
    }

    static func hasActivePass(now: Date = .now) -> Bool {
        guard let exp = passExpiresAt else { return false }
        return exp > now
    }

    // MARK: Rolling-hour entry log (drives escalating cost)

    /// Records an entry and returns its 1-indexed position in the past hour.
    static func registerEntry(now: Date = .now) -> Int {
        var log = (d.array(forKey: Key.entryLog) as? [Date]) ?? []
        log.removeAll { now.timeIntervalSince($0) > 3600 }
        log.append(now)
        d.set(log, forKey: Key.entryLog)
        return log.count
    }

    // MARK: Hand-off from the shield to the app

    /// Set by the shield-action extension when the user asks to answer.
    static func requestGate(appName: String?, now: Date = .now) {
        d.set(now, forKey: Key.gateRequestedAt)
        d.set(appName, forKey: Key.gateRequestedApp)
    }

    /// A request counts only if it is recent, so a stale tap from hours
    /// ago doesn't throw the user into a quiz when they open the app.
    static func pendingGate(now: Date = .now) -> (appName: String?, at: Date)? {
        guard let at = d.object(forKey: Key.gateRequestedAt) as? Date,
              now.timeIntervalSince(at) < 10 * 60 else { return nil }
        return (d.string(forKey: Key.gateRequestedApp), at)
    }

    static func clearPendingGate() {
        d.removeObject(forKey: Key.gateRequestedAt)
        d.removeObject(forKey: Key.gateRequestedApp)
    }
}
