import Foundation

/// DEL-250: Lauf-Ziel-Kategorie im Profil. Rein deskriptiv — aktuell kein
/// Coaching-Trigger, der danach verzweigt (im Gegensatz zu `TrainingGoal`,
/// das direkt die Goal-Matrix-Keys speist). Grundlage fuer eine spaetere,
/// distanzbewusste Coaching-Verfeinerung. Persistiert als String (analog
/// `TrainingGoal`/`CoachingTone`) fuer Lightweight-Migration.
public enum CardioGoal: String, Codable, Sendable, CaseIterable {
    case generalFitness
    case fiveK
    case tenK
    case halfMarathon
    case marathon

    /// Deutscher Default-String (Legacy/Fallback-Pattern wie `TrainingGoal.label`).
    /// UI nutzt `.localizedName` (FitnessAppUI/DomainEnums+Localization.swift).
    public var label: String {
        switch self {
        case .generalFitness: return "Allgemeine Fitness"
        case .fiveK:          return "5 km"
        case .tenK:           return "10 km"
        case .halfMarathon:   return "Halbmarathon"
        case .marathon:       return "Marathon"
        }
    }

    public var symbol: String {
        switch self {
        case .generalFitness:            return "figure.run"
        case .fiveK, .tenK:              return "flag.checkered"
        case .halfMarathon, .marathon:   return "medal.fill"
        }
    }
}

/// DEL-250: leitet grobe Trainings-Paces aus einer 5-km-Referenzzeit ab
/// (Nutzer-Entscheidung: Referenzzeit + abgeleitete Zonen statt einer
/// einzelnen, direkt eingegebenen Pace — praeziser fuer eine spaetere
/// `cardioProgressionEarned`-Verfeinerung).
///
/// Bewusst NUR zwei Zonen (locker/Tempo), keine distanzabhaengige
/// Renn-Pace-Projektion fuer 10k/Halbmarathon/Marathon (z.B. via
/// Riegel-Formel) — dafuer gibt es aktuell keinen Verbraucher, und eine
/// ungetestete Mehrdistanz-Projektion waere zusaetzliches Fehlerrisiko
/// ohne Nutzen. Die Faktoren sind grobe, dokumentierte Naeherungen
/// (angelehnt an gaengige Lauf-Coaching-Faustregeln, keine individuelle
/// Trainingsempfehlung) — bei Bedarf hier zentral anpassbar.
///
/// Pure functions — analog `DeloadAdvisor`/`CardioCoachingAdvisor`. Kein
/// Verbraucher in dieser Runde (DEL-250 ist bewusst auf Profil-Editor
/// beschraenkt, siehe `ProfileEditorView.cardioCard`); die Werte werden
/// nur informativ im Editor angezeigt.
public enum PaceZoneCalculator {

    /// Lockerer Lauf ≈ 30% langsamer als die 5-km-Renn-Pace — haelt
    /// "easy" wirklich locker (gaengige Faustregel-Spanne: 20-30% langsamer).
    public static let easyPaceFactor: Double = 1.30

    /// Tempolauf ≈ 10% langsamer als die 5-km-Renn-Pace — Naeherung an
    /// Schwellen-/Tempo-Pace (gaengige Spanne: 5-15% langsamer).
    public static let tempoPaceFactor: Double = 1.10

    /// 5-km-Renn-Pace in Minuten/km, direkt aus der Referenzzeit.
    /// Nil bei nicht-positiver Eingabe (Divisions-Sicherheit, gleiches
    /// Muster wie `PaceCalculator.minutesPerKm`).
    public static func racePaceMinutesPerKm(fiveKReferenceSeconds: Int) -> Double? {
        PaceCalculator.minutesPerKm(distanceKm: 5.0, durationSeconds: fiveKReferenceSeconds)
    }

    public static func easyPaceMinutesPerKm(fiveKReferenceSeconds: Int) -> Double? {
        racePaceMinutesPerKm(fiveKReferenceSeconds: fiveKReferenceSeconds).map { $0 * easyPaceFactor }
    }

    public static func tempoPaceMinutesPerKm(fiveKReferenceSeconds: Int) -> Double? {
        racePaceMinutesPerKm(fiveKReferenceSeconds: fiveKReferenceSeconds).map { $0 * tempoPaceFactor }
    }
}
