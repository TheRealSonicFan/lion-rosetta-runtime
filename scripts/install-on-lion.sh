#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

[ "$#" -eq 1 ] || { echo "usage: sudo $0 rosetta-10.6.8-runtime.tar.gz" >&2; exit 64; }
[ "$(id -u)" -eq 0 ] || { echo "error: run as root" >&2; exit 77; }

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
case "$PRODUCT_VERSION" in
    10.7|10.7.*) ;;
    *) echo "error: installer requires Mac OS X 10.7.x (found: $PRODUCT_VERSION)" >&2; exit 65 ;;
esac

PAYLOAD="$1"
[ -f "$PAYLOAD" ] || { echo "error: payload not found: $PAYLOAD" >&2; exit 66; }

if [ -x "$SCRIPT_DIR/inspect-payload.sh" ]; then
    echo "Validating payload manifest and hashes..."
    "$SCRIPT_DIR/inspect-payload.sh" "$PAYLOAD" >/dev/null
else
    echo "error: inspect-payload.sh is required next to this installer" >&2
    exit 67
fi

TMP="$(/usr/bin/mktemp -d /tmp/lion-rosetta-install.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
/usr/bin/tar -xzf "$PAYLOAD" -C "$TMP"

[ -f "$TMP/usr/libexec/oah/translate" ] || { echo "error: payload has no /usr/libexec/oah/translate" >&2; exit 67; }
[ -f "$TMP/private/var/db/dyld/dyld_shared_cache_rosetta" ] || {
    echo "error: payload has no Snow Leopard dyld_shared_cache_rosetta; Lion lacks many PPC system slices" >&2
    exit 67
}

# Verify the cache type before installing it. Snow Leopard's Rosetta cache begins
# with the ASCII magic 'dyld_v1     ppc'. Do not accept a native x86 cache here.
CACHE_MAGIC="$(/usr/bin/head -c 16 "$TMP/private/var/db/dyld/dyld_shared_cache_rosetta" 2>/dev/null || true)"
case "$CACHE_MAGIC" in
    "dyld_v1     ppc"*) ;;
    *) echo "error: Rosetta cache does not identify itself as a PPC dyld cache" >&2; exit 67 ;;
esac

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/var/backups/lion-rosetta-runtime/$STAMP"
/bin/mkdir -p "$BACKUP/usr/libexec" "$BACKUP/private/var/db/dyld" "$BACKUP/System/Library" "$BACKUP/Library/Preferences"

if [ -e /usr/libexec/oah ]; then
    /usr/bin/ditto --rsrc --extattr /usr/libexec/oah "$BACKUP/usr/libexec/oah"
fi
if [ -f /private/var/db/RosettaVersion.plist ]; then
    /usr/bin/ditto --rsrc --extattr /private/var/db/RosettaVersion.plist "$BACKUP/private/var/db/RosettaVersion.plist"
fi
for f in /private/var/db/dyld/dyld_shared_cache_rosetta /private/var/db/dyld/dyld_shared_cache_rosetta.map; do
    if [ -f "$f" ]; then
        /usr/bin/ditto --rsrc --extattr "$f" "$BACKUP$f"
    fi
done
for p in /System/Library/OAH /Library/Preferences/com.apple.ReportMessages.domains; do
    if [ -e "$p" ] || [ -L "$p" ]; then
        /bin/mkdir -p "$BACKUP$(dirname "$p")"
        /usr/bin/ditto --rsrc --extattr "$p" "$BACKUP$p"
    fi
done

/bin/mkdir -p /usr/libexec
/usr/bin/ditto --rsrc --extattr "$TMP/usr/libexec/oah" /usr/libexec/oah
/usr/sbin/chown -R root:wheel /usr/libexec/oah

if [ -f "$TMP/private/var/db/RosettaVersion.plist" ]; then
    /usr/bin/ditto --rsrc --extattr "$TMP/private/var/db/RosettaVersion.plist" /private/var/db/RosettaVersion.plist
    /usr/sbin/chown root:wheel /private/var/db/RosettaVersion.plist
fi

# Optional ancillary state captured by the refreshed collector.
if [ -e "$TMP/System/Library/OAH" ]; then
    /bin/mkdir -p /System/Library
    /usr/bin/ditto --rsrc --extattr "$TMP/System/Library/OAH" /System/Library/OAH
    /usr/sbin/chown -R root:wheel /System/Library/OAH
fi
if [ -f "$TMP/Library/Preferences/com.apple.ReportMessages.domains" ]; then
    /bin/mkdir -p /Library/Preferences
    /usr/bin/ditto --rsrc --extattr "$TMP/Library/Preferences/com.apple.ReportMessages.domains" /Library/Preferences/com.apple.ReportMessages.domains
    /usr/sbin/chown root:wheel /Library/Preferences/com.apple.ReportMessages.domains
fi

# Install only the Rosetta-specific PPC cache from Snow Leopard. This does not
# replace Lion's dyld_shared_cache_i386 or dyld_shared_cache_x86_64 files.
/bin/mkdir -p /private/var/db/dyld
/usr/bin/ditto --rsrc --extattr "$TMP/private/var/db/dyld/dyld_shared_cache_rosetta" /private/var/db/dyld/dyld_shared_cache_rosetta
/usr/sbin/chown root:wheel /private/var/db/dyld/dyld_shared_cache_rosetta
/bin/chmod 0644 /private/var/db/dyld/dyld_shared_cache_rosetta
if [ -f "$TMP/private/var/db/dyld/dyld_shared_cache_rosetta.map" ]; then
    /usr/bin/ditto --rsrc --extattr "$TMP/private/var/db/dyld/dyld_shared_cache_rosetta.map" /private/var/db/dyld/dyld_shared_cache_rosetta.map
    /usr/sbin/chown root:wheel /private/var/db/dyld/dyld_shared_cache_rosetta.map
    /bin/chmod 0644 /private/var/db/dyld/dyld_shared_cache_rosetta.map
fi

# Do not invoke Lion's update_dyld_shared_cache after this copy. Lion no longer
# builds a PPC/Rosetta cache and may alter cache state we are deliberately testing.
/bin/ln -sfn "$BACKUP" /var/backups/lion-rosetta-runtime/latest

echo "Installed local Snow Leopard Rosetta runtime on Lion."
echo "Backup: $BACKUP"
echo "Installed isolated PPC cache: /private/var/db/dyld/dyld_shared_cache_rosetta"
echo "Lion i386/x86_64 dyld caches were not replaced."
echo "Install/boot the patched kernel from lion-rosetta-xnu, then run diagnose-on-lion.sh."
