import XCTest

/// Audit-Fund (Modul Programs-Core): `kettlebellEmomCandidate` berechnete die
/// Haerte des EMOM-Finisher-Tages hartcodiert mit `experience: .intermediate`,
/// unabhaengig von der tatsaechlich gewaehlten Erfahrungsstufe. Dadurch lag
/// der EMOM-Tag haerte-maessig auf einer anderen Skala als die uebrigen Tage
/// derselben Woche (`strengthCandidates` nutzt fuer Nicht-EMOM-Tage korrekt
/// `experience: selection.experience`), was `loadLevels`/`spreadByHardness`
/// verfaelscht. `hardness` ist intern und ueber die oeffentliche
/// `PlanGenerator.generate(from:)`-API nicht zuverlaessig isoliert
/// beobachtbar (die resultierende `PlanLoadLevel`-Bucket-Einteilung ist
/// relativ zu allen Tagen einer Woche und haengt zusaetzlich von den
/// konkreten, hier nicht gemockten Bibliotheks-Uebungen ab) - folgt deshalb
/// dem in dieser Codebase etablierten Source-Inspection-Muster (siehe
/// `ExerciseEditorCheckmarkSaveBeforeDismissTests`).
final class PlanGeneratorKettlebellEmomHardnessTests: XCTestCase {
    private var source: String {
        get throws {
            try String(
                contentsOf: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("Sources/DeltiqCore/Programs/PlanGenerator.swift"),
                encoding: .utf8
            )
        }
    }

    func testKettlebellEmomCandidateTakesAnExperienceParameter() throws {
        let code = try source
        guard let start = code.range(of: "private static func kettlebellEmomCandidate(") else {
            return XCTFail("kettlebellEmomCandidate signature not found")
        }
        guard let end = code.range(of: ") -> Candidate {", range: start.upperBound..<code.endIndex) else {
            return XCTFail("end of kettlebellEmomCandidate parameter list not found")
        }
        let signature = code[start.upperBound..<end.lowerBound]
        XCTAssertTrue(signature.contains("experience: DifficultyLevel"),
                      "kettlebellEmomCandidate muss eine echte Experience-Stufe entgegennehmen statt sie intern hartzucodieren")
    }

    func testKettlebellEmomCandidateUsesThePassedExperienceNotAHardcodedOne() throws {
        let code = try source
        guard let start = code.range(of: "private static func kettlebellEmomCandidate(") else {
            return XCTFail("kettlebellEmomCandidate not found")
        }
        guard let end = code.range(of: "private static func strengthHardness(", range: start.upperBound..<code.endIndex) else {
            return XCTFail("end of kettlebellEmomCandidate body not found")
        }
        let body = code[start.upperBound..<end.lowerBound]

        XCTAssertFalse(body.contains("experience: .intermediate"),
                       "die Haerteberechnung darf die Experience-Stufe nicht mehr hartcodieren")
        XCTAssertTrue(body.contains("strengthHardness(spec, sets: 3, experience: experience)"),
                      "die Haerteberechnung muss die uebergebene experience-Variable verwenden")
    }

    func testStrengthCandidatesPassesSelectionExperienceToTheEmomCandidate() throws {
        let code = try source
        guard let start = code.range(of: "result.append(kettlebellEmomCandidate(") else {
            return XCTFail("kettlebellEmomCandidate call site not found")
        }
        guard let end = code.range(of: "))", range: start.upperBound..<code.endIndex) else {
            return XCTFail("end of kettlebellEmomCandidate call not found")
        }
        let call = code[start.upperBound..<end.lowerBound]
        XCTAssertTrue(call.contains("experience: selection.experience"),
                      "der Aufruf muss die Experience-Stufe der Auswahl durchreichen, nicht stillschweigend weglassen")
    }
}
