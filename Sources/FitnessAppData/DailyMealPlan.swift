#if canImport(SwiftData)
import Foundation
import SwiftData

/// Persistierter Mahlzeitenplan für einen Tag.
/// Manuell gespeicherte oder angepasste Pläne werden vom Generator nicht überschrieben —
/// Caller-Verantwortung: vor dem Speichern prüfen, ob für `date` bereits ein Plan existiert.
@Model
public final class DailyMealPlan {
    /// UTC-Mitternacht des Tages. Kein Uniqueness-Constraint (SwiftData hat keinen) —
    /// Caller stellt sicher, dass pro Tag nur ein Plan gespeichert wird.
    public var date: Date

    @Relationship(deleteRule: .cascade, inverse: \PlannedMealAssignment.plan)
    public var assignments: [PlannedMealAssignment] = []

    /// Generatorwarnung bei unzureichender Rezeptauswahl. Nil = Plan ohne Einschränkung.
    public var generatorWarning: String?

    public init(date: Date, generatorWarning: String? = nil) {
        self.date = date
        self.generatorWarning = generatorWarning
    }
}
#endif
