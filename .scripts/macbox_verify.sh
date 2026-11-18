#!/bin/bash
# macbox_verify.sh — Wrapper um macbox, der:
#   1. --dir auf den aufrufenden Worktree setzt (Haupt-Fix für Issue #25)
#   2. Quelle (dir, branch, sha) vor dem Build meldet
#   3. Dirty-Worktree meldet (uncommittete Änderungen ≠ HEAD-SHA)
#   4. SHA-Mismatch blockiert, wenn macbox setup-Output zurückgibt (bei Fehlern)
#
# HINWEIS: macbox gibt setup-Output NUR bei Buildfehlern zurück, nicht bei Erfolg.
# SHA-Verifikation greift daher nur bei Fehlern — bei Erfolg gilt: --dir gesetzt = korrekt.
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

# Dirty-Worktree erkennen (uncommittete Änderungen sind im HEAD-SHA NICHT enthalten)
DIRTY=""
if ! git -C "$SOURCE_DIR" diff --quiet HEAD 2>/dev/null; then
    DIRTY="$(git -C "$SOURCE_DIR" diff --stat HEAD | tail -1)"
fi

echo "=== macbox SHA-Verifikation (Issue #25) ==="
echo "Quelle-Dir:        $SOURCE_DIR"
echo "Branch:            $SOURCE_BRANCH"
echo "Erwarteter SHA:    $SOURCE_SHA"
echo "Ist Worktree:      $IS_WORKTREE"
[ "$DIR_ADDED" = true ] && echo "→ --dir automatisch hinzugefügt"
if [ -n "$DIRTY" ]; then
    echo "⚠  Dirty Worktree:  uncommittete Änderungen vorhanden"
    echo "   $DIRTY"
    echo "   HINWEIS: git rev-parse HEAD bildet diese Änderungen NICHT ab."
    echo "   macbox synchronisiert trotzdem alle Dateien."
fi

# SHA-Marker schreiben: macbox synchronisiert kein .git, daher schreiben wir die
# lokale HEAD-SHA in eine Datei, die setup auf dem Remote-Mac lesen kann.
MARKER_FILE="$SOURCE_DIR/.macbox/sha_marker"
mkdir -p "$SOURCE_DIR/.macbox"
printf '%s\n' "$SOURCE_SHA" > "$MARKER_FILE"
printf '%s\n' "$SOURCE_BRANCH" > "$SOURCE_DIR/.macbox/branch_marker"
ARGS+=("--include" ".macbox/sha_marker")
echo "→ SHA-Marker geschrieben: $MARKER_FILE"

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
# macbox gibt setup-Output NUR bei Buildfehlern zurück — nicht bei Erfolg.
REMOTE_SHA=$(echo "$MACBOX_OUTPUT" | grep "^MACBOX_REMOTE_SHA:" | awk '{print $2}' | head -1 || true)

echo ""

if [ -n "$REMOTE_SHA" ]; then
    # setup-Output liegt vor → SHA verifizieren (typisch bei Fehlern oder erstem Build)
    if [ "$REMOTE_SHA" = "unknown" ] || [ "$REMOTE_SHA" = "missing" ]; then
        echo "✗ FEHLER: Remote-SHA ist '$REMOTE_SHA' — Marker-Datei fehlte auf dem Remote-Mac." >&2
        echo "   Erwarteter SHA: $SOURCE_SHA" >&2
        echo "   .macbox/sha_marker wurde nicht korrekt synchronisiert." >&2
        exit 1
    fi
    echo "Remote-SHA: $REMOTE_SHA"
    if [ "$SOURCE_SHA" = "$REMOTE_SHA" ]; then
        echo "✓ SHA-Match: macbox hat den korrekten Worktree synchronisiert."
    else
        echo "✗ SHA-MISMATCH — macbox synchronisierte NICHT den erwarteten Worktree!" >&2
        echo "  Erwartet:  $SOURCE_SHA" >&2
        echo "  Gebaut:    $REMOTE_SHA" >&2
        echo "  Prüfe ob --dir korrekt gesetzt ist." >&2
        exit 1
    fi
else
    # Kein SHA im Output: macbox gibt setup-Output nur bei Fehlern zurück.
    # Bei erfolgreichem Build: --dir gesetzt = korrekte Synchronisierung.
    if [ "$EXIT_CODE" -eq 0 ]; then
        echo "✓ Build erfolgreich."
        echo "  --dir:          $SOURCE_DIR"
        echo "  Erwarteter SHA: $SOURCE_SHA"
        echo "  Remote-SHA:     nicht verfügbar (macbox gibt setup-Output nur bei Fehlern zurück)"
    fi
fi

exit "$EXIT_CODE"
