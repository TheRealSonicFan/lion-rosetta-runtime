#!/bin/bash
set -u

EXE="${1:-./ppc-process-manager-getprocessforpid-first-private-dyld}"
SHA_FILE="${2:-$EXE.sha256}"
APP="${3:-./RosettaProcessManagerPIDFirst.app}"

EXEC_NAME="RosettaProcessManagerPIDFirst"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
PLIST="$CONTENTS/Info.plist"
PKGINFO="$CONTENTS/PkgInfo"
MANIFEST="$APP.manifest.txt"

fail() {
    echo "error: $*" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

[ -x "$EXE" ] || fail "missing or non-executable PPC subject: $EXE"
[ -f "$SHA_FILE" ] || fail "missing SHA-256 sidecar: $SHA_FILE"

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SHA_FILE")"
[ -n "$EXPECTED_EXE_SHA" ] || fail "could not read executable SHA-256"
ACTUAL_EXE_SHA="$(sha256 "$EXE")"
[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "executable hash mismatch"

DESC="$(/usr/bin/file "$EXE" 2>/dev/null || true)"
echo "$DESC" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || fail "subject is not PowerPC"
echo "$DESC" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && fail "subject is PPC64, expected 32-bit PPC"

OT="$(/usr/bin/otool -l "$EXE" 2>&1 | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "subject LC_LOAD_DYLINKER is not /usr/oah/dyld"

/bin/rm -rf "$APP" || fail "could not remove old app bundle"
/bin/mkdir -p "$MACOS" || fail "could not create app bundle"

cp -p "$EXE" "$MACOS/$EXEC_NAME" || fail "could not copy PPC executable into app bundle"
/bin/chmod 755 "$MACOS/$EXEC_NAME" || fail "could not mark bundled executable executable"

cat > "$PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>RosettaProcessManagerPIDFirst</string>
    <key>CFBundleIdentifier</key>
    <string>com.therealsonicfan.rosetta-processmanager-pidfirst</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Rosetta Process Manager PID First</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>RPMF</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.5</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>ppc</string>
    </array>
    <key>LSEnvironment</key>
    <dict>
        <key>DYLD_SHARED_CACHE_DONT_VALIDATE</key>
        <string>1</string>
        <key>DYLD_PRINT_LIBRARIES</key>
        <string>1</string>
    </dict>
</dict>
</plist>
EOF

printf 'APPLRPMF' > "$PKGINFO"

BUNDLED_SHA="$(sha256 "$MACOS/$EXEC_NAME")"
[ "$BUNDLED_SHA" = "$EXPECTED_EXE_SHA" ] || fail "bundled executable hash changed"

CACHE_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_SHARED_CACHE_DONT_VALIDATE' "$PLIST" 2>/dev/null || true)"
PRINT_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_PRINT_LIBRARIES' "$PLIST" 2>/dev/null || true)"
PLIST_EXEC="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST" 2>/dev/null || true)"

[ "$CACHE_ENV" = "1" ] || fail "Info.plist cache-bypass environment is missing"
[ "$PRINT_ENV" = "1" ] || fail "Info.plist DYLD_PRINT_LIBRARIES is missing"
[ "$PLIST_EXEC" = "$EXEC_NAME" ] || fail "Info.plist CFBundleExecutable mismatch"

{
    echo "== Rosetta Process Manager GetProcessForPID-first bundle =="
    echo "app=$APP"
    echo "executable=$MACOS/$EXEC_NAME"
    echo "executable_sha256=$BUNDLED_SHA"
    echo "info_plist_sha256=$(sha256 "$PLIST")"
    echo "pkginfo_sha256=$(sha256 "$PKGINFO")"
    echo "CFBundleExecutable=$PLIST_EXEC"
    echo "LSEnvironment.DYLD_SHARED_CACHE_DONT_VALIDATE=$CACHE_ENV"
    echo "LSEnvironment.DYLD_PRINT_LIBRARIES=$PRINT_ENV"
    echo
    /usr/bin/file "$MACOS/$EXEC_NAME"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -info "$MACOS/$EXEC_NAME" || true
    fi
    /usr/bin/otool -l "$MACOS/$EXEC_NAME" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    /usr/bin/otool -L "$MACOS/$EXEC_NAME"
} > "$MANIFEST"

echo "Created:"
echo "  $APP"
echo "  $MANIFEST"
