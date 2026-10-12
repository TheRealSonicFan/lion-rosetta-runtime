# Process Manager ShowWindow ColorProfile resolve protocol audit

## Objective

The completed ColorProfileClient compatibility integration closes the client-registration boundary but does not make `ShowWindow` return.

The accepted v2 Snow control is behavior-preserving. The one legacy ColorProfileClient transaction remains a native Snow success and the full Snow ShowWindow control reaches its PASS markers.

On Lion, the first exact legacy ColorProfileClient request is now converted only by generated-MIG routine ID:

```text
legacy request             0x74d4
native request             0x74d6
native reply               0x753a / 0x28
native result              0
native client ID           nonzero
legacy-facing reply        0x7538 / 0x28
request body changes       0
reply body changes         0
adapter result             PASS
later ColorProfileClient retries  none
```

The diagnostic immediately after that successful PPC-facing reply has advanced. It is no longer `Cannot initialize color profile client`. The first color-profile failure is now:

```text
CGSColorProfileCreateWithColorProfileID: Cannot resolve color profile id(1)
_CGSWindowColorProfile: Invalid color profile id = 0x1
Failed to create window context color transform
CGWindowContextCreate: failed to create context delegate.
```

The accepted OrderFrontConditionally, AddTrackingArea, unchanged `0x7268 / 0x72cc`, SetFrontWindow, exact-six distributed-notifications, Security, FontServer, HIToolbox, NewWindow, release-backing, and create-alpha paths remain intact. Protected hashes remain unchanged. `S01_AFTER_ShowWindow` is still absent and the process still exits 139.

Existing static CoreGraphics evidence already shows that both Snow Leopard and Lion call `__CGSResolveColorProfile` immediately after a successful ColorProfileClient initialization inside `CGSColorProfileCreateWithColorProfileID`. The next safe gate is therefore a focused read-only protocol audit of the resolve path before any new live rewrite is considered.

This stage performs no PPC launch and authorizes no compatibility conversion.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-showwindow-color-profile-resolve-protocol.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and reads only the system CoreGraphics binary plus Rosetta shared-cache provenance. It selects the Snow Leopard `ppc7400` slice or Lion `i386` slice and emits provenance, focused strings/imports, symbol inventory, full disassembly windows, call/branch references, transport references, and generated-MIG-range immediates for the focused client/server family:

```text
_CGSColorProfileCreateWithColorProfileID
__CGSColorProfileClient
__CGSResolveColorProfile
__XResolveColorProfile
__CGXResolveColorProfile
__CGSReleaseColorProfile
__XReleaseColorProfile
__CGXReleaseColorProfile
```

The audit must determine, without guessing, whether Snow and Lion differ in the generated-MIG ResolveColorProfile request/reply IDs, message bits, send/receive sizes, request argument layout, reply/data layout, or server-side resolve semantics. ReleaseColorProfile is included only as an adjacent control for routine numbering and payload conventions.

Do not infer a ResolveColorProfile ID shift from routine ordering alone.

## Safety constraints

- Do not launch the PPC ShowWindow subject during this audit.
- Do not run the ColorProfileClient compatibility interposer during this audit.
- Do not add a ResolveColorProfile adapter during this audit.
- Do not synthesize, substitute, or force color profile ID 1.
- Do not force `CGSColorProfileCreateWithColorProfileID`, `_CGSWindowColorProfile`, `CGWindowContextCreate`, ColorSync, CoreUI, or RawCamera to succeed.
- Do not alter the accepted ColorProfileClient, SetFrontWindow, OrderFrontConditionally, AddTrackingArea, NewWindow, release-backing, create-alpha, FontServer, notification, Security, or HIToolbox compatibility rules.
- Do not adapt the earlier held `CGSShapeWindow` rejection.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, or XNU.
- Preserve the current Lion crash/plist/core diagnostics locally; they are not inputs to this static gate.

No syscall-295 rerun, kernel rebuild, or reboot is required for this read-only stage.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD
```

Confirm the current checkout contains the analyzer and this document:

```sh
ls -l ./scripts/audit-process-manager-showwindow-color-profile-resolve-protocol.py
ls -l ./docs/process-manager-post-windowtitle-showwindow-color-profile-resolve-protocol-audit.md
```

## Phase B — Snow Leopard static audit

On Snow Leopard 10.6.8:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-process-manager-showwindow-color-profile-resolve-protocol.py \
  ./process-manager-showwindow-color-profile-resolve-protocol-snowleopard.txt
```

Require:

```text
Created: ./process-manager-showwindow-color-profile-resolve-protocol-snowleopard.txt
RESULT: PASS
```

Do not launch the PPC subject after generating the report.

## Phase C — Lion static audit

On Lion 10.7.5:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-process-manager-showwindow-color-profile-resolve-protocol.py \
  ./process-manager-showwindow-color-profile-resolve-protocol-lion.txt
```

Require:

```text
Created: ./process-manager-showwindow-color-profile-resolve-protocol-lion.txt
RESULT: PASS
```

Do not perform another translated-PPC ShowWindow run in this stage.

## Review gate

Return exactly these two reports:

```text
process-manager-showwindow-color-profile-resolve-protocol-snowleopard.txt
process-manager-showwindow-color-profile-resolve-protocol-lion.txt
```

Review the reports before authorizing any new live experiment.

- If they prove an exact generated-MIG ResolveColorProfile differential with otherwise equivalent request/reply and server semantics, the next stage is a target-only passive live ResolveColorProfile trace on Snow and exactly one Lion run. Do not jump directly to an adapter.
- If the generated-MIG IDs match but payload/reply semantics differ, isolate that semantic difference first.
- If the client helper is equivalent but `__CGXResolveColorProfile` server semantics differ, audit the server-side profile-ID/client-ID relationship before modifying anything.
- If the static evidence is ambiguous, use the preserved Lion crash/core only as the next discriminator rather than synthesizing profile data or broadening the compatibility layer.

## Current boundary

```text
ColorProfileClient Snow control             PASS
ColorProfileClient Lion adapter             PASS; one exact call, no retry
ColorProfileClient native result            0, nonzero client ID
first new color-profile failure             Cannot resolve color profile id(1)
OrderFront/AddTracking/SetFront             accepted adapter PASS
exact-six notification broker               PASS
protected hashes                            unchanged
S01_AFTER_ShowWindow                        absent
Lion process                                exit 139
CGWindowContext/CoreUI/RawCamera            downstream/held
CGSShapeWindow                              held
next step                                   static ResolveColorProfile protocol differential
XNU                                         no change indicated
```
