import XCTest
@testable import FitnessAppCore

/// DEL-224: Eingefrorener v1.0.0-Korpus.
///
/// **Warum das existiert.** Die bestehenden CSV-Tests schreiben mit dem
/// AKTUELLEN Writer und lesen mit dem aktuellen Reader zurueck. Ein Roundtrip
/// bleibt damit auch dann gruen, wenn sich das Format aendert — beide Seiten
/// aendern sich gemeinsam. Genau dieser blinde Fleck macht Alt-Backups
/// unimportierbar, ohne dass die Suite etwas merkt. Die Strings hier sind
/// deshalb HANDGESCHRIEBEN und werden NIE regeneriert: sie sind der Vertrag
/// mit jedem ZIP, das ein Nutzer irgendwann exportiert hat.
///
/// Format-Fakten, die dieser Korpus festnagelt (Stand `formatVersion` 1.0.0):
///   * Zeilentrenner **CRLF** (`\r\n`) — der Exporter schreibt RFC-4180.
///     Genau hier lag der Datenverlust-Bug DEL-188: der Reader iterierte
///     ueber `Character`, und Swift behandelt `\r\n` als EIN Grapheme, das
///     weder auf `\r` noch auf `\n` matchte. Ergebnis: die komplette Datei
///     wurde als eine einzige Header-Zeile gelesen, jede Datei meldete
///     0 Zeilen, und ein Replace-Import loeschte den Bestand gegen Nichts.
///   * Zeitstempel ISO-8601 UTC mit Millisekunden.
///   * Dezimaltrenner Punkt, feste 2 Nachkommastellen.
///   * Booleans `true`/`false` klein.
///   * Leere Zelle = nil, kein NULL-Sentinel.
///   * Anfuehrungszeichen nur wenn noetig; eingebettetes `"` verdoppelt.
///
/// Wenn ein Test hier rot wird, ist das kein Test-Problem: dann liest die App
/// bestehende Backups anders als bisher. Erst pruefen, ob das gewollt ist, und
/// falls ja, den Importer abwaerts-kompatibel halten statt den Korpus
/// anzupassen.
final class GoldenCSVv1Tests: XCTestCase {

    // MARK: - Eingefrorene Nutzdaten (v1.0.0)

    /// water_log.csv — die Datei, an der DEL-188 sichtbar wurde.
    private let waterLogV1 = """
    id,date_utc,amount_ml\r
    E1A1F3C2-0000-4000-8000-000000000001,2026-07-20T06:45:00.000Z,250\r
    E1A1F3C2-0000-4000-8000-000000000002,2026-07-20T09:12:30.500Z,500\r
    E1A1F3C2-0000-4000-8000-000000000003,2026-07-20T18:00:00.000Z,1000\r

    """

    /// workouts.csv — Bools, optionale Fremdschluessel, leere Zellen.
    private let workoutsV1 = """
    id,start_time_utc,end_time_utc,duration_minutes,exercise_count,total_sets,total_volume_kg,notes,is_completed,is_rest_day,is_ad_hoc,day_name_snapshot,session_feeling,gear_id,day_id\r
    5E551011-0000-4000-8000-000000000001,2026-07-19T17:00:00.000Z,2026-07-19T18:12:00.000Z,72,5,18,4820.50,Guter Tag,true,false,false,Ganzkörper A,3,,DA400001-0000-4000-8000-000000000001\r
    5E551011-0000-4000-8000-000000000002,2026-07-20T07:30:00.000Z,2026-07-20T08:05:00.000Z,35,1,1,0.00,,true,false,true,,2,6EA40001-0000-4000-8000-000000000001,\r

    """

    /// logs.csv — der Satz-Level. Deckt Kraft, Bodyweight und Cardio ab, weil
    /// diese drei sich nur durch leere Zellen unterscheiden.
    private let logsV1 = """
    id,session_id,exercise_id,date_utc,set_index,weight_kg,reps,rpe,rir,comment,exercise_name_snapshot,exercise_is_cardio_snapshot,exercise_is_time_based_snapshot,exercise_cardio_equipment_snapshot,distance_km,duration_seconds\r
    10600001-0000-4000-8000-000000000001,5E551011-0000-4000-8000-000000000001,E8E80001-0000-4000-8000-000000000001,2026-07-19T17:05:00.000Z,0,80.00,8,0.00,2.0,,Bankdrücken,false,false,,,\r
    10600001-0000-4000-8000-000000000002,5E551011-0000-4000-8000-000000000001,E8E80001-0000-4000-8000-000000000002,2026-07-19T17:20:00.000Z,0,0.00,12,0.00,1.5,"Sauber, ohne Schwung",Klimmzüge,false,false,,,\r
    10600001-0000-4000-8000-000000000003,5E551011-0000-4000-8000-000000000002,E8E80001-0000-4000-8000-000000000003,2026-07-20T07:35:00.000Z,0,0.00,0,0.00,0.0,,Easy Run,true,false,treadmill,5.20,1830\r

    """

    // MARK: - Struktur

    func testWaterLogHeadersAreStable() throws {
        let reader = try CSVReader(waterLogV1)
        XCTAssertEqual(reader.headers, ["id", "date_utc", "amount_ml"])
    }

    func testWorkoutsHeadersAreStable() throws {
        let reader = try CSVReader(workoutsV1)
        XCTAssertEqual(reader.headers, [
            "id", "start_time_utc", "end_time_utc", "duration_minutes",
            "exercise_count", "total_sets", "total_volume_kg", "notes",
            "is_completed", "is_rest_day", "is_ad_hoc", "day_name_snapshot",
            "session_feeling", "gear_id", "day_id",
        ])
    }

    func testLogsHeadersAreStable() throws {
        let reader = try CSVReader(logsV1)
        XCTAssertEqual(reader.headers.count, 16)
        XCTAssertEqual(reader.headers.first, "id")
        XCTAssertEqual(reader.headers.last, "duration_seconds")
    }

    /// Der DEL-188-Kern: CRLF-Zeilen muessen als Zeilen erkannt werden.
    func testCRLFRowsAreCounted() throws {
        XCTAssertEqual(try CSVReader(waterLogV1).rows().count, 3)
        XCTAssertEqual(try CSVReader(workoutsV1).rows().count, 2)
        XCTAssertEqual(try CSVReader(logsV1).rows().count, 3)
    }

    /// Dieselben Daten mit LF statt CRLF muessen identisch gelesen werden —
    /// handgeschriebene oder von Tools umgeschriebene CSVs sollen importierbar
    /// bleiben.
    func testLFVariantParsesIdentically() throws {
        let lf = waterLogV1.replacingOccurrences(of: "\r\n", with: "\n")
        let crlfRows = try CSVReader(waterLogV1).rows()
        let lfRows = try CSVReader(lf).rows()
        XCTAssertEqual(lfRows.count, crlfRows.count)
        for (a, b) in zip(crlfRows, lfRows) {
            XCTAssertEqual(a.fields, b.fields)
        }
    }

    // MARK: - Werte

    func testWaterLogValues() throws {
        let rows = try CSVReader(waterLogV1).rows()
        XCTAssertEqual(rows[0].int("amount_ml"), 250)
        XCTAssertEqual(rows[1].int("amount_ml"), 500)
        XCTAssertEqual(rows[2].int("amount_ml"), 1000)
        // Millisekunden-Anteil muss geparst werden (Exporter-Default).
        XCTAssertNotNil(rows[1].date("date_utc"))
    }

    func testWorkoutBoolsAndOptionalForeignKeys() throws {
        let rows = try CSVReader(workoutsV1).rows()
        XCTAssertEqual(rows[0].bool("is_completed"), true)
        XCTAssertEqual(rows[0].bool("is_ad_hoc"), false)
        XCTAssertEqual(rows[1].bool("is_ad_hoc"), true)
        // Plan-Session: gear_id leer, day_id gesetzt.
        XCTAssertNil(rows[0].optionalString("gear_id"))
        XCTAssertNotNil(rows[0].optionalString("day_id"))
        // Ad-hoc-Session: umgekehrt.
        XCTAssertNotNil(rows[1].optionalString("gear_id"))
        XCTAssertNil(rows[1].optionalString("day_id"))
    }

    func testWorkoutDecimalsKeepTwoFractionDigits() throws {
        let rows = try CSVReader(workoutsV1).rows()
        XCTAssertEqual(rows[0].double("total_volume_kg") ?? 0, 4820.50, accuracy: 0.0001)
        XCTAssertEqual(rows[1].double("total_volume_kg") ?? -1, 0.0, accuracy: 0.0001)
    }

    /// Ein Kommentar mit Komma muss quotiert vorliegen und ohne Feldbruch
    /// zurueckkommen — sonst verschiebt sich die ganze Zeile.
    func testQuotedFieldWithCommaSurvives() throws {
        let rows = try CSVReader(logsV1).rows()
        XCTAssertEqual(rows[1].optionalString("comment"), "Sauber, ohne Schwung")
        // Und die Felder danach sind noch am richtigen Platz.
        XCTAssertEqual(rows[1].optionalString("exercise_name_snapshot"), "Klimmzüge")
    }

    func testUmlautsSurviveUTF8() throws {
        let rows = try CSVReader(logsV1).rows()
        XCTAssertEqual(rows[0].optionalString("exercise_name_snapshot"), "Bankdrücken")
    }

    /// Die drei Uebungs-Arten unterscheiden sich im CSV nur durch leere
    /// Zellen — genau das muss der Reader stabil abbilden.
    func testStrengthBodyweightAndCardioRowsAreDistinguishable() throws {
        let rows = try CSVReader(logsV1).rows()

        // Kraft: Gewicht + Reps, keine Cardio-Felder.
        XCTAssertEqual(rows[0].double("weight_kg") ?? -1, 80.0, accuracy: 0.0001)
        XCTAssertEqual(rows[0].int("reps"), 8)
        XCTAssertNil(rows[0].double("distance_km"))
        XCTAssertNil(rows[0].int("duration_seconds"))

        // Bodyweight: kein Gewicht, aber Reps.
        XCTAssertEqual(rows[1].double("weight_kg") ?? -1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(rows[1].int("reps"), 12)

        // Cardio: weder Gewicht noch Reps, aber Distanz + Dauer + Equipment.
        XCTAssertEqual(rows[2].double("distance_km") ?? -1, 5.20, accuracy: 0.0001)
        XCTAssertEqual(rows[2].int("duration_seconds"), 1830)
        XCTAssertEqual(rows[2].optionalString("exercise_cardio_equipment_snapshot"), "treadmill")
        XCTAssertEqual(rows[2].bool("exercise_is_cardio_snapshot"), true)
    }

    /// Trailing-Newline am Dateiende darf keine Leerzeile erzeugen — der
    /// Exporter schreibt nach der letzten Zeile ein CRLF.
    func testTrailingNewlineDoesNotProduceEmptyRow() throws {
        let rows = try CSVReader(waterLogV1).rows()
        XCTAssertEqual(rows.count, 3)
        XCTAssertFalse(rows.contains { $0.fields["id"]?.isEmpty ?? true })
    }

    /// DEL-225-Vorbereitung: Zwei Saetze derselben Uebung in derselben Session
    /// mit demselben set_index sind ein LEGITIMER Bestand (dieselbe Uebung
    /// zweimal im Training). Der Korpus haelt den Fall fest, damit ein
    /// Dedup-Schluessel, der nur (session, set_index, name) benutzt, hier
    /// auffaellt statt still die zweite Serie zu verschlucken.
    func testDuplicateExerciseNameSameSetIndexIsRepresentable() throws {
        let twoSeries = """
        id,session_id,exercise_id,date_utc,set_index,weight_kg,reps,rpe,rir,comment,exercise_name_snapshot,exercise_is_cardio_snapshot,exercise_is_time_based_snapshot,exercise_cardio_equipment_snapshot,distance_km,duration_seconds\r
        AA000001-0000-4000-8000-000000000001,5E551011-0000-4000-8000-000000000001,E8E80001-0000-4000-8000-00000000000A,2026-07-19T17:05:00.000Z,0,100.00,5,0.00,1.0,,Bankdrücken,false,false,,,\r
        AA000001-0000-4000-8000-000000000002,5E551011-0000-4000-8000-000000000001,E8E80001-0000-4000-8000-00000000000B,2026-07-19T17:45:00.000Z,0,70.00,12,0.00,2.0,,Bankdrücken,false,false,,,\r

        """
        let rows = try CSVReader(twoSeries).rows()
        XCTAssertEqual(rows.count, 2, "beide Serien muessen im CSV erhalten sein")
        XCTAssertEqual(rows[0].optionalString("exercise_name_snapshot"),
                       rows[1].optionalString("exercise_name_snapshot"))
        XCTAssertEqual(rows[0].int("set_index"), rows[1].int("set_index"))
        XCTAssertNotEqual(rows[0].optionalString("exercise_id"),
                          rows[1].optionalString("exercise_id"),
                          "unterscheidbar sind sie NUR ueber exercise_id")
    }
}
