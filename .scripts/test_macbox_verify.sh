#!/bin/bash
# test_macbox_verify.sh — Integrationstests für macbox_verify.sh (Issue #25)
#
# Testet den echten Wrapper mit Fake-macbox im temporären PATH.
# Die Fake-macbox zeichnet alle übergebenen Argumente auf;
# die Tests verifizieren, dass --dir mit dem richtigen Pfad an macbox übergeben wurde.
#
# HINWEIS: macbox gibt setup-Output (MACBOX_REMOTE_SHA:) nur bei Fehlern zurück, nicht
# bei Erfolg. Der Wrapper akzeptiert daher erfolgreiche Builds ohne SHA-Output (exit 0).
# SHA-Verifikation greift nur wenn MACBOX_REMOTE_SHA: im Output erscheint (Fehlerfall).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY="$SCRIPT_DIR/macbox_verify.sh"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LOCAL_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
WRONG_SHA="0000000000000000000000000000000000000000"

PASS=0
FAIL=0
TMPDIR_FAKE="$(mktemp -d)"
ARGS_FILE="$TMPDIR_FAKE/last_args.txt"
trap 'rm -rf "$TMPDIR_FAKE"' EXIT

FAKE_MACBOX="$TMPDIR_FAKE/macbox"
export PATH="$TMPDIR_FAKE:$PATH"

# Fake-macbox: zeichnet alle Argumente auf, gibt konfigurierten SHA aus
make_fake() {
    local remote_sha="${1:-$LOCAL_SHA}"
    # ARGS_FILE in Skript einbetten (nicht über Umgebungsvariable, für Portabilität)
    cat > "$FAKE_MACBOX" << HEREDOC
#!/bin/bash
printf '%s\n' "\$@" > "$ARGS_FILE"
echo "MACBOX_REMOTE_SHA: $remote_sha"
echo "MACBOX_REMOTE_BRANCH: test"
HEREDOC
    chmod +x "$FAKE_MACBOX"
}

# Fake ohne SHA-Ausgabe (simuliert: setup lief nicht / erfolgreicher Folge-Build)
make_fake_no_sha() {
    local exit_code="${1:-0}"
    cat > "$FAKE_MACBOX" << HEREDOC
#!/bin/bash
printf '%s\n' "\$@" > "$ARGS_FILE"
echo "Build output without setup."
exit $exit_code
HEREDOC
    chmod +x "$FAKE_MACBOX"
}

# Prüft ob --dir <expected> in den zuletzt an macbox übergebenen Argumenten steht
dir_arg_was() {
    local expected_dir="$1"
    [ -f "$ARGS_FILE" ] || return 1
    # Argumente sind zeilenweise gespeichert (printf '%s\n' "$@")
    local found_dir=false
    local next_is_dir=false
    while IFS= read -r arg; do
        if [ "$next_is_dir" = true ]; then
            if [ "$arg" = "$expected_dir" ]; then
                found_dir=true
            fi
            next_is_dir=false
        elif [ "$arg" = "--dir" ]; then
            next_is_dir=true
        fi
    done < "$ARGS_FILE"
    [ "$found_dir" = true ]
}

run_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2
    local actual_exit=0
    "$@" > /tmp/_mbv_$$.txt 2>&1 || actual_exit=$?
    rm -f /tmp/_mbv_$$.txt
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
run_test "verify-script existiert"       0  test -f "$VERIFY"
run_test "verify-script ist ausführbar"  0  test -x "$VERIFY"
run_test "setup-script existiert"        0  test -f "$REPO_ROOT/.macbox/setup"
run_test "setup-script ist ausführbar"   0  test -x "$REPO_ROOT/.macbox/setup"

# --- Szenario A: SHA-Match + --dir korrekt übergeben ---
echo ""
echo "--- Szenario A: SHA-Match → exit 0, --dir korrekt übergeben ---"
make_fake "$LOCAL_SHA"
run_test "SHA-Match → exit 0" 0  bash "$VERIFY" build --dir "$REPO_ROOT"
run_test "--dir='$REPO_ROOT' wurde an macbox übergeben" 0  dir_arg_was "$REPO_ROOT"

# --- Szenario B: SHA-Mismatch → exit 1 ---
echo ""
echo "--- Szenario B: SHA-Mismatch → exit 1 ---"
make_fake "$WRONG_SHA"
run_test "SHA-Mismatch → exit 1" 1  bash "$VERIFY" build --dir "$REPO_ROOT"

# --- Szenario C: SHA 'unknown' oder 'missing' → exit 1 ---
echo ""
echo "--- Szenario C: Remote-SHA = 'unknown' oder 'missing' → exit 1 ---"
make_fake "unknown"
run_test "'unknown' SHA → exit 1" 1  bash "$VERIFY" build --dir "$REPO_ROOT"
make_fake "missing"
run_test "'missing' SHA → exit 1" 1  bash "$VERIFY" build --dir "$REPO_ROOT"

# --- Szenario D: Kein MACBOX_REMOTE_SHA + Build erfolgreich → exit 0 ---
# macbox gibt setup-Output nur bei Fehlern zurück, nicht bei Erfolg.
# Erfolgreicher Build ohne SHA = normaler Folge-Build → Wrapper akzeptiert (--dir gesetzt).
echo ""
echo "--- Szenario D: Kein Remote-SHA + erfolgreicher Build → exit 0 (macbox-Verhalten) ---"
make_fake_no_sha 0
run_test "Kein SHA + Build erfolgreich → exit 0" 0  bash "$VERIFY" build --dir "$REPO_ROOT"

# --- Szenario D2: Kein Remote-SHA + Build fehlgeschlagen → exit 1 (macbox-Fehler) ---
# Der Wrapper propagiert den macbox-Exitcode; kein SHA im Fehlerfall ist OK.
echo ""
echo "--- Szenario D2: Kein Remote-SHA + fehlgeschlagener Build → exit 1 (macbox-Fehler) ---"
make_fake_no_sha 1
run_test "Kein SHA + Build fehlgeschlagen → exit 1" 1  bash "$VERIFY" build --dir "$REPO_ROOT"

# --- Szenario E: Ungültiges --dir → exit 1 ---
echo ""
echo "--- Szenario E: Ungültiges --dir → exit 1 ---"
make_fake "$LOCAL_SHA"
run_test "Nicht-existentes --dir → exit 1"  1  bash "$VERIFY" build --dir "/nonexistent/xyz_$$"
run_test "Kein Git-Repo als --dir → exit 1" 1  bash "$VERIFY" build --dir "/tmp"

# --- Szenario F: Ohne --dir → auto-inject aus CWD ---
echo ""
echo "--- Szenario F: build ohne --dir → --dir aus aufrufendem git-Toplevel ---"
make_fake "$LOCAL_SHA"
run_test "Auto-dir (SHA-Match) → exit 0" 0  bash -c "cd '$REPO_ROOT' && bash '$VERIFY' build"
run_test "--dir='$REPO_ROOT' automatisch übergeben" 0  dir_arg_was "$REPO_ROOT"

# --- Szenario G: Explizites --dir, --dir-Argument wird korrekt weitergegeben ---
echo ""
echo "--- Szenario G: Explizites --dir → wird an macbox weitergegeben ---"
make_fake "$LOCAL_SHA"
run_test "Explizites --dir + Match → exit 0" 0  bash "$VERIFY" test --dir "$REPO_ROOT" --scheme DeltiqAppTests
run_test "--dir='$REPO_ROOT' korrekt an macbox übergeben" 0  dir_arg_was "$REPO_ROOT"

# --- Szenario H: Pfad mit Leerzeichen ---
echo ""
echo "--- Szenario H: Pfad mit Leerzeichen ---"
TMPDIR_SPACES="$TMPDIR_FAKE/path with spaces"
mkdir -p "$TMPDIR_SPACES"
git -C "$TMPDIR_SPACES" init -q 2>/dev/null
git -C "$TMPDIR_SPACES" commit --allow-empty -m "init" --quiet 2>/dev/null || true
SPACES_SHA="$(git -C "$TMPDIR_SPACES" rev-parse HEAD 2>/dev/null || echo 'none')"
make_fake "$SPACES_SHA"
run_test "Pfad mit Leerzeichen → exit 0" 0  bash "$VERIFY" build --dir "$TMPDIR_SPACES"
run_test "--dir mit Leerzeichen korrekt übergeben" 0  dir_arg_was "$TMPDIR_SPACES"

# --- Szenario I: Aufruf von unterschiedlichem Worktree ohne --dir ---
# Testet: SHA-Quelle ist CWD des Aufrufers, NICHT Verzeichnis des Skripts.
# Verwendet git worktree list --porcelain (parse-sicher für Pfade mit Leerzeichen).
echo ""
echo "--- Szenario I: Auto-dir aus anderem Worktree als Skript-Verzeichnis ---"

OTHER_WORKTREE=""
OTHER_SHA_EXPECTED=""
candidate=""
while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
        candidate="${line#worktree }"
    elif [[ "$line" == HEAD\ * ]] && [ -n "$candidate" ] && [ "$candidate" != "$REPO_ROOT" ]; then
        if [ -d "$candidate" ] && git -C "$candidate" rev-parse HEAD > /dev/null 2>&1; then
            OTHER_WORKTREE="$candidate"
            OTHER_SHA_EXPECTED="${line#HEAD }"
            break
        fi
    fi
done < <(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null || true)

if [ -n "$OTHER_WORKTREE" ]; then
    make_fake "$OTHER_SHA_EXPECTED"
    run_test "Auto-dir aus anderem Worktree → exit 0" 0  bash -c "cd '$OTHER_WORKTREE' && bash '$VERIFY' build"
    run_test "--dir='$OTHER_WORKTREE' korrekt gesetzt" 0  dir_arg_was "$OTHER_WORKTREE"
    # Verifikation dass der FALSCHE SHA erkannt wird:
    # Wenn wir LOCAL_SHA als fake liefern aber aus OTHER_WORKTREE aufrufen → Mismatch
    if [ "$LOCAL_SHA" != "$OTHER_SHA_EXPECTED" ]; then
        make_fake "$LOCAL_SHA"
        run_test "Falscher Remote-SHA für anderen Worktree → exit 1" 1  bash -c "cd '$OTHER_WORKTREE' && bash '$VERIFY' build"
    else
        echo "⚠  Worktrees haben gleichen SHA, Mismatch-Test übersprungen"
    fi
else
    echo "⚠  Kein weiterer Worktree gefunden, Szenario I übersprungen"
fi

# --- Ergebnis ---
echo ""
echo "==============================="
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
echo "==============================="

[ "$FAIL" -gt 0 ] && exit 1
exit 0
