import ManagedSettings
import ManagedSettingsUI
import UIKit

final class HabitShield: ShieldConfigurationDataSource {
    private func make() -> ShieldConfiguration {
        ShieldConfiguration(backgroundBlurStyle: .systemMaterialDark, backgroundColor: .systemBackground, icon: UIImage(systemName: "leaf.fill"), title: .init(text: "Prima ciò che conta.", color: .label), subtitle: .init(text: "Completa le abitudini e attiva uno sblocco in Abitudini Locale.", color: .secondaryLabel), primaryButtonLabel: .init(text: "Chiudi", color: .white), primaryButtonBackgroundColor: .systemGreen)
    }
    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make() }
}
