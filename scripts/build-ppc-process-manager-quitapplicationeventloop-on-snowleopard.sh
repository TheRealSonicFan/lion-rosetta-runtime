#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-postidentity-quitapplicationeventloop.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
EXPECTED_BUILD_ID="cps-quitapplicationeventloop-validation-v1"
EXPECTED_BASENAME="ppc-process-manager-cgs-session-bootstrap-integration-private-dyld"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper" >&2; exit 66; }
[ "$(/usr/bin/basename "$OUT")" = "$EXPECTED_BASENAME" ] || {
    echo "error: output basename must remain $EXPECTED_BASENAME for the exact registration predicate" >&2
    exit 64
}
/usr/bin/grep -Fq "$EXPECTED_BUILD_ID" "$SRC" || {
    echo "error: stale QuitApplicationEventLoop subject source; pull current runtime main" >&2
    exit 66
}
/usr/bin/grep -Fq 'timer_upp = NewEventLoopTimerUPP(ProbeTimer);' "$SRC" || {
    echo "error: NewEventLoopTimerUPP source expression missing from validation subject" >&2
    exit 66
}
/usr/bin/grep -Fq 'main_event_loop = GetMainEventLoop();' "$SRC" || {
    echo "error: GetMainEventLoop source expression missing from validation subject" >&2
    exit 66
}
/usr/bin/grep -Fq 'status = InstallEventLoopTimer(main_event_loop, 2.0 * kEventDurationSecond, 0.0, timer_upp, &g_timer_fired, &timer_ref);' "$SRC" || {
    echo "error: InstallEventLoopTimer source expression missing from validation subject" >&2
    exit 66
}
/usr/bin/grep -Fq 'QuitApplicationEventLoop();' "$SRC" || {
    echo "error: QuitApplicationEventLoop source expression missing from validation subject" >&2
    exit 66
}

/bin/rm -f "$OUT" "$INFO" "$SHA"

BUILD_COMPLETE=0
cleanup_on_exit() {
    rc=$?
    if [ "$BUILD_COMPLETE" -ne 1 ]; then
        /bin/rm -f "$OUT" "$INFO" "$SHA"
    fi
    return "$rc"
}
trap cleanup_on_exit EXIT

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 \
    -DPM_CPS_QUITAPPLICATIONEVENTLOOP_VALIDATION=1 \
    "$SRC" -framework Carbon -o "$OUT"
/bin/chmod +x "$OUT"
/usr/bin/python "$PATCH_DYLINKER" "$OUT" /usr/oah/dyld

is_ppc32_macho() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq 'Mach-O' || return 1
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

is_ppc32_macho "$OUT" || {
    echo "error: output is not a 32-bit PowerPC Mach-O executable" >&2
    /usr/bin/file "$OUT" >&2 || true
    /usr/bin/lipo -info "$OUT" >&2 2>/dev/null || true
    exit 70
}

OT="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: output LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/otool -L "$OUT" | /usr/bin/grep -Fq '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon' || {
    echo "error: output does not link Carbon" >&2
    exit 72
}

for sym in _GetProcessForPID _GetProcessPID _TransformProcessType _SetFrontProcess _GetFrontProcess _GetCurrentProcess _CreateNewWindow _CFStringCreateWithCString _SetWindowTitleWithCFString _ShowWindow _SelectWindow _IsWindowVisible _GetMainEventLoop _InstallEventLoopTimer _QuitApplicationEventLoop _CFRelease _DisposeWindow; do
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: output does not import $sym" >&2
        exit 72
    }
done

if /usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq '(^|[[:space:]])_NewEventLoopTimerUPP$'; then
    NEWEVENTLOOPTIMERUPP_LINKAGE="undefined-import"
else
    NEWEVENTLOOPTIMERUPP_LINKAGE="sdk-lowered-no-undefined-import"
fi

for marker in \
    "PM_CPS_CREATEWINDOW_BUILD_ID:$EXPECTED_BUILD_ID" \
    'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS' \
    'PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS' \
    'PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS' \
    'PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS' \
    'PM_POSTIDENTITY_MILESTONE:M14_BEFORE_GetFrontProcess' \
    'PM_POSTIDENTITY_MILESTONE:M15_AFTER_GetFrontProcess' \
    'PM_POSTIDENTITY_STATUS:GetFrontProcess=' \
    'PM_POSTIDENTITY_FRONT_PSN:' \
    'PM_POSTIDENTITY_RESULT:GETFRONTPROCESS_MATCH_PASS' \
    'PM_POSTIDENTITY_MILESTONE:M16_GETFRONTPROCESS_SUCCESS' \
    'PM_POSTIDENTITY_MILESTONE:M17_BEFORE_GetCurrentProcess' \
    'PM_POSTIDENTITY_MILESTONE:M18_AFTER_GetCurrentProcess' \
    'PM_POSTIDENTITY_STATUS:GetCurrentProcess=' \
    'PM_POSTIDENTITY_CURRENT_PSN:' \
    'PM_POSTIDENTITY_RESULT:GETCURRENTPROCESS_MATCH_PASS' \
    'PM_POSTIDENTITY_MILESTONE:M19_GETCURRENTPROCESS_SUCCESS' \
    'PM_POSTIDENTITY_MILESTONE:M20_BEFORE_CreateNewWindow' \
    'PM_POSTIDENTITY_MILESTONE:M21_AFTER_CreateNewWindow' \
    'PM_POSTIDENTITY_STATUS:CreateNewWindow=' \
    'PM_POSTIDENTITY_WINDOW:' \
    'PM_POSTIDENTITY_RESULT:CREATENEWWINDOW_PASS' \
    'PM_POSTWINDOWTITLE_MILESTONE:T00_BEFORE_CFStringCreateWithCString' \
    'PM_POSTWINDOWTITLE_MILESTONE:T01_AFTER_CFStringCreateWithCString' \
    'PM_POSTWINDOWTITLE_CFSTRING:' \
    'PM_POSTWINDOWTITLE_RESULT:CFSTRING_PASS' \
    'PM_POSTWINDOWTITLE_MILESTONE:T02_BEFORE_SetWindowTitleWithCFString' \
    'PM_POSTWINDOWTITLE_MILESTONE:T03_AFTER_SetWindowTitleWithCFString' \
    'PM_POSTWINDOWTITLE_STATUS:SetWindowTitleWithCFString=' \
    'PM_POSTWINDOWTITLE_RESULT:SETWINDOWTITLE_PASS' \
    'PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow' \
    'PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow' \
    'PM_POSTWINDOWSHOW_RESULT:SHOWWINDOW_PASS' \
    'PM_POSTWINDOWSELECT_MILESTONE:S02_BEFORE_SelectWindow' \
    'PM_POSTWINDOWSELECT_MILESTONE:S03_AFTER_SelectWindow' \
    'PM_POSTWINDOWSELECT_RESULT:SELECTWINDOW_PASS' \
    'PM_POSTWINDOWVISIBLE_MILESTONE:S04_BEFORE_IsWindowVisible' \
    'PM_POSTWINDOWVISIBLE_MILESTONE:S05_AFTER_IsWindowVisible' \
    'PM_POSTWINDOWVISIBLE_VALUE:visible=' \
    'PM_POSTWINDOWVISIBLE_RESULT:ISWINDOWVISIBLE_PASS' \
    'PM_POSTWINDOWTIMERUPP_MILESTONE:S06_BEFORE_NewEventLoopTimerUPP' \
    'PM_POSTWINDOWTIMERUPP_MILESTONE:S07_AFTER_NewEventLoopTimerUPP' \
    'PM_POSTWINDOWTIMERUPP_POINTER:pointer=' \
    'PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_PASS' \
    'PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S08_BEFORE_GetMainEventLoop' \
    'PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S09_AFTER_GetMainEventLoop' \
    'PM_POSTWINDOWMAINEVENTLOOP_POINTER:pointer=' \
    'PM_POSTWINDOWMAINEVENTLOOP_RESULT:GETMAINEVENTLOOP_PASS' \
    'PM_POSTWINDOWTIMERINSTALL_MILESTONE:S10_BEFORE_InstallEventLoopTimer' \
    'PM_POSTWINDOWTIMERINSTALL_MILESTONE:S11_AFTER_InstallEventLoopTimer' \
    'PM_POSTWINDOWTIMERINSTALL_STATUS:InstallEventLoopTimer=' \
    'PM_POSTWINDOWTIMERINSTALL_POINTER:pointer=' \
    'PM_POSTWINDOWTIMERINSTALL_CALLBACK:fired=' \
    'PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_PASS' \
    'PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S12_BEFORE_QuitApplicationEventLoop' \
    'PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S13_AFTER_QuitApplicationEventLoop' \
    'PM_POSTWINDOWEVENTLOOPQUIT_CALLBACK:fired=' \
    'PM_POSTWINDOWEVENTLOOPQUIT_RESULT:QUITAPPLICATIONEVENTLOOP_PASS' \
    'PM_POSTWINDOWTITLE_MILESTONE:T04_BEFORE_CFRelease' \
    'PM_POSTWINDOWTITLE_MILESTONE:T05_AFTER_CFRelease' \
    'PM_POSTIDENTITY_MILESTONE:M22_BEFORE_DisposeWindow' \
    'PM_POSTIDENTITY_MILESTONE:M23_AFTER_DisposeWindow' \
    'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS'; do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required subject marker missing: $marker" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"
SOURCE_SHA="$(/usr/bin/shasum -a 256 "$SRC" | /usr/bin/awk '{print $1}')"

{
    echo "== PPC restored-stack post-InstallEventLoopTimer QuitApplicationEventLoop validation subject =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "source_sha256=$SOURCE_SHA"
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "required_basename=$EXPECTED_BASENAME"
    echo "neweventlooptimerupp_source_expression=NewEventLoopTimerUPP(ProbeTimer)"
    echo "neweventlooptimerupp_linkage=$NEWEVENTLOOPTIMERUPP_LINKAGE"
    echo "getmaineventloop_source_expression=GetMainEventLoop()"
    echo "getmaineventloop_linkage=undefined-import"
    echo "installeventlooptimer_source_expression=InstallEventLoopTimer(main_event_loop,2.0*kEventDurationSecond,0.0,timer_upp,&g_timer_fired,&timer_ref)"
    echo "installeventlooptimer_linkage=undefined-import"
    echo "installeventlooptimer_callback_expected_before_event_loop=0"
    echo "quitapplicationeventloop_source_expression=QuitApplicationEventLoop()"
    echo "quitapplicationeventloop_linkage=undefined-import"
    echo "quitapplicationeventloop_context=no-active-application-event-loop"
    echo "quitapplicationeventloop_callback_expected=0"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    echo "$OT"
    echo
    echo "== Process Manager imports =="
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -E '(_GetProcessForPID|_GetProcessPID|_TransformProcessType|_SetFrontProcess|_GetFrontProcess|_GetCurrentProcess|_CreateNewWindow|_CFStringCreateWithCString|_SetWindowTitleWithCFString|_ShowWindow|_SelectWindow|_IsWindowVisible|_NewEventLoopTimerUPP|_GetMainEventLoop|_InstallEventLoopTimer|_QuitApplicationEventLoop|_CFRelease|_DisposeWindow)' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

/usr/bin/shasum -a 256 "$OUT" > "$SHA"
BUILD_COMPLETE=1

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
