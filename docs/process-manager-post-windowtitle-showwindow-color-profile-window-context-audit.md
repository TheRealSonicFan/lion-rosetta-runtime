# Process Manager ShowWindow color-profile/window-context static audit

## Objective

The SetFrontWindow compatibility experiment closed the last currently identified ShowWindow generated-MIG ID mismatch. On Lion, the accepted path now proves:

```text
OrderFrontConditionally  adapter PASS
AddTrackingArea          adapter PASS
0x7268 / 0x72cc         native success
SetFrontWindow           adapter PASS, native result 0
```

Despite that, `S01_AFTER_ShowWindow` is still absent and the PPC process exits 139. The continuing failure cluster is no longer another observed application-CGS request/reply mismatch. Immediately around and after the successful SetFrontWindow transaction, Lion reports:

```text
CGSColorProfileCreateWithColorProfileID: Cannot initialize color profile client
_CGSWindowColorProfile: Invalid color profile id = 0x1
Failed to create window context color transform
CGWindowContextCreate: failed to create context delegate.
CGContext...: invalid context 0x0
CoreUI: Invalid ArtFile Path! ...
```

The same color-profile/window-context cluster already appeared before OrderFrontConditionally in earlier Lion ShowWindow runs. The SetFrontWindow conversion therefore removes one transport rejection but does not explain the context-creation failure.

The next safe step is a static Snow-Leopard-versus-Lion CoreGraphics audit of the color-profile client and window-context creation path. This stage performs no live PPC execution and authorizes no compatibility rule.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-showwindow-color-profile-window-context.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and reads only the system CoreGraphics binary plus Rosetta shared-cache provenance. It selects the Snow Leopard `ppc7400` slice or Lion `i386` slice and emits:

- CoreGraphics and selected-slice SHA-256 provenance;
- linked libraries;
- focused color-profile/window-context cstrings;
- focused undefined/imported symbols;
- exact locations and full disassembly windows for:
  - `_CGSColorProfileCreateWithColorProfileID`
  - `__CGSColorProfileClient`
  - `__CGSWindowColorProfile`
  - `_CGWindowContextCreate`
- supporting `CGSColorProfile`, `CGXColorProfile`, `XColorProfile`, `CGWindowContext`, `CGColorTransform`, WindowServer-port, bootstrap, Mach, MIG, and ColorSync symbols;
- call/branch lines and transport/bootstrap/color-profile references inside the emitted target windows;
- small protocol-range immediates found inside those windows.

The goal is to determine whether Snow and Lion differ in color-profile client initialization, service/port acquisition, generated-MIG contract, or local window-context setup before considering any live adaptation.

## Known static anchors from the earlier broad audit

Both releases expose the same core family, but the implementations are at different release-specific addresses.

Snow Leopard PPC included at least:

```text
_CGSColorProfileCreateWithColorProfileID  0x136ba8
__CGSWindowColorProfile                   0x18e6ac
_CGWindowContextCreate                    0x196ab4
__CGSColorProfileClient                   0x1ef9b8
```

Lion i386 included at least:

```text
_CGWindowContextCreate                    0x7b37a
__CGSWindowColorProfile                   0x7ddb4
_CGSColorProfileCreateWithColorProfileID  0x7ded5
__CGSColorProfileClient                   0x7e333
```

Those symbol anchors alone are not enough to authorize a live fix; this audit captures the exact function bodies and dependencies.

## Safety constraints

- Do not launch the PPC ShowWindow subject during this audit.
- Do not run the Lion compatibility interposer during this audit.
- Do not modify the SetFrontWindow, OrderFrontConditionally, AddTrackingArea, NewWindow, release-backing, create-alpha, FontServer, notification, Security, or HIToolbox compatibility rules.
- Do not adapt the earlier `CGSShapeWindow` rejection.
- Do not patch ColorSync, CoreGraphics, CoreUI, RawCamera, window-context creation, WindowServer, Rosetta, dyld, caches, launchd, or XNU.
- Do not infer a compatibility rule solely from matching symbol names.
- Preserve the current crash/core diagnostics locally; they are not required for this static gate unless the two reports leave the client-initialization path unresolved.

No kernel rebuild or reboot is part of this stage.

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
ls -l ./scripts/audit-process-manager-showwindow-color-profile-window-context.py
ls -l ./docs/process-manager-post-windowtitle-showwindow-color-profile-window-context-audit.md
```

## Phase B — Snow Leopard static audit

On Snow Leopard 10.6.8:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-process-manager-showwindow-color-profile-window-context.py \
  ./process-manager-showwindow-color-profile-window-context-snowleopard.txt
```

Require the command to finish with:

```text
Created: ./process-manager-showwindow-color-profile-window-context-snowleopard.txt
RESULT: PASS
```

Do not launch the PPC subject after generating the report.

## Phase C — Lion static audit

On Lion 10.7.5:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-process-manager-showwindow-color-profile-window-context.py \
  ./process-manager-showwindow-color-profile-window-context-lion.txt
```

Require the command to finish with:

```text
Created: ./process-manager-showwindow-color-profile-window-context-lion.txt
RESULT: PASS
```

Do not perform another ShowWindow integration run in this stage.

## Review gate

Return exactly these two reports:

```text
process-manager-showwindow-color-profile-window-context-snowleopard.txt
process-manager-showwindow-color-profile-window-context-lion.txt
```

The next compatibility decision will be based on the static differential.

Possible outcomes:

- If the reports expose an exact generated-MIG/service-port contract change with equivalent semantics, prepare a separate narrow local policy proof before any live integration.
- If Lion requires a different color-profile client initialization sequence, audit that initialization path first; do not synthesize a profile or force success.
- If the window-context failure is local and downstream of an already-failed profile lookup, fix or adapt only the proven upstream cause.
- If the two reports do not resolve the path, then inspect the preserved Lion crash report/core as the next discriminator rather than guessing.

## Current boundary

```text
OrderFrontConditionally                          accepted adapter PASS
AddTrackingArea                                  accepted adapter PASS
0x7268 / 0x72cc                                  native success unchanged
SetFrontWindow                                   accepted adapter PASS
post-SetFront application-CGS mismatch            none observed
S01_AFTER_ShowWindow                              absent
exact-six broker                                  PASS
protected hashes                                  unchanged
persistent first-order failure                    color-profile/window-context initialization
CGSShapeWindow                                    held
CoreUI/RawCamera rendering errors                 downstream/held
next step                                         static color-profile/window-context differential
XNU                                               no change indicated
```
