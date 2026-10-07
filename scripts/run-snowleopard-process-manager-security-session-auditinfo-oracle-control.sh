#!/bin/bash
set -u

PPC="${1:-./ppc-process-manager-security-session-auditinfo-private-dyld}"
PPC_SHA_FILE="${2:-$PPC.sha256}"
I386="${3:-./i386-process-manager-security-session-auditinfo-oracle}"
I386_SHA_FILE="${4:-$I386.sha256}"
LOG="${5:-./process-manager-security-session-auditinfo-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$LOG" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

: > "$LOG" || exit 73

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$LOG"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"

[ -z "${SECURITYSERVER+x}" ] || fail "SECURITYSERVER must be unset"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || fail "DYLD_INSERT_LIBRARIES must be unset"

for p in "$PPC" "$PPC_SHA_FILE" "$I386" "$I386_SHA_FILE" "$PRIVATE_DYLD"; do
    [ -e "$p" ] || fail "missing required path: $p"
done

EXPECTED_PPC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$PPC_SHA_FILE")"
EXPECTED_I386_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$I386_SHA_FILE")"
ACTUAL_PPC_SHA="$(sha256 "$PPC")"
ACTUAL_I386_SHA="$(sha256 "$I386")"
DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"

echo "expected_ppc_sha256=$EXPECTED_PPC_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_ppc_sha256=$ACTUAL_PPC_SHA" | /usr/bin/tee -a "$LOG"
echo "expected_i386_sha256=$EXPECTED_I386_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_i386_sha256=$ACTUAL_I386_SHA" | /usr/bin/tee -a "$LOG"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$LOG"

[ "$ACTUAL_PPC_SHA" = "$EXPECTED_PPC_SHA" ] || fail "PPC hash mismatch"
[ "$ACTUAL_I386_SHA" = "$EXPECTED_I386_SHA" ] || fail "i386 hash mismatch"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

echo "== Snow Leopard PPC session-ID/audit control ==" | /usr/bin/tee -a "$LOG"
"$PPC" session-id-audit >> "$LOG" 2>&1
PPC_RC=$?
echo "ppc_status=$PPC_RC" | /usr/bin/tee -a "$LOG"

echo "== Snow Leopard i386 session-ID/audit control ==" | /usr/bin/tee -a "$LOG"
"$I386" session-id-audit >> "$LOG" 2>&1
I386_RC=$?
echo "i386_status=$I386_RC" | /usr/bin/tee -a "$LOG"

if [ "$PPC_RC" -eq 0 ] &&
   [ "$I386_RC" -eq 0 ] &&
   [ "$(/usr/bin/grep -Fc 'PM_SECURITY_AUDITINFO_RESULT:SESSION_ID_AUDIT_MATCH' "$LOG")" -eq 2 ] &&
   [ "$(/usr/bin/grep -Fc 'PM_SECURITY_AUDITINFO_COMPARE:sessionIdMatch=YES ' "$LOG")" -eq 2 ]; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$PPC_RC" -ne 0 ] && exit "$PPC_RC"
[ "$I386_RC" -ne 0 ] && exit "$I386_RC"
exit 1
