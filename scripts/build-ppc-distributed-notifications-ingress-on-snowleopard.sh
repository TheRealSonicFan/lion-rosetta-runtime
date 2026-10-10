#!/bin/bash
set -e

PROBE_OUT="${1:-./ppc-distributed-notifications-ingress-probe-private-dyld}"
INTERPOSER_OUT="${2:-./ppc-distributed-notifications-ingress-interposer.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE_SRC="$ROOT/tests/ppc-distributed-notifications-ingress-probe.c"
INTERPOSER_SRC="$ROOT/tests/ppc-distributed-notifications-ingress-interposer.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

EXPECTED_PROBE_BUILD_ID="distributed-notifications-ppc-ingress-probe-v1"
EXPECTED_INTERPOSER_BUILD_ID="distributed-notifications-ppc-ingress-interposer-v2"

[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || {
    echo "error: build PPC ingress artifacts on Snow Leopard 10.6.8" >&2
    exit 65
}
[ -x "$CC_SELECTED" ] || {
    echo "error: compiler not executable: $CC_SELECTED" >&2
    exit 69
}
for file in "$PROBE_SRC" "$INTERPOSER_SRC" "$PATCH_DYLINKER"; do
    [ -f "$file" ] || {
        echo "error: missing $file" >&2
        exit 66
    }
done

/bin/rm -f     "$PROBE_OUT" "$PROBE_OUT.sha256" "$PROBE_OUT.info.txt"     "$INTERPOSER_OUT" "$INTERPOSER_OUT.sha256" "$INTERPOSER_OUT.info.txt"

"$CC_SELECTED" -arch ppc -std=gnu99 -Wall -Wextra     -mmacosx-version-min=10.5     "$PROBE_SRC"     -framework CoreFoundation     -o "$PROBE_OUT"

/bin/chmod 755 "$PROBE_OUT"
/usr/bin/python "$PATCH_DYLINKER" "$PROBE_OUT" /usr/oah/dyld

"$CC_SELECTED" -arch ppc -std=gnu99 -Wall -Wextra     -mmacosx-version-min=10.5 -dynamiclib     "$INTERPOSER_SRC"     -install_name "@loader_path/$(/usr/bin/basename "$INTERPOSER_OUT")"     -o "$INTERPOSER_OUT"

/bin/chmod 755 "$INTERPOSER_OUT"

macho_archs() {
    file="$1"
    info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"

    case "$info" in
        *" is architecture: "*)
            echo "$info" | /usr/bin/sed 's/^.* is architecture: //'
            ;;
        *" are: "*)
            echo "$info" | /usr/bin/sed 's/^.* are: //'
            ;;
        *)
            return 1
            ;;
    esac
}

is_ppc32_arch_name() {
    case "$1" in
        ppc|ppc601|ppc603|ppc603e|ppc603ev|ppc604|ppc604e|ppc750|ppc7400|ppc7450|ppc970)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

arch_matches() {
    wanted="$1"
    present="$2"

    if [ "$wanted" = "ppc" ]; then
        is_ppc32_arch_name "$present"
        return $?
    fi

    [ "$present" = "$wanted" ]
}

has_arch() {
    file="$1"
    wanted="$2"
    archs="$(macho_archs "$file")" || return 1

    for arch in $archs; do
        arch_matches "$wanted" "$arch" && return 0
    done
    return 1
}

is_thin_ppc32_macho() {
    file="$1"
    info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"
    arch=""

    case "$info" in
        *" is architecture: "*)
            arch="$(echo "$info" | /usr/bin/sed 's/^.* is architecture: //')"
            ;;
        *)
            return 1
            ;;
    esac

    is_ppc32_arch_name "$arch" || return 1

    /usr/bin/file "$file" | /usr/bin/grep -Eq         'Mach-O .* ppc

for file in "$PROBE_OUT" "$INTERPOSER_OUT"; do
    is_thin_ppc32_macho "$file" || {
        echo "error: expected a thin 32-bit PPC Mach-O: $file" >&2
        /usr/bin/file "$file" >&2 || true
        /usr/bin/lipo -info "$file" >&2 || true
        exit 70
    }
done

# Keep a generic architecture parser exercised as a second independent check.
for file in "$PROBE_OUT" "$INTERPOSER_OUT"; do
    has_arch "$file" ppc || {
        echo "error: 32-bit PPC architecture family not reported by lipo -info: $file" >&2
        /usr/bin/lipo -info "$file" >&2 || true
        exit 70
    }
done

OT="$(/usr/bin/otool -l "$PROBE_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: probe LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/strings "$PROBE_OUT" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID" || {
    echo "error: probe build marker missing" >&2
    exit 71
}

/usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" || {
    echo "error: interposer build marker missing" >&2
    exit 71
}

for sym in     _CFNotificationCenterGetDistributedCenter     _CFNotificationCenterAddObserver     _CFNotificationCenterPostNotificationWithOptions     _CFNotificationCenterRemoveObserver
do
    /usr/bin/nm -u "$PROBE_OUT" | /usr/bin/grep -Eq         "(^|[[:space:]])$sym$" || {
        echo "error: probe missing import $sym" >&2
        exit 72
    }
done

for sym in     _bootstrap_look_up2     _mach_msg     _posix_spawn     _pthread_create     _socketpair     __NSGetEnviron
do
    /usr/bin/nm -u "$INTERPOSER_OUT" | /usr/bin/grep -Eq         "(^|[[:space:]])$sym$" || {
        echo "error: interposer missing import $sym" >&2
        exit 72
    }
done

if /usr/bin/nm -u "$INTERPOSER_OUT" | /usr/bin/grep -Eq     '(^|[[:space:]])_environ$'; then
    echo "error: interposer must not contain a direct _environ import; use _NSGetEnviron" >&2
    exit 72
fi

INTERPOSE_SECTION="$(/usr/bin/otool -l "$INTERPOSER_OUT" |     /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq "__interpose" || {
    echo "error: interpose section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000008' || {
    echo "error: interposer must contain exactly one PPC interpose tuple" >&2
    exit 72
}

for marker in     'com.apple.distributed_notifications.2'     'lion-ppc-ingress-v1'     'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:'     'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:'     'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:'     'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS'
do
    /usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: interposer marker missing: $marker" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null &&     /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] ||     RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== PPC distributed-notifications ingress probe =="
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "compiler=$CC_SELECTED"
    echo "build_id=$EXPECTED_PROBE_BUILD_ID"
    /usr/bin/file "$PROBE_OUT"
    /usr/bin/lipo -info "$PROBE_OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    echo "$OT"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$PROBE_OUT"
} > "$PROBE_OUT.info.txt"

{
    echo "== PPC distributed-notifications ingress interposer =="
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "compiler=$CC_SELECTED"
    echo "build_id=$EXPECTED_INTERPOSER_BUILD_ID"
    /usr/bin/file "$INTERPOSER_OUT"
    /usr/bin/lipo -info "$INTERPOSER_OUT" 2>/dev/null || true
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$INTERPOSER_OUT"
} > "$INTERPOSER_OUT.info.txt"

/usr/bin/shasum -a 256 "$PROBE_OUT" > "$PROBE_OUT.sha256"
/usr/bin/shasum -a 256 "$INTERPOSER_OUT" > "$INTERPOSER_OUT.sha256"

echo "Created:"
echo "  $PROBE_OUT"
echo "  $PROBE_OUT.info.txt"
echo "  $PROBE_OUT.sha256"
echo "  $INTERPOSER_OUT"
echo "  $INTERPOSER_OUT.info.txt"
echo "  $INTERPOSER_OUT.sha256"
 || return 1

    return 0
}

for file in "$PROBE_OUT" "$INTERPOSER_OUT"; do
    is_thin_ppc32_macho "$file" || {
        echo "error: expected a thin 32-bit PPC Mach-O: $file" >&2
        /usr/bin/file "$file" >&2 || true
        /usr/bin/lipo -info "$file" >&2 || true
        exit 70
    }
done

# Keep a generic architecture parser exercised as a second independent check.
for file in "$PROBE_OUT" "$INTERPOSER_OUT"; do
    has_exact_arch "$file" ppc || {
        echo "error: PPC architecture not reported by lipo -info: $file" >&2
        /usr/bin/lipo -info "$file" >&2 || true
        exit 70
    }
done

OT="$(/usr/bin/otool -l "$PROBE_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: probe LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/strings "$PROBE_OUT" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID" || {
    echo "error: probe build marker missing" >&2
    exit 71
}

/usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" || {
    echo "error: interposer build marker missing" >&2
    exit 71
}

for sym in     _CFNotificationCenterGetDistributedCenter     _CFNotificationCenterAddObserver     _CFNotificationCenterPostNotificationWithOptions     _CFNotificationCenterRemoveObserver
do
    /usr/bin/nm -u "$PROBE_OUT" | /usr/bin/grep -Eq         "(^|[[:space:]])$sym$" || {
        echo "error: probe missing import $sym" >&2
        exit 72
    }
done

for sym in     _bootstrap_look_up2     _mach_msg     _posix_spawn     _pthread_create     _socketpair     __NSGetEnviron
do
    /usr/bin/nm -u "$INTERPOSER_OUT" | /usr/bin/grep -Eq         "(^|[[:space:]])$sym$" || {
        echo "error: interposer missing import $sym" >&2
        exit 72
    }
done

if /usr/bin/nm -u "$INTERPOSER_OUT" | /usr/bin/grep -Eq     '(^|[[:space:]])_environ$'; then
    echo "error: interposer must not contain a direct _environ import; use _NSGetEnviron" >&2
    exit 72
fi

INTERPOSE_SECTION="$(/usr/bin/otool -l "$INTERPOSER_OUT" |     /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq "__interpose" || {
    echo "error: interpose section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000008' || {
    echo "error: interposer must contain exactly one PPC interpose tuple" >&2
    exit 72
}

for marker in     'com.apple.distributed_notifications.2'     'lion-ppc-ingress-v1'     'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:'     'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:'     'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:'     'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS'
do
    /usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: interposer marker missing: $marker" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null &&     /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] ||     RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== PPC distributed-notifications ingress probe =="
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "compiler=$CC_SELECTED"
    echo "build_id=$EXPECTED_PROBE_BUILD_ID"
    /usr/bin/file "$PROBE_OUT"
    /usr/bin/lipo -info "$PROBE_OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    echo "$OT"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$PROBE_OUT"
} > "$PROBE_OUT.info.txt"

{
    echo "== PPC distributed-notifications ingress interposer =="
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "compiler=$CC_SELECTED"
    echo "build_id=$EXPECTED_INTERPOSER_BUILD_ID"
    /usr/bin/file "$INTERPOSER_OUT"
    /usr/bin/lipo -info "$INTERPOSER_OUT" 2>/dev/null || true
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$INTERPOSER_OUT"
} > "$INTERPOSER_OUT.info.txt"

/usr/bin/shasum -a 256 "$PROBE_OUT" > "$PROBE_OUT.sha256"
/usr/bin/shasum -a 256 "$INTERPOSER_OUT" > "$INTERPOSER_OUT.sha256"

echo "Created:"
echo "  $PROBE_OUT"
echo "  $PROBE_OUT.info.txt"
echo "  $PROBE_OUT.sha256"
echo "  $INTERPOSER_OUT"
echo "  $INTERPOSER_OUT.info.txt"
echo "  $INTERPOSER_OUT.sha256"
