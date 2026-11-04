#if canImport(SwiftUI)
import SwiftUI

/// Attribution fuer die Uebungs-GIFs. Quelle: `hasaneyldrm/exercises-dataset`
/// (Namens-/Equipment-Daten, MIT-Lizenz) + `arvids-unavailable/openGym`
/// (die eigentlichen 180x180-GIF-Dateien). Die Bildrechte selbst liegen bei
/// Gym visual (gymvisual.com) — Pflicht-Hinweistext wird verbatim gezeigt,
/// siehe `NOTICE-exercise-gifs.md` im Repo-Root fuer die vollen Bedingungen.
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseMediaCreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            DeltiqHeader(
                eyebrow: String(localized: "tab.more", bundle: .module).uppercased(),
                title: String(localized: "settings.credits.exerciseMedia.title", bundle: .module),
                onBack: { dismiss() }
            )

            VStack(alignment: .leading, spacing: 16) {
                Text("settings.credits.exerciseMedia.body", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Color.Deltiq.textSecondary)

                Text("settings.credits.exerciseMedia.attribution", bundle: .module)
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .deltiqCardStyle(padding: 12, cornerRadius: Deltiq.Radius.medium)

                Text("settings.credits.exerciseMedia.sources", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(Color.Deltiq.textTertiary)
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
