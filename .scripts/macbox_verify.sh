#!/bin/bash
# macbox_verify.sh — Source-Root-Wrapper für macbox (Issue #25)
#
# Was dieser Wrapper garantiert:
#   1. --dir zeigt auf den aufrufenden Worktree (kein versehentlicher Main-Sync)
#   2. Quelle (dir, branch, sha) wird vor dem Build geloggt
#   3. Uncommittete + ungetrackte Dateien werden gemeldet (macbox synct sie alle)
#   4. SHA-Vergleich wenn macbox setup-Output liefert (nur bei Fehlern/erstem Build)
#   5. Fail-hard bei MACBOX_REMOTE_SHA: missing/unknown/Mismatch
#
# Was dieser Wrapper NICHT garantiert:
#   - Dass die kompilierten Quelldateien exakt dem HEAD-SHA entsprechen
#   - Pro-Build Remote-Inhaltsverifikation (macbox gibt setup-Output nur bei Fehlern zurück)
#   - SHA-Bestätigung für erfolgreiche Folge-Builds (kein macbox-API-Support)
#
# Verwendung: .scripts/macbox_verify.sh <macbox-befehl> [--dir /pfad] [opts]
# Beispiel:   .scripts/macbox_verify.sh build --scheme Deltiq
# Beispiel:   .scripts/macbox_verify.sh build --dir /pfad/zum/worktree --scheme Deltiq

set -euo pipefail

# --dir aus Argumenten extrahieren
declare -a ARGS=()
SOURCE_DIR=""
NEXT_IS_DIR=false

for arg in "$@"; do
    if [ "$NEXT_IS_DIR" = true ]; then
        SOURCE_DIR="$arg"
        NEXT_IS_DIR=false
    elif [ "$arg" = "--dir" ]; then
        NEXT_IS_DIR=true
    elif [[ "$arg" == --dir=* ]]; then
        SOURCE_DIR="${arg#--dir=}"
    fi
    ARGS+=("$arg")
done

# Falls kein --dir übergeben: git-Toplevel des aufrufenden Verzeichnisses (nicht des Skripts)
DIR_ADDED=false
if [ -z "$SOURCE_DIR" ]; then
    SOURCE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
    ARGS+=("--dir" "$SOURCE_DIR")
    DIR_ADDED=true
fi

# --dir validieren
if [ ! -d "$SOURCE_DIR" ]; then
    echo "✗ FEHLER: --dir '$SOURCE_DIR' existiert nicht." >&2
    exit 1
fi
if ! git -C "$SOURCE_DIR" rev-parse HEAD > /dev/null 2>&1; then
    echo "✗ FEHLER: --dir '$SOURCE_DIR' ist kein gültiges Git-Repository." >&2
    exit 1
fi

# SHA und Branch aus SOURCE_DIR (nicht aus Skript-Verzeichnis)
SOURCE_SHA="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
SOURCE_BRANCH="$(git -C "$SOURCE_DIR" rev-parse --abbrev-ref HEAD)"

# Worktree-Erkennung: .git ist eine Datei in Worktrees, ein Verzeichnis im Haupt-Checkout
IS_WORKTREE=false
if [ -f "$SOURCE_DIR/.git" ]; then
    IS_WORKTREE=true
fi

# Dirty-Worktree erkennen: uncommittete Änderungen UND ungetrackte neue Dateien.
# macbox synchronisiert beides; HEAD-SHA bildet weder das eine noch das andere ab.
# git status --porcelain --untracked-files=normal: zeigt auch neue Dateien (??),
# aber nicht gitignorierte (also nicht .macbox/sha_marker oder branch_marker).
DIRTY_LINES="$(git -C "$SOURCE_DIR" status --porcelain --untracked-files=normal 2>/dev/null || true)"
DIRTY_COUNT=0
if [ -n "$DIRTY_LINES" ]; then
    DIRTY_COUNT="$(echo "$DIRTY_LINES" | wc -l | tr -d ' ')"
fi

echo "=== macbox Source-Root-Wrapper (Issue #25) ==="
echo "Quelle-Dir:     $SOURCE_DIR"
echo "Branch:         $SOURCE_BRANCH"
echo "HEAD-SHA:       $SOURCE_SHA"
echo "Ist Worktree:   $IS_WORKTREE"
[ "$DIR_ADDED" = true ] && echo "→ --dir automatisch hinzugefügt"
if [ "$DIRTY_COUNT" -gt 0 ]; then
    echo "⚠  Dirty Worktree: $DIRTY_COUNT Datei(en) mit uncommitteten/ungetrackten Änderungen"
    echo "$DIRTY_LINES" | head -5 | sed 's/^/   /'
    [ "$DIRTY_COUNT" -gt 5 ] && echo "   ... ($DIRTY_COUNT gesamt)"
    echo "   HINWEIS: HEAD-SHA ($SOURCE_SHA) bildet diese Änderungen NICHT ab."
    echo "   macbox synchronisiert trotzdem alle Dateien inkl. ungetrackte."
fi

# SHA-Marker und Branch-Marker schreiben:
# macbox synchronisiert kein .git, daher schreiben wir die lokale HEAD-SHA
# in eine Datei, die setup auf dem Remote-Mac lesen kann.
# branch_marker und sha_marker müssen beide explizit mit --include übergeben werden,
# da sie in .gitignore stehen und macbox gitignorierte Dateien sonst überspringt.
MARKER_FILE="$SOURCE_DIR/.macbox/sha_marker"
BRANCH_MARKER="$SOURCE_DIR/.macbox/branch_marker"
mkdir -p "$SOURCE_DIR/.macbox"
printf '%s\n' "$SOURCE_SHA" > "$MARKER_FILE"
printf '%s\n' "$SOURCE_BRANCH" > "$BRANCH_MARKER"
ARGS+=("--include" ".macbox/sha_marker")
ARGS+=("--include" ".macbox/branch_marker")
echo "→ SHA-Marker:    $MARKER_FILE"
echo "→ Branch-Marker: $BRANCH_MARKER"

echo ""
echo "Ausführen: macbox ${ARGS[*]}"
echo ""

# macbox ausführen
set +e
MACBOX_OUTPUT=$(macbox "${ARGS[@]}" 2>&1)
EXIT_CODE=$?
set -e
echo "$MACBOX_OUTPUT"

# Remote-SHA aus macbox-Output (von .macbox/setup gesetzt, wenn setup lief)
# HINWEIS: macbox gibt setup-Output NUR bei Buildfehlern zurück, nicht bei Erfolg.
# SHA-Verifikation greift daher nur in Ausnahmefällen (Fehler oder erste Setup-Ausführung).
REMOTE_SHA=$(echo "$MACBOX_OUTPUT" | grep "^MACBOX_REMOTE_SHA:" | awk '{print $2}' | head -1 || true)

echo ""

if [ -n "$REMOTE_SHA" ]; then
    # setup-Output liegt vor → SHA verifizieren
    if [ "$REMOTE_SHA" = "unknown" ] || [ "$REMOTE_SHA" = "missing" ]; then
        echo "✗ FEHLER: Remote-SHA ist '$REMOTE_SHA' — Marker-Datei fehlte auf dem Remote-Mac." >&2
        echo "   Erwarteter SHA: $SOURCE_SHA" >&2
        echo "   .macbox/sha_marker wurde nicht korrekt synchronisiert." >&2
        exit 1
    fi
    echo "Remote-SHA: $REMOTE_SHA"
    if [ "$SOURCE_SHA" = "$REMOTE_SHA" ]; then
        echo "✓ SHA-Match: Remote-Mac hat denselben HEAD-SHA empfangen."
        echo "  (SHA-Match beweist Marker-Sync, nicht zwingend identische Dateiinhalte)"
    else
        echo "✗ SHA-MISMATCH — Remote-Mac hat einen anderen SHA als erwartet!" >&2
        echo "  Erwartet:  $SOURCE_SHA" >&2
        echo "  Empfangen: $REMOTE_SHA" >&2
        echo "  Prüfe ob --dir korrekt gesetzt ist." >&2
        exit 1
    fi
else
    # Kein SHA im Output: normaler Folge-Build (macbox gibt setup-Output nur bei Fehlern zurück)
    if [ "$EXIT_CODE" -eq 0 ]; then
        echo "✓ Build erfolgreich."
        echo "  --dir:          $SOURCE_DIR  (korrekte Synchronisierung)"
        echo "  HEAD-SHA:       $SOURCE_SHA  (nicht remote verifiziert)"
        echo "  Remote-SHA:     unbekannt — macbox gibt setup-Output nur bei Fehlern zurück"
        echo "  Status:         UNVERIFIED — Source-Root korrekt gesetzt, SHA nicht bestätigt"
    fi
fi

exit "$EXIT_CODE"
