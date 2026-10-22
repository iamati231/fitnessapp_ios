# Online-Lebensmittelsuche (Open Food Facts) Design

**Status:** Entwurf — wartet auf Review durch den Nutzer.

## Ziel

Wenn ein Lebensmittel weder im lokalen ~100-Eintrag-Katalog noch über die
KI-Freitext-Erfassung (Task E) einen eindeutigen Treffer hat, soll der
Nutzer — nach explizitem Opt-in und nur bei verfügbarem Netz — online nach
dem Lebensmittel suchen, einen Treffer aus einer offenen Lebensmittel-
Datenbank auswählen, die Nährwerte vor dem Speichern sehen/korrigieren und
erst nach Bestätigung einen neuen lokalen Katalogeintrag anlegen.

Dieses Feature ist bewusst **unabhängig von `FitnessAppAI`/Foundation
Models** (Tasks D-F dieses Repos): es braucht kein Apple-Intelligence-
fähiges Gerät, funktioniert auf jedem iOS 17+-Gerät mit Internetzugang,
und bricht — anders als `FitnessAppAI` — bewusst mit dem Grundsatz
"KI ist strikt lokal", weshalb es eine eigene, klar abgegrenzte
Netzwerk-Komponente bekommt statt in `FitnessAppAI` eingebaut zu werden.

## Datenquelle: Open Food Facts

- Kostenlose, offene Lebensmittel-Datenbank, kein API-Key nötig.
- Endpunkt-Familie: `https://world.openfoodfacts.org/api/v2/...` (Produkt-
  Lookup per Barcode) bzw. die Such-API für Freitext-Namen.
- Rate-Limits (offizielle Doku, Stand der Recherche): 15 Lese-Anfragen/Min/IP
  für Produkt-Abrufe, 10 Anfragen/Min/IP für Suchanfragen — die Such-API ist
  der strengere Fall und bestimmt das Rate-Limit-Verhalten der App.
- **Pflicht:** jeder API-Aufruf braucht einen eigenen `User-Agent`-Header,
  der die App identifiziert (Projektauflage von Open Food Facts).
- **Lizenz:** Daten stehen unter ODbL (Open Database License) — Pflicht zu
  Attribution + Share-Alike. Die App muss Open Food Facts sichtbar nennen,
  sobald ein importierter Eintrag genutzt wird (siehe Attribution-Sektion).
- Daten sind crowd-gesourct — Vollständigkeit pro Produkt schwankt, jedes
  Feld muss auf Vorhandensein geprüft werden, nie blind angenommen.

## Architektur

### Neues Modul: `FitnessAppFoodLookup`

Eigenständiges SPM-Target, analog zur Isolation von `FitnessAppAI`:

- Abhängigkeiten: nur `FitnessAppCore` (für `FoodCatalogItem`-ähnliche
  Werttypen), **keine** Abhängigkeit zu `FitnessAppAI` und umgekehrt — die
  beiden Module bleiben vollständig getrennt, damit ein Reviewer an der
  Modul-Struktur ablesen kann: genau `FitnessAppFoodLookup` darf
  Netzwerkzugriffe machen, sonst niemand.
- Nutzt `URLSession` (bisher **nirgendwo** im Repo verwendet — dies ist der
  erste Netzwerk-Code der ganzen App; App Transport Security/Info.plist
  brauchen keine Ausnahme, da Open Food Facts HTTPS unterstützt).
- Öffentliche Schnittstelle (Form, exakte Signaturen folgen im
  Implementierungsplan nach einer kurzen API-Doku-Verifikation, analog zu
  Task D's Foundation-Models-Recherche):
  - Ein Werttyp für ein Suchergebnis: Name, Marke (falls vorhanden),
    Nährwerte pro 100g (kcal/Protein/Kohlenhydrate/Fett — optional, da
    crowd-gesourct), Quellen-Attribution.
  - Eine Protokoll-Schnittstelle fürs Suchen (injizierbar, analog
    `NutritionAIMealExtracting` aus Task E) — Tests laufen gegen Fakes,
    nie gegen die echte API.
  - Fehlerfälle als Enum: kein Netz, Rate-Limit erreicht, keine Treffer,
    ungültige Antwort — nie ein stiller leerer Erfolg.

### `FoodCatalogEntry` — additive Erweiterung

Zwei neue, optionale Felder (additiv, kein `VersionedSchema` nötig,
Projekt-Konvention):

- `displayName: String?` — wenn gesetzt, zeigt die UI diesen Klartext-Namen
  statt `nameKey` über `String(localized:)` aufzulösen. Online importierte
  Einträge haben keinen xcstrings-Key (kann zur Laufzeit nicht angelegt
  werden) und brauchen deshalb einen echten Namen statt eines Lookup-Keys.
  `resolvedName(for:)` in `AddMealView.swift` wird entsprechend erweitert:
  `displayName` hat Vorrang vor der `nameKey`-Auflösung.
- `isOnlineImported: Bool` (Default `false`) — markiert Einträge, die über
  dieses Feature entstanden sind, im Unterschied zu den ~100 seedierten
  Katalogeinträgen. Wird gebraucht, um diese Einträge als Nutzerdaten statt
  Katalogdaten zu behandeln (siehe nächster Abschnitt).

### Nutzerdaten-Scope (Export/Wipe)

Online importierte Einträge gelten als **Nutzerdaten**, nicht als
Katalogdaten:

- `Sources/FitnessAppData/Export/UserDataWipe.swift`: `deleteSharedUserData`
  löscht `FoodCatalogEntry`-Zeilen mit `isOnlineImported == true` mit (die
  seedierten ~100 Einträge bleiben unberührt — kein globales Löschen aller
  `FoodCatalogEntry`).
- `DataExportService.swift`/`DataImportService.swift`: online importierte
  Einträge werden mit exportiert/importiert (gleiches Muster wie
  `meals.csv`/`meal_items.csv` aus dem vorherigen Plan), seedierte
  Katalogeinträge weiterhin nicht (sie kommen über `FoodCatalogSeeder`
  zurück, nicht über Import).

### Opt-in-Einstellung

- Neuer Toggle in `Sources/FitnessAppUI/Settings/SettingsDataConnectionsView.swift`
  (thematisch passend — bestehender `externalWorkoutImportEnabled`-Toggle
  ist das Vorbild für Stil/Persistenz-Pattern), Default **aus**.
- Name/Copy z.B. "Online-Suche für unbekannte Lebensmittel" mit kurzem
  Erklärtext (sendet den Lebensmittel-Suchbegriff an Open Food Facts, wenn
  aktiviert).
- Ohne Opt-in: Verhalten bleibt exakt wie heute (kein Treffer = kein
  Treffer, keine neue Aktion sichtbar).

### Attribution

Neuer kurzer Abschnitt, nach dem Vorbild von
`Sources/FitnessAppUI/Settings/ExerciseMediaCreditsView.swift` (dort wird
bereits eine pflichtgemäße Attribution für die Übungs-GIFs gezeigt) — z.B.
ergänzt in derselben oder einer benachbarten Credits-Ansicht: Open-Food-
Facts-Namen, ODbL-Lizenzhinweis, Link zur Projektseite. Wird nur relevant
bzw. sichtbar gemacht, sobald der Opt-in-Schalter aktiviert ist oder
mindestens ein Eintrag importiert wurde (Sichtbarkeits-Detail für den
Implementierungsplan).

### UI-Flow

Zwei Einstiegspunkte, beide nur bei aktivem Opt-in + Netz verfügbar:

1. **Manuelle Suche, 0 Treffer** (`AddMealView.swift:181-182`, bestehender
   `nutrition.addMeal.noResults`-Zustand): zusätzliche Aktion "Online
   suchen" mit dem eingegebenen Suchtext.
2. **KI-Freitext-Kandidat ohne Katalogtreffer** (`MealDraftCandidate.hasNoCatalogMatch`
   aus Task E): zusätzliche Aktion in der bestehenden Kandidaten-Zeile,
   vorausgefüllt mit dem von der KI erkannten `foodText`.

Beide münden im selben Flow:

1. Anfrage an Open Food Facts mit dem Suchtext.
2. Trefferliste anzeigen (gleiches UI-Pattern wie die bestehende
   Mehrdeutigkeits-Auswahl aus Task E — **inklusive Fix für den dort in der
   finalen Review gefundenen Critical-Bug C1**, nie mehrere Default-Buttons
   in einer Form-Row).
3. Nutzer wählt einen Treffer → Vorschau: Name (editierbar, vorausgefüllt
   mit `displayName`-Entwurf aus dem Treffer) + Makros pro 100g (editierbar,
   vorausgefüllt aus den Open-Food-Facts-Nährwerten, falls vorhanden —
   fehlende Felder bleiben leer, nie geraten/interpoliert).
4. Explizite Bestätigung legt einen neuen `FoodCatalogEntry` an
   (`isOnlineImported = true`, `displayName` gesetzt) und fügt ihn direkt
   wie einen normalen Katalogtreffer der aktuellen Mahlzeit hinzu (über den
   bestehenden `addItem`/`save()`-Pfad — keine neue Persistenz-Logik).
5. Danach ist der Eintrag ein normaler, lokal gespeicherter Katalogeintrag
   — auch für künftige Suchen sofort auffindbar.

### Fehlerfälle

- Kein Netz: Aktion "Online suchen" ist ausgeblendet oder zeigt einen
  kurzen Hinweis statt eines leeren/blockierten Zustands (analog zum
  `.unavailable`-Pattern aus den Tasks D-F).
- Rate-Limit erreicht / Timeout / ungültige Antwort: lokalisierter
  Fehlertext, keine stille leere Liste, manuelle Erfassung bleibt
  jederzeit als Fallback nutzbar.
- Keine Treffer bei Open Food Facts: lokalisierter Hinweis, kein
  automatisches Anlegen eines leeren/geratenen Eintrags.

## Global Constraints (dieses Feature)

- Netzwerkzugriff NUR in `FitnessAppFoodLookup`, nie in `FitnessAppAI`,
  `FitnessAppCore`, `FitnessAppData` oder UI-Code direkt.
- Netzwerkzugriff NUR nach explizitem Opt-in — Standard ist aus.
- Jede Netzwerkanfrage trägt einen identifizierenden `User-Agent`.
- Kein Nährwert wird je erfunden/interpoliert — fehlende Felder bleiben
  leer, nie ein Platzhalterwert.
- Neuer Katalogeintrag entsteht ausschließlich nach expliziter
  Nutzerbestätigung (Vorschau + Bestätigen) — kein Auto-Save direkt aus
  dem Suchergebnis.
- Jeder neue sichtbare Text geht über `Localizable.xcstrings` (DE/EN/TR).
- Rundung/Formatierung ausschließlich über bestehende
  `DoubleFormatting.swift`-Extensions.
- Keine Logs von Suchbegriffen, Nährwerten oder Rohantworten der API.
- ODbL-Attribution ist sichtbar, sobald das Feature genutzt wird.

## Review Focus

- Rate-Limit-Verhalten unter schneller Wiederholung (Doppeltipp auf
  "Online suchen") — Debounce/Disable während laufender Anfrage, analog
  zum bereits in Task E gelösten Doppeltipp-Schutz.
- Der in der finalen Branch-Review gefundene Mehrfach-Button-in-einer-Row-
  Bug (C1) darf in der neuen Trefferliste nicht wiederholt werden.
- Teilweise fehlende Nährwerte in der Open-Food-Facts-Antwort (z.B. nur
  kcal, keine Makros) — UI muss das sichtbar machen, nicht stillschweigend
  mit 0 auffüllen.
- Export/Import/Wipe-Pfade müssen `isOnlineImported`-Einträge korrekt von
  seedierten Katalogeinträgen unterscheiden — ein Bug hier könnte entweder
  Nutzerdaten beim Reset behalten (Datenschutz-Erwartung verletzt) oder
  seedierte Katalogdaten versehentlich löschen (App bricht).
- Lokalisierung des `displayName`-Felds: da es Klartext statt eines
  xcstrings-Keys ist, bleibt es in der Sprache, in der der Nutzer gesucht
  hat — das ist beabsichtigt (keine automatische Übersetzung
  nutzergenerierter Namen), sollte aber explizit im Implementierungsplan
  als bewusste Entscheidung festgehalten werden, nicht als Lücke.
