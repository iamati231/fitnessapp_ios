# Übungs-GIFs aus externen Quellen

Die animierten GIFs unter [`Sources/FitnessAppUI/ExerciseGifs/`](Sources/FitnessAppUI/ExerciseGifs/)
sind **unveränderte Kopien** aus zwei externen Repos:

- **Metadaten** (Namen, Equipment, Zielmuskel — nicht Teil der App):
  [hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset),
  Daten-Anteil MIT-lizenziert.
- **Bilddateien** (die hier eingebundenen `.gif`s):
  [arvids-unavailable/openGym](https://github.com/arvids-unavailable/openGym),
  Pfad `media/gif/`.

## Bildrechte: Gym visual

Laut der `NOTICE.md` von `hasaneyldrm/exercises-dataset` gehört die Media
(Bilder + GIFs) **Gym visual** (<https://gymvisual.com/>) und wird dort "mit
Erlaubnis" weitergegeben — **nicht** unter der MIT-Lizenz des restlichen
Datensatzes. Pflichtbedingungen laut dieser NOTICE:

- Nur in 180×180 verwenden (Original-Auflösung, nicht hoch-/herunterskalieren).
- Bei jeder Verwendung folgenden Hinweis zeigen: **„© Gym visual — https://gymvisual.com/“**
  (in der App unter Einstellungen → Übungs-GIFs sichtbar).
- Volle Bedingungen: <https://gymvisual.com/content/3-terms-and-conditions-of-use>.
  Das Quell-Repo selbst sagt ausdrücklich: *"cloning this repo is not a
  license"* — Nutzung über das Zitat hinaus erfordert eine eigene Lizenz von
  Gym visual.

Die `media/gif/`-Dateien im `openGym`-Repo tragen denselben
`mediaId`-Namensraum wie die Gym-visual-Media im `exercises-dataset`-Repo,
sind in `openGym`s eigener `NOTICE.md` aber nicht gesondert dokumentiert.
`openGym` selbst ist ein eigenständiges Gym-Tracker-Webapp-Projekt
(AGPL-3.0) — davon wird hier **nur** der statische `media/gif/`-Ordner als
Bild-Asset übernommen, keine Zeilen Code.

## Stand der Kopie

- `exercises-dataset`-Commit: `7455efae41b330c265e7cd4b78dfa848e7ce5ebd`
- `openGym`-Commit: `c42ba6b98e3776af5981f20c05ba392238799670`
- Kopiert am: 2026-10-12, mit [`.scripts/build_exercise_gif_map.py`](.scripts/build_exercise_gif_map.py)
- Umfang: nur die GIFs, denen das Mapping-Skript eine App-Übung sicher
  zuordnen konnte (siehe [`GIF_MATCH_REPORT.md`](GIF_MATCH_REPORT.md)) —
  nicht alle ~1300 Dateien aus `openGym`.

## Aktualisieren

```bash
python3 .scripts/build_exercise_gif_map.py --refresh
```

Lädt Metadaten + Datei-Listing neu, matcht erneut gegen
`Sources/FitnessAppCore/Programs/ExerciseLibraryData.swift`, aktualisiert
`exercise_gif_map.json` / `GIF_MATCH_REPORT.md` / die generierten
Swift-Tabellen und lädt neue/fehlende GIFs nach. Danach die Commit-Hashes
oben nachtragen.
