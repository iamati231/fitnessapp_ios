# Xcode App-Target Setup

Schritt-fuer-Schritt-Anleitung, um das Swift-Package (`./` mit Sources/FitnessAppCore, FitnessAppData, FitnessAppUI) in ein echtes iOS-App-Target einzubinden. Sobald das App-Target laeuft, koennen wir auf native APIs wie HealthKit, Benachrichtigungen und Live Activities zugreifen.

## 1. Xcode-Projekt anlegen

1. **Xcode → File → New → Project**
2. **iOS → App** waehlen
3. Felder ausfuellen:
   - **Product Name:** `FitnessApp`
   - **Team:** dein Apple-Developer-Team (fuer spaetere HealthKit-Entitlements)
   - **Organization Identifier:** `com.atamya` (passend zu `a.isik@atamya.com`)
   - **Bundle Identifier** wird automatisch zu `com.atamya.FitnessApp`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None  ← wichtig, wir setzen den ModelContainer manuell auf
   - **Include Tests:** kannst du anhaken (App-Tests waeren fuer UI-Snapshots)
4. **Speicherort:** im selben Verzeichnis wie dieses Package (z.B. als Schwester-Ordner `fitnessapp_ios_app/` neben `fitnessapp_ios/`). So bleiben Package und App im Repo getrennt aber benachbart.

## 2. Swift-Package als lokale Dependency einbinden

1. Im Project Navigator (links) auf das **blaue Projekt-Icon ganz oben** klicken
2. Im mittleren Pane: **Targets → FitnessApp** waehlen
3. Tab **General → Frameworks, Libraries, and Embedded Content**
4. **+** klicken → **Add Other… → Add Local…**
5. Den Package-Ordner (`fitnessapp_ios/`) auswaehlen
6. **Wichtig:** alle drei Libraries hinzufuegen:
   - `FitnessAppCore`
   - `FitnessAppData`
   - `FitnessAppUI`

Wenn du nur eine Library hinzufuegst, beschwert sich der Linker spaeter ueber fehlende Symbole.

## 3. App-Entry-Point verkabeln

Xcode hat dir eine `FitnessAppApp.swift` generiert. Inhalt komplett ersetzen mit:

```swift
import SwiftUI
import FitnessAppUI
import FitnessAppData

@main
struct FitnessAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // AppSchema.types ist eine vorbereitete Liste aller acht @Model-Klassen.
        // Wenn wir spaeter neue Models hinzufuegen, brauchen wir HIER nichts zu aendern.
        .modelContainer(for: AppSchema.types)
    }
}
```

Das war's. **Drei Imports, eine Scene.** `RootView` regelt den Onboarding-vs-MainTabView-Switch automatisch via `@Query` auf `UserBodyProfile`.

## 4. Verifikation

Build & Run im iOS-Simulator (z.B. iPhone 15):

- Erster Start: **Onboarding-Screen**, weil noch kein Profil existiert
- Nach Profil-Anlage: **MainTabView** mit vier Tabs (Dashboard, Plan, Messung, Rechner)
- Plan anlegen → Tag anlegen → Uebung waehlen → Training starten → Set loggen → Pause-Timer → Speichern → Summary → Dashboard
- Auf dem Dashboard: Plan-Tag-Karte ("Naechstes Training"), Trend-Chart (sobald 3 Messungen vorhanden), Letzte Workouts

Wenn das alles funktioniert: Foundation steht.

## 5. Bundle-ID festhalten

Nach dem Anlegen die **Bundle-ID** notieren — typischerweise `com.atamya.FitnessApp`. Wir brauchen sie fuer:

- HealthKit-Capabilities (ans App-Target gebunden)
- App-Group fuer Live-Activities-Widget (separates Bundle, abgeleitet von der Haupt-ID)
- WidgetKit-Extension (Bundle-Suffix `.widget`)
- Benachrichtigungs-Capability (an Bundle-ID gebunden)

## 6. Naechste Integration: HealthKit

Sobald die App startet:

1. **Im App-Target die HealthKit-Capability aktivieren**:
   - Project Settings → Signing & Capabilities → **+ Capability** → **HealthKit**
2. **Info.plist:** zwei Keys hinzufuegen (sonst crasht der Permission-Flow):
   - `NSHealthShareUsageDescription`: "Liest dein Gewicht und deinen Koerperfett-Anteil aus Apple Health, damit du Werte nicht doppelt eintragen musst."
   - `NSHealthUpdateUsageDescription`: "Schreibt jede neue Messung zurueck nach Apple Health, damit deine Daten in einer Quelle leben."
3. **HealthKit-Service** kommt als neues Package-Target `FitnessAppHealth` — wird beim naechsten Schritt zusammen mit dem Permission-Flow gebaut.

## Troubleshooting

- **"No such module 'FitnessAppCore'"**: Package nicht eingebunden. Schritt 2 wiederholen, alle drei Libraries hinzufuegen.
- **"Cannot find 'RootView' in scope"**: `import FitnessAppUI` fehlt in `FitnessAppApp.swift`.
- **"Cannot find 'AppSchema' in scope"**: `import FitnessAppData` fehlt.
- **Package-Source-Aenderungen kommen nicht durch**: Xcode → Product → Clean Build Folder (Shift+Cmd+K), dann erneut bauen. Bei lokalen Packages cached Xcode aggressiv.
- **Preview crasht in Xcode**: das Package nutzt `PreviewSeed.*Container` mit In-Memory-Storage — das funktioniert in Xcode-Previews. Wenn ein Crash kommt, liegt's vermutlich an `@Query`-Fields ohne ModelContainer im Environment.
- **Profil-Reset**: aktuell gibt's keinen Reset-Knopf. Fuer Tests die App im Simulator unter **Device → Erase All Content and Settings** zuruecksetzen, oder den Simulator komplett neu installieren.
