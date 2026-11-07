import Foundation

/// Plan-Generierungs-Eingabe fuer den Lauf-Anteil eines Nutzers. Eigener kleiner
/// Typ statt direkt `UserBodyProfile`: die Plan-Logik sieht nur die lauf-relevanten
/// Werte und bleibt ohne SwiftData testbar. Der Aufrufer baut ihn aus dem Profil;
/// Optionals sind nil, wenn der Nutzer die Angabe nicht gemacht hat.
public struct CardioRunProfile: Sendable, Hashable, Codable {
    public let goal: CardioGoal
    public let current5kReferenceSeconds: Int?
    public let weeklyBaseVolumeKm: Double?

    public init(goal: CardioGoal, current5kReferenceSeconds: Int?, weeklyBaseVolumeKm: Double?) {
        self.goal = goal
        self.current5kReferenceSeconds = current5kReferenceSeconds
        self.weeklyBaseVolumeKm = weeklyBaseVolumeKm
    }
}
