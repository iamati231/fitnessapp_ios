import Foundation

/// Smart-Onboarding-Epic Phase 2 (PLAN_EQUIPMENT_MATCHING_AUDIT.md):
/// einzelner, eigenstaendig verfuegbarer Ausruestungsgegenstand des
/// NUTZERS. Getrennt von `Equipment` (`DomainEnums.swift`) — jenes bleibt
/// die grobe Pro-Uebung-Klassifikation, die bereits ueberall referenziert
/// wird (`ExerciseTemplateSpec.equipment`, 229 Katalog-Eintraege, CSV-
/// Export `exercise.equipment`). `Equipment` kennt weder Zubehoer (Bank/
/// Rack/Klimmzugstange) noch Stueckzahl (Audit Abschnitt 3/5.3) — dieses
/// Enum schliesst genau diese Luecke, OHNE `Equipment` selbst anzufassen.
///
/// Gleiche Fallnamen wie bei `Equipment` (z.B. `.barbell`) sind bewusst:
/// beide meinen dasselbe physische Ding, nur aus zwei verschiedenen
/// Blickwinkeln (Uebungs-Klassifikation vs. Nutzer-Inventar) — der
/// Compiler haelt beide Typen trotzdem strikt auseinander.
///
/// Kein `.bodyweight`-Fall: Koerpergewicht hat keine Verfuegbarkeits-Frage.
public enum EquipmentItem: String, Codable, Sendable, CaseIterable, Hashable {
    // Gewichte
    case dumbbell
    case kettlebell
    case barbell
    case resistanceBand
    // Zubehoer / Stationen
    case pullUpBar
    /// Smart-Onboarding-Epic Phase 4 (PLAN_EQUIPMENT_MATCHING_AUDIT.md
    /// Abschnitt 13): eine Uebung, die nur eine FLACHE Bank braucht, nutzt in
    /// `ExerciseLibraryData` immer `.any([.item(.flatBench), .item(.adjustableBench)])`,
    /// nie `.item(.flatBench)` allein — eine verstellbare Bank kann flach
    /// genutzt werden, deckt eine Flachbank-Anforderung also mit ab. Umgekehrt
    /// gilt das NICHT: eine reine Flachbank kann nicht inclinen/declinen, eine
    /// Schraegbank-Uebung verlangt deshalb ausschliesslich `.adjustableBench`.
    case flatBench
    case adjustableBench
    case rack
    case cableStation
    case machineStation

    /// Items, bei denen die Stueckzahl matching-relevant ist (Audit
    /// Beispiel: "eine gegenueber zwei Kettlebells"). Zubehoer/Stationen
    /// sind binaer vorhanden/nicht — eine Anzahl ergibt dort fuer kein
    /// aktuelles Anforderungs-Beispiel einen Unterschied.
    public var supportsCount: Bool {
        switch self {
        case .dumbbell, .kettlebell: return true
        case .barbell, .resistanceBand, .pullUpBar, .flatBench, .adjustableBench, .rack, .cableStation, .machineStation:
            return false
        }
    }
}

/// Dreiwertige Verfuegbarkeit — ersetzt die bisherige binaere
/// "im Set enthalten oder nicht" (`UserBodyProfile.equipmentPreferences`,
/// DEL-170) fuer die NEUEN `EquipmentItem`s. `.unknown` ist der Default
/// und bedeutet ausdruecklich NICHT "nicht vorhanden" — Audit Abschnitt
/// 5.3: "falsche Sicherheit aus unvollstaendigen Angaben" vermeiden.
public enum EquipmentAvailability: String, Codable, Sendable, Hashable {
    case available
    case unavailable
    case unknown
}

/// Reine, SwiftData-freie Sicht auf die Ausruestung eines Nutzers — von
/// `UserBodyProfile` (FitnessAppData) befuellt/gelesen. Macht die
/// Voraussetzungs-Pruefung unten in Core testbar, ohne einen ModelContext
/// zu brauchen.
///
/// Ein Item OHNE Eintrag in `availability` ist `.unknown` (siehe
/// `availability(for:)`) — das deckt sowohl ein brandneues Item als auch
/// ein komplett unberuehrtes Bestandsprofil identisch und korrekt ab
/// ("eine leere alte Auswahl bleibt unbekannt").
///
/// Absichtlich KEINE `environment`-basierte Default-Herleitung hier oder
/// in einer kuenftigen Phase (Audit Abschnitt 5.1: "Ort ist nicht
/// Ausstattung" — "Gym"/"Home-Gym" duerfen niemals automatisch Zubehoer
/// als sicher vorhanden markieren).
public struct UserEquipmentProfile: Sendable, Equatable {
    public var availability: [EquipmentItem: EquipmentAvailability]
    /// Nur fuer Items mit `supportsCount == true` befuellt. Ein fehlender
    /// Eintrag bedeutet "Anzahl nicht erfasst", NICHT "0" — ein Item kann
    /// `.available` sein, ohne dass die genaue Stueckzahl bekannt ist.
    public var counts: [EquipmentItem: Int]

    public init(
        availability: [EquipmentItem: EquipmentAvailability] = [:],
        counts: [EquipmentItem: Int] = [:]
    ) {
        self.availability = availability
        self.counts = counts
    }

    public func availability(for item: EquipmentItem) -> EquipmentAvailability {
        availability[item] ?? .unknown
    }

    public func count(for item: EquipmentItem) -> Int? {
        counts[item]
    }

    /// Smart-Onboarding-Epic Phase 3: die "vollstaendige Bestaetigung".
    /// Vor diesem Aufruf bleibt ein nicht ausgewaehltes Item `.unknown`
    /// (siehe Typ-Dokumentation oben) — genau das verlangt die Vorgabe
    /// ("ungewaehlte Geraete vor der vollstaendigen Bestaetigung nicht als
    /// fehlend interpretieren"). Danach ist jedes NIE ANGEFASSTE Item
    /// explizit entschieden: alles ohne eigenen Dictionary-Eintrag wird jetzt
    /// zu `.unavailable`. Idempotent — ein zweiter Aufruf (z.B. nach einem
    /// spaeteren App-Update mit neuen `EquipmentItem`-Faellen) aendert nur
    /// die inzwischen neu hinzugekommenen, noch unbekannten Items.
    ///
    /// Smart-Onboarding-Epic Phase 6 (docs/PLAN_LOCATION_EQUIPMENT_ONBOARDING.md
    /// Pflicht-Test 6): ein Item, das EXPLIZIT auf `.unknown` gesetzt wurde
    /// (z.B. "Weiß ich noch nicht" bei Bank/Klimmzugstange —
    /// `EquipmentProfileEditor`), ist bewusst von einem nie angefassten Item
    /// (kein Dictionary-Eintrag) unterschieden: NUR Letzteres wird hier zu
    /// `.unavailable`. Eine bewusste "weiß ich nicht"-Aussage bleibt auch
    /// nach der vollstaendigen Bestaetigung `.unknown` — "bewusst unbekannte
    /// Angaben nicht ueberschreiben" (Vorgabe woertlich).
    public mutating func confirmRemainingAsUnavailable() {
        for item in EquipmentItem.allCases where availability[item] == nil {
            availability[item] = .unavailable
        }
    }

    /// Projiziert diese reichhaltigeren Phase-2/3-Daten auf das aeltere,
    /// grobe `Equipment`-Set (DEL-170) — ausschliesslich fuer Rueckwaerts-
    /// Kompatibilitaet mit Call-Sites, die noch nicht auf
    /// `UserEquipmentProfile` umgestellt sind (`PlanMatchmaker`,
    /// `ProgramInstantiator`, `EquipmentVariant`). Zaehlt NUR echte
    /// `.available`-Eintraege — niemals `.unknown`, sonst waere das genau
    /// die "falsche Sicherheit aus unvollstaendigen Angaben", die beide
    /// Phasen vermeiden sollen. `.bodyweight` ist immer enthalten (jeder
    /// hat einen Koerper, unabhaengig von jeder Auswahl hier).
    ///
    /// Zubehoer/Stationen ohne Entsprechung im alten Modell (Bank, Rack,
    /// Klimmzugstange) tragen bewusst nichts bei — das grobe `Equipment`
    /// kennt sie schlicht nicht (Audit Abschnitt 3).
    public var legacyEquipmentPreferences: Set<Equipment> {
        var result: Set<Equipment> = [.bodyweight]
        if availability(for: .dumbbell) == .available { result.insert(.dumbbell) }
        if availability(for: .kettlebell) == .available { result.insert(.kettlebell) }
        if availability(for: .barbell) == .available { result.insert(.barbell) }
        if availability(for: .resistanceBand) == .available { result.insert(.band) }
        if availability(for: .cableStation) == .available { result.insert(.cable) }
        if availability(for: .machineStation) == .available { result.insert(.machine) }
        return result
    }
}

/// Voraussetzung fuer eine konkrete Uebungs-Variante: ein Baum aus UND/
/// ODER-Knoten ueber `EquipmentItem`s, optional mit Mindest-Stueckzahl.
///
/// Audit Abschnitt 4, Worked Examples:
/// - Goblet Squat: `.any([.item(.kettlebell), .item(.dumbbell)])`
/// - Incline DB Press: `.all([.item(.dumbbell, minimumCount: 2), .item(.adjustableBench)])`
/// - Pull-ups: `.item(.pullUpBar)` (keine erfundene "sichere Aufhaengung")
/// - Double KB Push Press: `.item(.kettlebell, minimumCount: 2)`
public indirect enum ExerciseRequirement: Sendable, Hashable {
    case item(EquipmentItem, minimumCount: Int = 1)
    case all([ExerciseRequirement])
    case any([ExerciseRequirement])
}

/// Grund, warum ein einzelnes `EquipmentItem` eine Anforderung (noch)
/// nicht definitiv erfuellt — Baustein fuer die "konkreten Gruende", die
/// die dreistufige Pruefung liefern soll.
public struct UnmetReason: Sendable, Equatable {
    public let item: EquipmentItem
    public let requiredCount: Int
    public let availability: EquipmentAvailability
    public let knownCount: Int?
}

/// Ergebnis der dreistufigen Pruefung einer `ExerciseRequirement` gegen
/// ein `UserEquipmentProfile`. Niemals nur zweiwertig: "nicht erfuellbar"
/// und "koennte erfuellbar sein, aber unklar" sind bewusst unterschieden —
/// Audit Abschnitt 5.3/4: nie falsche Sicherheit aus unvollstaendigen
/// Daten vortaeuschen.
public enum RequirementStatus: Sendable, Equatable {
    case satisfied
    case unmet(reasons: [UnmetReason])
    case unknown(reasons: [UnmetReason])

    public var isSatisfied: Bool {
        if case .satisfied = self { return true }
        return false
    }
}

public extension ExerciseRequirement {

    /// Dreiwertige Auswertung (verfuegbar / nicht verfuegbar / unbekannt)
    /// mit konkreten Gruenden je betroffenem Item. Dreiwertige Logik
    /// (Kleene/Łukasiewicz) fuer UND/ODER:
    /// - UND: EIN definitiv unerfuelltes Kind macht das Ganze definitiv
    ///   unerfuellt, unabhaengig von unbekannten Geschwister-Knoten. Ohne
    ///   definitiv Unerfuelltes, aber mindestens ein unbekanntes Kind ->
    ///   das Ganze ist unbekannt. Nur wenn ALLE Kinder erfuellt sind ->
    ///   erfuellt.
    /// - ODER: EIN erfuelltes Kind macht das Ganze erfuellt. Sind ALLE
    ///   Kinder definitiv unerfuellt -> das Ganze ist definitiv unerfuellt.
    ///   Sonst (kein erfuelltes, aber mindestens ein unbekanntes Kind) ->
    ///   das Ganze ist unbekannt (die unbekannte Alternative koennte noch
    ///   erfuellt sein).
    func evaluate(against profile: UserEquipmentProfile) -> RequirementStatus {
        switch self {
        case let .item(item, minimumCount):
            let availability = profile.availability(for: item)
            switch availability {
            case .unavailable:
                return .unmet(reasons: [UnmetReason(
                    item: item, requiredCount: minimumCount,
                    availability: .unavailable, knownCount: profile.count(for: item)
                )])
            case .unknown:
                return .unknown(reasons: [UnmetReason(
                    item: item, requiredCount: minimumCount,
                    availability: .unknown, knownCount: profile.count(for: item)
                )])
            case .available:
                guard item.supportsCount, minimumCount > 1 else { return .satisfied }
                guard let knownCount = profile.count(for: item) else {
                    // Vorhanden, aber Stueckzahl nie erfasst -> koennte
                    // reichen oder nicht, also unbekannt statt optimistisch
                    // "erfuellt".
                    return .unknown(reasons: [UnmetReason(
                        item: item, requiredCount: minimumCount,
                        availability: .available, knownCount: nil
                    )])
                }
                if knownCount >= minimumCount { return .satisfied }
                return .unmet(reasons: [UnmetReason(
                    item: item, requiredCount: minimumCount,
                    availability: .available, knownCount: knownCount
                )])
            }

        case let .all(children):
            guard !children.isEmpty else { return .satisfied }
            var unknownReasons: [UnmetReason] = []
            for child in children {
                switch child.evaluate(against: profile) {
                case .satisfied:
                    continue
                case let .unmet(reasons):
                    return .unmet(reasons: reasons)
                case let .unknown(reasons):
                    unknownReasons.append(contentsOf: reasons)
                }
            }
            return unknownReasons.isEmpty ? .satisfied : .unknown(reasons: unknownReasons)

        case let .any(children):
            guard !children.isEmpty else {
                return .unmet(reasons: [])
            }
            var unmetReasons: [UnmetReason] = []
            var unknownReasons: [UnmetReason] = []
            for child in children {
                switch child.evaluate(against: profile) {
                case .satisfied:
                    return .satisfied
                case let .unmet(reasons):
                    unmetReasons.append(contentsOf: reasons)
                case let .unknown(reasons):
                    unknownReasons.append(contentsOf: reasons)
                }
            }
            // Mindestens eine Alternative ist noch unklar (statt definitiv
            // ausgeschlossen) -> das Ganze bleibt unbekannt, nicht unerfuellt.
            // Gruende beider Art werden gemeldet: "bereits ausgeschlossen"
            // UND "noch zu klaeren" sind beide fuer eine konkrete Erklaerung
            // relevant, keine der beiden Informationen wird stillschweigend
            // verworfen.
            return unknownReasons.isEmpty
                ? .unmet(reasons: unmetReasons)
                : .unknown(reasons: unknownReasons + unmetReasons)
        }
    }
}
