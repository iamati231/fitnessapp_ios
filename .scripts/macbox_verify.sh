#!/bin/bash
# macbox_verify.sh — Wrapper um macbox, der:
#   1. --dir automatisch auf den aktuellen Worktree setzt (verhindert falschen main-Sync)
#   2. Den Remote-Checkout-SHA nach dem Sync verifiziert (Issue #25)
#   3. Bei SHA-Mismatch mit exit 1 hart abbricht
#
# Verwendung: .scripts/macbox_verify.sh <macbox-befehl> [--dir /pfad] [weitere Optionen]
# Beispiel:   .scripts/macbox_verify.sh build --scheme DeltiqApp
# Beispiel:   .scripts/macbox_verify.sh test --scheme DeltiqAppTests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LOCAL_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
LOCAL_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"

# Worktree erkennen: .git ist eine Datei (kein Verzeichnis) in Worktrees
GIT_DIR_PATH="$(git -C "$REPO_ROOT" rev-parse --git-dir)"
IS_WORKTREE=false
if [ "$GIT_DIR_PATH" != "$REPO_ROOT/.git" ]; then
    IS_WORKTREE=true
fi

echo "=== macbox SHA-Verifikation (Issue #25) ==="
echo "Branch:          $LOCAL_BRANCH"
echo "Erwarteter SHA:  $LOCAL_SHA"
echo "Worktree-Root:   $REPO_ROOT"
echo "Ist Worktree:    $IS_WORKTREE"
echo ""

# --dir automatisch ergänzen, falls nicht übergeben
ARGS=("$@")
HAS_DIR=false
for arg in "${ARGS[@]}"; do
    if [ "$arg" = "--dir" ]; then
        HAS_DIR=true
        break
    fi
done

if [ "$HAS_DIR" = false ]; then
    if [ "$IS_WORKTREE" = true ]; then
        echo "→ Worktree erkannt: --dir wird automatisch gesetzt"
    fi
    ARGS+=("--dir" "$REPO_ROOT")
fi

echo "Ausführen: macbox ${ARGS[*]}"
echo ""

# macbox ausführen und Ausgabe capturen (stdout + stderr)
MACBOX_OUTPUT=$(macbox "${ARGS[@]}" 2>&1) || { EXIT_CODE=$?; echo "$MACBOX_OUTPUT"; exit $EXIT_CODE; }
echo "$MACBOX_OUTPUT"

# Remote-SHA aus macbox-Output extrahieren (von .macbox/setup gesetzt)
REMOTE_SHA=$(echo "$MACBOX_OUTPUT" | grep "^MACBOX_REMOTE_SHA:" | awk '{print $2}' | head -1)

echo ""
if [ -z "$REMOTE_SHA" ] || [ "$REMOTE_SHA" = "unknown" ]; then
    echo "⚠  Warnung: Remote-SHA nicht im Output gefunden."
    echo "   Prüfe ob .macbox/setup im Repo existiert."
    exit 0
fi

echo "Remote-SHA:      $REMOTE_SHA"

if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
    echo "✓ SHA-Match: macbox hat den korrekten Worktree gebaut."
else
    echo ""
    echo "✗ SHA-MISMATCH — macbox hat NICHT den erwarteten Worktree synchronisiert!"
    echo "  Erwartet:  $LOCAL_SHA"
    echo "  Gebaut:    $REMOTE_SHA"
    echo ""
    echo "Ursache: macbox hat wahrscheinlich main statt den Worktree gebaut."
    echo "Lösung:  macbox ${ARGS[0]} --dir \"$REPO_ROOT\""
    exit 1
fi
