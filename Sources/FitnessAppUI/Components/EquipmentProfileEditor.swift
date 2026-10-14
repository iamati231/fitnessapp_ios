#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

/// Smart-Onboarding-Epic Phase 3 (PLAN_EQUIPMENT_MATCHING_AUDIT.md): EINZIGE
/// UI-Implementierung der neuen, dreiwertigen Equipment-Erfassung — genutzt
/// sowohl vom Onboarding-Schritt als auch vom Profil-Editor (keine zweite,
/// unabhaengig gepflegte Equipment-Datenquelle). Reine Editier-Flaeche fuer
/// einen gebundenen `UserEquipmentProfile`-Wert: die "vollstaendige
/// Bestaetigung" (vor der ein nicht ausgewaehltes Item `.unknown` bleibt,
/// siehe `UserEquipmentProfile.confirmRemainingAsUnavailable`) ist bewusst
/// NICHT Teil dieser View — das ist eine Navigations-Entscheidung des
/// jeweiligen Einbettungs-Kontexts (Onboarding-Wizard-"Weiter" bzw. der
/// Profil-Editor-Sheet-Toolbar-Button "Fertig"), nicht der Dateneingabe
/// selbst.
///
/// "Nur Koerpergewicht" dagegen IST Teil dieser View: fachlich gehoert die
/// Aktion zur Eingabe (verwirft eine begonnene Teil-Auswahl und markiert
/// alles explizit als nicht verfuegbar), nicht zur Navigation — identisch
/// in beiden Kontexten nutzbar.
@available(iOS 17.0, macOS 14.0, *)
struct EquipmentProfileEditor: View {
    @Binding var equipmentProfile: UserEquipmentProfile

    private static let weightItems: [EquipmentItem] = [.dumbbell, .kettlebell, .barbell, .resistanceBand]
    private static let accessoryItems: [EquipmentItem] = [
        .pullUpBar, .flatBench, .adjustableBench, .rack, .cableStation, .machineStation
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            bodyweightOnlyButton

            Text("equipmentEditor.section.weights", bundle: .module)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(spacing: 10) {
                ForEach(Self.weightItems, id: \.self) { itemRow($0) }
            }

            Text("equipmentEditor.section.accessories", bundle: .module)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(spacing: 10) {
                ForEach(Self.accessoryItems, id: \.self) { itemRow($0) }
            }

            Text("equipmentEditor.footer", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - "Nur Körpergewicht"

    /// Zeigt den Button als aktiv, wenn JEDES Item bereits explizit
    /// `.unavailable` ist — niemals schon dann, wenn ein unberuehrtes Profil
    /// einfach ueberall `.unknown` (den Default) liefert.
    private var isBodyweightOnly: Bool {
        EquipmentItem.allCases.allSatisfy { equipmentProfile.availability(for: $0) == .unavailable }
    }

    private var bodyweightOnlyButton: some View {
        Button {
            var fresh = UserEquipmentProfile()
            fresh.confirmRemainingAsUnavailable()
            equipmentProfile = fresh
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "figure.walk")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isBodyweightOnly ? Color.deltiqOrange : .secondary)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("equipmentEditor.bodyweightOnly.title", bundle: .module)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("equipmentEditor.bodyweightOnly.subtitle", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isBodyweightOnly ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isBodyweightOnly ? Color.deltiqOrange : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isBodyweightOnly ? Color.deltiqOrange.opacity(0.08) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isBodyweightOnly ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                            lineWidth: isBodyweightOnly ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Einzel-Item-Zeile

    @ViewBuilder
    private func itemRow(_ item: EquipmentItem) -> some View {
        let isSelected = equipmentProfile.availability(for: item) == .available
        VStack(alignment: .leading, spacing: 8) {
            Button {
                toggle(item)
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: item.iconName)
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
                        .frame(width: 32, height: 32)
                    Text(item.localizedName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.deltiqOrange.opacity(0.08) : Color.secondary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.25),
                                lineWidth: isSelected ? 1.5 : 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Stueckzahl nur anbieten, wenn relevant UND ausgewaehlt. Kein
            // Chip ist vorausgewaehlt — ein nie angetippter Chip bedeutet
            // "Anzahl unbekannt" (`UserEquipmentProfile.count(for:)` liefert
            // dann `nil`), nie "0" oder "1" per Default.
            if isSelected, item.supportsCount {
                countPicker(for: item)
                    .padding(.leading, 46)
            }
        }
    }

    /// Entfernt den Eintrag komplett statt `.unavailable` zu schreiben —
    /// vor der vollstaendigen Bestaetigung bedeutet ein erneutes Abwaehlen
    /// "wieder unbekannt", nie "jetzt explizit nicht vorhanden" (das macht
    /// ausschliesslich die Bestaetigung selbst, siehe Typ-Dokumentation).
    private func toggle(_ item: EquipmentItem) {
        if equipmentProfile.availability(for: item) == .available {
            equipmentProfile.availability.removeValue(forKey: item)
            equipmentProfile.counts.removeValue(forKey: item)
        } else {
            equipmentProfile.availability[item] = .available
        }
    }

    // MARK: - Stückzahl

    private func countPicker(for item: EquipmentItem) -> some View {
        HStack(spacing: 10) {
            Text("equipmentEditor.count.label", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
            countChip(1, for: item)
            countChip(2, for: item)
        }
    }

    private func countChip(_ value: Int, for item: EquipmentItem) -> some View {
        let isSelected = equipmentProfile.count(for: item) == value
        return Button {
            equipmentProfile.counts[item] = value
        } label: {
            Text(value == 1 ? "equipmentEditor.count.one" : "equipmentEditor.count.twoOrMore", bundle: .module)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.deltiqOrange.opacity(0.15) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.deltiqOrange : Color.secondary.opacity(0.3),
                                     lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
#endif
