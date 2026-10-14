#if canImport(SwiftUI)
import SwiftUI
import FitnessAppCore

// MARK: - Geteilte Zeilen-Primitiven (file-private)
//
// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
// §5): als freie Funktionen/Typen statt Methoden auf `EquipmentProfileEditor`,
// damit `NoEquipmentQuickEquipmentPicker` (Kein-Equipment-Kurzfrage, weiter
// unten in dieser Datei) denselben visuellen Stil ohne Duplikation
// wiederverwendet — EINE Datei bleibt die einzige UI-Implementierung fuer
// Equipment-Zeilen, auch wenn es jetzt zwei Views sind.

private protocol ChoiceOption {
    var titleKey: String { get }
    var iconName: String { get }
}

/// PLAN_LOCATION_EQUIPMENT_ONBOARDING.md §5: mappt auf die ZWEI
/// unabhaengigen `EquipmentItem`-Faelle, nicht auf ein neues Modell-Feld.
private enum BenchChoice: CaseIterable, ChoiceOption {
    case none, flat, adjustable, unknown

    var titleKey: String {
        switch self {
        case .none:       return "equipmentEditor.bench.none"
        case .flat:       return "equipmentEditor.bench.flat"
        case .adjustable: return "equipmentEditor.bench.adjustable"
        case .unknown:    return "equipmentEditor.bench.unknown"
        }
    }

    var iconName: String {
        switch self {
        case .none:       return "xmark.circle"
        case .flat:       return "rectangle"
        case .adjustable: return "slider.horizontal.3"
        case .unknown:    return "questionmark.circle"
        }
    }

    /// Liest den aktuellen Zustand aus den zwei Items zurueck. Sollten beide
    /// (z.B. aus einem alten, vor Phase 6 angelegten Profil) `.available`
    /// sein, gewinnt "Verstellbare Bank" — sie deckt die flache Nutzung mit
    /// ab (bestehende Core-Konvention), ist also die praezisere Aussage.
    static func current(in profile: UserEquipmentProfile) -> BenchChoice {
        let flat = profile.availability(for: .flatBench)
        let adjustable = profile.availability(for: .adjustableBench)
        if adjustable == .available { return .adjustable }
        if flat == .available { return .flat }
        if flat == .unknown && adjustable == .unknown { return .unknown }
        return .none
    }

    /// "Verstellbare Bank" setzt NUR `adjustableBench` — `flatBench` bleibt
    /// `.unavailable`, keine zusaetzliche, unbelegte Behauptung. Die
    /// bestehende `.any([.flatBench, .adjustableBench])`-Konvention in
    /// `ExerciseLibraryData` deckt Flachbank-Anforderungen darueber bereits
    /// ab (Vorgabe wörtlich: "die vorhandene Core-Semantik nutzen").
    func apply(to profile: inout UserEquipmentProfile) {
        switch self {
        case .none:
            profile.availability[.flatBench] = .unavailable
            profile.availability[.adjustableBench] = .unavailable
        case .flat:
            profile.availability[.flatBench] = .available
            profile.availability[.adjustableBench] = .unavailable
        case .adjustable:
            profile.availability[.flatBench] = .unavailable
            profile.availability[.adjustableBench] = .available
        case .unknown:
            profile.availability.removeValue(forKey: .flatBench)
            profile.availability.removeValue(forKey: .adjustableBench)
        }
    }
}

/// Einzelauswahl Ja/Nein/Weiß-ich-nicht fuer ein einzelnes `EquipmentItem`
/// (Klimmzugstange in Abschnitt C, optional auch in der Kein-Equipment-
/// Kurzfrage).
private enum TriStateChoice: CaseIterable, ChoiceOption {
    case yes, no, unknown

    var titleKey: String {
        switch self {
        case .yes:     return "equipmentEditor.pullUpBar.yes"
        case .no:      return "equipmentEditor.pullUpBar.no"
        case .unknown: return "equipmentEditor.pullUpBar.unknown"
        }
    }

    var iconName: String {
        switch self {
        case .yes:     return "checkmark.circle"
        case .no:      return "xmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    static func current(for item: EquipmentItem, in profile: UserEquipmentProfile) -> TriStateChoice {
        switch profile.availability(for: item) {
        case .available:   return .yes
        case .unavailable: return .no
        case .unknown:     return .unknown
        }
    }

    func apply(to item: EquipmentItem, in profile: inout UserEquipmentProfile) {
        switch self {
        case .yes:     profile.availability[item] = .available
        case .no:      profile.availability[item] = .unavailable
        case .unknown: profile.availability.removeValue(forKey: item)
        }
    }
}

/// Gemeinsames visuelles Grundelement fuer jede Zeile (Mehrfachauswahl-
/// Toggle UND Einzelauswahl-Option) — ein optischer Stil fuer die gesamte
/// Equipment-UI, unabhaengig von der Auswahl-Semantik dahinter.
@available(iOS 17.0, macOS 14.0, *)
private func selectableRow(icon: String, title: Text, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
                .frame(width: 32, height: 32)
            title
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
}

@available(iOS 17.0, macOS 14.0, *)
private func choiceRow<T: ChoiceOption>(_ option: T, isSelected: Bool, onSelect: @escaping (T) -> Void) -> some View {
    selectableRow(icon: option.iconName, title: Text(option.titleKey, bundle: .module), isSelected: isSelected) {
        onSelect(option)
    }
}

/// Mehrfachauswahl-Zeile fuer ein einzelnes `EquipmentItem` inkl. optionaler
/// Stueckzahl — gemeinsam genutzt vom vollen Editor (Gewichte/Weitere
/// Ausstattung) UND der Kein-Equipment-Kurzfrage.
@available(iOS 17.0, macOS 14.0, *)
private func equipmentItemRow(_ item: EquipmentItem, profile: Binding<UserEquipmentProfile>) -> some View {
    let isSelected = profile.wrappedValue.availability(for: item) == .available
    return VStack(alignment: .leading, spacing: 8) {
        selectableRow(icon: item.iconName, title: Text(item.localizedName), isSelected: isSelected) {
            toggleItem(item, profile: profile)
        }
        // Stueckzahl nur anbieten, wenn relevant UND ausgewaehlt. Kein Chip
        // ist vorausgewaehlt — ein nie angetippter Chip bedeutet "Anzahl
        // unbekannt" (`UserEquipmentProfile.count(for:)` liefert dann
        // `nil`), nie "0" oder "1" per Default.
        if isSelected, item.supportsCount {
            countPicker(for: item, profile: profile)
                .padding(.leading, 46)
        }
    }
}

/// Entfernt den Eintrag komplett statt `.unavailable` zu schreiben — vor der
/// vollstaendigen Bestaetigung bedeutet ein erneutes Abwaehlen "wieder
/// unbekannt", nie "jetzt explizit nicht vorhanden" (das macht
/// ausschliesslich die Bestaetigung selbst, siehe Typ-Dokumentation).
private func toggleItem(_ item: EquipmentItem, profile: Binding<UserEquipmentProfile>) {
    if profile.wrappedValue.availability(for: item) == .available {
        profile.wrappedValue.availability.removeValue(forKey: item)
        profile.wrappedValue.counts.removeValue(forKey: item)
    } else {
        profile.wrappedValue.availability[item] = .available
    }
}

@available(iOS 17.0, macOS 14.0, *)
private func countPicker(for item: EquipmentItem, profile: Binding<UserEquipmentProfile>) -> some View {
    HStack(spacing: 10) {
        Text("equipmentEditor.count.label", bundle: .module)
            .font(.footnote)
            .foregroundStyle(.secondary)
        countChip(1, for: item, profile: profile)
        countChip(2, for: item, profile: profile)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private func countChip(_ value: Int, for item: EquipmentItem, profile: Binding<UserEquipmentProfile>) -> some View {
    let isSelected = profile.wrappedValue.count(for: item) == value
    return Button {
        profile.wrappedValue.counts[item] = value
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

/// Zeigt den Button als aktiv, wenn JEDES Item bereits explizit
/// `.unavailable` ist — niemals schon dann, wenn ein unberuehrtes Profil
/// einfach ueberall `.unknown` (den Default) liefert.
private func isBodyweightOnly(_ profile: UserEquipmentProfile) -> Bool {
    EquipmentItem.allCases.allSatisfy { profile.availability(for: $0) == .unavailable }
}

@available(iOS 17.0, macOS 14.0, *)
private func bodyweightOnlyButton(titleKey: String, subtitleKey: String, profile: Binding<UserEquipmentProfile>) -> some View {
    let isSelected = isBodyweightOnly(profile.wrappedValue)
    return Button {
        var fresh = UserEquipmentProfile()
        fresh.confirmRemainingAsUnavailable()
        profile.wrappedValue = fresh
    } label: {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "figure.walk")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.deltiqOrange : .secondary)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey, bundle: .module)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitleKey, bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
}

// MARK: - Voller Editor (Home-Gym-Step, Gym-"Ausstattung anpassen"-Sheet, Profil-Editor)

/// Smart-Onboarding-Epic Phase 3 (PLAN_EQUIPMENT_MATCHING_AUDIT.md): EINZIGE
/// UI-Implementierung der neuen, dreiwertigen Equipment-Erfassung — genutzt
/// vom Home-Gym-Onboarding-Schritt, dem optionalen Gym-"Ausstattung
/// anpassen"-Sheet UND dem Profil-Editor (keine zweite, unabhaengig
/// gepflegte Equipment-Datenquelle). Reine Editier-Flaeche fuer einen
/// gebundenen `UserEquipmentProfile`-Wert: die "vollstaendige Bestaetigung"
/// (vor der ein nicht ausgewaehltes Item `.unknown` bleibt, siehe
/// `UserEquipmentProfile.confirmRemainingAsUnavailable`) ist bewusst NICHT
/// Teil dieser View — das ist eine Navigations-Entscheidung des jeweiligen
/// Einbettungs-Kontexts, nicht der Dateneingabe selbst.
///
/// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
/// §5): restrukturiert in vier Abschnitte (Gewichte / Bank / Klimmzugstange /
/// Weitere Ausstattung). Bank und Klimmzugstange sind jetzt EINZELAUSWAHL
/// statt unabhaengiger Toggles — ein User hat typischerweise genau eine Bank
/// oder gar keine, nie "Flachbank UND verstellbare Bank" als unabhaengige,
/// gleichwertige Aussagen. Das Datenmodell (`UserEquipmentProfile`/
/// `EquipmentItem`) bleibt dabei vollstaendig unveraendert — reine
/// View-Restrukturierung.
@available(iOS 17.0, macOS 14.0, *)
struct EquipmentProfileEditor: View {
    @Binding var equipmentProfile: UserEquipmentProfile

    private static let weightItems: [EquipmentItem] = [.dumbbell, .kettlebell, .barbell, .resistanceBand]
    /// Abschnitt D ("Weitere Ausstattung"). Bewusst NUR Items mit echter
    /// Core-Faehigkeit (PLAN_LOCATION_EQUIPMENT_ONBOARDING.md §6) — Dip-
    /// Barren/Ringe-Schlingentrainer existieren nicht als `EquipmentItem` und
    /// werden deshalb NICHT angeboten (kein Toggle ohne Matching-Wirkung).
    private static let furtherItems: [EquipmentItem] = [.rack, .cableStation, .machineStation]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            bodyweightOnlyButton(
                titleKey: "equipmentEditor.bodyweightOnly.title",
                subtitleKey: "equipmentEditor.bodyweightOnly.subtitle",
                profile: $equipmentProfile
            )

            sectionHeader("equipmentEditor.section.weights")
            VStack(spacing: 10) {
                ForEach(Self.weightItems, id: \.self) { equipmentItemRow($0, profile: $equipmentProfile) }
            }

            sectionHeader("equipmentEditor.section.bench")
            VStack(spacing: 10) {
                ForEach(BenchChoice.allCases, id: \.titleKey) { choice in
                    choiceRow(choice, isSelected: choice == BenchChoice.current(in: equipmentProfile)) { selected in
                        selected.apply(to: &equipmentProfile)
                    }
                }
            }

            sectionHeader("equipmentEditor.section.pullUpBar")
            VStack(spacing: 10) {
                ForEach(TriStateChoice.allCases, id: \.titleKey) { choice in
                    choiceRow(choice, isSelected: choice == TriStateChoice.current(for: .pullUpBar, in: equipmentProfile)) { selected in
                        selected.apply(to: .pullUpBar, in: &equipmentProfile)
                    }
                }
            }

            DisclosureGroup {
                VStack(spacing: 10) {
                    ForEach(Self.furtherItems, id: \.self) { equipmentItemRow($0, profile: $equipmentProfile) }
                }
                .padding(.top, 10)
            } label: {
                Text("equipmentEditor.section.further", bundle: .module)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Text("equipmentEditor.footer", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private func sectionHeader(_ key: String) -> some View {
        Text(key, bundle: .module)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - Kein-Equipment-Kurzfrage

/// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
/// §1): "Hast du kleine Trainingshilfen?" — bewusst NUR die drei tragbaren
/// Items (Kurzhanteln/Kettlebell/Widerstandsband, KEINE Langhantel — passt
/// nicht zu "kein Equipment"), plus "Nur Koerpergewicht" (Dateneingabe, wie
/// im vollen Editor) und ein optionaler, eingeklappter Bereich fuer die
/// seltenen Faelle einer vorhandenen Klimmzugstange/sonstigen Ausstattung.
/// "Später entscheiden" bleibt wie beim Home-Gym-Editor eine
/// Navigations-Entscheidung des einbettenden Schritts, nicht dieser View.
@available(iOS 17.0, macOS 14.0, *)
struct NoEquipmentQuickEquipmentPicker: View {
    @Binding var equipmentProfile: UserEquipmentProfile

    private static let helperItems: [EquipmentItem] = [.dumbbell, .kettlebell, .resistanceBand]
    private static let furtherItems: [EquipmentItem] = [.rack, .cableStation, .machineStation]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 10) {
                ForEach(Self.helperItems, id: \.self) { equipmentItemRow($0, profile: $equipmentProfile) }
            }

            bodyweightOnlyButton(
                titleKey: "equipmentEditor.bodyweightOnly.title",
                subtitleKey: "equipmentEditor.bodyweightOnly.subtitle",
                profile: $equipmentProfile
            )

            DisclosureGroup {
                VStack(spacing: 10) {
                    ForEach(TriStateChoice.allCases, id: \.titleKey) { choice in
                        choiceRow(choice, isSelected: choice == TriStateChoice.current(for: .pullUpBar, in: equipmentProfile)) { selected in
                            selected.apply(to: .pullUpBar, in: &equipmentProfile)
                        }
                    }
                    ForEach(Self.furtherItems, id: \.self) { equipmentItemRow($0, profile: $equipmentProfile) }
                }
                .padding(.top, 10)
            } label: {
                Text("onboarding.equipment.noEquipment.further", bundle: .module)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
    }
}
#endif
