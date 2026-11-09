#if canImport(SwiftData)
import Foundation
import SwiftData

/// Settings-Epic Phase 2 (docs/SETTINGS_UX_AUDIT.md, Befund PE-FFM + Teil 4
/// Entscheidung 5): `BodyMeasurement.makeDerived` berechnete KFA/FFM/FFMI
/// bisher unbedingt ueber einen Deurenberg-BMI-Naeherungswert, auch wenn gar
/// keine Umfaenge vorlagen — jede Onboarding-Erstmessung (die nie Umfaenge
/// erfasst) traegt dadurch bereits einen erfundenen Wert, der auf dem
/// Dashboard wie ein echter aussieht.
///
/// Dieser One-Shot-Backfill bereinigt bestehende Datensaetze: Zeilen ohne
/// `navyBodyFatPct` (keine echten Umfaenge) aber mit `deurenbergBodyFatPct`
/// (der BMI-Naeherungswert wurde also tatsaechlich als Quelle fuer
/// FFM/FFMI verwendet) werden auf die Komposition genullt. `bmi`/`bmr`
/// bleiben stehen — beides sind exakte Gewicht/Groesse/Alter-Formeln, keine
/// Naeherung, also keine Fabrikation.
///
/// Idempotent ohne eigenes Flag: nach dem Nullen von `deurenbergBodyFatPct`
/// matcht die betroffene Zeile den Fetch-Filter nicht mehr, der Pass laeuft
/// beim naechsten App-Start leer durch — identisches Muster zu
/// `LibrarySeeder`s Backfills.
@MainActor
public enum BodyMeasurementMigrator {

    @discardableResult
    public static func backfillFabricatedBodyCompositionIfNeeded(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<BodyMeasurement>(
            predicate: #Predicate { $0.deurenbergBodyFatPct != nil }
        )
        let candidates = (try? context.fetch(descriptor)) ?? []
        guard !candidates.isEmpty else { return 0 }

        var updated = 0
        for measurement in candidates where measurement.navyBodyFatPct == nil {
            measurement.deurenbergBodyFatPct = nil
            measurement.fatFreeMassKg = nil
            measurement.ffmi = nil
            measurement.normalizedFfmi = nil
            updated += 1
        }
        return updated
    }
}
#endif
