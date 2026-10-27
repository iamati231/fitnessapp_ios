import XCTest

/// Audit-Fund (fokussierter Onboarding-Audit, Fund 2): der Plan-uebernehmen-
/// Button war an zwei Stellen hart auf Deutsch kodiert, unabhaengig von der
/// App-Sprache - `OnboardingView`s Vorschau-Sheet und
/// `ProgramTemplatePickerView`s Default-Parameter.
final class AdoptButtonTitleLocalizationTests: XCTestCase {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: sourcesRoot.appendingPathComponent(path), encoding: .utf8)
    }

    func testOnboardingPassesALocalizedAdoptButtonTitle() throws {
        let text = try read("FitnessAppUI/OnboardingView.swift")
        XCTAssertFalse(text.contains("adoptButtonTitle: \"Diesen Plan wählen\""),
                       "must not pass a hardcoded German literal")
        XCTAssertTrue(text.contains("adoptButtonTitle: String(localized: \"onboarding.plan.adoptButton\", bundle: .module)"))
    }

    /// `TemplatePreviewView.init` has no default for `adoptButtonTitle`
    /// (a `public init`'s default-argument expression is re-evaluated at
    /// the call site and may not reference `Bundle.module`, which is
    /// `internal`) — the picker's own NavigationLink must pass the
    /// localized title explicitly instead.
    func testTemplatePickerPassesALocalizedAdoptButtonTitleExplicitly() throws {
        let text = try read("FitnessAppUI/Workout/ProgramTemplatePickerView.swift")
        XCTAssertFalse(text.contains("adoptButtonTitle: String = \"Diesen Plan übernehmen\""),
                       "must not default to a hardcoded German literal")
        XCTAssertFalse(text.contains("adoptButtonTitle: String = String(localized:"),
                       "a public init must not default an argument to an expression using the internal Bundle.module")
        XCTAssertTrue(text.contains("adoptButtonTitle: String(localized: \"picker.plan.adoptButton\", bundle: .module)"))
    }

    func testBothAdoptButtonKeysExistWithAllThreeLanguages() throws {
        let xcstringsURL = sourcesRoot.appendingPathComponent("FitnessAppUI/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: xcstringsURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = json?["strings"] as? [String: Any]

        for key in ["onboarding.plan.adoptButton", "picker.plan.adoptButton"] {
            guard let entry = strings?[key] as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else {
                XCTFail("\(key) not found in Localizable.xcstrings")
                continue
            }
            for lang in ["de", "en", "tr"] {
                guard let langEntry = localizations[lang] as? [String: Any],
                      let stringUnit = langEntry["stringUnit"] as? [String: Any],
                      let value = stringUnit["value"] as? String,
                      !value.isEmpty
                else {
                    XCTFail("\(key) is missing a non-empty '\(lang)' translation")
                    continue
                }
            }
        }
    }
}
