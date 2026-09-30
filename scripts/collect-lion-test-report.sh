#!/bin/bash
set -e

OUT="${1:-./lion-rosetta-test-report.txt}"
SMOKE="${2:-}"

{
    echo "lion-rosetta first-test report"
    echo "generated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo

    echo "== System =="
    /usr/bin/sw_vers 2>&1 || true
    /bin/uname -a 2>&1 || true

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
            /usr/bin/otool -L "$f" 2>&1 || true
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
    found=0
    for dir in "$HOME/Library/Logs/DiagnosticReports" "$HOME/Library/Logs/CrashReporter" /Library/Logs/DiagnosticReports /Library/Logs/CrashReporter; do
        if [ -d "$dir" ]; then
            for crash in "$dir"/translate*.crash "$dir"/ppc-smoketest*.crash; do
                [ -f "$crash" ] && echo "$crash"
            done
            found=1
        fi
    done
    [ "$found" -eq 1 ] || echo "no standard crash-report directories found"

    if [ -n "$SMOKE" ]; then
        echo
        echo "== PPC smoke test =="
        if [ -x "$SMOKE" ]; then
            /usr/bin/file "$SMOKE" 2>&1 || true
            /usr/bin/otool -L "$SMOKE" 2>&1 || true
            /usr/bin/shasum -a 256 "$SMOKE" 2>&1 || true
            echo "-- execution --"
            if "$SMOKE"; then rc=0; else rc=$?; fi
            echo "smoke_exit_status=$rc"
        else
            echo "not executable or missing: $SMOKE"
        fi
    fi
} > "$OUT" 2>&1

echo "Created: $OUT"
