#!/bin/bash
# test_macbox_verify.sh — Integrationstests für macbox_verify.sh (Issue #25)
#
# Testet den echten Wrapper mit Fake-macbox im temporären PATH.
# Szenarien: SHA-Match, SHA-Mismatch, 'unknown', fehlender Marker,
# ungültiges --dir, Auto-dir-Injection, explizites --dir.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY="$SCRIPT_DIR/macbox_verify.sh"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LOCAL_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
WRONG_SHA="0000000000000000000000000000000000000000"

PASS=0
FAIL=0
TMPDIR_FAKE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FAKE"' EXIT

FAKE_MACBOX="$TMPDIR_FAKE/macbox"
export PATH="$TMPDIR_FAKE:$PATH"

# Erstellt ein Fake-macbox das MACBOX_REMOTE_SHA ausgibt
make_fake() {
    local remote_sha="${1:-$LOCAL_SHA}"
    printf '#!/bin/bash\necho "MACBOX_REMOTE_SHA: %s"\necho "MACBOX_REMOTE_BRANCH: test"\n' "$remote_sha" > "$FAKE_MACBOX"
    chmod +x "$FAKE_MACBOX"
}

# Fake ohne SHA-Ausgabe (simuliert: setup lief nicht)
make_fake_no_marker() {
    printf '#!/bin/bash\necho "Build succeeded."\n' > "$FAKE_MACBOX"
    chmod +x "$FAKE_MACBOX"
}

run_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2
    local actual_exit=0
    "$@" > /tmp/_mbv_test_$$.txt 2>&1 || actual_exit=$?
    rm -f /tmp/_mbv_test_$$.txt
    if [ "$actual_exit" = "$expected_exit" ]; then
        echo "✓ $name"
        PASS=$((PASS + 1))
    else
        echo "✗ $name (erwartet exit $expected_exit, bekam $actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== macbox_verify.sh Integrationstests (Issue #25) ==="
echo "Repo:  $REPO_ROOT"
echo "SHA:   $LOCAL_SHA"
echo ""

# --- Vorbedingungen ---
echo "--- Vorbedingungen ---"
run_test "verify-script existiert"      0  test -f "$VERIFY"
run_test "verify-script ist ausführbar" 0  test -x "$VERIFY"
run_test "setup-script existiert"       0  test -f "$REPO_ROOT/.macbox/setup"
run_test "setup-script ist ausführbar"  0  test -x "$REPO_ROOT/.macbox/setup"

# --- Szenario A: SHA-Match ---
echo ""
echo "--- Szenario A: Korrekter Checkout (SHA-Match) → exit 0 ---"
make_fake "$LOCAL_SHA"
run_test "SHA-Match → exit 0" 0  bash "$VERIFY" build --dir "$REPO_ROOT"

# --- Szenario B: SHA-Mismatch ---
echo ""
echo "--- Szenario B: Falscher Checkout (SHA-Mismatch) → exit 1 ---"
make_fake "$WRONG_SHA"
run_test "SHA-Mismatch → exit 1" 1  bash "$VERIFY" build --dir "$REPO_ROOT"

# --- Szenario C: SHA 'unknown' (git auf Remote fehlgeschlagen) ---
echo ""
echo "--- Szenario C: Remote-SHA = 'unknown' → exit 1 ---"
make_fake "unknown"
run_test "'unknown' SHA → exit 1" 1  bash "$VERIFY" build --dir "$REPO_ROOT"

# --- Szenario D: Kein MACBOX_REMOTE_SHA (setup lief nicht) ---
echo ""
echo "--- Szenario D: Kein Remote-SHA-Marker → exit 0 (Warnung) ---"
make_fake_no_marker
run_test "Fehlender SHA-Marker → exit 0" 0  bash "$VERIFY" build --dir "$REPO_ROOT"

# --- Szenario E: Ungültiges --dir ---
echo ""
echo "--- Szenario E: Ungültiges --dir → exit 1 ---"
make_fake "$LOCAL_SHA"
run_test "Nicht-existentes --dir → exit 1"  1  bash "$VERIFY" build --dir "/nonexistent/xyz_$$"
run_test "Kein Git-Repo als --dir → exit 1" 1  bash "$VERIFY" build --dir "/tmp"

# --- Szenario F: Ohne --dir (auto-inject aus aufrufendem Verzeichnis) ---
echo ""
echo "--- Szenario F: Kein --dir → wird automatisch aus aufrufendem git-Toplevel gesetzt ---"
make_fake "$LOCAL_SHA"
# Aufruf aus REPO_ROOT: script soll git-Toplevel des CWD nehmen
run_test "Auto-dir (SHA-Match) → exit 0" 0  bash -c "cd '$REPO_ROOT' && bash '$VERIFY' build"

# --- Szenario G: Explizites --dir mit korrektem SHA ---
echo ""
echo "--- Szenario G: Explizites --dir zeigt auf Worktree ---"
make_fake "$LOCAL_SHA"
run_test "Explizites --dir + Match → exit 0" 0  bash "$VERIFY" test --dir "$REPO_ROOT" --scheme DeltiqAppTests

# --- Szenario H: Pfad mit Leerzeichen ---
echo ""
echo "--- Szenario H: Pfad mit Leerzeichen ---"
TMPDIR_SPACES="$TMPDIR_FAKE/path with spaces"
mkdir -p "$TMPDIR_SPACES"
# git init damit es als Repo erkannt wird
git -C "$TMPDIR_SPACES" init -q 2>/dev/null
git -C "$TMPDIR_SPACES" commit --allow-empty -m "init" --quiet 2>/dev/null || true
SPACES_SHA="$(git -C "$TMPDIR_SPACES" rev-parse HEAD 2>/dev/null || echo 'none')"
make_fake "$SPACES_SHA"
run_test "Pfad mit Leerzeichen → exit 0" 0  bash "$VERIFY" build --dir "$TMPDIR_SPACES"

# --- Ergebnis ---
echo ""
echo "==============================="
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
echo "==============================="

[ "$FAIL" -gt 0 ] && exit 1
exit 0
