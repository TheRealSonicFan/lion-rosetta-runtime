#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/native-dn-runapplicationeventloop-remaining-registration-broker.c"
OUT="${1:-./dn-runapplicationeventloop-remaining-registration-broker}"
EXPECTED_BUILD_ID="distributed-notifications-runapplicationeventloop-remaining-registration-broker-v1"

for generated in "$OUT" "$OUT.sha256" "$OUT.info.txt"; do
    generated_name="$(/usr/bin/basename "$generated")"
    [ "${#generated_name}" -le 240 ] || {
        echo "error: artifact filename too long: $generated_name" >&2
        exit 64
    }
done

[ "$(/usr/bin/sw_vers -productVersion)" = "10.7.5" ] || {
    echo "error: build RunApplicationEventLoop exact remaining-wave registration broker on Lion 10.7.5" >&2
    exit 65
}

if [ -n "${CC:-}" ]; then
    CC_SELECTED="$CC"
elif [ -x /usr/bin/clang ]; then
    CC_SELECTED=/usr/bin/clang
elif [ -x /Developer/usr/bin/clang ]; then
    CC_SELECTED=/Developer/usr/bin/clang
elif [ -x /usr/bin/gcc-4.2 ]; then
    CC_SELECTED=/usr/bin/gcc-4.2
elif [ -x /Developer/usr/bin/gcc-4.2 ]; then
    CC_SELECTED=/Developer/usr/bin/gcc-4.2
else
    echo "error: no supported Lion compiler found" >&2
    exit 69
fi

[ -x "$CC_SELECTED" ] || {
    echo "error: compiler not executable: $CC_SELECTED" >&2
    exit 69
}
[ -f "$SRC" ] || {
    echo "error: missing source: $SRC" >&2
    exit 66
}

/bin/rm -f "$OUT" "$OUT.sha256" "$OUT.info.txt"

"$CC_SELECTED" -arch i386 -std=gnu99 -Wall -Wextra \
    -mmacosx-version-min=10.7 \
    "$SRC" \
    -framework CoreFoundation \
    -o "$OUT"

/bin/chmod 755 "$OUT"

if /usr/bin/lipo -verify_arch i386 "$OUT" >/dev/null 2>&1; then
    :
elif /usr/bin/lipo "$OUT" -verify_arch i386 >/dev/null 2>&1; then
    :
else
    echo "error: RunApplicationEventLoop exact remaining-wave registration broker is not i386" >&2
    /usr/bin/file "$OUT" >&2 || true
    exit 70
fi

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: RunApplicationEventLoop exact remaining-wave registration broker build marker missing" >&2
    exit 71
}

for sym in \
    _CFPropertyListCreateWithData \
    _CFPropertyListCreateData \
    _CFNotificationCenterGetDistributedCenter \
    _CFNotificationCenterAddObserver \
    _CFNotificationCenterRemoveObserver
do
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -Fq "$sym" || {
        echo "error: RunApplicationEventLoop exact remaining-wave registration broker missing import $sym" >&2
        exit 72
    }
done

for marker in \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2' \
    'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SEVENTH_REGISTRATION_POLICY:index=7 allowed=5 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_POLICY:index=11 allowed=9 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_POLICY:index=12 allowed=10 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_REGISTRATION_POLICY:index=13 allowed=11 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_REGISTRATION_POLICY:index=14 allowed=12 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FIFTEENTH_REGISTRATION_POLICY:index=15 allowed=13 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_SIXTEENTH_REGISTRATION_POLICY:index=16 allowed=14 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_SEVENTEENTH_REGISTRATION_POLICY:index=17 allowed=15 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTEENTH_REGISTRATION_POLICY:index=18 allowed=16 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINETEENTH_REGISTRATION_POLICY:index=19 allowed=17 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWENTIETH_REGISTRATION_POLICY:index=20 allowed=18 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWENTYFIRST_REGISTRATION_POLICY:index=21 allowed=19 counter=1' \
    'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_CALLBACK:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS'
do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: RunApplicationEventLoop exact remaining-wave registration broker marker missing: $marker" >&2
        exit 72
    }
done

for literal in \
    'com.apple.MCX._managementStatusChangedForDomains' \
    'com.apple.MCX' \
    'com.apple.CFPreferences._domainsChangedExternally' \
    'com.apple.CFPreferences' \
    'AppleColorPreferencesChangedNotification' \
    'AppleAquaColorVariantChanged' \
    'com_apple_CoreText_FontManagerChangedNotification' \
    'com.apple.ColorSync.DisplayProfileNotification' \
    'AppleDatePreferencesChangedNotification' \
    'AppleTimePreferencesChangedNotification' \
    'AppleNumberPreferencesChangedNotification' \
    'AppleTextBehaviorPreferencesChangedNotification' \
    'AppleLanguagePreferencesChangedNotification' \
    'AppleKeyboardMenuPreferencesChangedNotification' \
    'AppleKeyboardPreferencesChangedNotification' \
    'AppleKeyboardPreferencesSelectedItemsChangedNotification' \
    'AppleSelectedInputMethodPasteboardInvalidNotification' \
    'AppleTextInputMenuExtraDidLoadNotification' \
    'AppleInstalledInputSourcesChangedNotification' \
    'AppleEnabledInputSourcesChangedNotification' \
    'AppleSelectedInputSourcesChangedNotification' \
    'com.apple.accessibility.api' \
    'kCFNotificationAnyObject'
do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$literal" || {
        echo "error: RunApplicationEventLoop exact remaining-wave registration broker exact-schema literal missing: $literal" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== Native distributed-notifications RunApplicationEventLoop exact remaining-wave registration broker =="
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "compiler=$CC_SELECTED"
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "source=$SRC"
    /usr/bin/shasum -a 256 "$SRC"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== Dependencies =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$OUT.info.txt"

/usr/bin/shasum -a 256 "$OUT" > "$OUT.sha256"

echo "Created:"
echo "  $OUT"
echo "  $OUT.info.txt"
echo "  $OUT.sha256"
