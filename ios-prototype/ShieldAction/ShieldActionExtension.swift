import ManagedSettings
import UserNotifications

/// Handles the shield's buttons.
///
/// A shield-action extension has no public API to open its parent app,
/// so "Answer a question" records the request in the App Group and posts
/// a local notification; tapping it opens Strolle, which picks the
/// request up on foreground and shows the gate.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, name: Application(token: application).localizedDisplayName,
                completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, name: WebDomain(token: webDomain).domain, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, name: nil, completionHandler)
    }

    private func respond(_ action: ShieldAction, name: String?,
                         _ done: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            SharedState.requestGate(appName: name)
            postOpenStrolleNotification(appName: name) { done(.defer) }
        case .secondaryButtonPressed:
            done(.close)
        @unknown default:
            done(.close)
        }
    }

    private func postOpenStrolleNotification(appName: String?, then: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "Tap to answer"
        content.body = appName.map { "One question, then \($0) opens." } ?? "One question, then you're in."
        content.sound = nil
        let request = UNNotificationRequest(identifier: "strolle.gate", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in then() }
    }
}
