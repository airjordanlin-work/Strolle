import Foundation
import SwiftUI
import FamilyControls
import UserNotifications

/// One gate visit: how many questions this entry costs, and which app the
/// user was trying to open.
struct GateSession: Identifiable {
    let id = UUID()
    let appName: String?
    let questionsOwed: Int
}

@MainActor
final class AppModel: ObservableObject {
    @Published var authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    @Published var authError: String?
    @Published var selection = SharedState.selection
    @Published var passExpiresAt = SharedState.passExpiresAt
    @Published var gate: GateSession?

    let rules = PassRules()
    let queue = ReviewQueue()
    let pool = QuestionBank.loadGatePool()

    // MARK: Setup

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = AuthorizationCenter.shared.authorizationStatus == .approved
            authError = nil
        } catch {
            // Most common real-world cause for a 16-17 year old tester: a
            // parent-held Screen Time passcode or a Family Sharing child
            // account. Say so instead of dead-ending (README, iOS notes).
            authError = "Screen Time access was not granted. If a parent manages Screen Time on this phone, they'll need to approve Strolle. (\(error.localizedDescription))"
        }
        // The shield-action extension uses a notification to bring the
        // user here, since a shield can't open an app directly.
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func saveSelection(_ newValue: FamilyActivitySelection) {
        selection = newValue
        SharedState.selection = newValue
        ShieldController.reconcile()
    }

    // MARK: Gate flow

    func onForeground() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        passExpiresAt = SharedState.passExpiresAt
        guard authorized else { return }
        ShieldController.reconcile()
        if gate == nil, let pending = SharedState.pendingGate() {
            SharedState.clearPendingGate()
            startGate(appName: pending.appName)
        }
    }

    func startGate(appName: String?) {
        let entry = SharedState.registerEntry()
        let cost = rules.costForEntry(entry)
        if cost == 0 {
            grant(seconds: rules.passLength(for: .correct))
        } else {
            gate = GateSession(appName: appName, questionsOwed: cost)
        }
    }

    /// Called by the gate once every owed question has been answered.
    /// Engagement, not correctness, decides entry: the pass is granted
    /// either way, and on iOS both outcomes get the 5-minute floor.
    func finishGate(lastResult: AnswerResult) {
        gate = nil
        grant(seconds: rules.passLength(for: lastResult))
    }

    func lockNow() {
        PassScheduler.revoke()
        passExpiresAt = nil
    }

    private func grant(seconds: TimeInterval) {
        do {
            try PassScheduler.grantPass(length: seconds)
        } catch {
            authError = "Couldn't start the pass timer: \(error.localizedDescription)"
        }
        passExpiresAt = SharedState.passExpiresAt
    }
}
