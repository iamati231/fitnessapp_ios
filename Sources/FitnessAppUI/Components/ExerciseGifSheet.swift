#if canImport(SwiftUI)
import SwiftUI

/// Separates Sheet fuer das animierte Uebungs-GIF im aktiven Workout.
///
/// Bugfix "Workout-GIF-Overlay": vorher war `ExerciseGifView` klein (44x44)
/// aber ANIMIERT direkt im `ExerciseCard`-Header eingebettet. Je nach GIF-
/// Seitenverhaeltnis hat `UIImageView.intrinsicContentSize` (siehe
/// `GifImageView.sizeThatFits`) die SwiftUI-Frame-Vorgabe durchbrochen und
/// das GIF ueber Uebungsname/Satzzeilen gelegt. Die Karte zeigt jetzt gar
/// kein GIF mehr inline — nur einen kleinen Play-Button (siehe
/// `ExerciseCard.gifButton`), der DIESES Sheet oeffnet. Dekodierung und
/// Animation starten dadurch automatisch erst bei explizitem Tap und enden
/// beim Schliessen (SwiftUI deallokiert die Sheet-Inhalte, `GifImageView.
/// dismantleUIView` stoppt die Animation) — der darunterliegende Workout-
/// Zustand (Sets, Timer, aktuelle Seite) bleibt unberuehrt, weil `ExerciseCard`
/// waehrenddessen einfach weiter gemountet bleibt, nur ueberdeckt vom Sheet.
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseGifSheet: View {
    let exerciseName: String
    let displayName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)
                // Feste, von aussen vorgegebene Flaeche statt einer von der
                // Bildgroesse abgeleiteten — `contentMode: .fit` (statt des
                // Thumbnail-Defaults `.fill`) zeigt das GANZE GIF ohne
                // Beschnitt; der weisse Hintergrund der Original-Assets
                // bleibt dabei auf genau diese Flaeche begrenzt statt in den
                // Rest des Sheets auszulaufen.
                ExerciseGifView(
                    exerciseName: exerciseName,
                    displayName: displayName,
                    animated: true,
                    cornerRadius: Deltiq.Radius.card,
                    contentMode: .fit
                )
                .frame(width: 260, height: 260)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous))
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle(Text(displayName))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.close", bundle: .module)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Exercise GIF Sheet") {
    ExerciseGifSheet(exerciseName: "Bankdrücken", displayName: "Bankdrücken")
}
#endif
#endif
