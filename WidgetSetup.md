# Widget Extension Setup (Live Activities)

Step-by-step guide for adding the Live-Activity widget that renders the rest-timer
on the Lock Screen and in the Dynamic Island. Picks up where `XcodeSetup.md` left off.

## 1. Widget Extension anlegen

1. **Xcode → File → New → Target...**
2. **Widget Extension** auswaehlen
3. Felder:
   - **Product Name:** `FitnessAppWidgets`
   - **Bundle Identifier:** `com.atamya.FitnessApp.widgets` (passt zur App-ID-Hierarchie)
   - **Include Live Activity:** ☑️ aktivieren  ← **wichtig**, generiert das Boilerplate
   - **Include Configuration App Intent:** ☐ kann aus bleiben (brauchen wir nicht)
4. **Embed in Application:** dein App-Target

Xcode legt das Target an und fuegt eine Boilerplate-Datei wie `FitnessAppWidgetsLiveActivity.swift` oder `FitnessAppWidgetsBundle.swift` in den Extension-Ordner.

## 2. Package-Dependency hinzufuegen

Das Widget braucht Zugriff auf `RestTimerAttributes` (in `FitnessAppActivities`):

1. Im Project Navigator das **Widget-Target** auswaehlen
2. Tab **General → Frameworks, Libraries, and Embedded Content**
3. **+** → `FitnessAppActivities` auswaehlen
4. **Frameworks erscheint mit `Embed: Do Not Embed`** — das ist richtig fuer ein
   Widget, da es im selben App-Bundle laeuft

Sollte `FitnessAppActivities` in der Liste fehlen: das Swift-Package ist nicht zur
App-Workspace hinzugefuegt — siehe `XcodeSetup.md` Schritt 2.

## 3. Info.plist-Eintraege

### App-Target (NICHT die Extension)

In `Info.plist` des App-Targets zwei Eintraege:

```xml
<key>NSSupportsLiveActivities</key>
<true/>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.atamya.FitnessApp</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fitnessapp</string>
        </array>
    </dict>
</array>
```

- `NSSupportsLiveActivities = YES` — ohne das ignoriert iOS unsere `Activity.request(...)`-Aufrufe stillschweigend
- `CFBundleURLTypes` registriert das Custom-Scheme `fitnessapp` — damit ein Tap auf das Widget die App oeffnet (siehe `FitnessAppDeepLink.scheme` im Package)

## 4. Widget-UI implementieren

Ersetze den von Xcode generierten Boilerplate-Code in
`FitnessAppWidgetsLiveActivity.swift` (oder wie auch immer Xcode die Datei genannt hat)
mit folgendem Code. Er verkabelt sich exakt mit `RestTimerAttributes` aus dem Package.

```swift
import ActivityKit
import WidgetKit
import SwiftUI
import FitnessAppActivities

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // ── Lock Screen / Banner ──────────────────────────────────────
            LockScreenTimerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded (long-press) ─────────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Satz \(context.attributes.setNumber) / \(context.attributes.totalSets)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Pause")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)            // verhindert Wackeln beim Sekundenwechsel
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.cyan)
            }
            // Tap → App oeffnet auf der ActiveWorkoutView. Scheme-Registrierung in
            // Info.plist (siehe Schritt 3) ist Pflicht — sonst macht das Tap nichts.
            .widgetURL(FitnessAppDeepLink.activeWorkout)
            .keylineTint(.cyan)
        }
    }
}

// MARK: - Lock Screen layout

private struct LockScreenTimerView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(context.attributes.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("Satz \(context.attributes.setNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(context.state.isFinished ? "Pause vorbei" : "Pause laeuft")
                    .font(.subheadline)
                Spacer()
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(context.state.isFinished ? .green : .cyan)
            }

            ProgressView(
                timerInterval: Date()...context.state.endDate,
                countsDown: true
            )
            .tint(context.state.isFinished ? .green : .cyan)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    }
}
```

## 5. Bundle-Konfiguration in `FitnessAppWidgetsBundle.swift`

Xcode generiert eine zweite Datei, die alle Widgets dieser Extension auflistet.
Stell sicher, dass `RestTimerLiveActivity()` darin enthalten ist:

```swift
import WidgetKit
import SwiftUI

@main
struct FitnessAppWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
        // Future Home-Screen-Widgets adden sich hier dazu.
    }
}
```

## 6. Deep-Link-Handling im App-Target

Tap auf das Widget oeffnet die App via `fitnessapp://workout/active`. Damit das
nicht ins Leere laeuft, in `FitnessAppApp.swift` einen `.onOpenURL`-Handler:

```swift
import SwiftUI
import FitnessAppUI
import FitnessAppData
import FitnessAppActivities

@main
struct FitnessAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    handle(url: url)
                }
        }
        .modelContainer(for: AppSchema.types)
    }

    private func handle(url: URL) {
        guard url.scheme == FitnessAppDeepLink.scheme else { return }
        // Naechster Schritt: AppNavigation injizieren und auf den Plan-Tab + die
        // aktive Session navigieren. Das brauchen wir aus `RootView` heraus —
        // siehe Issue "Deep-Link-Routing" im Backlog.
    }
}
```

(Den vollstaendigen Routing-Hook bauen wir, sobald das Widget kompiliert — er muss
auf `AppNavigation.workoutPath` zugreifen, was leichter ist sobald wir den Live-Test
hatten.)

## 7. Verifikation

1. **Compile**: Build der Widget-Extension allein muss durchgehen
2. **Compile App-Target**: muss weiterhin durchgehen
3. **Run im Simulator**: 
   - App starten → Onboarding durch → Plan anlegen → Tag → Uebung → Training starten
   - Ersten Satz speichern → in der Active-View sollte die Sticky-Bar erscheinen UND
     gleichzeitig die Dynamic Island am oberen Bildschirmrand zeigen, dass die Pause laeuft
   - App in den Hintergrund schieben (Cmd+Shift+H im Simulator) → Dynamic Island bleibt
     sichtbar, Lock-Screen-View zeigt die Karte
   - Lange auf die Island tippen → Expanded-View mit grossem Timer
4. **Skip-Test**: Im Simulator auf die Sticky-Bar tippen → Activity verschwindet sofort
5. **Auto-Complete-Test**: Kurzes `restSeconds` (z.B. 10s) setzen, Set loggen, warten —
   Activity sollte gruen werden, dann nach 8s vom Lock-Screen verschwinden

## Troubleshooting

- **Activity erscheint nicht**: `NSSupportsLiveActivities` fehlt in der App-Plist
- **"No such module 'FitnessAppActivities'"**: Library nicht zum Widget-Target hinzugefuegt
- **Widget-Tap macht nichts**: `CFBundleURLTypes` mit Scheme `fitnessapp` fehlt in der App-Plist
- **Activity zeigt 00:00 statisch**: `endDate` liegt in der Vergangenheit. `Text(timerInterval:countsDown:)` zaehlt selbststaendig — wir muessen NICHT pro Sekunde updaten
- **Compile-Fehler `Cannot find 'RestTimerAttributes'`**: Activities-Library nicht
  korrekt eingebunden, oder die App-Workspace zeigt das Package nicht
