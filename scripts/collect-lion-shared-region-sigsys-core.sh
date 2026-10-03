#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CORE="${1:-/cores/core.1090}"
REPORT="${2:-$ROOT/payload/lion-shared-region-sigsys-core.txt}"
OUT_DIR="$(/usr/bin/dirname "$REPORT")"
WINDOW="$OUT_DIR/lion-shared-region-sigsys-window.bin"
WINDOW_SUM="$WINDOW.sha256"

TRANSLATOR="/usr/libexec/oah/translate"
GDB="/usr/bin/gdb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
CRASH_EIP="0xb815ac07"
WINDOW_START="0xb815ab80"
WINDOW_END="0xb815ac80"

fail() {
    echo "error: $*" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

/bin/mkdir -p "$OUT_DIR" || fail "cannot create output directory: $OUT_DIR"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
[ "$PRODUCT_VERSION" = "10.7.5" ] || fail "requires Mac OS X 10.7.5 (found: $PRODUCT_VERSION)"
[ -x "$GDB" ] || fail "missing Apple GDB at $GDB"
[ -x "$TRANSLATOR" ] || fail "missing Rosetta translator at $TRANSLATOR"
[ -f "$CORE" ] || fail "missing preserved non-debugged core: $CORE"

TRANSLATOR_SHA="$(sha256 "$TRANSLATOR")"
[ "$TRANSLATOR_SHA" = "$EXPECTED_TRANSLATOR_SHA" ] ||     fail "translator hash mismatch: $TRANSLATOR_SHA"

TMPDIR="$(/usr/bin/mktemp -d /tmp/rosetta-sigsys-postmortem.XXXXXX)" || fail "mktemp failed"
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
echo === instructions from crash EIP ===\n
x/32i 0xb815ac07
echo === wider instruction window ===\n
x/96i 0xb815ab80
echo === raw bytes around crash ===\n
x/256bx 0xb815ab80
echo === caller frame instruction window ===\n
x/64i 0xb8179480
EOF

cat > "$STACK_GDB" <<'EOF'
set pagination off
set confirm off
echo === stack words around ESP ===\n
x/128wx $esp-0x100
echo === frame words around EBP ===\n
x/128wx $ebp-0x100
EOF

cat > "$DUMP_GDB" <<EOF
set pagination off
set confirm off
dump binary memory $WINDOW $WINDOW_START $WINDOW_END
EOF

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$MAIN_GDB" > "$MAIN_OUT" 2>&1
MAIN_STATUS=$?

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$STACK_GDB" > "$STACK_OUT" 2>&1
STACK_STATUS=$?

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$DUMP_GDB" > "$DUMP_OUT" 2>&1
DUMP_STATUS=$?

{
    echo "== Lion Rosetta SIGSYS postmortem =="
    echo "product_version=$PRODUCT_VERSION"
    echo "build_version=$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
    echo "core=$CORE"
    /bin/ls -l "$CORE" 2>&1 || true
    echo "translator=$TRANSLATOR"
    echo "translator_sha256=$TRANSLATOR_SHA"
    echo "expected_crash_eip=$CRASH_EIP"
    echo "window=$WINDOW_START-$WINDOW_END"
    echo "gdb_main_status=$MAIN_STATUS"
    echo "gdb_stack_status=$STACK_STATUS"
    echo "gdb_dump_status=$DUMP_STATUS"
    echo
    "$GDB" --version 2>&1 | /usr/bin/head -5
    echo
    /bin/cat "$MAIN_OUT"
    echo
    /bin/cat "$STACK_OUT"
    echo
    echo "== dump command output =="
    /bin/cat "$DUMP_OUT"
} > "$REPORT"

[ -f "$WINDOW" ] || fail "GDB did not produce runtime window; preserve $REPORT"
WINDOW_SIZE="$(/usr/bin/stat -f '%z' "$WINDOW" 2>/dev/null || echo 0)"
[ "$WINDOW_SIZE" = "256" ] || fail "runtime window has unexpected size $WINDOW_SIZE; preserve $REPORT"

/usr/bin/shasum -a 256 "$WINDOW" > "$WINDOW_SUM"

if ! /usr/bin/grep -Fq "$CRASH_EIP" "$MAIN_OUT"; then
    fail "postmortem output did not contain expected crash EIP; preserve $REPORT"
fi

echo "Created:"
echo "  $REPORT"
echo "  $WINDOW"
echo "  $WINDOW_SUM"
echo "No live process was attached and no system file was modified."
