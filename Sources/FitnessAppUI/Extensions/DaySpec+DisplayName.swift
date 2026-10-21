#if canImport(SwiftUI)
import Foundation
import SwiftUI
import FitnessAppCore

/// DEL-115: Lokalisierter Display-Name fuer `DaySpec` (Tagesname innerhalb
/// eines `ProgramTemplate`).
///
/// **Vertrag:**
///   * Wenn `localizationKey` non-nil + non-empty ist (alle Shipped-Day-
///     Specs nach DEL-115, plus alle generierten Tage nach DEL-247), wird
///     der Catalog-Eintrag aufgeloest (siehe `resolveDayLocalizationKey`) →
///     multilinguale Anzeige.
///   * Sonst fällt es auf das rohe `name`-Feld zurueck. Das deckt:
///     - Custom-Tage in User-erstellten Plänen
///     - Day-Specs ohne Annotation (defensiv — sollte nach DEL-115 keinen
///       Library-Day-Spec mehr betreffen)
///
/// **Wo aufrufen:** Template-Picker-Day-Header in `TemplatePreviewView`,
/// `ProgramTemplatePickerView`, "Plan bauen"-Wizard-Vorschau in
/// `PlanBuilderView`. SwiftData-Side `TrainingDay`-Models nutzen ihre
/// eigene, analoge `displayName` (`TrainingDay+DisplayName.swift`) — beim
/// Adopt wird `localizationKey` mitpropagiert (DEL-123), `name` bleibt der
/// Snapshot-Fallback, ist aber danach frei editierbar.
extension DaySpec {
    public var displayName: String {
        if let key = localizationKey, !key.isEmpty {
            return resolveDayLocalizationKey(key)
        }
        return name
    }
}

/// DEL-247: gemeinsamer Resolver fuer `DaySpec.displayName` und
/// `TrainingDay.displayName`/`.localizedSystemName`. Liegt hier (statt in
/// der SwiftData-gated `TrainingDay+DisplayName.swift`), weil er nur
/// `canImport(SwiftUI)` braucht - die staerker eingeschraenkte Datei kann
/// jederzeit hierauf zugreifen, umgekehrt nicht.
///
/// Format: `"key1[·key2[&key3]][#rawSuffix]"`. `·` trennt bis zu zwei
/// Top-Level-Teile (z.B. Trainingsart · Fokus), `&` verbindet bis zu zwei
/// Kategorien INNERHALB eines Teils (z.B. "Push & Pull"), `#` haengt einen
/// rohen, NICHT lokalisierten Rest an (Ziffern-/Buchstaben-Suffix wie "2"
/// oder "A" - die brauchen in DE/EN/TR keine Uebersetzung). Jeder einzelne
/// Teil ist ein normaler Catalog-Key und wird wie bisher ueber
/// `String(localized:bundle:)` aufgeloest. Ein simpler Key ohne
/// `·`/`&`/`#` (alle bestehenden `plan.day.*`-Keys, `day.restDay.title`)
/// durchlaeuft dieselbe Logik unveraendert, da keiner dieser drei Trenner
/// je in einem echten Catalog-Key vorkommt (die sind ausschliesslich
/// `[a-zA-Z0-9_.]`) - reine Erweiterung, kein Sonderfall fuer "alte" Keys.
func resolveDayLocalizationKey(_ raw: String) -> String {
    let keyPart: Substring
    let rawSuffix: Substring?
    if let hashIndex = raw.firstIndex(of: "#") {
        keyPart = raw[raw.startIndex..<hashIndex]
        rawSuffix = raw[raw.index(after: hashIndex)...]
    } else {
        keyPart = raw[...]
        rawSuffix = nil
    }

    let resolvedTopParts = keyPart.split(separator: "·").map { topPart -> String in
        topPart.split(separator: "&")
            .map { String(localized: String.LocalizationValue(String($0)), bundle: .module) }
            .joined(separator: " & ")
    }
    var result = resolvedTopParts.joined(separator: " · ")
    if let rawSuffix, !rawSuffix.isEmpty {
        result += " \(rawSuffix)"
    }
    return result
}
#endif
