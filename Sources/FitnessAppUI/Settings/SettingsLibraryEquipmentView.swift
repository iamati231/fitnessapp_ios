#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI

/// Settings-Epic Phase 3 (docs/SETTINGS_UX_AUDIT.md, Teil 3): Gruppe
/// "Bibliothek & Ausrüstung" — globale Übungsbibliothek + Gear-Tracker
/// (Schuhe/Räder). Reine Verschiebung aus `SettingsView.preferencesSection`.
/// Bewusst getrennt vom Trainingsequipment-Profil im Profil-Editor (siehe
/// `GEAR-01`/`GEAR-04`-Befunde) — hier geht es um Verschleiss-Tracking, nicht
/// um die Plan-Filterung.
@available(iOS 17.0, macOS 14.0, *)
public struct SettingsLibraryEquipmentView: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.group.libraryEquipment", bundle: .module),
                onBack: { dismiss() }
            )
            ScrollView {
                VStack(spacing: 18) {
                    libraryGearSection
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

    private var libraryGearSection: some View {
        DeltiqSection(String(localized: "settings.group.libraryEquipment", bundle: .module).uppercased()) {
            NavigationLink {
                ExerciseLibraryView()
            } label: {
                DeltiqRow(
                    icon: "figure.strengthtraining.traditional",
                    label: String(localized: "settings.preferences.exerciseLibrary", bundle: .module),
                    showsChevron: true
                )
            }
            NavigationLink {
                GearListView()
            } label: {
                DeltiqRow(
                    icon: "shoe",
                    label: String(localized: "settings.preferences.gear", bundle: .module),
                    showsChevron: true,
                    showsDivider: false
                )
            }
        }
    }
}
#endif
