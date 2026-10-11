# Process Manager CreateNewWindow post-NewWindow CGS protocol audit

## Scope

The live NewWindow compatibility integration has moved the boundary past the generated `CGSNewWindowWithOpaqueShape` request itself.

The accepted Lion run proves all of the following before the subject stops returning from `CreateNewWindow`:

- the Dock bootstrap adapter returns a valid `com.apple.dock.server` send right;
- the exact legacy inline NewWindow request is recognized once;
- the private request copy changes only `0x7394 -> 0x739a`;
- Lion returns native `0x73fe`, size `0x38`, result 0 with swapped NDR;
- the reply copy changes only `0x73fe -> 0x73f8`;
- the legacy-facing trace sees `0x73f8`, size `0x38`, with Mach transport success.

Immediately after that successful NewWindow reply, Lion reports these CoreGraphics failures before `M21_AFTER_CreateNewWindow`:

```text
MIG: server type check failure: CGSSetWindowToReleaseBackingOnOrderOut
(ipc/rcv) msg too large: CGSSetWindowOpacity
kCGErrorIllegalArgument: CGSGetDisplayBounds (display 0)
MIG: server type check failure: CGSShapeWindow
```

The process then terminates with status 138 and produces a crash report and core. Protected hashes remain unchanged. The earlier runner label `CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_PASS_NO_RETURN` was too coarse because it was selected before the NewWindow-compatibility decision block; current main corrects that classification.

This stage is **static and read-only**. It does not rerun the translated PPC subject and does not add another compatibility rule.

## Question

Determine whether Snow Leopard PPC and Lion i386 CoreGraphics use different generated-MIG/client contracts for the first post-NewWindow helpers now named by the live diagnostics:

- `CGSSetWindowToReleaseBackingOnOrderOut`
- `CGSSetWindowOpacity`
- `CGSGetDisplayBounds`
- `CGSShapeWindow`

For each family, compare the PPC/i386 symbol windows, direct calls, immediate-bearing instructions, Mach-message construction, request/reply IDs, fixed sizes, descriptor use, NDR handling, and any obvious argument-layout differences.

Do not infer a compatibility policy from the diagnostic names alone. The static Snow/Lion differential is the gate before any broader live Mach trace or ID conversion.

## Prepared analyzer

```text
scripts/audit-process-manager-cgs-post-newwindow-protocol.py
```

Analyzer version: `1`.

It inspects the system CoreGraphics binary without launching a PowerPC application. On Snow Leopard 10.6.8 it requires the `ppc7400` slice; on Lion 10.7.5 it requires the `i386` slice. It also records Rosetta-cache provenance where available.

## Safety constraints

- do not rerun `CreateNewWindow` during this audit;
- do not rebuild the combined CoreServices compatibility dylib;
- do not rebuild the native distributed-notifications broker;
- do not modify the Dock bootstrap, HIToolbox Extras, notification, NewWindow, CoreGraphics, WindowServer, Rosetta, dyld, launchd, or XNU paths;
- do not restart or signal WindowServer or launchd jobs;
- preserve the existing 2026-10-11 14:54:26 Lion crash report and `/cores/core.33036`; they are not required for this static gate but may be needed if the four client contracts prove wire-compatible;
- no XNU rebuild or reboot.

## Phase A — update repositories

Pull current `main` for both repositories before doing anything else. Confirm that runtime contains this document and analyzer.

## Phase B — Snow Leopard 10.6.8 static audit

Run:

```sh
/usr/bin/python ./scripts/audit-process-manager-cgs-post-newwindow-protocol.py \
  ./process-manager-cgs-post-newwindow-protocol-snowleopard.txt
```

Hard gate:

```text
product_version=10.6.8
CGSSetWindowToReleaseBackingOnOrderOut count >= 1 in ppc7400
CGSSetWindowOpacity count >= 1 in ppc7400
CGSGetDisplayBounds count >= 1 in ppc7400
CGSShapeWindow count >= 1 in ppc7400
RESULT: PASS
```

Stop if the analyzer reports `FAIL`. Do not substitute a live trace for a missing static symbol family.

## Phase C — Lion 10.7.5 static audit

Run:

```sh
/usr/bin/python ./scripts/audit-process-manager-cgs-post-newwindow-protocol.py \
  ./process-manager-cgs-post-newwindow-protocol-lion.txt
```

Hard gate:

```text
product_version=10.7.5
CGSSetWindowToReleaseBackingOnOrderOut count >= 1 in i386
CGSSetWindowOpacity count >= 1 in i386
CGSGetDisplayBounds count >= 1 in i386
CGSShapeWindow count >= 1 in i386
RESULT: PASS
```

Do not launch the translated PPC subject after the audit.

## Phase D — return for review

Return exactly:

```text
process-manager-cgs-post-newwindow-protocol-snowleopard.txt
process-manager-cgs-post-newwindow-protocol-lion.txt
```

Keep the current Lion crash report and core locally. They are not requested in this phase.

## Decision gate

If one or more of the four helpers show a narrow generated-MIG/request-layout differential, the next stage should be a passive, exact transport trace limited to the first post-NewWindow traffic needed to validate that differential. Do not implement compatibility from static evidence alone.

If the Snow PPC and Lion i386 contracts are wire-compatible, stop. The next review will use the preserved crash/core plus the live argument/state evidence rather than introducing an ID translation.

If the analyzer cannot recover a required family, treat that as an analyzer/modeling problem and stop.

## Current boundary statement

The NewWindow ID-only adapter is now proven to reach a native Lion NewWindow success reply. The unresolved boundary is inside the remaining work performed by `CreateNewWindow` after that reply, where the first observable failures are the four CoreGraphics helpers above. This remains a runtime/user-space compatibility investigation; the current evidence does not indicate another XNU defect.
