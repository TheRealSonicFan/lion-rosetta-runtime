# PPC Carbon GUI backing-store synchronization compatibility integration

## Status

**NEXT CONTROLLED LIVE STEP.** The CGSShapeWindow inline ID-only integration is complete and restores the historical Carbon window's geometry and visual presentation on Lion. The exact subject now reaches an onscreen 400x222 window at (120,98), and the user manually observed the window. The remaining visible defect is titlebar fidelity: the titlebar appears transparent/background-colored and the three traffic-light controls appear uniformly yellow rather than normal Aqua red/yellow/green.

The completed run also exposes a previously known but now visually relevant generated-MIG collision in the backing-store synchronization path. The Lion trace repeatedly sends the Snow PPC transaction:

```text
bits             0x1513
request / reply  0x7265 / 0x72c9
send / receive   0x2c / 0x2c
window           current Carbon window
arg1             3
arg2             1
result           -304 / MIG_BAD_ARGUMENTS
```

Each failed reply is immediately followed by:

```text
kCGErrorFailure: _CGSLockWindow: Cannot synchronize window backing store
```

The prior read-only backing-lock protocol audit already supplies the exact static attribution:

```text
Snow PPC  __CGSSynchronizeWindowBackingStore   0x7265 / 0x72c9
Lion i386 __CGSSynchronizeWindowBackingStore   0x7266 / 0x72ca
Lion i386 __CGSSetWindowAutofillColor          0x7265 / 0x72c9
```

Snow and Lion synchronization clients otherwise use the same live-relevant simple contract: bits 0x1513, option 0x3, send/receive 0x2c/0x2c, three 32-bit body scalars, and a 0x24 simple reply carrying a result. Lion's AutofillColor client that reuses the old Snow synchronization ID instead expects a different request layout and a 0x30 send size. The live PPC 0x2c synchronization request therefore reaches the wrong Lion routine and is rejected by its server type check.

This phase tests only that exact synchronization ID collision. It does **not** alter titlebar CoreUI path translation, ArtFile payloads, window geometry, backing descriptors, display state, or later CGS traffic.

## Exact compatibility rule

For the exact historical Carbon window only:

```text
legacy synchronization request   0x7265
Lion synchronization request     0x7266
Lion synchronization reply       0x72ca
legacy synchronization reply     0x72c9

request body                     unchanged
reply body/result                unchanged
ports/NDR/options/sizes          unchanged
```

The live predicate is intentionally narrow:

```text
bits               0x1513
request ID         0x7265
option             0x3
send / receive     0x2c / 0x2c
remote port        accepted application CGS port
reply port         nonzero / receive port
NDR                 native legacy NDR
window ID          nonzero; first exact window becomes the only target
arg1               3
arg2               1
timeout            none
notify             null
maximum exact calls 32
```

All later exact calls must target the same first captured window ID. No different window or body is adapted.

## Current-main implementation

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
Git blob cd01e142460fd094f739ebfb83d805d33f72eff7

scripts/build-ppc-carbon-gui-backing-sync-compat-on-snowleopard.sh
Git blob 454e9803d389640388a89220f6ac800dc1ecaf83

scripts/run-snowleopard-ppc-carbon-gui-backing-sync-control.sh
Git blob 7822f7466708cc4f8745d7d9aa0c8cc73f202be1

scripts/run-lion-ppc-carbon-gui-backing-sync-integration.sh
Git blob dcef472c5e63c00ed3bac44b552b2be417e80d03
```

New combined compatibility build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v6
```

New mode:

```text
ROSETTA_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_MODE
Snow control: passthrough
Lion test:    lion-id-v1
```

## Fixed reused identities

Keep unchanged:

```text
historical PPC Carbon subject
fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067

native CGWindow observer
0416a9b3bd9466708f6e540616be94fcc2ba65c5a89a68844602eee7bb220634

Carbon GUI exact-21 broker
ba7477848f84bbefdbdaa188f847aa8c369ccb0d63c9ac88bbbd752fc7bed5ac

Security compatibility
9aed61996fd5079299f7b8971a77efcfc25908636618e4754866ea8267306b51

CGS / DockServer / FontServer rendezvous compatibility
f7dbcb98cbf5d64f95a33af222432d5a86ba273b475f5e3de83fff6d6c3c931b

HIToolbox Extras compatibility
a5b385d29bb5a6d887122ba0b2a7b1e78c45a1b69bfceb687c9cb2c77cc70572

Snow HIToolbox Extras resource
a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197

titlebar exact-six compatibility
6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72

Lion CoreUI ArtFile.bin
0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4

private dyld
963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb

Rosetta translator
4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18

Rosetta cache
2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911

Rosetta cache map
66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9

Lion CoreGraphics
fff91efa5392c007ef4bde715666cc738b69f652f565abfce056ba07273aa192

accepted Lion kernel
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

## Safety constraints

- Snow Leopard must be 10.6.8 / 10K549.
- Lion must be 10.7.5 / 11G63.
- Build the new v6 PPC compatibility dylib only on Snow Leopard.
- Do not rebuild or modify the historical PPC subject.
- Do not rebuild the observer.
- Do not modify the exact-21 notification broker.
- Do not alter the accepted titlebar bsearch interposer or Lion ArtFile.
- Do not add or change any titlebar key or payload translation in this phase.
- Do not synthesize a backing result or shared-memory descriptor.
- Do not rewrite the synchronization body, window ID, args, NDR, ports, sizes, or result.
- Do not adapt AutofillColor or any other neighboring routine.
- Do not adapt more than 32 exact same-window synchronization calls.
- Do not patch CoreGraphics, CoreUI, WindowServer, system resources, Rosetta, dyld, caches, or XNU.
- Do not restart WindowServer, Dock, Finder, distnoted, launchd, or the machine.
- Run the Snow subject once and Lion subject once before review.

## Phase A — pull and pin current main

On Snow and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c)" = \
  "cd01e142460fd094f739ebfb83d805d33f72eff7" || exit 1
test "$(git hash-object ./scripts/build-ppc-carbon-gui-backing-sync-compat-on-snowleopard.sh)" = \
  "454e9803d389640388a89220f6ac800dc1ecaf83" || exit 1
test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-backing-sync-control.sh)" = \
  "7822f7466708cc4f8745d7d9aa0c8cc73f202be1" || exit 1
test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-backing-sync-integration.sh)" = \
  "dcef472c5e63c00ed3bac44b552b2be417e80d03" || exit 1
```

Syntax-check both shell scripts on their respective hosts before use.

On Lion also fast-forward the XNU companion checkout, but do not build or reboot.

## Phase B — build v6 on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/bin/bash ./scripts/build-ppc-carbon-gui-backing-sync-compat-on-snowleopard.sh \
  ./pm-carbon-gui-backing-sync-compat.dylib || exit 1
```

Require:

```text
pm-carbon-gui-backing-sync-compat.dylib
pm-carbon-gui-backing-sync-compat.dylib.info.txt
pm-carbon-gui-backing-sync-compat.dylib.sha256
```

The info file must show PPC32, the v6 build ID, the embedded distributed-notification ingress marker, exactly two interpose tuples, and both shape-inline plus backing-sync markers. The sidecar becomes the authoritative SHA for this newly built artifact.

## Phase C — one Snow passthrough control

Use the exact historical subject and exact observer:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-backing-sync-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-backing-sync-snow-control.log \
  ./ppc-carbon-gui-backing-sync-snow-observer.log
```

Require:

```text
shape inline predicate exact / PASSTHROUGH exactly once
backing-sync exact count >= 1
backing-sync PASSTHROUGH count == exact count
backing-sync ADAPTER_PASS count = 0
backing-sync predicate rejects = 0
subject exit 0
both historical markers once
observer PASS
400x222 titled geometry observed
RESULT: PPC_CARBON_GUI_BACKING_SYNC_SNOW_CONTROL_PASS
RESULT: PASS
```

Manually record whether the Snow Carbon window and titlebar remain visually normal.

If the explicit Snow synchronization predicate is never reached, stop before Lion. Do not infer the live Lion adapter from static evidence alone.

## Phase D — transfer the exact v6 artifact to Lion

Copy unchanged to Lion payload:

```text
pm-carbon-gui-backing-sync-compat.dylib
pm-carbon-gui-backing-sync-compat.dylib.info.txt
pm-carbon-gui-backing-sync-compat.dylib.sha256
```

Verify the Lion copy against the Snow sidecar. Do not rebuild on Lion.

## Phase E — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  ./sys295-carbon-gui-backing-sync.log || exit 1
```

Require EBADF, no SIGSYS, probe exit 0, and final PASS.

## Phase F — exactly one Lion integration

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-carbon-gui-backing-sync-integration.sh \
  ./payload/ppc-carbon-gui-smoketest-private-dyld \
  ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./payload/pm-carbon-gui-backing-sync-compat.dylib \
  ./payload/pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./dn-carbon-gui-registration-broker \
  ./dn-carbon-gui-registration-broker.sha256 \
  ./payload/lion-ppc-carbon-gui-backing-sync-integration.log \
  ./payload/cgwindowlist-pid-observer \
  ./payload/cgwindowlist-pid-observer.sha256 \
  ./payload/lion-ppc-carbon-gui-backing-sync-observer.log
```

Raw log:

```text
payload/lion-ppc-carbon-gui-backing-sync-integration.raw.log
```

Do not rerun before review.

## Backing-sync acceptance

Require one or more same-window exact transactions, with every exact transaction completing all stages:

```text
PM_CGS_BACKING_SYNC_COMPAT_CALL:
  mode=lion-id-v1
  exact=YES
  id=0x7265
  send=0x2c
  recv=0x2c
  arg1=3
  arg2=1

PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:
  legacyId=0x7265
  lionId=0x7266
  changedBytes=1
  bodyChangedBytes=0
  sourceChangedBytes=0

PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:
  bits=0x1200
  size=0x24
  id=0x72ca
  result=0
  ndrSwapped=YES
  replyClass=SUCCESS

PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:
  nativeId=0x72ca
  legacyId=0x72c9
  changedBytes=1
  bodyChangedBytes=0
  result=0

PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS
```

Require:

```text
exact_count >= 1
adapted_request_count == exact_count
native_success_count == exact_count
adapted_reply_count == exact_count
adapter_pass_count == exact_count
predicate_reject_count = 0
native_reject_count = 0
backing_sync_lock_failure_count = 0
```

The successful call count is deliberately not pinned to the 12 failures from the preceding Lion run because successful synchronization may change later retry behavior.

## Regression gates

The runner also requires all previously closed machine gates, including:

- exact historical CPS registration PASS;
- 21 exact notification registrations / zero rejects / broker PASS;
- NewWindow, release-backing, opacity, ShapeWindow-inline, WindowBackingInfo, color-profile, tracking, order-front, set-front and FontServer adapters at accepted counts;
- ShapeWindow-inline exact adapter still PASS;
- no CGSShapeWindow server type-check diagnostic;
- titlebar exact-six translations still exactly 6 with zero guard rejects;
- observer reaches the exact 400x222 titled window onscreen;
- both historical subject markers once;
- subject exit 0;
- no new crash diagnostic;
- protected system hashes unchanged.

Machine success:

```text
RESULT: PPC_CARBON_GUI_BACKING_SYNC_INTEGRATION_PASS
visual_window_observation=MANUAL_REQUIRED
visual_titlebar_observation=MANUAL_REQUIRED
RESULT: PASS
```

## Manual visual discriminator

Report both independently:

```text
Lion Carbon window visible: YES/NO
Lion titlebar normal Aqua appearance with distinct red/yellow/green controls: YES/NO
```

If the titlebar remains visually abnormal, include one screenshot.

## Decision gate

### Adapter PASS + no lock-sync failures + normal titlebar

The titlebar defect was downstream of the synchronization ID collision. The direct historical Carbon GUI smoke can then be reviewed for visual closure without adding another compatibility rule.

### Adapter PASS + no lock-sync failures + titlebar still abnormal

Do not broaden synchronization or ShapeWindow compatibility. The CGS synchronization boundary is closed; next perform a read-only CoreUI/ArtFile rendered-titlebar fidelity differential focused on the six already translated semantic keys and their payload use.

### Adapter PASS but lock-sync failure remains

Review chronology and exact request ownership. Do not adapt AutofillColor or another neighboring routine automatically.

### Native 0x7266 reply nonzero or malformed

Stop. Preserve raw evidence. Do not translate the result or synthesize backing state.

### Predicate reject or Snow control failure

Stop. Do not broaden the predicate and do not run Lion.

## Return for review

Return:

```text
pm-carbon-gui-backing-sync-compat.dylib.info.txt
pm-carbon-gui-backing-sync-compat.dylib.sha256
ppc-carbon-gui-backing-sync-snow-control.log
ppc-carbon-gui-backing-sync-snow-observer.log
sys295-carbon-gui-backing-sync.log
lion-ppc-carbon-gui-backing-sync-integration.log
lion-ppc-carbon-gui-backing-sync-integration.raw.log
lion-ppc-carbon-gui-backing-sync-observer.log
```

Also state:

```text
Snow manual Carbon window visible: YES/NO
Snow titlebar visually normal: YES/NO
Lion manual Carbon window visible: YES/NO
Lion titlebar normal Aqua appearance with distinct red/yellow/green controls: YES/NO
```

Return any new crash/core artifact only if the Lion runner explicitly names one.

## Current boundary

```text
CGSShapeWindow inline adapter                  LIVE-PROVEN PASS
Lion frame                                    400x222 at (120,98), onscreen
Lion manual window                            VISIBLE
Lion titlebar                                 VISIBLE BUT VISUALLY ABNORMAL
titlebar exact-six bsearch translations       6 / guard rejects 0
Snow SynchronizeWindowBackingStore            0x7265 / 0x72c9
Lion SynchronizeWindowBackingStore            0x7266 / 0x72ca
Lion 0x7265 / 0x72c9                          SetWindowAutofillColor collision
current live sync result                      repeated -304 + lock-sync failure
next step                                     exact same-window sync ID-only integration
CoreUI/ArtFile payload changes                HELD
later CGS adapters                            HELD
LaunchServices / Finder / Cocoa               HELD
XNU                                           no source change indicated
```
