#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI

/// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md, Teil 3): Gruppe
/// "Hilfe & Informationen" — Version, Bundle-ID, Übungs-GIF-Credits. Reine
/// Verschiebung aus `SettingsView.aboutSection`.
@available(iOS 17.0, macOS 14.0, *)
public struct SettingsHelpInfoView: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.group.helpInfo", bundle: .module),
                onBack: { dismiss() }
            )
            ScrollView {
                VStack(spacing: 18) {
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .deltiqSwipeBackEnabled()
    }

    private var aboutSection: some View {
        DeltiqSection(String(localized: "settings.section.about", bundle: .module).uppercased()) {
            DeltiqControlRow(label: String(localized: "settings.about.version", bundle: .module)) {
                Text(appVersion)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            DeltiqControlRow(label: String(localized: "settings.about.bundle", bundle: .module)) {
                Text(bundleIdentifier)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            NavigationLink {
                ExerciseMediaCreditsView()
            } label: {
                DeltiqRow(
                    icon: "photo.on.rectangle.angled",
                    label: String(localized: "settings.about.exerciseMediaCredit", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }

    private var appVersion: String {
        let d = Bundle.main.infoDictionary
        let version = d?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = d?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "—"
    }
}
#endif
