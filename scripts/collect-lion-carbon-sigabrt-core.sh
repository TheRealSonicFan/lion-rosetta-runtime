#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CORE="${1:-/cores/core.1311}"
REPORT="${2:-$ROOT/payload/lion-carbon-sigabrt-core.txt}"
OUT_DIR="$(/usr/bin/dirname "$REPORT")"

TRANSLATOR="/usr/libexec/oah/translate"
GDB="/usr/bin/gdb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"

CRASH_EIP="0xb815ac07"
CALLER_PC="0xb8179fb4"
FRAME2_PC="0xb80c6b13"

WRAPPER_BIN="$OUT_DIR/lion-carbon-sigabrt-wrapper-window.bin"
CALLER_BIN="$OUT_DIR/lion-carbon-sigabrt-caller-window.bin"
FRAME2_BIN="$OUT_DIR/lion-carbon-sigabrt-frame2-window.bin"

WRAPPER_START="0xb815ab80"
WRAPPER_END="0xb815ac80"
CALLER_START="0xb8179e80"
CALLER_END="0xb817a080"
FRAME2_START="0xb80c6a80"
FRAME2_END="0xb80c6c00"

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

TMPDIR="$(/usr/bin/mktemp -d /tmp/rosetta-carbon-sigabrt.XXXXXX)" || fail "mktemp failed"
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
echo === crash syscall wrapper ===\n
x/48i 0xb815ab80
echo === direct caller window ===\n
x/128i 0xb8179e80
echo === next caller window ===\n
x/96i 0xb80c6a80
echo === following frame windows ===\n
x/64i 0xb80bff80
x/64i 0xb80dd800
echo === raw bytes at wrapper ===\n
x/256bx 0xb815ab80
echo === raw bytes at direct caller ===\n
x/512bx 0xb8179e80
EOF

cat > "$STACK_GDB" <<'EOF'
set pagination off
set confirm off
echo === stack words around ESP ===\n
x/192wx $esp-0x180
echo === frame words around EBP ===\n
x/192wx $ebp-0x180
echo === bytes around stack ===\n
x/512bx $esp-0x100
EOF

cat > "$DUMP_GDB" <<EOF
set pagination off
set confirm off
dump binary memory $WRAPPER_BIN $WRAPPER_START $WRAPPER_END
dump binary memory $CALLER_BIN $CALLER_START $CALLER_END
dump binary memory $FRAME2_BIN $FRAME2_START $FRAME2_END
EOF

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$MAIN_GDB" > "$MAIN_OUT" 2>&1
MAIN_STATUS=$?

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$STACK_GDB" > "$STACK_OUT" 2>&1
STACK_STATUS=$?

"$GDB" -nx -batch -e "$TRANSLATOR" -c "$CORE" -x "$DUMP_GDB" > "$DUMP_OUT" 2>&1
DUMP_STATUS=$?

{
    echo "== Lion Carbon SIGABRT postmortem =="
    echo "product_version=$PRODUCT_VERSION"
    echo "build_version=$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
    echo "core=$CORE"
    /bin/ls -l "$CORE" 2>&1 || true
    echo "translator=$TRANSLATOR"
    echo "translator_sha256=$TRANSLATOR_SHA"
    echo "expected_crash_eip=$CRASH_EIP"
    echo "expected_direct_caller=$CALLER_PC"
    echo "expected_frame2=$FRAME2_PC"
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

for spec in     "$WRAPPER_BIN:256"     "$CALLER_BIN:512"     "$FRAME2_BIN:384"; do
    file="${spec%:*}"
    expected="${spec##*:}"
    [ -f "$file" ] || fail "GDB did not produce $file; preserve $REPORT"
    size="$(/usr/bin/stat -f '%z' "$file" 2>/dev/null || echo 0)"
    [ "$size" = "$expected" ] || fail "$file has unexpected size $size (expected $expected); preserve $REPORT"
    /usr/bin/shasum -a 256 "$file" > "$file.sha256"
done

/usr/bin/grep -Fq "$CRASH_EIP" "$MAIN_OUT" ||     fail "postmortem output did not contain expected crash EIP; preserve $REPORT"
/usr/bin/grep -Fq "$CALLER_PC" "$MAIN_OUT" ||     fail "postmortem output did not contain expected direct caller; preserve $REPORT"

echo "Created:"
echo "  $REPORT"
echo "  $WRAPPER_BIN"
echo "  $WRAPPER_BIN.sha256"
echo "  $CALLER_BIN"
echo "  $CALLER_BIN.sha256"
echo "  $FRAME2_BIN"
echo "  $FRAME2_BIN.sha256"
echo "No live process was attached and no system file was modified."
