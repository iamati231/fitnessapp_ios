import Foundation

/// Configurable Hero-Metric-Card-Type fuer das Dashboard. Persistiert in
/// `UserBodyProfile.heroMetricSlotsRaw` als String-Array — die Reihenfolge
/// des Arrays bestimmt die Render-Reihenfolge der drei Top-Cards, und
/// nicht-enthaltene Cases sind versteckt.
///
/// **Designziel:** das gleiche Pattern wie `DashboardWidgetType` (DEL-109),
/// aber fuer die Hero-Reihe oben auf dem Dashboard. User kann frei
/// entscheiden welche Body-Metriken er als prominente "wie-bin-ich-grade"-
/// Anker sehen will.
///
/// **Slot-Count:** 0-3 erlaubt. Length 0 = ganze Hero-Reihe ausgeblendet
/// (z.B. fuer User die nur Training tracken, keine Body-Composition).
/// Length 1-2 = entsprechend weniger Cards. Length 3 = Default.
/// Mehr als 3 wuerden das HStack-Layout sprengen — clamping uebernimmt
/// die Settings-UI, nicht das Model.
///
/// **Phase-1-Cases (5):** alle aus den schon persistierten Measurement-
/// Feldern bzw. dem Profile-Height berechenbar. KEINE HealthKit-Quellen
/// (kommt mit Phase 3) — Phase 1 ist 100% offline & permission-frei.
///
/// **Neue Cases:** raw-Value ist der Persistenz-Schluessel — rename =
/// Storage-Migration noetig. Neue Cases bei Bedarf am Ende anhaengen,
/// dann erbt der bestehende Default ohne Migration die alten 3 Slots.
public enum HeroMetricType: String, Codable, Sendable, CaseIterable, Hashable {

    /// Latest `weightKg` aus `UserBodyMeasurement`. Mit Weekly-Delta.
    case weight

    /// Navy-Method-Body-Fat-% aus dem letzten Measurement. Nil → "—".
    case bodyFatNavy

    /// Fat-Free-Mass-Index aus dem letzten Measurement. Nil → "—".
    case ffmi

    /// Fettfreie Masse (kg) aus `UserBodyMeasurement.fatFreeMassKg`.
    /// Nil → "—". DEL-Phase-1: bereits berechnet von makeDerived(),
    /// kein neuer Datenpfad noetig.
    case leanMass

    /// Body-Mass-Index, on-the-fly berechnet aus latest weight + profile
    /// height. Nil-Fallback wenn entweder Measurement fehlt oder
    /// `profile.heightCm == 0`.
    case bmi

    /// xcstrings-Lookup-Key: `heroMetric.{rawValue}.label`.
    public var localizationKey: String {
        "heroMetric.\(rawValue).label"
    }

    /// Default-Belegung fuer Erst-User: das identische 3er-Set, das die
    /// pre-Dashboard-Customization App-Version (UX-205 und davor)
    /// hartcodiert hatte. Backward-Compatible-Optik fuer Bestandsuser
    /// nach Lightweight-Migration.
    public static var defaultOrder: [HeroMetricType] {
        [.weight, .bodyFatNavy, .ffmi]
    }

    /// Max-Slots fuer die HStack-Hero-Reihe. Mehr wuerden die Cards
    /// auf iPhone-SE-Breite kollabieren (jede Card braucht Mindest-
    /// Breite fuer Label + Value lesbar).
    public static let maxSlots: Int = 3
}
