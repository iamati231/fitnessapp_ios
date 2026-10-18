import XCTest
@testable import FitnessAppCore

/// DEL-199: Roundtrip- und Parser-Tests für die CSV-Schicht.
///
/// Lektion aus DEL-188: der Grapheme-Cluster-Bug (`\r\n` als EIN Character)
/// hat einen kompletten Datenbestand als "0 rows" geparst und wäre von
/// JEDEM dieser Tests gefangen worden. Die CSV-Schicht ist der gefährlichste
/// Code der App (Restore-Pfad) — sie bleibt ab jetzt nicht mehr ungetestet.
final class CSVRoundtripTests: XCTestCase {

    // MARK: Roundtrip — Writer-Output muss durch den Reader zurückkommen

    func testSimpleRoundtrip() throws {
        var w = CSVWriter(headers: ["a", "b", "c"])
        w.appendRow(["1", "2", "3"])
        w.appendRow(["x", "y", "z"])
        let reader = try CSVReader(String(data: w.data(), encoding: .utf8)!)
        XCTAssertEqual(reader.headers, ["a", "b", "c"])
        let rows = reader.rows()
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["a"], "1")
        XCTAssertEqual(rows[1]["c"], "z")
    }

    /// DER DEL-188-Regressions-Test: CRLF-Separator (Writer-Standard) muss
    /// als Record-Grenze erkannt werden — Grapheme-Cluster-Falle.
    func testCRLFRecordSeparationSurvivesRoundtrip() throws {
        var w = CSVWriter(headers: ["id", "value"])
        for i in 0..<50 {
            w.appendRow(["\(i)", "v\(i)"])
        }
        let text = String(data: w.data(), encoding: .utf8)!
        XCTAssertTrue(text.contains("\r\n"), "Writer muss RFC-4180-CRLF schreiben")
        let reader = try CSVReader(text)
        XCTAssertEqual(reader.headers.count, 2, "Header darf nicht das ganze File verschlucken")
        XCTAssertEqual(reader.rows().count, 50)
    }

    func testQuotedFieldsWithCommasQuotesAndNewlines() throws {
        var w = CSVWriter(headers: ["name", "note"])
        w.appendRow(["a,b", "Zeile1\nZeile2"])
        w.appendRow(["sagt \"hi\"", "tab\there"])
        let reader = try CSVReader(String(data: w.data(), encoding: .utf8)!)
        let rows = reader.rows()
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["name"], "a,b")
        XCTAssertEqual(rows[0]["note"], "Zeile1\nZeile2")
        XCTAssertEqual(rows[1]["name"], "sagt \"hi\"")
    }

    func testUmlautsEmojiAndTurkishCharacters() throws {
        var w = CSVWriter(headers: ["text"])
        w.appendRow(["Kreuzheben — über 100 kg 💪 ağırlık çalışması"])
        let reader = try CSVReader(String(data: w.data(), encoding: .utf8)!)
        XCTAssertEqual(reader.rows()[0]["text"], "Kreuzheben — über 100 kg 💪 ağırlık çalışması")
    }

    func testEmptyAndNilFields() throws {
        var w = CSVWriter(headers: ["a", "b", "c"])
        w.appendRow([Optional("1"), nil, Optional("")])
        let reader = try CSVReader(String(data: w.data(), encoding: .utf8)!)
        let row = reader.rows()[0]
        XCTAssertEqual(row["a"], "1")
        XCTAssertEqual(row["b"], "")
        XCTAssertEqual(row["c"], "")
    }

    // MARK: Reader-Toleranzen

    func testLFOnlyInput() throws {
        let reader = try CSVReader("a,b\n1,2\n3,4\n")
        XCTAssertEqual(reader.rows().count, 2)
    }

    func testBareCROnlyInput() throws {
        let reader = try CSVReader("a,b\r1,2\r3,4")
        XCTAssertEqual(reader.rows().count, 2)
    }

    func testHeaderOnlyFileHasZeroRows() throws {
        let reader = try CSVReader("a,b,c\r\n")
        XCTAssertEqual(reader.headers.count, 3)
        XCTAssertEqual(reader.rows().count, 0)
    }

    func testEmptyInputThrows() {
        XCTAssertThrowsError(try CSVReader(""))
    }

    func testShortRowsArePaddedLongRowsTruncated() throws {
        let reader = try CSVReader("a,b,c\r\n1\r\n1,2,3,4\r\n")
        let rows = reader.rows()
        XCTAssertEqual(rows[0]["b"], "")     // padded
        XCTAssertEqual(rows[1]["c"], "3")    // truncated at header width
    }

    // MARK: Typed accessors

    func testISO8601DateRoundtrip() throws {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        var w = CSVWriter(headers: ["d"])
        w.appendRow([CSVWriter.iso8601(date)])
        let reader = try CSVReader(String(data: w.data(), encoding: .utf8)!)
        let parsed = reader.rows()[0].date("d")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testDecimalIsLocaleIndependent() throws {
        // CSVWriter.decimal MUSS "." schreiben, nie "," — sonst kollidiert
        // der Wert mit dem Feld-Separator auf DE-Geräten.
        XCTAssertEqual(CSVWriter.decimal(82.5), "82.50")
        let reader = try CSVReader("w\r\n82.50\r\n")
        XCTAssertEqual(reader.rows()[0].double("w"), 82.5)
    }

    func testBoolAccessor() throws {
        let reader = try CSVReader("a,b,c,d\r\ntrue,false,1,banana\r\n")
        let row = reader.rows()[0]
        XCTAssertEqual(row.bool("a"), true)
        XCTAssertEqual(row.bool("b"), false)
        XCTAssertEqual(row.bool("c"), true)
        XCTAssertNil(row.bool("d"))
    }

    // MARK: Altbestand — additive Spalten, die eine ÄLTERE CSV gar nicht kennt

    /// P9-Audit-Nachweis: eine Spalte, die in der Header-Zeile komplett
    /// FEHLT (echter Altbestand vor der Spalten-Einführung — nicht bloß ein
    /// LEERER Wert einer bekannten Spalte), muss sich für jeden typisierten
    /// Accessor exakt wie ein leerer Wert verhalten: `nil`, nie ein Crash,
    /// nie ein erratener Wert. Trägt die zahlreichen "additive Spalte,
    /// Altbestand liefert nil"-Kommentare in `DataImportService.swift`
    /// (`activated_at_utc`, `review_completed_at_utc`, `generator_input_raw`,
    /// …) erstmals auf Ebene des Parsers selbst nach, statt sich nur auf das
    /// `?? ""`-Subscript-Verhalten zu verlassen.
    func testMissingColumnEntirelyBehavesLikeAnEmptyValueForEveryTypedAccessor() throws {
        // Bewusst OHNE "activated_at_utc"/"review_completed_at_utc"-Spalte —
        // simuliert ein Backup von VOR deren Einführung.
        let reader = try CSVReader("id,name\r\n1,Plan A\r\n")
        let row = reader.rows()[0]
        XCTAssertEqual(row["activated_at_utc"], "", "Subscript auf unbekannte Spalte muss leer sein, nie crashen")
        XCTAssertNil(row.date("activated_at_utc"))
        XCTAssertNil(row.int("activated_at_utc"))
        XCTAssertNil(row.double("activated_at_utc"))
        XCTAssertNil(row.optionalString("activated_at_utc"))
        XCTAssertEqual(row.bool("activated_at_utc"), false, "bool() liefert fuer leer/fehlend false, nicht nil — wie fuer eine bekannte, aber leere Spalte")
    }
}
