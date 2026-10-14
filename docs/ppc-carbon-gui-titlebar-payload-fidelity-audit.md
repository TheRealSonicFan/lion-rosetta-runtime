# PPC Carbon GUI titlebar payload fidelity audit

## Status

NEXT CONTROLLED STEP after the completed backing-store synchronization compatibility integration.

## Reviewed result that advances this step

The returned backing-sync evidence is positive under current `main` semantics.

Snow Leopard 10.6.8/10K549:

```text
backing_sync_exact_count=0
backing_sync_passthrough_count=0
backing_sync_adapter_pass_count=0
backing_sync_predicate_reject_count=0
RESULT: PPC_CARBON_GUI_BACKING_SYNC_SNOW_CONTROL_PASS
RESULT: PASS
```

Zero Snow backing-sync calls is the expected healthy positive control for this exact historical subject. The returned Snow window is manually visible and its titlebar is visually normal.

Lion 10.7.5/11G63:

```text
PM_CGS_BACKING_SYNC_COMPAT_CALL ... exact=YES id=0x00007265 send=0x0000002c recv=0x0000002c ... arg1=3 arg2=1
PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST ... legacyId=0x00007265 lionId=0x00007266 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0
PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY ... id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS
PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY ... nativeId=0x000072ca legacyId=0x000072c9 changedBytes=1 bodyChangedBytes=0 result=0
PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS
backing_sync_lock_failure_count=0
titlebar_translated_count=6
titlebar_guard_reject_count=0
RESULT: PPC_CARBON_GUI_BACKING_SYNC_INTEGRATION_PASS
RESULT: PASS
```

The WindowServer observer again reaches the exact titled `400x222` window at `(120,98)`, and the user manually sees it. The titlebar is still not Snow-equivalent: the bar remains transparent/background-colored and the red/yellow/green controls are now distinct but visually distorted.

This closes the generated-MIG synchronization boundary. Do not broaden the backing-sync predicate and do not add another CGS adapter from this visual defect alone.

## Objective

Determine whether the remaining titlebar defect is explained by a release-specific legacy-`ArtFile.bin` payload/consumer contract mismatch at the six semantic titlebar keys already live-translated, before any new live titlebar policy or resource substitution is attempted.

The exact six live translations remain:

```text
disabled-clear  a613161f7a000000 -> 9914172272000000
disabled-minus  a6161f567a000000 -> 9917225572000000
disabled-zoom   a6161f7ab6000000 -> 99172272a9000000
active-clear    a60113167a000000 -> 9901141772000000
active-minus    a60116567a000000 -> 9901175572000000
active-zoom     a601167ab6000000 -> 99011772a9000000
```

Prior work proves that every Lion target is a unique valid semantic-equivalent legacy-ArtFile index entry. It did not prove that Snow PPC `CUIElement::LoadFromArtFile` interprets Lion's referenced payload metadata identically enough for visual fidelity.

This stage is static and read-only.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-titlebar-payload-fidelity.py
```

Pinned identity:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-payload-fidelity-v1
git_blob=643982a9e75b64156d74a3d3cb0aafc6eb77c70d
```

The analyzer is Python-2-compatible and:

- verifies Snow 10.6.8/10K549 or Lion 10.7.5/11G63;
- verifies the accepted release-local `ArtFile.bin` identity and legacy index geometry;
- verifies the accepted Snow PPC or Lion i386 CoreUI slice identity;
- resolves the same six semantic titlebar paths through the release-local component dictionary;
- requires exactly one local index record for each path;
- records each payload offset, span-to-next-payload, span SHA-256, first `0x68` bytes, and first `0x100` bytes;
- emits the complete local `CUIElement::LoadFromArtFile` body and release-local `CUIElement::Load` body for consumer-contract comparison.

The payload bytes are diagnostic evidence only. This audit does not authorize copying Snow payloads to Lion or synthesizing ArtFile records.

## Safety constraints

- Do not launch the PPC Carbon subject.
- Do not rerun the backing-sync integration.
- Do not rebuild the backing-sync compatibility dylib.
- Do not broaden the exact-six bsearch translation.
- Do not add a seventh titlebar key.
- Do not copy Snow CoreUI, `ArtFile.bin`, `SArtFile.bin`, or UI recipe resources to Lion.
- Do not patch Lion CoreUI or any ArtFile.
- Do not change ShapeWindow, WindowBackingInfo, synchronization, notification, CPS, or later CGS compatibility.
- Do not test LaunchServices, Finder, Cocoa, or another PPC application.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-titlebar-payload-fidelity.py)" =   "643982a9e75b64156d74a3d3cb0aafc6eb77c70d" || exit 1

/usr/bin/grep -q "^ANALYZER_VERSION='1'"   ./scripts/audit-ppc-carbon-gui-titlebar-payload-fidelity.py || exit 1
/usr/bin/grep -q "^AUDIT_CONTRACT='carbon-gui-titlebar-payload-fidelity-v1'"   ./scripts/audit-ppc-carbon-gui-titlebar-payload-fidelity.py || exit 1
```

## Phase B — syntax-check

On each system:

```sh
/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-titlebar-payload-fidelity.py","rb").read(),"audit-ppc-carbon-gui-titlebar-payload-fidelity.py","exec")' || exit 1
```

## Phase C — Snow static control

On Snow Leopard:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-payload-fidelity.py   ./ppc-carbon-gui-titlebar-payload-fidelity-snow.txt || exit 1
```

Require:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-payload-fidelity-v1
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
artfile_sha256=1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5
coreui_slice_sha256=5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839
six_payload_records_exact=YES
RESULT: PASS
```

Every one of the six paths must have `local_index_hits=1`.

## Phase D — Lion static differential

Only after Snow passes, run on Lion:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-payload-fidelity.py   ./ppc-carbon-gui-titlebar-payload-fidelity-lion.txt || exit 1
```

Require:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-payload-fidelity-v1
product_version=10.7.5
build_version=11G63
required_arch=i386
artfile_sha256=0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4
coreui_slice_sha256=5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b
six_payload_records_exact=YES
RESULT: PASS
```

Again every path must have `local_index_hits=1`.

Do not launch translated PPC afterward.

## Phase E — return evidence

Return exactly:

```text
ppc-carbon-gui-titlebar-payload-fidelity-snow.txt
ppc-carbon-gui-titlebar-payload-fidelity-lion.txt
```

No binaries are required.

## Review gate

Compare the six payload records and the two release-local consumer bodies before choosing any live change.

- If the payload layout consumed by Snow PPC is demonstrably incompatible with Lion's corresponding payload metadata, the next step must isolate the smallest process-local payload/consumer compatibility boundary; do not copy an entire Snow ArtFile.
- If the payload contract is structurally compatible, do not modify payloads. The next discriminator should trace or statically inventory additional titlebar lookups for silent semantic collisions outside the already-proven six keys.
- If either report fails provenance, index, or symbol validation, fix the analyzer/audit before any live run.
- A visual defect by itself does not authorize a broader titlebar translation table.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
backing-sync native result                       0
backing-sync lock failure                        absent
Lion exact titled frame                          400x222 at (120,98), onscreen
Lion Carbon window                               manually visible
titlebar exact-six translations                  6
titlebar guard rejects                           0
Lion titlebar                                    transparent; controls distinct but distorted
next step                                        static six-payload/consumer fidelity differential
new titlebar keys                                NOT AUTHORIZED
ArtFile payload substitution                     NOT AUTHORIZED
later CGS / LaunchServices / Finder / Cocoa      HELD
XNU                                              no source change indicated
```
