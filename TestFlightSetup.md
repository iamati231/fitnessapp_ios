# TestFlight Release Setup

End-to-end-Anleitung für den ersten signierten TestFlight-Build, **nachdem** der
Apple Developer Program-Account aktiv ist (Bestätigungs-Mail von Apple).

Bis dahin ist der `testflight`-Workflow in der `codemagic.yaml` zwar
syntaktisch eingebaut, wird aber jeden Build mit "API key not configured"
abbrechen. Das ist gewollt — Codemagic darf nichts hochladen, solange der
Account nicht existiert.

---

## Phase 1: App Store Connect — App-Record anlegen (~5 Min)

1. Login auf <https://appstoreconnect.apple.com>
2. **My Apps → `+` → New App**
3. Eingaben:
   - **Platform**: iOS
   - **Name**: `Atamya Fitness` (oder dein Wunschname — kann später geändert
     werden)
   - **Primary Language**: Englisch (US)
   - **Bundle ID**: `com.atamya.FitnessApp` *(muss exakt mit `project.yml`
     übereinstimmen)*
   - **SKU**: `fitnessapp-ios-001` (egal was, muss nur unique in deinem
     Account sein)
   - **User Access**: Full Access
4. Submit. Du landest im neuen App-Record.
5. **Notiere die Apple ID des Apps**: App Information → unter "General
   Information" steht eine 10-stellige Zahl ("Apple ID"). Brauchen wir
   gleich für die `codemagic.yaml`.

---

## Phase 2: App Store Connect API Key (~3 Min, einmalig)

Codemagic braucht einen API-Key, um Builds für dich hochzuladen. **Ohne
diesen Key kann der Workflow nicht laufen.**

1. **Users and Access → Integrations → App Store Connect API → `+` Generate
   API Key**
2. Eingaben:
   - **Name**: `codemagic-uploader`
   - **Access**: `App Manager` (genug für TestFlight-Uploads)
3. Apple zeigt dir **EINMALIG** drei Werte. Kopiere alle drei sofort:
   - **Issuer ID**: oben auf der Seite, sieht aus wie eine UUID
     (`69a6de7…-…-…-…-…`)
   - **Key ID**: 10-stelliger Code neben dem Schlüsselnamen (z.B.
     `ABCDE12345`)
   - **API Key (.p8 file)**: Apple bietet einen "Download API Key"-Button.
     **Lädst du diese .p8-Datei nicht runter, ist sie unwiederbringlich
     verloren** — du musst dann einen neuen Key generieren.

   Ablage-Empfehlung: Lege die `.p8`-Datei und die beiden IDs in deinen
   1Password-Vault (oder ähnlich). Niemals committen.

---

## Phase 3: Codemagic — API-Key hinterlegen (~2 Min)

1. Login auf <https://codemagic.io>
2. **Teams → Personal Account → Integrations → App Store Connect → Add new
   key**
3. Eingaben:
   - **Name**: `atamya-asc-key` *(muss exakt mit `codemagic.yaml`
     übereinstimmen)*
   - **Issuer ID**: aus Phase 2
   - **Key ID**: aus Phase 2
   - **API key**: Inhalt der `.p8`-Datei (mit `-----BEGIN PRIVATE KEY-----`
     und `-----END PRIVATE KEY-----` Zeilen)
4. Save.

---

## Phase 4: Codemagic — Environment-Variablen-Group (~3 Min)

Die `codemagic.yaml` referenziert eine Variable-Group namens
`app_store_credentials`. Die müssen wir in der Codemagic-UI definieren —
**Secrets gehören NIEMALS in die yaml.**

1. **Apps → fitnessapp_ios → Workflow Editor → Environment variables**
2. **Add new group → Name: `app_store_credentials`**
3. In der Group, drei Variablen hinzufügen (alle als "Secure"):
   - `APP_STORE_CONNECT_PRIVATE_KEY` = Inhalt der `.p8`-Datei
   - `APP_STORE_CONNECT_KEY_IDENTIFIER` = Key ID aus Phase 2
   - `APP_STORE_CONNECT_ISSUER_ID` = Issuer ID aus Phase 2
4. Save.

---

## Phase 5: `codemagic.yaml` finalisieren (~1 Min)

In der `codemagic.yaml`, im `testflight`-Workflow:

```yaml
vars:
  XCODE_PROJECT: 'FitnessApp.xcodeproj'
  XCODE_SCHEME: 'FitnessApp'
  APP_STORE_APP_ID: '1234567890'   # ← Apple ID aus Phase 1, Schritt 5
```

Den 10-stelligen Apple-ID-Wert eintragen, committen, pushen.

---

## Phase 6: TestFlight Internal Testing-Group anlegen (~2 Min)

1. App Store Connect → deine App → **TestFlight → Internal Testing → `+`**
2. **Group Name**: `Atamya Internal`
3. **Add testers**: dich selbst zuerst. Später kannst du Freunde/Gym-Buddies
   per Email einladen — bis 100 Internal Tester sind erlaubt.
4. Save.

Der Group-Name `Atamya Internal` ist exakt das, was in `codemagic.yaml`
unter `beta_groups:` steht — wenn du ihn anders nennst, dort auch ändern.

---

## Phase 7: Den ersten Build pushen 🚀

```bash
# Markiere den aktuellen main-Stand als v0.1.0
git tag v0.1.0
git push origin v0.1.0
```

Das Tag triggered den `testflight`-Workflow. Was passiert in den nächsten
~10–15 Minuten:

1. Codemagic provisioniert sich automatisch ein Distribution-Cert + ein
   Provisioning-Profile via die ASC API
2. XcodeGen generiert das `.xcodeproj`
3. `xcode-project build-ipa` archiviert die App + signiert sie für die
   App Store-Distribution
4. Die `.ipa` wird zu App Store Connect hochgeladen
5. Apple "processes" den Build (~5–10 Min)
6. Du bekommst eine TestFlight-Email "Build 1 ready to test"
7. Auf deinem iPhone: TestFlight-App → Atamya Fitness → "Install"

Done. Erster Real-Device-Build live.

---

## Troubleshooting — die häufigsten Stolpersteine

| Symptom | Ursache | Fix |
|---|---|---|
| `No matching profiles found` | Bundle-ID stimmt nicht | `project.yml` `PRODUCT_BUNDLE_IDENTIFIER` muss exakt `com.atamya.FitnessApp` sein |
| `Build number already used` | Forgot to bump | Workflow tut das automatisch via `agvtool new-version` — wenn der Schritt fehlt, wird's blockt |
| `Invalid API key` | `.p8`-Inhalt enthält Whitespace | Codemagic-Variable: `.p8` mit `cat` ausgeben und reinkopieren, **nicht** öffnen-und-copy-paste aus dem Editor |
| `Missing privacy manifests` | iOS 17.2+-Anforderung | Ggf. später nachzulegen — nicht für die ersten TestFlight-Builds blocking |
| `App icon missing` | `AppIcon`-Asset im Asset-Catalog leer | Schaut in `App/FitnessApp/Assets.xcassets/AppIcon.appiconset/` — Slots müssen alle bestueckt sein |

---

## Was DANACH passiert

Nach dem ersten erfolgreichen TestFlight-Upload kannst du:

1. **Real-Device-Test der HealthKit-Integration**: Apple Health App → Browse →
   Body Measurements → Weight → Sample eintragen. Dann in der App: Messung
   neu öffnen → Gewicht sollte mit "Aus Apple Health uebernommen"-Badge
   vorausgefüllt sein.
2. **Real-Device-Test der PR-Celebration**: ein Workout durchführen, das
   einen PR aufstellt → Lock-Screen-Banner erwarten + Dynamic-Island-Trophy
   für ~8 Sekunden.
3. **Real-Device-Test des `HKWorkout`-Push**: Apple Health App → Browse →
   Workouts → das Workout sollte als "Traditional Strength Training"
   auftauchen, mit deinen Custom-Metadaten in den Workout-Details.
4. **Beta-Tester einladen**: über App Store Connect → TestFlight → Internal
   Testing → Add tester. Per Email-Adresse. Tester kriegen eine TF-Einladung.

Sobald die ersten Real-Device-Bugs gefixt sind und 5–10 Tester ein paar
Wochen ohne Crashes durchgehalten haben, geht's an den Public-Submit-Flow
(neuer Workflow `app-store-release`, anderer Build, separate Apple-Review-
Phase).
