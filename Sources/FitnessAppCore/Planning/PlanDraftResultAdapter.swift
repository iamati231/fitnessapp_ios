import Foundation

/// Planung-&-Trainingsbegleitung-Epic, P2.4-Nachbesserung: der tatsaechlich
/// verwendete Bruecken-Adapter zwischen `PlanDraft` (Entwurfs-Schicht) und
/// `PlanGenerator.Result` (Berechnung-Schicht/Uebergabe-Vertrag an
/// `onGenerated`/`PlanGeneratorInstantiator.createPlan`). Vorher war dieselbe
/// Transformation direkt - und nicht fuer sich testbar - in
/// `PlanBuilderView.currentResult` inline implementiert. Liegt hier in Core,
/// weil die gesamte Transformation ausschliesslich Core-Typen braucht
/// (`PlanDraft`, `DraftDayID`, `PlanLoadLevel`, `PlanGenerator.Result`) -
/// der vorherige Ort in einer SwiftUI-View war ein Zufall des State-Haltens,
/// keine echte Abhaengigkeit.
public enum PlanDraftResultAdapter {

    public enum AdapterError: Error, Equatable {
        /// Fuer einen Tag im Draft existiert keine `loadLevel`-Zuordnung.
        /// `loadLevel` ist eine ABGELEITETE, generatorspezifische Angabe
        /// (siehe `PlanGenerator.Result.GeneratedDay.loadLevel` - relativ zu
        /// ALLEN Tagen EINES Generierungslaufs berechnet, keine Eigenschaft
        /// eines einzelnen Tages fuer sich). Ein fehlender Eintrag bedeutet
        /// "fuer diesen Tag nicht bekannt/nicht bewertet" - NICHT "nimm
        /// `.medium` als Default". Ein stiller Default wuerde dem Nutzer eine
        /// Einordnung vortaeuschen, die es nicht gibt.
        case missingLoadLevel(dayID: DraftDayID)
    }

    /// Rekonstruiert ein `PlanGenerator.Result` aus dem AKTUELLEN Stand eines
    /// `PlanDraft`. Inhalt UND Reihenfolge kommen ausschliesslich aus
    /// `draft.resolvedDaySpecs` - jede `reorder`/`moveDay`/`replaceContent`-
    /// Aenderung spiegelt sich dadurch vollstaendig wider, es wird nichts vom
    /// urspruenglichen Generator-Output zwischengespeichert oder
    /// wiederverwendet. `nil`, wenn der Draft keine Tage (mehr) enthaelt -
    /// ein leeres Result ist fuer eine Uebernahme nicht sinnvoll (siehe
    /// Aufrufer).
    ///
    /// VERBINDLICH fuer P3 (hier NOCH NICHT umgesetzt, da heute keine UI
    /// einen Tagesinhalt tatsaechlich aendert - siehe
    /// docs/PLANUNG_BEGLEITUNG_AUDIT.md, P2.4-Nachbesserung): `loadLevel` ist
    /// relativ zu ALLEN Tagen EINES Generierungslaufs berechnet
    /// (`PlanGenerator.loadLevels(for:)`). Sobald P3 `replaceContent(of:with:)`
    /// tatsaechlich aufruft, wird die bisherige `loadLevels`-Zuordnung fuer
    /// die GESAMTE Woche stale - nicht nur fuer den geaenderten Tag, weil die
    /// relative Einstufung aller anderen Tage sich mit-aendern kann. P3 MUSS
    /// diesen Fall entweder vollstaendig neu berechnen (alle Ladestufen neu)
    /// oder die betroffenen Eintraege ausdruecklich aus `loadLevels`
    /// entfernen (dieser Adapter wirft dann `missingLoadLevel` statt zu
    /// raten) - niemals die alte, jetzt falsche Einstufung unveraendert
    /// weiterzeigen. Dieselbe Regel gilt fuer `explanationKey`: er
    /// beschreibt, WARUM der Generator eine bestimmte Auswahl getroffen hat -
    /// nach einer manuellen Aenderung trifft diese Begruendung nicht mehr zu
    /// und muss von P3 entfernt oder ersetzt werden, nicht unveraendert
    /// mitgefuehrt werden.
    public static func makeResult(
        from draft: PlanDraft,
        loadLevels: [DraftDayID: PlanLoadLevel],
        explanationKey: String?
    ) throws -> PlanGenerator.Result? {
        guard !draft.days.isEmpty else { return nil }
        let days = try zip(draft.days, draft.resolvedDaySpecs).map { draftDay, spec -> PlanGenerator.Result.GeneratedDay in
            guard let level = loadLevels[draftDay.id] else {
                throw AdapterError.missingLoadLevel(dayID: draftDay.id)
            }
            return PlanGenerator.Result.GeneratedDay(spec: spec, loadLevel: level)
        }
        return PlanGenerator.Result(days: days, explanationKey: explanationKey)
    }
}
