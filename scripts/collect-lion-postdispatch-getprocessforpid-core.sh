#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CORE="${1:-}"
CRASH="${2:-}"
REPORT="${3:-$ROOT/payload/lion-postdispatch-getprocessforpid-postmortem.txt}"
OUT_DIR="$(/usr/bin/dirname "$REPORT")"

TRANSLATOR="/usr/libexec/oah/translate"
GDB="/usr/bin/gdb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"

WINDOW="$OUT_DIR/lion-postdispatch-getprocessforpid-crash-window.bin"
WINDOW_SHA="$WINDOW.sha256"

fail() {
    echo "error: $*" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

[ -n "$CORE" ] || fail "usage: $0 /cores/core.PID /path/to/report.crash [output-report]"
[ -n "$CRASH" ] || fail "usage: $0 /cores/core.PID /path/to/report.crash [output-report]"

/bin/mkdir -p "$OUT_DIR" || fail "cannot create output directory: $OUT_DIR"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
[ "$PRODUCT_VERSION" = "10.7.5" ] || fail "requires Mac OS X 10.7.5 (found: $PRODUCT_VERSION)"
[ -x "$GDB" ] || fail "missing Apple GDB at $GDB"
[ -x "$TRANSLATOR" ] || fail "missing Rosetta translator at $TRANSLATOR"
[ -f "$CORE" ] || fail "missing preserved non-debugged core: $CORE"
[ -f "$CRASH" ] || fail "missing preserved crash report: $CRASH"

TRANSLATOR_SHA="$(sha256 "$TRANSLATOR")"
[ "$TRANSLATOR_SHA" = "$EXPECTED_TRANSLATOR_SHA" ] ||
    fail "translator hash mismatch: $TRANSLATOR_SHA"

/bin/rm -f "$REPORT" "$WINDOW" "$WINDOW_SHA"

TMPDIR="$(/usr/bin/mktemp -d /tmp/rosetta-postdispatch-pm.XXXXXX)" ||
    fail "mktemp failed"
trap '/bin/rm -rf "$TMPDIR"' EXIT HUP INT TERM

MAIN_GDB="$TMPDIR/main.gdb"
STACK_GDB="$TMPDIR/stack.gdb"
DUMP_GDB="$TMPDIR/dump.gdb"
MAIN_OUT="$TMPDIR/main.txt"
STACK_OUT="$TMPDIR/stack.txt"
DUMP_OUT="$TMPDIR/dump.txt"

cat > "$MAIN_GDB" <<'EOF'
set pagination off
set confirm off
echo === registers ===\n
info registers
echo === backtrace ===\n
bt
echo === all-thread backtraces ===\n
thread apply all bt
echo === instructions around crash PC ===\n
x/128i $eip-0x100
echo === raw bytes around crash PC ===\n
x/512bx $eip-0x100
EOF

cat > "$STACK_GDB" <<'EOF'
set pagination off
set confirm off
echo === stack words around ESP ===\n
x/256wx $esp-0x200
echo === frame words around EBP ===\n
x/256wx $ebp-0x200
echo === stack bytes ===\n
x/1024bx $esp-0x200
EOF

cat > "$DUMP_GDB" <<EOF
set pagination off
set confirm off
set \$window_start = \$eip - 0x100
set \$window_end = \$eip + 0x100
dump binary memory $WINDOW \$window_start \$window_end
EOF

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$MAIN_GDB" > "$MAIN_OUT" 2>&1
MAIN_STATUS=$?

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$STACK_GDB" > "$STACK_OUT" 2>&1
STACK_STATUS=$?

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$DUMP_GDB" > "$DUMP_OUT" 2>&1
DUMP_STATUS=$?

{
    echo "== Lion post-dispatch GetProcessForPID postmortem =="
    echo "product_version=$PRODUCT_VERSION"
    echo "build_version=$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
    echo "core=$CORE"
    /bin/ls -l "$CORE" 2>&1 || true
    echo "crash_report=$CRASH"
    /bin/ls -l "$CRASH" 2>&1 || true
    echo "translator=$TRANSLATOR"
    echo "translator_sha256=$TRANSLATOR_SHA"
    echo "gdb_main_status=$MAIN_STATUS"
    echo "gdb_stack_status=$STACK_STATUS"
    echo "gdb_dump_status=$DUMP_STATUS"
    echo
    "$GDB" --version 2>&1 | /usr/bin/head -5
    echo
    echo "== preserved crash report =="
    /bin/cat "$CRASH"
    echo
    /bin/cat "$MAIN_OUT"
    echo
    /bin/cat "$STACK_OUT"
    echo
    echo "== dump command output =="
    /bin/cat "$DUMP_OUT"
} > "$REPORT"

[ "$MAIN_STATUS" -eq 0 ] || fail "main GDB pass failed; preserve $REPORT"
[ "$STACK_STATUS" -eq 0 ] || fail "stack GDB pass failed; preserve $REPORT"
[ "$DUMP_STATUS" -eq 0 ] || fail "dump GDB pass failed; preserve $REPORT"

[ -f "$WINDOW" ] || fail "GDB did not produce crash window; preserve $REPORT"
WINDOW_SIZE="$(/usr/bin/stat -f '%z' "$WINDOW" 2>/dev/null || echo 0)"
[ "$WINDOW_SIZE" = "512" ] ||
    fail "crash window has unexpected size $WINDOW_SIZE (expected 512); preserve $REPORT"

/usr/bin/shasum -a 256 "$WINDOW" > "$WINDOW_SHA"

/usr/bin/grep -Eq '(^|[[:space:]])eip[[:space:]]' "$MAIN_OUT" ||
    fail "postmortem output did not contain EIP; preserve $REPORT"
/usr/bin/grep -Fq '=== backtrace ===' "$MAIN_OUT" ||
    fail "postmortem output did not contain backtrace marker; preserve $REPORT"

{
    echo
    echo "crash_window_size=$WINDOW_SIZE"
    echo "crash_window_sha256=$(/usr/bin/awk 'NR==1 {print $1}' "$WINDOW_SHA")"
    echo "RESULT: PASS"
} >> "$REPORT"

echo "Created:"
echo "  $REPORT"
echo "  $WINDOW"
echo "  $WINDOW_SHA"
echo "No live process was attached and no system file was modified."
echo "RESULT: PASS"
