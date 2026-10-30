#if canImport(SwiftData)
import Foundation
import SwiftData

/// Persistierter Mahlzeitenplan für einen Tag.
/// Manuell angepasste Pläne (`isManuallyAdjusted == true`) dürfen vom Generator
/// nicht überschrieben werden — `fetchOrCreate` und `upsertGenerated` durchsetzen das.
@Model
public final class DailyMealPlan {
    /// UTC-Mitternacht des Tages. Kein Uniqueness-Constraint (SwiftData hat keinen) —
    /// `fetchOrCreate` stellt sicher, dass pro Tag nur ein Plan gespeichert wird.
    public var date: Date

    @Relationship(deleteRule: .cascade, inverse: \PlannedMealAssignment.plan)
    public var assignments: [PlannedMealAssignment] = []

    /// Generatorwarnung bei unzureichender Rezeptauswahl. Nil = Plan ohne Einschränkung.
    public var generatorWarning: String?

    /// `true` wenn der Nutzer den Plan manuell angepasst hat.
    /// Generierte Pläne starten mit `false`. Beim Speichern einer manuellen Änderung
    /// muss der Caller dieses Flag setzen. `upsertGenerated` überschreibt solche Pläne nie.
    public var isManuallyAdjusted: Bool = false

    public init(date: Date, generatorWarning: String? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.generatorWarning = generatorWarning
    }

    /// Holt einen vorhandenen Plan für `date` oder legt einen neuen an.
    /// Normalisiert auf Tagesbeginn (startOfDay) — verhindert Duplikate durch
    /// unterschiedliche Uhrzeiten desselben Tages.
    @discardableResult
    public static func fetchOrCreate(
        for date: Date,
        in context: ModelContext
    ) throws -> DailyMealPlan {
        let start = Calendar.current.startOfDay(for: date)
        var descriptor = FetchDescriptor<DailyMealPlan>(
            predicate: #Predicate { $0.date == start }
        )
        descriptor.fetchLimit = 1
        let existing = try context.fetch(descriptor)
        if let plan = existing.first { return plan }
        let plan = DailyMealPlan(date: start)
        context.insert(plan)
        return plan
    }

    /// Speichert einen generierten Plan — überschreibt jedoch NIE einen manuell
    /// angepassten Plan. Gibt `true` zurück wenn der Plan tatsächlich aktualisiert wurde.
    @discardableResult
    public static func upsertGenerated(
        date: Date,
        assignments newAssignments: [PlannedMealAssignment],
        warning: String?,
        in context: ModelContext
    ) throws -> Bool {
        let plan = try fetchOrCreate(for: date, in: context)
        guard !plan.isManuallyAdjusted else { return false }
        plan.assignments.forEach { context.delete($0) }
        plan.assignments = newAssignments
        plan.generatorWarning = warning
        return true
    }
}
#endif
