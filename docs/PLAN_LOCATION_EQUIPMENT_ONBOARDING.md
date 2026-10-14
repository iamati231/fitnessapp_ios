# Phase 6 — Equipment-Onboarding abhängig vom Trainingsort

Branch `claude/smart-onboarding-epic`, baut auf Phase 1–4
(`docs/PLAN_EQUIPMENT_MATCHING_AUDIT.md`) und Phase 5
(`docs/PLAN_SUBSTITUTION_ENGINE.md`) auf. Quelle: vom User hochgeladene
`Anweisung_an_claude_code_etwas_pra_ziser.md`. Ziel: dieselbe Equipment-Logik
behalten, aber die Erfassung kontextabhängig vereinfachen (Gym = kein
Pflichtschritt, Home-Gym = voller Editor, Kein Equipment = kurze Frage).
**Keine zweite Equipment-Datenquelle, kein Umbau der Ersatzübungs-Engine,
keine Änderung an bestehenden Nutzerplänen** (explizite Vorgaben).

## 1. Entscheidungstabelle (Schritt 2 der Vorgabe)

| Aspekt | Gym | Home-Gym | Kein Equipment |
|---|---|---|---|
| Equipment-Schritt | **Kein Pflichtschritt.** Hinweistext + optionaler „Ausstattung anpassen"-Button öffnet den bestehenden `EquipmentProfileEditor` als Sheet | Voller, restrukturierter `EquipmentProfileEditor` (Abschnitte A–D, siehe §5) | Kurze Frage „Hast du kleine Trainingshilfen?" (KH/KB/Band) + „Nein, nur Körpergewicht" + „Später entscheiden" + optional „Weitere Ausstattung" |
| Ohne Interaktion | **Standard-Gym-Profil** (reine Planungsannahme, §4) | Alles bleibt `.unknown` (unverändert seit Phase 3) | Alles bleibt `.unknown` (unverändert seit Phase 3) |
| `equipmentProfileConfirmedComplete` | bleibt `false`, außer der User bestätigt explizit im Editor-Sheet | `true` nur bei explizitem "Weiter" (unverändert) | `true` nur bei „Nein, nur Körpergewicht" oder vollständiger Bestätigung (unverändert) |
| UI-Sprache im Default | „Wir planen für ein übliches Fitnessstudio. Fehlende Geräte kannst du jederzeit anpassen." NIE „Equipment bestätigt" | „Equipment bestätigt" / „Nur Körpergewicht bestätigt" (unverändert) | „Equipment bestätigt" / „Nur Körpergewicht bestätigt" (unverändert) |
| Matching/Vorschau | Effektives Profil = `gymDefault` überlagert von individuellen Angaben (§2). Banner zeigt Planungsannahme-Hinweis, NIE „Equipment passend/angepasst/fehlt" | Unveränderte Phase-4/5-Prüfung gegen das real erfasste Profil | Unveränderte Phase-4/5-Prüfung; zusätzlich `envMatches` gelockert (§3) |
| Persistenz | Keine neue Spalte — `environment` + `equipmentProfile` + `equipmentProfileConfirmedComplete` sind bereits vorhanden und reichen, um den Kontext jederzeit neu herzuleiten (siehe §7, wird in 6.6 verifiziert) | unverändert | unverändert |

**Warum keine vierte `EquipmentAvailability`-Fall:** `available`/`unavailable`/
`unknown` ist eine seit Phase 2 pervasiv genutzte, auch persistierte
Drei-Wert-Logik. Ein viertes `.assumed` hätte jeden Konsumenten (Checker,
Matcher, Substitutions-Engine, CSV, UI) angefasst — für eine reine
Planungsannahme, die nur am EINEN Punkt entsteht (Gym ohne Anpassung), ist
das unverhältnismäßig. Stattdessen trägt ein neuer, rein-rechnerischer
`EquipmentPlanningContext` (§2) die Information „woher kommt das
effektive Profil" NEBEN dem unveränderten `UserEquipmentProfile` — die
Drei-Wert-Logik selbst bleibt unangetastet.

## 2. `EquipmentPlanningContext` (Core, neu)

Neue Datei `Sources/FitnessAppCore/Programs/EquipmentPlanningContext.swift`:

```swift
public enum EquipmentPlanningSource: String, Sendable, Equatable {
    case confirmed       // Erfassung abgeschlossen (confirmRemainingAsUnavailable gelaufen)
    case gymAssumption   // Gym gewählt, nicht individuell eingerichtet — Standard-Gym-Annahme aktiv
    case unconfirmed     // Home-Gym/Kein Equipment, Erfassung läuft noch oder "später entscheiden"
}

public struct EquipmentPlanningContext: Sendable, Equatable {
    public let effectiveProfile: UserEquipmentProfile
    public let source: EquipmentPlanningSource
    public var isAssumption: Bool { source == .gymAssumption }
}

public enum EquipmentPlanningResolver {
    public static func resolve(
        environment: EnvironmentType,
        individualProfile: UserEquipmentProfile,
        confirmedComplete: Bool
    ) -> EquipmentPlanningContext {
        if confirmedComplete {
            return EquipmentPlanningContext(effectiveProfile: individualProfile, source: .confirmed)
        }
        if environment == .gym {
            return EquipmentPlanningContext(
                effectiveProfile: mergeIndividualOverGymDefault(individualProfile),
                source: .gymAssumption
            )
        }
        return EquipmentPlanningContext(effectiveProfile: individualProfile, source: .unconfirmed)
    }
}
```

`mergeIndividualOverGymDefault`: startet bei `UserEquipmentProfile.gymDefault`
und überschreibt JEDES Item, zu dem der User selbst schon eine Angabe
gemacht hat (ob `.available` ODER `.unavailable`) — nie umgekehrt. Das
erfüllt wörtlich: „Explizit fehlende Geräte dürfen niemals durch
Gym-Defaults überschrieben werden" und „Individuell bestätigte Angaben
haben Vorrang". Ein Item, das der User nie angefasst hat, bleibt die
Gym-Annahme — „unbekannte Standardgeräte dürfen als Annahme berücksichtigt
werden".

`confirmedComplete == true` gewinnt immer, unabhängig vom `environment` —
sobald die Erfassung (für JEDEN Ort, auch Gym über „Ausstattung anpassen")
abgeschlossen ist, gibt es keine Lücke mehr, die eine Annahme füllen müsste.

Reine Core-Funktion, keine SwiftData-Abhängigkeit, kein neuer persistierter
Zustand — vollständig auf Linux testbar.

## 3. `PlanMatchmaker.envMatches` — Erweiterung für `.noEquipment`

Bisher (Phase ≤5):
```swift
case .noEquipment: return plan == .noEquipment
```

Neu, symmetrisch zur bestehenden `.homeGym`-Regel:
```swift
case .homeGym, .noEquipment: return plan == .homeGym || plan == .noEquipment
```

**Warum sicher:** `envMatches` ist nur EINER von zwei UND-verknüpften
Hard-Filtern in `rankPlansDetailed` — der zweite, unveränderte
`equipmentMatches` entscheidet weiterhin über die TATSÄCHLICHE
Ausführbarkeit (Phase 4: nur `.unavailable`, also definitiv fehlendes
Geräte bei mindestens einer annotierten Übung, schließt aus; `.unknown`
lässt bewusst durch). Die Lockerung sorgt NUR dafür, dass ein
Home-Gym-getaggtes Template für `.noEquipment`-User überhaupt erst in die
engere Auswahl kommt — ob es WIRKLICH passt, entscheidet weiterhin die
präzise Prüfung. Ein `.gym`-getaggtes Template bleibt für
`.noEquipment`-User in jedem Fall ausgeschlossen (Vorgabe wörtlich:
„Ein Gym-Plan darf nicht allein deshalb zugelassen werden, weil eine
Kurzhantel vorhanden ist").

**Bewusste Konsequenz, dokumentiert statt übersehen:** auch ein
`.noEquipment`-User, der NOCH NICHTS bestätigt hat (Profil komplett
`.unknown`, z.B. direkt „Später entscheiden"), sieht dadurch jetzt
zusätzlich Home-Gym-Templates mit Status „unbekannt" statt sie hart
auszublenden. Das ist konsistent mit der seit Phase 2 geltenden
Drei-Wert-Philosophie („nie eine Option wegen Unsicherheit verstecken,
nie etwas Unsicheres als sicher passend behaupten") und mit der
Vorgabe selbst: „Maßgeblich sind konkrete Voraussetzungen... nicht der
Ort". `fallback(...)` (greift nur wenn ALLES rausgefiltert wurde) bleibt
unverändert auf dem reinen `.noEquipment`-Pool — das ist ein bewusst
separates, konservativeres Sicherheitsnetz.

`PlanSelectionResolver`/`ProgramInstantiator` kennen `environment`
ohnehin nicht (sie bekommen ein bereits gewähltes Template) — die
envMatches-Änderung wirkt ausschließlich auf die Empfehlungsliste, nicht
auf Vorschau/Instanziierung.

## 4. Standard-Gym-Profil (`UserEquipmentProfile.gymDefault`)

Explizit dokumentierte Annahme für ein **übliches** kommerzielles
Fitnessstudio — keine Spezialgeräte, keine Ringe, keine ungewöhnlichen
Aufbauten (Vorgabe wörtlich):

| Item | Angenommen | Begründung |
|---|---|---|
| `.barbell` | `.available` | Langhantel+Hantelbank ist Kern-Inventar jedes Studios |
| `.dumbbell` | `.available` (Anzahl unbekannt) | Kurzhantel-Rack ist Standard |
| `.adjustableBench` | `.available` | deckt per bestehender Konvention (`EquipmentRequirement.flatBench`-Doku) auch Flachbank-Anforderungen ab |
| `.flatBench` | `.unknown` | wird nie isoliert verlangt (immer `.any([.flatBench, .adjustableBench])`), daher ohne Wirkung — keine zusätzliche, unbelegte Behauptung nötig |
| `.rack` | `.available` | Kniebeugenständer/Power-Rack ist Standard |
| `.cableStation` | `.available` | Kabelzug ist Standard |
| `.machineStation` | `.available` | Maschinenpark ist Standard |
| `.pullUpBar` | `.available` | i.d.R. am Rack oder als eigene Station vorhanden |
| `.kettlebell` | `.unknown` | NICHT universell — viele Studios haben wenige/keine Kettlebells |
| `.resistanceBand` | `.unknown` | NICHT universell — eher Home-/Mitbring-Zubehör |

`kettlebell`/`resistanceBand` bleiben bewusst `.unknown` statt `.available`
ODER `.unavailable` — eine Vorlage, die sie fälschlich als vorhanden
behauptet, wäre eine erfundene Sicherheit; sie als fehlend zu markieren,
würde ohne jeden Beleg eine kettlebell-/band-lastige Variante zu Unrecht
ausschließen. `.unknown` ist hier die ehrliche Antwort.

## 5. `EquipmentProfileEditor` — Restrukturierung (Abschnitte A–D)

Wiederverwendet von Home-Gym-Step, dem neuen Gym-„Ausstattung anpassen"-Sheet
UND `ProfileEditorView` — weiterhin EINZIGE Equipment-UI-Implementierung.

- **A. Gewichte** — unverändert Mehrfachauswahl (`dumbbell`, `kettlebell`,
  `barbell`, `resistanceBand`), KH/KB weiterhin gleichzeitig wählbar.
- **B. Bank** — NEU als Einzelauswahl („Keine Bank" / „Flachbank" /
  „Verstellbare Bank" / „Weiß ich noch nicht") statt zwei unabhängiger
  Toggles. Mapping:
  | Auswahl | `flatBench` | `adjustableBench` |
  |---|---|---|
  | Keine Bank | `.unavailable` | `.unavailable` |
  | Flachbank | `.available` | `.unavailable` |
  | Verstellbare Bank | `.unavailable` | `.available` (deckt Flachbank-Bedarf über die bestehende `.any(...)`-Konvention ab — `flatBench` wird NICHT zusätzlich auf `.available` gesetzt, das wäre eine unbelegte Zusatzbehauptung) |
  | Weiß ich noch nicht | entfernt (→ `.unknown`) | entfernt (→ `.unknown`) |
- **C. Klimmzugstange** — NEU als Einzelauswahl „Ja"/„Nein"/„Weiß ich noch
  nicht" statt einem einzelnen Toggle (`pullUpBar` ist bereits ein einzelnes
  Item, daher direktes Mapping `available`/`unavailable`/entfernt).
- **D. Weitere Ausstattung** — aufklappbar (`DisclosureGroup`), NUR Items mit
  echter Core-Fähigkeit: `rack`, `cableStation`, `machineStation` (siehe §6).

Die alte flache Liste (10 gleichwertige Toggle-Zeilen) entfällt zugunsten
dieser Gruppierung; Datenmodell (`UserEquipmentProfile`/`EquipmentItem`)
bleibt vollständig unverändert — reine View-Restrukturierung.

## 6. Dip-Barren / Ringe-Schlingentrainer — bewusst NICHT hinzugefügt

Die Vorgabe nennt diese zwei Items in Abschnitt D, aber ausdrücklich nur
„Nur tatsächlich im Core-Modell vorhandene Fähigkeiten anbieten." Geprüft:
`EquipmentItem` kennt aktuell 10 Fälle, keiner davon Dip/Ringe; kein
`EquipmentRequirement` im gesamten Katalog verlangt sie (die einzige
Dip-Übung, „Dip (assistiert)", ist auf das grobe `.machine` getaggt, nicht
auf ein `EquipmentItem`). Ein UI-Toggle ohne jede Matching-Wirkung wäre
Equipment-Theater — stattdessen zeigt Abschnitt D nur `rack`/`cableStation`/
`machineStation`. Eine spätere Erweiterung (neues `EquipmentItem` +
Katalog-Audit, welche Übungen sie tatsächlich brauchen) ist expliziter
Scope dieser Phase NICHT.

## 7. Persistenz — erwartete Entscheidung (Verifikation folgt in 6.6)

`UserBodyProfile.environment`, `.equipmentProfile`, `.equipmentProfileConfirmedComplete`
sind bereits persistiert (CSV, Backup/Restore, Reset). `EquipmentPlanningContext`
wird bei Bedarf aus genau diesen drei Werten neu berechnet (reine Funktion,
§2) — es gibt keinen Grund, das Ergebnis selbst zu speichern. Erwartung:
**keine neue Spalte/Property nötig.** Wird in Task 6.6 gegen den
tatsächlichen Export-/Import-/Reset-Code verifiziert, nicht nur angenommen.

## 8. Pflicht-Test-Mapping (Vorgabe Abschnitt 6 → konkrete Tests)

| # | Szenario | Testebene |
|---|---|---|
| 1 | Gym ohne Anpassung: kein Pflichtschritt, Standard-Empfehlung, nicht bestätigt gespeichert | Core (`EquipmentPlanningResolverTests`) + manuelle UI-Prüfung |
| 2 | Gym mit explizit fehlendem Gerät: Default überschreibt Angabe nicht | Core |
| 3 | Home-Gym: nur KB, keine Bank, keine Stange → keine unveränderten KH-/Bank-/Klimmzug-Übungen als passend | Core (bestehende Phase-4-Infrastruktur, neuer Testfall) |
| 4 | Home-Gym: KH+KB+verstellbare Bank+Stange → Kombination bleibt vollständig erhalten | Core |
| 5 | Home-Gym: Flachbank → keine automatische Freigabe für Schrägbank | Core |
| 6 | Home-Gym: Bank ausdrücklich unbekannt → bleibt `unknown` | Core |
| 7 | Kein Equipment + Widerstandsband → bandbasierte Varianten möglich | Core (`PlanMatchmakerTests`) |
| 8 | Kein Equipment + Kurzhanteln → nicht nur durch Ortsfilter blockiert | Core (`PlanMatchmakerTests`, envMatches) |
| 9 | „Nein, nur Körpergewicht" → Zusatzgeräte gelten als fehlend, keine Gym-Annahme | Core |
| 10 | „Später entscheiden" → keine automatische Abwesenheitsbestätigung | Core |
| 11 | Ortswechsel/Zurück/Sheet-Abbruch → keine verlorenen Angaben | Manuell (reiner `@State`-Fluss, kein Core-Test möglich) + Code-Review |
| 12 | Vorschau und Übernahme: identische Variante + Planungskontext; geänderte Inhalte verlangen erneute Freigabe | Core (`ResolvedPlanSelection.isStale` gegen effektives Profil) |

Items 1 und 11 sind reine UI-/Navigations-Fragen ohne sinnvollen
SwiftData-/Core-Test — werden per Code-Review verifiziert und im
Abschlussbericht (6.10) explizit als „code-gelesen, nicht automatisiert
getestet" ausgewiesen, nicht stillschweigend als getestet behauptet.
