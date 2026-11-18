#!/bin/bash
# macbox_verify.sh — Wrapper um macbox, der:
#   1. --dir auf den aufrufenden Worktree setzt (Haupt-Fix für Issue #25)
#   2. Quelle (dir, branch, sha) vor dem Build meldet
#   3. Bei Remote-SHA "unknown" oder SHA-Mismatch hart abbricht (exit 1)
#   4. Wenn kein SHA im Output: warnt, bricht aber nicht ab (--dir-Fix greift bereits)
#
# Verwendung: .scripts/macbox_verify.sh <macbox-befehl> [--dir /pfad] [weitere Optionen]
# Beispiel:   .scripts/macbox_verify.sh build --scheme DeltiqApp

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

echo "=== macbox SHA-Verifikation (Issue #25) ==="
echo "Quelle-Dir:     $SOURCE_DIR"
echo "Branch:         $SOURCE_BRANCH"
echo "Erwarteter SHA: $SOURCE_SHA"
echo "Ist Worktree:   $IS_WORKTREE"
[ "$DIR_ADDED" = true ] && echo "→ --dir automatisch hinzugefügt"
echo ""
echo "Ausführen: macbox ${ARGS[*]}"
echo ""

# macbox ausführen
set +e
MACBOX_OUTPUT=$(macbox "${ARGS[@]}" 2>&1)
EXIT_CODE=$?
set -e
echo "$MACBOX_OUTPUT"

[ "$EXIT_CODE" -ne 0 ] && exit "$EXIT_CODE"

# Remote-SHA aus macbox-Output (von .macbox/setup gesetzt)
REMOTE_SHA=$(echo "$MACBOX_OUTPUT" | grep "^MACBOX_REMOTE_SHA:" | awk '{print $2}' | head -1 || true)

echo ""

if [ -z "$REMOTE_SHA" ]; then
    # setup lief nicht (macbox-Verhalten: nur beim ersten Build/Änderung)
    echo "⚠  Warnung: Remote-SHA nicht im Output — .macbox/setup lief vermutlich nicht."
    echo "   --dir war gesetzt auf: $SOURCE_DIR"
    echo "   Erwarteter SHA:        $SOURCE_SHA"
    echo "   Verifikation nicht möglich; --dir-Parameter ist trotzdem gesetzt."
    exit 0
fi

if [ "$REMOTE_SHA" = "unknown" ]; then
    echo "✗ FEHLER: Remote-SHA ist 'unknown' — git war auf dem Remote-Mac nicht auswertbar." >&2
    echo "   Erwarteter SHA: $SOURCE_SHA" >&2
    exit 1
fi

echo "Remote-SHA:     $REMOTE_SHA"

if [ "$SOURCE_SHA" = "$REMOTE_SHA" ]; then
    echo "✓ SHA-Match: macbox hat den korrekten Worktree gebaut."
else
    echo "✗ SHA-MISMATCH — macbox synchronisierte NICHT den erwarteten Worktree!" >&2
    echo "  Erwartet:  $SOURCE_SHA" >&2
    echo "  Gebaut:    $REMOTE_SHA" >&2
    echo "  Prüfe ob --dir korrekt gesetzt ist." >&2
    exit 1
fi
