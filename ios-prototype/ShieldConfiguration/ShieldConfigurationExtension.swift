import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the shield over a gated app. It can only show a title, subtitle,
/// icon and up to two buttons; the quiz itself runs in the main app.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    private func make(name: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            icon: UIImage(systemName: "graduationcap"),
            title: .init(text: name.map { "\($0) is one question away" } ?? "One question away",
                         color: .label),
            subtitle: .init(text: "Answer a quick SAT question to open it for a few minutes. Tap below, then tap the Strolle notification.",
                            color: .secondaryLabel),
            primaryButtonLabel: .init(text: "Answer a question", color: .white),
            primaryButtonBackgroundColor: .systemIndigo,
            secondaryButtonLabel: .init(text: "Not now", color: .secondaryLabel)
        )
    }
}
