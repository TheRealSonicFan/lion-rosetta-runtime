#!/bin/bash
# Read-only inventory helper for the Snow Leopard source machine.
PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
echo "== System =="
/usr/bin/sw_vers 2>/dev/null || true

echo
echo "== Rosetta package receipts =="
if [ -x /usr/sbin/pkgutil ]; then
    for pkg in com.apple.pkg.Rosetta com.apple.pkg.update.rosetta.10.6.8.combo; do
        echo "-- $pkg"
        /usr/sbin/pkgutil --pkg-info "$pkg" 2>&1 || true
        /usr/sbin/pkgutil --files "$pkg" 2>&1 || true
    done
else
    echo "pkgutil unavailable"
fi

echo
echo "== Known Rosetta locations =="
for p in \
    /usr/libexec/oah \
    /private/var/db/RosettaVersion.plist \
    /private/var/db/dyld/dyld_shared_cache_rosetta \
    /private/var/db/dyld/dyld_shared_cache_rosetta.map \
    /Library/Preferences/com.apple.ReportMessages.domains \
    /System/Library/OAH; do
    if [ -e "$p" ] || [ -L "$p" ]; then
        /bin/ls -ld "$p"
        if [ -d "$p" ]; then /usr/bin/find "$p" -print 2>/dev/null || true; fi
    else
        echo "missing: $p"
    fi
done

echo
echo "== Critical file identity =="
for f in \
    /usr/libexec/oah/translate \
    /private/var/db/dyld/dyld_shared_cache_rosetta \
    /private/var/db/dyld/dyld_shared_cache_rosetta.map \
    /Library/Preferences/com.apple.ReportMessages.domains; do
    if [ -f "$f" ]; then
        /usr/bin/stat -f '%N size=%z mtime_epoch=%m' "$f" 2>/dev/null || /bin/ls -ln "$f"
        /usr/bin/shasum -a 256 "$f" 2>/dev/null || true
    else
        echo "missing: $f"
    fi
done

echo
echo "== translate dependencies =="
/usr/bin/file /usr/libexec/oah/translate 2>&1 || true
/usr/bin/otool -L /usr/libexec/oah/translate 2>&1 || true
/usr/bin/strings -a /usr/libexec/oah/translate 2>/dev/null | /usr/bin/grep -E '/System/Library/OAH|/usr/libexec/oah|Rosetta|rosetta' || true

echo
echo "Source version: $PRODUCT_VERSION"
