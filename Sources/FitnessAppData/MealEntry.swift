#if canImport(SwiftData)
import Foundation
import SwiftData
import FitnessAppCore

/// Eine protokollierte Mahlzeit (z.B. "Fruehstueck am 2026-10-21"). Mehrere
/// `MealEntry`s mit demselben `mealType` am selben Tag sind ausdruecklich
/// erlaubt — keine Uniqueness-Constraint.
@Model
public final class MealEntry {
    public var date: Date
    public var mealTypeRaw: String

    /// Typisierter Zugriff auf `mealTypeRaw`.
    public var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    /// Cascade-Attribut nur auf der Eltern-Seite (identisch zu
    /// `TrainingPlan.days`/`TrainingDay.exercises`) — `MealItem.meal` traegt
    /// nur ein plaines Backref.
    @Relationship(deleteRule: .cascade, inverse: \MealItem.meal)
    public var items: [MealItem] = []

    public init(date: Date = Date(), mealType: MealType) {
        self.date = date
        self.mealTypeRaw = mealType.rawValue
    }
}
#endif
