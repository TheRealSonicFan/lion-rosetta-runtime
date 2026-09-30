#!/bin/bash

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
echo "== System =="
/usr/bin/sw_vers 2>/dev/null || true
/bin/uname -a

echo
echo "== Kernel architecture handler =="
/usr/sbin/sysctl kern.exec.archhandler.powerpc 2>&1 || true

echo
echo "== OAH directory =="
/bin/ls -la /usr/libexec/oah 2>&1 || true

for f in /usr/libexec/oah/translate /usr/libexec/oah/RosettaNonGrata; do
    if [ -e "$f" ]; then
        echo
        echo "-- $f"
        /usr/bin/file "$f" 2>&1 || true
        /usr/bin/otool -L "$f" 2>&1 || true
        /usr/bin/shasum -a 256 "$f" 2>&1 || true
    fi
done

echo
echo "== translate native dependencies on Lion =="
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
echo "== Shims =="
if [ -d /usr/libexec/oah/Shims ]; then
    /usr/bin/find /usr/libexec/oah/Shims -type f -print 2>/dev/null || true
else
    echo "missing: /usr/libexec/oah/Shims"
fi

echo
echo "== Ancillary OAH state =="
for p in /System/Library/OAH /Library/Preferences/com.apple.ReportMessages.domains; do
    if [ -e "$p" ] || [ -L "$p" ]; then
        /bin/ls -ld "$p" 2>&1 || true
        if [ -d "$p" ]; then /usr/bin/find "$p" -print 2>/dev/null || true; fi
    else
        echo "missing: $p"
    fi
done

echo
echo "== Rosetta metadata =="
/bin/ls -l /private/var/db/RosettaVersion.plist 2>&1 || true
if [ -f /private/var/db/RosettaVersion.plist ]; then
    /usr/bin/plutil -p /private/var/db/RosettaVersion.plist 2>/dev/null || /bin/cat /private/var/db/RosettaVersion.plist
fi

echo
echo "== dyld caches =="
/bin/ls -lh /private/var/db/dyld/dyld_shared_cache_* 2>&1 || true
if [ -f /private/var/db/dyld/dyld_shared_cache_rosetta ]; then
    echo "Rosetta cache magic:"
    /usr/bin/head -c 16 /private/var/db/dyld/dyld_shared_cache_rosetta 2>/dev/null || true
    echo
    /usr/bin/stat -f 'Rosetta cache size=%z mtime_epoch=%m' /private/var/db/dyld/dyld_shared_cache_rosetta 2>/dev/null || true
    /usr/bin/shasum -a 256 /private/var/db/dyld/dyld_shared_cache_rosetta 2>/dev/null || true
fi
if [ -f /private/var/db/dyld/dyld_shared_cache_rosetta.map ]; then
    /usr/bin/shasum -a 256 /private/var/db/dyld/dyld_shared_cache_rosetta.map 2>/dev/null || true
fi

echo
echo "== mach_kernel signatures =="
if [ -r /mach_kernel ]; then
    /usr/bin/strings -a /mach_kernel | /usr/bin/grep '/usr/libexec/oah/' || true
fi

echo
echo "== Suggested next check =="
case "$PRODUCT_VERSION" in
    10.7|10.7.*) echo "Use run-ppc-smoketest.sh with a disposable 32-bit PowerPC Mach-O executable." ;;
    *) echo "This diagnostic was designed for Mac OS X 10.7.x." ;;
esac
