#!/bin/bash
set -u

REPORT="${1:-./launchservices-rosetta-environment-audit.txt}"
APP="${2:-}"

LS_FRAMEWORK="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework"
LS_BINARY="$LS_FRAMEWORK/Versions/A/LaunchServices"
LSREGISTER="$LS_FRAMEWORK/Support/lsregister"
OPEN_BIN="/usr/bin/open"
ROSETTA_VERSION="/private/var/db/RosettaVersion.plist"
TRANSLATOR="/usr/libexec/oah/translate"
NON_GRATA="/usr/libexec/oah/RosettaNonGrata"

TMP_DUMP="/tmp/launchservices-rosetta-audit-lsregister.$$"

cleanup() {
    /bin/rm -f "$TMP_DUMP"
}
trap cleanup EXIT HUP INT TERM

sha256() {
    /usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/awk '{print $1}'
}

section() {
    echo
    echo "== $* =="
}

{
    echo "== LaunchServices Rosetta environment audit =="
    echo "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
    echo "host=$(/bin/hostname)"
    echo "product_version=$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
    echo "build_version=$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
    echo "current_user=$(/usr/bin/id -un 2>/dev/null || true)"
    echo "console_user=$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"

    section "Kernel PowerPC handler"
    /usr/sbin/sysctl kern.exec.archhandler.powerpc 2>&1 || true
    /usr/sbin/sysctl hw.cputype hw.cpusubtype 2>&1 || true

    section "Rosetta runtime identity"
    for f in "$TRANSLATOR" "$NON_GRATA"; do
        if [ -e "$f" ]; then
            /bin/ls -l "$f"
            /usr/bin/file "$f" 2>&1 || true
            echo "sha256=$(sha256 "$f") path=$f"
        else
            echo "missing: $f"
        fi
    done

    if [ -f "$ROSETTA_VERSION" ]; then
        /bin/ls -l "$ROSETTA_VERSION"
        echo "sha256=$(sha256 "$ROSETTA_VERSION") path=$ROSETTA_VERSION"
        /bin/cat "$ROSETTA_VERSION"
    else
        echo "missing: $ROSETTA_VERSION"
    fi

    section "Rosetta receipts and metadata candidates"
    /usr/sbin/pkgutil --pkgs 2>/dev/null | /usr/bin/grep -Ei 'rosetta|oah' || true
    /usr/bin/find /var/db/receipts /Library/Receipts -maxdepth 2 -iname '*rosetta*' -print 2>/dev/null || true

    section "LaunchServices framework identity"
    if [ -f "$LS_BINARY" ]; then
        /bin/ls -l "$LS_BINARY"
        /usr/bin/file "$LS_BINARY" 2>&1 || true
        if [ -x /usr/bin/lipo ]; then
            /usr/bin/lipo -info "$LS_BINARY" 2>&1 || true
        fi
        echo "launchservices_sha256=$(sha256 "$LS_BINARY")"
        /usr/bin/otool -L "$LS_BINARY" 2>&1 || true
    else
        echo "missing: $LS_BINARY"
    fi

    section "LaunchServices Rosetta-related strings"
    if [ -f "$LS_BINARY" ]; then
        /usr/bin/strings -a "$LS_BINARY" 2>/dev/null |
            /usr/bin/grep -Ei 'rosetta|oah|powerpc|ppc|translate|RosettaVersion|archhandler|NoRosetta' |
            /usr/bin/sort -u || true
    fi

    section "LaunchServices Rosetta-related symbols/imports"
    if [ -f "$LS_BINARY" ]; then
        /usr/bin/nm -m "$LS_BINARY" 2>/dev/null |
            /usr/bin/grep -Ei 'rosetta|oah|powerpc|ppc|translate|sysctl|gestalt|arch' || true
        echo "-- indirect symbols/imports --"
        /usr/bin/otool -Iv "$LS_BINARY" 2>/dev/null |
            /usr/bin/grep -Ei 'rosetta|oah|powerpc|ppc|translate|sysctl|gestalt|arch' || true
    fi

    section "LaunchServices support files"
    if [ -d "$LS_FRAMEWORK" ]; then
        /usr/bin/find "$LS_FRAMEWORK" -maxdepth 4 -type f -print 2>/dev/null | /usr/bin/sort
    fi

    section "LaunchServices helper identities"
    for f in "$LSREGISTER" "$OPEN_BIN"; do
        if [ -e "$f" ]; then
            /bin/ls -l "$f"
            /usr/bin/file "$f" 2>&1 || true
            echo "sha256=$(sha256 "$f") path=$f"
        else
            echo "missing: $f"
        fi
    done

    section "LaunchServices/CoreServices processes"
    /bin/ps -ax 2>/dev/null | /usr/bin/grep -Ei 'launchservices|coreservices|lsregister' | /usr/bin/grep -v grep || true
    /bin/launchctl list 2>/dev/null | /usr/bin/grep -Ei 'launchservices|coreservices' || true

    section "Registered Rosetta Carbon app record"
    if [ -n "$APP" ]; then
        echo "app_argument=$APP"
        if [ -d "$APP" ]; then
            echo "app_executable=$APP/Contents/MacOS/RosettaCarbonLaunchServices"
            /usr/bin/file "$APP/Contents/MacOS/RosettaCarbonLaunchServices" 2>&1 || true
            if [ -x /usr/bin/lipo ]; then
                /usr/bin/lipo -info "$APP/Contents/MacOS/RosettaCarbonLaunchServices" 2>&1 || true
            fi
            /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c 'Print :LSArchitecturePriority' "$APP/Contents/Info.plist" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c 'Print :LSEnvironment' "$APP/Contents/Info.plist" 2>/dev/null || true
        else
            echo "missing app: $APP"
        fi
    else
        echo "No app path supplied; skipping bundle-specific inspection."
    fi

    if [ -x "$LSREGISTER" ]; then
        "$LSREGISTER" -dump > "$TMP_DUMP" 2>/dev/null || true
        if [ -s "$TMP_DUMP" ]; then
            /usr/bin/grep -i -B12 -A40 'com.therealsonicfan.rosetta-carbon-launchservices' "$TMP_DUMP" || true
            if [ -n "$APP" ]; then
                APP_BASE="$(/usr/bin/basename "$APP")"
                /usr/bin/grep -i -B12 -A40 "$APP_BASE" "$TMP_DUMP" || true
            fi
        else
            echo "lsregister dump unavailable"
        fi
    fi

    section "Known LaunchServices result code"
    echo "kLSNoRosettaEnvironmentErr=-10665"
    echo "Interpretation: LaunchServices determined that a PowerPC launch required a Rosetta environment that it considered unavailable."

    section "Audit integrity"
    echo "No process was launched by this audit."
    echo "No system file was modified by this audit."
} > "$REPORT"

echo "Created: $REPORT"
echo "No process was launched and no system file was modified."
