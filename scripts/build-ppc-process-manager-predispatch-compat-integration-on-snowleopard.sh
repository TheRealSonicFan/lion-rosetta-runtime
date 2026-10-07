#!/bin/bash
set -e

PREDISPATCH_OUT="${1:-./ppc-process-manager-predispatch-compat-private-dyld}"
INTERPOSER_OUT="${2:-./ppc-process-manager-coreservices-compat-interposer.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREDISPATCH_BUILDER="$SCRIPT_DIR/build-ppc-process-manager-predispatch-preflight-on-snowleopard.sh"
INTERPOSER_BUILDER="$SCRIPT_DIR/build-ppc-process-manager-coreservices-compat-interposer-on-snowleopard.sh"

[ -f "$PREDISPATCH_BUILDER" ] || { echo "error: missing pre-dispatch builder: $PREDISPATCH_BUILDER" >&2; exit 66; }
[ -f "$INTERPOSER_BUILDER" ] || { echo "error: missing interposer builder: $INTERPOSER_BUILDER" >&2; exit 66; }

echo "Building PPC pre-dispatch subject..."
CC="${CC:-}" /bin/bash "$PREDISPATCH_BUILDER" "$PREDISPATCH_OUT"

echo "Building PPC CoreServices compatibility interposer..."
CC="${CC:-}" /bin/bash "$INTERPOSER_BUILDER" "$INTERPOSER_OUT"

echo "Prepared pre-dispatch compatibility artifacts:"
echo "  $PREDISPATCH_OUT"
echo "  $PREDISPATCH_OUT.info.txt"
echo "  $PREDISPATCH_OUT.sha256"
echo "  $INTERPOSER_OUT"
echo "  $INTERPOSER_OUT.info.txt"
echo "  $INTERPOSER_OUT.sha256"
