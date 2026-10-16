#if canImport(SwiftData)
import Foundation
import SwiftData

/// Nachbesserung (Task #197, dritte Korrekturrunde): schliesst die verbleibende
/// Duplikat-Lücke aus `PlanCreationError.createdButRebindFailed`. `createPlan`s eigener
/// interner Ein-Retry (siehe dortige Doku) deckt nur den SOFORTIGEN Fall ab — scheitert auch
/// DIESER, und der Nutzer tippt die Übernehmen-Aktion danach erneut an, darf das NIEMALS
/// `build`/`createPlan` ein zweites Mal aufrufen, weil der Plan bereits persistiert EXISTIERT.
///
/// `PlanCreationOperation` ist der Zustand, der genau das durchsetzt: sobald einmal ein
/// `committedPlanID` bekannt ist, ruft `attempt(...)` das übergebene `create()` NIE WIEDER auf —
/// jeder weitere Aufruf löst ausschliesslich über `PlanGeneratorInstantiator.resolveCreatedPlan`
/// auf. Diese Festlegung ist PERMANENT für die Lebensdauer einer Instanz; es gibt bewusst keine
/// Reset-Funktion — ein wirklich neuer Versuch braucht eine neue Instanz (z.B. ein frisch
/// geöffnetes "Plan anpassen"-Sheet), nie denselben, bereits committeten Vorgang.
///
/// Bewusst EIN eigenes Objekt pro Button/Flow (als `@State` an der jeweiligen View gehalten),
/// kein globaler Singleton — jede Übernahme-Aktion (`PlanBuilderView`s eigener Pfad,
/// `PlansListView`/`ProfileEditorView`s direkter Button UND deren jeweiliges "Plan anpassen"-
/// Sheet) ist ein eigener, unabhängiger Vorgang mit eigenem Zustand.
///
/// Reine Zustandsmaschine ohne eigene Lokalisierung: `Outcome` liefert einen TYPISIERTEN
/// Zustand, keinen fertigen Text — `FitnessAppData` kennt `FitnessAppUI`s Lokalisierungs-Bundle
/// nicht. Der Aufrufer leitet die angezeigte Nachricht aus `Outcome` ab, nicht umgekehrt.
@MainActor
public final class PlanCreationOperation {

    public enum Outcome {
        case success(TrainingPlan)
        /// `create()` lieferte `nil` (z.B. leeres Generator-Ergebnis) — kein Fehler, bestehende
        /// Konvention alller Aufrufer: kein Alert, nur stiller Reset des UI-Zustands.
        case nothingToCreate
        /// Nichts wurde persistiert — ein erneuter Versuch darf die volle Operation
        /// (`create()`) wiederholen.
        case failedBeforeCommit
        /// Der Plan WURDE persistiert, ist aber auch nach `createPlan`s eigenem internen
        /// Retry nicht auflösbar. Diese Instanz ruft `create()` ab jetzt für immer nicht mehr
        /// auf — jeder weitere `attempt(...)`-Aufruf versucht ausschliesslich die Auflösung.
        case committedButUnresolved
    }

    /// Nicht-`nil` bedeutet: fuer diese Instanz gilt unwiderruflich, dass unter dieser ID
    /// bereits ein Plan angelegt wurde — `attempt(...)` ruft `create()` dann nie wieder auf.
    public private(set) var committedPlanID: PersistentIdentifier?

    public init() {}

    /// Führt `create()` aus, AUSSER diese Instanz kennt bereits ein `committedPlanID` — dann
    /// wird `create()` ÜBERHAUPT NICHT aufgerufen, nur aufgelöst. Das ist die strukturelle
    /// Garantie gegen einen zweiten, doppelten Plan: der Aufruf von `create()` ist nach dem
    /// ersten Commit für diese Instanz technisch unerreichbar, nicht nur per Konvention
    /// vermieden.
    @discardableResult
    public func attempt(in context: ModelContext, create: () throws -> TrainingPlan?) -> Outcome {
        if let committedPlanID {
            if let plan = PlanGeneratorInstantiator.resolveCreatedPlan(id: committedPlanID, in: context) {
                return .success(plan)
            }
            return .committedButUnresolved
        }
        do {
            guard let plan = try create() else {
                return .nothingToCreate
            }
            return .success(plan)
        } catch PlanGeneratorInstantiator.PlanCreationError.createdButRebindFailed(let planID) {
            committedPlanID = planID
            return .committedButUnresolved
        } catch {
            return .failedBeforeCommit
        }
    }
}
#endif
