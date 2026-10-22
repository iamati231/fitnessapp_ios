#if canImport(SwiftUI)
import SwiftUI

/// Pflicht-Attribution fuer Open Food Facts (Task 3,
/// docs/superpowers/sdd/2026-10-22-online-food-lookup): die kommende
/// Online-Suche fuer unbekannte Lebensmittel (Task 4/5, FitnessAppFoodLookup)
/// fragt die ODbL-lizenzierte Open-Food-Facts-Datenbank ab. Die ODbL verlangt
/// einen sichtbaren Lizenzhinweis + Link zur Quelle — siehe
/// https://opendatacommons.org/licenses/odbl/1-0/. Muster: `ExerciseMediaCreditsView`.
@available(iOS 17.0, macOS 14.0, *)
struct OnlineFoodLookupCreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.credits.onlineFoodLookup.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 16) {
                Text("settings.credits.onlineFoodLookup.body", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Color.Deltiq.textSecondary)

                Text("settings.credits.onlineFoodLookup.attribution", bundle: .module)
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .deltiqCardStyle(padding: 12, cornerRadius: Deltiq.Radius.medium)

                Link("openfoodfacts.org", destination: URL(string: "https://world.openfoodfacts.org")!)
                    .font(.footnote)
            }
            .deltiqScreen()
        }
        .background(Color.Deltiq.background.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .deltiqSwipeBackEnabled()
    }
}
#endif
