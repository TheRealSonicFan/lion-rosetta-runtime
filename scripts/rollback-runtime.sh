#!/bin/bash
set -e

[ "$(id -u)" -eq 0 ] || { echo "error: run as root" >&2; exit 77; }
BACKUP="${1:-/var/backups/lion-rosetta-runtime/latest}"
[ -e "$BACKUP" ] || { echo "error: backup not found: $BACKUP" >&2; exit 66; }
BACKUP="$(cd "$BACKUP" && pwd -P)"

if [ -d "$BACKUP/usr/libexec/oah" ]; then
    /bin/rm -rf /usr/libexec/oah
    /usr/bin/ditto --rsrc --extattr "$BACKUP/usr/libexec/oah" /usr/libexec/oah
else
    /bin/rm -rf /usr/libexec/oah
fi

if [ -f "$BACKUP/private/var/db/RosettaVersion.plist" ]; then
    /usr/bin/ditto --rsrc --extattr "$BACKUP/private/var/db/RosettaVersion.plist" /private/var/db/RosettaVersion.plist
else
    /bin/rm -f /private/var/db/RosettaVersion.plist
fi

for f in /private/var/db/dyld/dyld_shared_cache_rosetta /private/var/db/dyld/dyld_shared_cache_rosetta.map; do
    if [ -f "$BACKUP$f" ]; then
        /usr/bin/ditto --rsrc --extattr "$BACKUP$f" "$f"
    else
        /bin/rm -f "$f"
    fi
done

for p in /System/Library/OAH /Library/Preferences/com.apple.ReportMessages.domains; do
    if [ -e "$BACKUP$p" ] || [ -L "$BACKUP$p" ]; then
        /bin/rm -rf "$p"
        /bin/mkdir -p "$(dirname "$p")"
        /usr/bin/ditto --rsrc --extattr "$BACKUP$p" "$p"
    else
        /bin/rm -rf "$p"
    fi
done

echo "Runtime rollback completed from: $BACKUP"
