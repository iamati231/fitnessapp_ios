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
///
/// Nachbesserung (Review nach dritter Korrekturrunde, Punkt 2): `committedPlanID` wird jetzt
/// auch bei einem GANZ NORMALEN Erfolg gesetzt, nicht nur bei `createdButRebindFailed`. Vorher
/// galt die Duplikat-Sicherheit nur fuer den Rebind-Fehlerfall — ein wiederholter `attempt(...)`-
/// Aufruf NACH einem bereits erfolgreichen, unproblematischen Durchlauf (z.B. durch einen nicht
/// korrekt gesperrten Doppel-Tap) haette weiterhin ein zweites Mal `create()` aufgerufen und
/// einen echten zweiten Plan angelegt. Die Garantie gilt jetzt uneingeschraenkt: SOBALD diese
/// Instanz irgendeinen Plan erfolgreich erzeugt hat, ruft sie `create()` nie wieder auf - jeder
/// weitere Aufruf loest nur noch denselben Plan auf.
///
/// Nachbesserung (Review nach dritter Korrekturrunde, Punkt 3): `completion` (optional) ist ein
/// einmalig auszufuehrender Abschluss (z.B. ein Fachlich-Status/Fingerprint-Abschluss beim
/// Cardio-Coaching-Handoff), der von der eigentlichen Planerstellung GETRENNT, aber an denselben
/// Erfolg gebunden ist. Wird NUR beim allerersten Mal, wenn diese Instanz einen Plan tatsaechlich
/// auflösen kann (egal ob sofort oder erst bei einem spaeteren `attempt(...)`/
/// `resumeIfCommitted(...)`-Aufruf), ausgefuehrt — und zwar GENAU der `completion`-Closure, die
/// beim ALLERERSTEN Aufruf uebergeben wurde (spaetere Aufrufe koennen eine neue Closure
/// uebergeben, die dann bewusst IGNORIERT wird). Das stellt sicher, dass der Abschluss die
/// BESTAETIGTEN ANGABEN DES URSPRUENGLICHEN VORGANGS verwendet, nicht womoeglich abweichende
/// Werte aus einer spaeter neu berechneten Aufrufer-Closure.
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
    /// Gilt gleichermassen nach einem ganz normalen Erfolg wie nach `createdButRebindFailed`.
    public private(set) var committedPlanID: PersistentIdentifier?

    /// Der einmalig auszufuehrende Abschluss aus dem ALLERERSTEN `attempt(...)`-Aufruf, der
    /// einen Plan committed hat - siehe Typ-Doku Punkt 3. `nil` nach erfolgreicher Ausfuehrung
    /// (laeuft exakt einmal).
    private var pendingCompletion: (() -> Void)?

    public init() {}

    /// Liefert `nil`, solange diese Instanz noch NICHTS committed hat - der Aufrufer muss dann
    /// den vollen `attempt(in:create:completion:)` aufrufen. Ist bereits etwas committed, wird
    /// AUSSCHLIESSLICH aufgeloest (nie `create()` aufgerufen) und bei Erfolg der gespeicherte
    /// `pendingCompletion` nachgeholt, falls er noch nicht gelaufen ist.
    @discardableResult
    public func resumeIfCommitted(in context: ModelContext) -> Outcome? {
        guard let committedPlanID else { return nil }
        if let plan = PlanGeneratorInstantiator.resolveCreatedPlan(id: committedPlanID, in: context) {
            runPendingCompletionIfNeeded()
            return .success(plan)
        }
        return .committedButUnresolved
    }

    /// Führt `create()` aus, AUSSER diese Instanz kennt bereits ein `committedPlanID` — dann
    /// wird `create()` ÜBERHAUPT NICHT aufgerufen, nur aufgelöst (`resumeIfCommitted`). Das ist
    /// die strukturelle Garantie gegen einen zweiten, doppelten Plan: der Aufruf von `create()`
    /// ist nach dem ersten Commit für diese Instanz technisch unerreichbar, nicht nur per
    /// Konvention vermieden.
    ///
    /// `completion` (optional): siehe Typ-Doku Punkt 3 - nur relevant fuer Aufrufer, die einen
    /// vom eigentlichen Plan GETRENNTEN, aber an denselben Erfolg gebundenen Abschluss brauchen.
    @discardableResult
    public func attempt(
        in context: ModelContext,
        create: () throws -> TrainingPlan?,
        completion: (() -> Void)? = nil
    ) -> Outcome {
        if let resumed = resumeIfCommitted(in: context) {
            return resumed
        }
        do {
            guard let plan = try create() else {
                return .nothingToCreate
            }
            committedPlanID = plan.persistentModelID
            if pendingCompletion == nil { pendingCompletion = completion }
            runPendingCompletionIfNeeded()
            return .success(plan)
        } catch PlanGeneratorInstantiator.PlanCreationError.createdButRebindFailed(let planID) {
            committedPlanID = planID
            if pendingCompletion == nil { pendingCompletion = completion }
            return .committedButUnresolved
        } catch {
            return .failedBeforeCommit
        }
    }

    private func runPendingCompletionIfNeeded() {
        guard let pendingCompletion else { return }
        pendingCompletion()
        self.pendingCompletion = nil
    }
}
#endif
