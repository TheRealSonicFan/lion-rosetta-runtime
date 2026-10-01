#!/bin/bash
set -e

OUT="${1:-./lion-rosetta-test-report.txt}"
SMOKE="${2:-}"
EXECUTE_SMOKE="${3:-}"
OTOOL="$(command -v otool 2>/dev/null || true)"

{
    echo "lion-rosetta first-test report"
    echo "generated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo

    echo "== System =="
    /usr/bin/sw_vers 2>&1 || true
    if [ -x /usr/bin/uname ]; then
        /usr/bin/uname -a 2>&1 || true
    elif [ -x /bin/uname ]; then
        /bin/uname -a 2>&1 || true
    else
        uname -a 2>&1 || true
    fi

    echo
    echo "== Architecture handler =="
    /usr/sbin/sysctl kern.exec.archhandler.powerpc 2>&1 || true

    echo
    echo "== Kernel handler strings =="
    if [ -r /mach_kernel ]; then
        /usr/bin/strings -a /mach_kernel 2>/dev/null | /usr/bin/grep '/usr/libexec/oah/' || true
        /usr/bin/shasum -a 256 /mach_kernel 2>/dev/null || true
    else
        echo "unreadable: /mach_kernel"
    fi

    echo
    echo "== translate =="
    for f in /usr/libexec/oah/translate /usr/libexec/oah/RosettaNonGrata; do
        if [ -f "$f" ]; then
            echo "-- $f"
            /usr/bin/file "$f" 2>&1 || true
            if [ -n "$OTOOL" ]; then
                "$OTOOL" -L "$f" 2>&1 || true
            else
                echo "otool: unavailable (Developer Tools not installed)"
            fi
            /usr/bin/shasum -a 256 "$f" 2>&1 || true
        else
            echo "missing: $f"
        fi
    done

    echo
    echo "== Rosetta dyld cache =="
    for f in /private/var/db/dyld/dyld_shared_cache_rosetta /private/var/db/dyld/dyld_shared_cache_rosetta.map; do
        if [ -f "$f" ]; then
            /usr/bin/stat -f '%N size=%z mtime_epoch=%m' "$f" 2>/dev/null || /bin/ls -ln "$f"
            /usr/bin/shasum -a 256 "$f" 2>/dev/null || true
        else
            echo "missing: $f"
        fi
    done
    if [ -f /private/var/db/dyld/dyld_shared_cache_rosetta ]; then
        printf 'cache_magic='
        /usr/bin/head -c 16 /private/var/db/dyld/dyld_shared_cache_rosetta 2>/dev/null || true
        echo
    fi

    echo
    echo "== Native dependencies used by translate =="
    for f in \
        /System/Library/Frameworks/IOKit.framework/Versions/A/IOKit \
        /usr/lib/libstdc++.6.dylib \
        /usr/lib/libgcc_s.1.dylib \
        /usr/lib/libSystem.B.dylib \
        /usr/lib/dyld; do
        if [ -e "$f" ]; then
            echo "-- present: $f"
            /usr/bin/file "$f" 2>&1 || true
        else
            echo "MISSING: $f"
        fi
    done

    echo
    echo "== Candidate Rosetta crash reports =="
    latest_crash=""
    latest_current_boot_crash=""
    boot_epoch=""
    if [ -x /usr/sbin/sysctl ]; then
        boot_epoch="$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null | /usr/bin/sed -E 's/.*sec = ([0-9]+).*/\\1/' || true)"
        case "$boot_epoch" in
            ''|*[!0-9]*) boot_epoch="" ;;
        esac
    fi
    [ -n "$boot_epoch" ] && echo "boot_epoch=$boot_epoch"

    for dir in "$HOME/Library/Logs/DiagnosticReports" "$HOME/Library/Logs/CrashReporter" /Library/Logs/DiagnosticReports /Library/Logs/CrashReporter; do
        if [ -d "$dir" ]; then
            for crash in "$dir"/ppc-smoketest*.crash "$dir"/translate*.crash; do
                [ -f "$crash" ] || continue
                crash_epoch="$(/usr/bin/stat -f '%m' "$crash" 2>/dev/null || echo 0)"
                echo "$crash mtime_epoch=$crash_epoch"
                if [ -z "$latest_crash" ] || [ "$crash" -nt "$latest_crash" ]; then
                    latest_crash="$crash"
                fi
                if [ -n "$boot_epoch" ] && [ "$crash_epoch" -ge "$boot_epoch" ] 2>/dev/null; then
                    if [ -z "$latest_current_boot_crash" ] || [ "$crash" -nt "$latest_current_boot_crash" ]; then
                        latest_current_boot_crash="$crash"
                    fi
                fi
            done
        fi
    done

    if [ -z "$latest_crash" ]; then
        echo "none found"
    elif [ -n "$boot_epoch" ] && [ -z "$latest_current_boot_crash" ]; then
        echo
        echo "No Rosetta crash report from the current boot."
        echo "Newest historical crash (not embedded): $latest_crash"
    else
        crash_to_embed="$latest_current_boot_crash"
        [ -n "$crash_to_embed" ] || crash_to_embed="$latest_crash"
        echo
        echo "== Newest Rosetta crash report from current boot =="
        echo "path=$crash_to_embed"
        /bin/cat "$crash_to_embed" 2>&1 || true
    fi

    echo
    echo "== Relevant system.log tail =="
    if [ -r /var/log/system.log ]; then
        /usr/bin/grep -Ei 'Rosetta|translate|ppc-smoketest|shared region|dyld' /var/log/system.log 2>/dev/null | /usr/bin/tail -n 200 || true
    else
        echo "unreadable: /var/log/system.log"
    fi

    if [ -n "$SMOKE" ]; then
        echo
        echo "== PPC smoke test =="
        if [ -x "$SMOKE" ]; then
            /usr/bin/file "$SMOKE" 2>&1 || true
            if [ -n "$OTOOL" ]; then
                "$OTOOL" -L "$SMOKE" 2>&1 || true
            else
                echo "otool: unavailable (Developer Tools not installed)"
            fi
            /usr/bin/shasum -a 256 "$SMOKE" 2>&1 || true

            if [ "$EXECUTE_SMOKE" = "--execute" ]; then
                echo "-- execution --"
                if "$SMOKE"; then rc=0; else rc=$?; fi
                echo "smoke_exit_status=$rc"
            else
                echo "execution skipped (pass --execute as third argument to rerun)"
            fi
        else
            echo "not executable or missing: $SMOKE"
        fi
    fi
} > "$OUT" 2>&1

echo "Created: $OUT"
