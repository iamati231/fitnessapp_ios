#if canImport(SwiftData)
import Foundation
import SwiftData

/// DEL-084: Equipment-Tracker, primaer fuer Laufschuhe. Laufschuhe
/// verlieren ihre Daempfung nach ~600–800 km — die App buckhted Cardio-
/// Kilometer aus abgeschlossenen Sessions hier auf und warnt, wenn das
/// Maximum erreicht ist.
///
/// `type` ist offen fuer spaetere Erweiterungen (Rad, Schwimmflossen, ...);
/// aktuell pflegt das UI nur `.shoe` und `.bike` aktiv.
public enum GearType: String, Codable, CaseIterable, Sendable {
    case shoe
    case bike
}

@Model
public final class Gear {
    public var name: String
    public var type: GearType
    public var maxDistanceKm: Double
    public var currentDistanceKm: Double
    /// Nur ein "Default-Gear" je Type. UI-Picker prefilled das aktive Gear,
    /// wenn der User ein Cardio-Workout abschliesst.
    public var isActive: Bool
    /// Wann das Gear angelegt wurde — fuer Sortier-/Anzeigereihenfolge.
    public var createdAt: Date

    public init(
        name: String,
        type: GearType,
        maxDistanceKm: Double = 800,
        currentDistanceKm: Double = 0,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.type = type
        self.maxDistanceKm = maxDistanceKm
        self.currentDistanceKm = currentDistanceKm
        self.isActive = isActive
        self.createdAt = createdAt
    }

    /// P8-Fund: ohne diese explizite inverse Relationship wendet SwiftData
    /// den `.nullify`-Delete-Rule auf `WorkoutSession.gear` nicht zuverlässig
    /// an (siehe identischer Befund + Diagnose bei `TrainingDay.sessions`).
    /// Nirgends sonst im Code direkt gelesen; existiert ausschließlich,
    /// damit SwiftData die Nullifizierung korrekt ausführt.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.gear)
    public var sessions: [WorkoutSession] = []

    /// 0...1+ Anteil der `currentDistanceKm` an `maxDistanceKm`. UI rendert
    /// einen Progress-Bar; >= 1.0 = Warnstufe (rot).
    public var progress: Double {
        guard maxDistanceKm > 0 else { return 0 }
        return currentDistanceKm / maxDistanceKm
    }

    /// True wenn das Gear ausgetauscht werden sollte (>= max).
    public var needsReplacement: Bool {
        currentDistanceKm >= maxDistanceKm
    }
}
#endif
