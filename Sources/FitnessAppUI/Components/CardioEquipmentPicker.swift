#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// DEL-155: Kompakter Menu-Picker fuer das Cardio-Equipment einer Uebung.
///
/// Funktioniert sowohl in einer `Form`-Section (ExerciseEditorView) als auch
/// in einer `List`-Section (WorkoutSummaryView History-Edit). Bindet direkt
/// an `Exercise.cardioEquipment` — die Aenderung persistiert via SwiftData-
/// Autosave und wird sofort im Verlauf sichtbar.
///
/// Kartenflaeche/Radius geprueft: dieser Picker zeichnet keine eigene
/// Flaeche (kein `.background`/`.clipShape` hier) - er sitzt als reine
/// Menu-Row im Caller-Grid, der Caller gibt via `.listRowBackground(...)`
/// die Deltiq-Karten-Flaeche vor (siehe ExerciseEditorViews
/// cardioTargetSection). Nichts zu tun.
@available(iOS 17.0, macOS 14.0, *)
struct CardioEquipmentPicker: View {
    @Binding var selection: CardioEquipment

    var body: some View {
        Picker(selection: $selection) {
            ForEach(CardioEquipment.allCases, id: \.self) { equipment in
                Label {
                    Text(equipment.localizedName)
                } icon: {
                    Image(systemName: equipment.iconName)
                }
                .tag(equipment)
            }
        } label: {
            Label {
                Text("cardioEquipment.fieldLabel", bundle: .module)
            } icon: {
                Image(systemName: selection.iconName)
                    .foregroundStyle(Color.deltiqOrange)
            }
        }
        .pickerStyle(.menu)
        // Tint auf primary, damit der Menu-Wert nicht im System-Blau,
        // sondern im neutralen Label-Stil rendert (matcht die uebrigen
        // Editor-Rows).
        .tint(.primary)
    }
}

/// DEL-155: Read-Only-Zeile fuer das gewaehlte Cardio-Equipment — im
/// Verlaufs-Replay (nicht im Edit-Mode) gerendert, damit der User die
/// gespeicherte Auswahl sieht. `.none` wird vom Caller ausgeblendet.
@available(iOS 17.0, macOS 14.0, *)
struct CardioEquipmentDisplayRow: View {
    let equipment: CardioEquipment

    var body: some View {
        Label {
            Text(equipment.localizedName)
        } icon: {
            Image(systemName: equipment.iconName)
                .foregroundStyle(Color.deltiqOrange)
        }
        .font(.callout)
        .foregroundStyle(Color.Deltiq.textSecondary)
    }
}
#endif
