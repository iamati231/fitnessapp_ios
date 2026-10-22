# Lebensmittel-Katalog-Erweiterung: Online-Suche + Eigenes Lebensmittel (Design)

**Status:** Freigegeben (Online-Suche: ursprünglich freigegeben; Amendment
vom 2026-10-22 ergänzt "Eigenes Lebensmittel anlegen" als zweiten,
unabhängigen Weg, explizit vom Nutzer nachgefordert — siehe Abschnitt
"Eigenes Lebensmittel anlegen (manuell)").

## Ziel

Zwei unabhängige, aber dieselbe Grundlage teilende Wege, einen fehlenden
Katalogtreffer zu beheben:

1. **Online-Suche** (Open Food Facts): Wenn ein Lebensmittel weder im
   lokalen ~100-Eintrag-Katalog noch über die KI-Freitext-Erfassung
   (Task E) einen eindeutigen Treffer hat, soll der Nutzer — nach
   explizitem Opt-in und nur bei verfügbarem Netz — online suchen, einen
   Treffer auswählen, die Nährwerte vor dem Speichern sehen/korrigieren
   und erst nach Bestätigung einen neuen lokalen Katalogeintrag anlegen.
2. **Eigenes Lebensmittel anlegen** (manuell, kein Netz/KI nötig): der
   Nutzer kann jederzeit — unabhängig von Online-Suche, KI-Verfügbarkeit
   oder Internetzugang — ein Lebensmittel von Hand mit Name und
   Nährwerten pro 100g anlegen, lokal speichern und später wiederfinden.

Beide Wege erzeugen denselben Ergebnistyp (einen neuen, lokal
gespeicherten `FoodCatalogEntry`) über denselben erweiterten Mechanismus
— siehe "`FoodCatalogEntry` — additive Erweiterung" unten.

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

**Amendment-Entscheidung:** statt eines reinen `isOnlineImported: Bool`
(ursprünglicher Entwurf) bekommt `FoodCatalogEntry` ein allgemeineres
Herkunfts-Feld, das online importierte UND manuell angelegte Einträge
einheitlich abdeckt — keine zwei leicht unterschiedlichen
"Custom-Food"-Mechanismen nebeneinander:

```swift
public enum FoodCatalogEntrySource: String, Codable, Sendable {
    case seeded          // einer der ~100 mitgelieferten Katalogeintraege
    case onlineImported  // via Open-Food-Facts-Suche uebernommen
    case userCreated     // manuell vom Nutzer angelegt
}
```

Zwei neue, additive Felder (kein `VersionedSchema` nötig, Projekt-
Konvention — bestehende `FoodCatalogEntry`-Zeilen ohne dieses Feld gelten
implizit als `.seeded`, siehe Migrations-Hinweis unten):

- `displayName: String?` — wenn gesetzt, zeigt die UI diesen Klartext-Namen
  statt `nameKey` über `String(localized:)` aufzulösen. Online importierte
  UND manuell angelegte Einträge haben keinen xcstrings-Key (kann zur
  Laufzeit nicht angelegt werden) und brauchen deshalb einen echten Namen
  statt eines Lookup-Keys. `resolvedName(for:)` in `AddMealView.swift`
  wird entsprechend erweitert: `displayName` hat Vorrang vor der
  `nameKey`-Auflösung.
- `source: FoodCatalogEntrySource` (Default `.seeded` für bestehende
  Zeilen) — ersetzt das ursprünglich geplante `isOnlineImported: Bool`.
  Wird gebraucht, um online importierte und manuell angelegte Einträge
  einheitlich als Nutzerdaten statt Katalogdaten zu behandeln (siehe
  nächster Abschnitt).

**Migrations-Hinweis:** da SwiftData ein additives, nicht-optionales Feld
mit Default-Wert bei bestehenden Zeilen automatisch auf den Default setzt
(kein `VersionedSchema` nötig, Projekt-Konvention), bekommen alle ~100
bereits seedierten Zeilen beim ersten Start nach dem Update automatisch
`source == .seeded` — kein manueller Backfill nötig.

### Nutzerdaten-Scope (Export/Wipe)

Einträge mit `source != .seeded` (also `.onlineImported` UND
`.userCreated`) gelten als **Nutzerdaten**, nicht als Katalogdaten:

- `Sources/FitnessAppData/Export/UserDataWipe.swift`: `deleteSharedUserData`
  löscht `FoodCatalogEntry`-Zeilen mit `source != .seeded` mit (die
  seedierten ~100 Einträge bleiben unberührt — kein globales Löschen aller
  `FoodCatalogEntry`).
- `DataExportService.swift`/`DataImportService.swift`: Einträge mit
  `source != .seeded` werden mit exportiert/importiert (gleiches Muster
  wie `meals.csv`/`meal_items.csv` aus dem vorherigen Plan, `source`-Wert
  wird mitexportiert, damit Import die Unterscheidung behält), seedierte
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
   (`source = .onlineImported`, `displayName` gesetzt) und fügt ihn direkt
   wie einen normalen Katalogtreffer der aktuellen Mahlzeit hinzu (über den
   bestehenden `addItem`/`save()`-Pfad — keine neue Persistenz-Logik).
5. Danach ist der Eintrag ein normaler, lokal gespeicherter Katalogeintrag
   — auch für künftige Suchen sofort auffindbar.

### Fehlerfälle (Online-Suche)

- Kein Netz: Aktion "Online suchen" ist ausgeblendet oder zeigt einen
  kurzen Hinweis statt eines leeren/blockierten Zustands (analog zum
  `.unavailable`-Pattern aus den Tasks D-F).
- Rate-Limit erreicht / Timeout / ungültige Antwort: lokalisierter
  Fehlertext, keine stille leere Liste, manuelle Erfassung bleibt
  jederzeit als Fallback nutzbar.
- Keine Treffer bei Open Food Facts: lokalisierter Hinweis, kein
  automatisches Anlegen eines leeren/geratenen Eintrags.

## Eigenes Lebensmittel anlegen (manuell)

Dritter Weg neben Katalogsuche und Online-Suche, **ohne Netz/KI-
Abhängigkeit** — jederzeit erreichbar, auch offline.

### Einstiegspunkt

Zusätzliche, sichtbar beschriftete Aktion "Eigenes Lebensmittel anlegen"
an denselben beiden Stellen wie die Online-Suche
(`nutrition.addMeal.noResults`-Zustand der manuellen Suche UND in der
KI-Kandidaten-Zeile ohne Katalogtreffer), PLUS — da dieser Weg nie an
Opt-in/Netz/KI gebunden ist — als eigenständig jederzeit sichtbare Aktion
im Lebensmittel-Suchbereich selbst (nicht nur im "0 Treffer"-Zustand),
damit der Nutzer auch ohne vorherige erfolglose Suche direkt ein eigenes
Lebensmittel anlegen kann.

### Formular

- **Pflicht:** Name (Klartext → `displayName`), Nährwertbasis (fest:
  Angabe pro 100g, konsistent mit allen bestehenden Katalogeinträgen —
  keine abweichende Basis wie "pro Portion" zur Auswahl, um
  Inkonsistenz im Katalog zu vermeiden), kcal/Protein/Kohlenhydrate/Fett
  pro 100g.
- **Optional:** Stückgewicht in Gramm (`pieceWeightGrams`) UND/ODER
  Dichte in g/ml (`densityGramsPerMl`) — nur wenn der Nutzer sie explizit
  einträgt; ohne Angabe bleiben Stück-/ml-Einheiten für diesen Eintrag
  nicht verfügbar (gleiche Regel wie für seedierte Katalogeinträge: "Stück
  nur mit definiertem Stückgewicht, Milliliter nur mit explizit
  lebensmittelspezifischer Dichte — niemals pauschal 1 ml = 1 g").
- Validierung: alle Pflichtfelder gesetzt und numerisch plausibel (keine
  negativen Werte) — nutzt dieselbe Validierungs-/Formatierungs-Logik wie
  bestehende Zahlen-Eingabefelder in der App (siehe auch Abschnitt
  "Appweite UI-Konsistenz" im zugehörigen separaten Arbeitspaket für
  Tastatur-/Eingabe-Standards).

### Speichern

- Explizite Bestätigung (sichtbar beschrifteter Speichern-Button, kein
  Auto-Save) legt `FoodCatalogEntry` mit `source = .userCreated` an.
- **Schutz gegen Mehrfachtap:** Speichern-Aktion deaktiviert sich sofort
  nach dem ersten Tap bis die Persistenz abgeschlossen ist (gleiches
  Pattern wie der bestehende Doppeltipp-Schutz aus Task E) — keine
  stillen Duplikate.
- Bei Speicherfehler: Entwurf bleibt erhalten, keine Erfolgsmeldung
  (gleiche Regel wie der bestehende Mahlzeiten-Speicherpfad).
- Nach Bestätigung: Eintrag ist sofort normaler, lokal gespeicherter
  Katalogeintrag — auffindbar über die normale Katalogsuche, übersteht
  Kaltstart (reguläre SwiftData-Persistenz, kein Sonderfall).

### Fehlerfälle (Eigenes Lebensmittel)

- Kein Netz: betrifft dieses Feature nicht — funktioniert immer.
- Ungültige/unvollständige Eingabe: Speichern-Button bleibt deaktiviert,
  lokalisierter Hinweis welches Feld fehlt/ungültig ist.

## Global Constraints (dieses Feature)

- Netzwerkzugriff NUR in `FitnessAppFoodLookup`, nie in `FitnessAppAI`,
  `FitnessAppCore`, `FitnessAppData` oder UI-Code direkt. "Eigenes
  Lebensmittel anlegen" macht NIE einen Netzwerkzugriff — rein lokale
  SwiftData-Persistenz.
- Netzwerkzugriff (Online-Suche) NUR nach explizitem Opt-in — Standard
  ist aus. "Eigenes Lebensmittel anlegen" braucht KEINEN Opt-in (keine
  Netzwerkkomponente).
- Jede Netzwerkanfrage trägt einen identifizierenden `User-Agent`.
- Kein Nährwert wird je erfunden/interpoliert — fehlende Felder (Online-
  Suche) bleiben leer, nie ein Platzhalterwert; bei "Eigenes Lebensmittel"
  sind alle vier Makro-Felder Pflicht (der Nutzer selbst ist die Quelle).
- Neuer Katalogeintrag entsteht ausschließlich nach expliziter
  Nutzerbestätigung (Vorschau + Bestätigen bzw. expliziter
  Speichern-Tap) — kein Auto-Save.
- Jeder neue sichtbare Text geht über `Localizable.xcstrings` (DE/EN/TR).
- Rundung/Formatierung ausschließlich über bestehende
  `DoubleFormatting.swift`-Extensions.
- Keine Logs von Suchbegriffen, Nährwerten oder Rohantworten der API.
- ODbL-Attribution ist sichtbar, sobald die Online-Suche genutzt wird
  (gilt nicht für "Eigenes Lebensmittel", da keine Fremddaten beteiligt
  sind).
- Keine bestehenden Daten werden beim Hinzufügen dieses Features gelöscht
  oder zurückgesetzt — additive SwiftData-Änderung, bestehende seedierte
  Katalogeinträge und alle Nutzerdaten bleiben unverändert erreichbar.

## Review Focus

- Rate-Limit-Verhalten unter schneller Wiederholung (Doppeltipp auf
  "Online suchen") — Debounce/Disable während laufender Anfrage, analog
  zum bereits in Task E gelösten Doppeltipp-Schutz. Gleiches gilt für den
  Speichern-Button bei "Eigenes Lebensmittel anlegen" (Mehrfachtap darf
  keine Duplikate erzeugen).
- Der in der finalen Branch-Review gefundene Mehrfach-Button-in-einer-Row-
  Bug (C1) darf in der neuen Trefferliste nicht wiederholt werden.
- Teilweise fehlende Nährwerte in der Open-Food-Facts-Antwort (z.B. nur
  kcal, keine Makros) — UI muss das sichtbar machen, nicht stillschweigend
  mit 0 auffüllen.
- Export/Import/Wipe-Pfade müssen Einträge mit `source != .seeded`
  korrekt von seedierten Katalogeinträgen unterscheiden — ein Bug hier
  könnte entweder Nutzerdaten beim Reset behalten (Datenschutz-Erwartung
  verletzt) oder seedierte Katalogdaten versehentlich löschen (App
  bricht). Gilt gleichermaßen für `.onlineImported` und `.userCreated`.
- Lokalisierung des `displayName`-Felds: da es Klartext statt eines
  xcstrings-Keys ist, bleibt es in der Sprache, in der der Nutzer gesucht/
  eingegeben hat — das ist beabsichtigt (keine automatische Übersetzung
  nutzergenerierter Namen), sollte aber explizit im Implementierungsplan
  als bewusste Entscheidung festgehalten werden, nicht als Lücke.
- "Eigenes Lebensmittel anlegen" ohne Stückgewicht/Dichte darf für diesen
  Eintrag später in der Mengenauswahl NICHT Stück/ml als Option anbieten
  — dieselbe Regel wie für seedierte Einträge, hier aber leicht zu
  übersehen, da der Nutzer gerade erst alle Felder selbst ausgefüllt hat.
