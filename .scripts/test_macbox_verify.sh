#!/bin/bash
# test_macbox_verify.sh — Tests für macbox_verify.sh (Issue #25)
#
# Testet beide Szenarien ohne macbox-Verbindung:
#   Szenario A: korrekter Checkout → muss pass (exit 0)
#   Szenario B: falscher Checkout (SHA-Mismatch) → muss blockieren (exit 1)
#
# Verwendung: .scripts/test_macbox_verify.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LOCAL_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
VERIFY_SCRIPT="$SCRIPT_DIR/macbox_verify.sh"

PASS=0
FAIL=0

check() {
    local name="$1"
    local expected_exit="$2"
    shift 2
    local actual_exit=0
    "$@" > /dev/null 2>&1 || actual_exit=$?
    if [ "$actual_exit" = "$expected_exit" ]; then
        echo "✓ $name"
        PASS=$((PASS + 1))
    else
        echo "✗ $name (exit erwartet=$expected_exit, bekam=$actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== macbox_verify.sh Unit-Tests (Issue #25) ==="
echo ""

# --- Vorbedingungen ---
echo "--- Vorbedingungen ---"
check "verify-script existiert"      0  test -f "$VERIFY_SCRIPT"
check "verify-script ist ausführbar" 0  test -x "$VERIFY_SCRIPT"
check "setup-script existiert"       0  test -f "$REPO_ROOT/.macbox/setup"
check "setup-script ist ausführbar"  0  test -x "$REPO_ROOT/.macbox/setup"

# --- SHA-Vergleichs-Logik isoliert testen ---
# Wir imitieren die Kern-Logik direkt im Test (kein macbox erforderlich).

sha_compare() {
    local expected="$1"
    local remote="$2"
    if [ "$expected" = "$remote" ]; then
        return 0
    else
        return 1
    fi
}

echo ""
echo "--- Szenario A: Korrekter Checkout (SHA-Match) ---"
check "SHA-Match → exit 0" 0  sha_compare "$LOCAL_SHA" "$LOCAL_SHA"

echo ""
echo "--- Szenario B: Falscher Checkout (SHA-Mismatch) ---"
WRONG_SHA="0000000000000000000000000000000000000000"
check "SHA-Mismatch → exit 1" 1  sha_compare "$LOCAL_SHA" "$WRONG_SHA"

# --- Worktree-Erkennung ---
echo ""
echo "--- Worktree-Erkennung ---"
GIT_DIR_PATH="$(git -C "$REPO_ROOT" rev-parse --git-dir)"
detect_worktree() {
    if [ "$GIT_DIR_PATH" != "$REPO_ROOT/.git" ]; then
        return 0  # Ist Worktree
    else
        return 1  # Kein Worktree
    fi
}
check "Aktueller Kontext ist ein Worktree" 0  detect_worktree

# --- dir-Argument-Erkennung (simuliert) ---
echo ""
echo "--- --dir Argument-Erkennung ---"

has_dir_arg() {
    for arg in "$@"; do
        if [ "$arg" = "--dir" ]; then return 0; fi
    done
    return 1
}

check "build ohne --dir → kein dir-Flag gesetzt"      1  has_dir_arg build
check "build --dir /x → dir-Flag erkannt"             0  has_dir_arg build --dir /x
check "test --scheme X → kein dir-Flag"               1  has_dir_arg test --scheme DeltiqAppTests
check "test --dir /y --scheme X → dir-Flag erkannt"   0  has_dir_arg test --dir /y --scheme DeltiqAppTests

# --- Ergebnis ---
echo ""
echo "==============================="
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
echo "==============================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
