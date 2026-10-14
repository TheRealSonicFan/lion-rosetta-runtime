# PPC Carbon GUI CGSShapeWindow inline compatibility integration

## Status

**NEXT CONTROLLED LIVE STEP.** Both static protocol audits pass and resolve the first collapsed-window geometry failure to a narrow generated-MIG ID collision.

The Snow Leopard PPC client used by the historical Carbon path is:

```text
helper                      __CGSSetWindowShapeInline
request / reply             0x724d / 0x72b1
bits                        0x1513
option                      0x3
send size                   0x2c + 4*count
receive size                0x2c
count limit                 0x1000
accepted reply size         0x24
```

Lion i386 keeps the same inline wire contract but moves it by one ID:

```text
helper                      __CGSSetWindowShapeInline
request / reply             0x724e / 0x72b2
bits                        0x1513
option                      0x3
send size                   0x2c + 4*count
receive size                0x2c
count limit                 0x1000
accepted reply size         0x24
```

The crucial collision is that Lion reuses the old Snow inline IDs for a different **non-inline** generated client:

```text
Lion helper                 __CGSSetWindowShape
request / reply             0x724d / 0x72b1
bits                        0x80001513
send size                   0x3c fixed
receive size                0x2c
```

Therefore the historical PPC request with bits 0x1513, ID 0x724d, count 9, and send size 0x50 is being dispatched by Lion to the wrong generated server contract. That explains the observed -304 / MIG_BAD_ARGUMENTS and immediate CGSShapeWindow server type-check diagnostic.

The first live compatibility rule is now justified as an **ID-only inline conversion**:

```text
legacy request              0x724d
Lion inline request         0x724e
Lion inline reply           0x72b2
legacy reply                0x72b1
request body                unchanged
reply body/result           unchanged
```

No display-ID, region-data, geometry, CoreGraphics, WindowServer, or backing-state rewrite is authorized in this phase.

## Exact live predicate

The new adapter matches only the single historical request already observed from the exact Carbon smoke subject:

```text
bits                        0x1513
request ID                  0x724d
option                      0x3
send / receive              0x50 / 0x2c
NDR                         native legacy NDR
window ID                   nonzero
arg1                        1
count                       9
shape words:
  0x80000000
  0x00000002
  0x00000062
  0x00000004
  0x00000078
  0x00000208
  0x00000140
  0x00000002
  0x7fffffff
```

The shape words encode the already observed Snow frame edges (x=120, y=98, right=520, bottom=320) within the legacy region payload. The adapter refuses later or different payloads and requires its first exact call.

## Prepared current-main files

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
  Git blob d52cd6a1fe850102ae8c9041e48b178d354fc532

scripts/build-ppc-carbon-gui-cgsshapewindow-inline-compat-on-snowleopard.sh
  Git blob 977424d4f63b3754aa9dc2bbc9d3922e0c92a205

scripts/run-snowleopard-ppc-carbon-gui-cgsshapewindow-inline-control.sh
  Git blob 1a9ccff345c615f14c56514d14acced18fb2fe0e

scripts/run-lion-ppc-carbon-gui-cgsshapewindow-inline-integration.sh
  Git blob 9832dfb208f0dedb20a213c4ed8bd6e7c6fa695f
```

Compatibility build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v5
```

New runtime mode:

```text
Snow Leopard  ROSETTA_CGS_SHAPEWINDOW_INLINE_COMPAT_MODE=passthrough
Lion          ROSETTA_CGS_SHAPEWINDOW_INLINE_COMPAT_MODE=lion-inline-id-v1
```

## Fixed reused identities

Keep these accepted artifacts unchanged:

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
- Build the new PPC compatibility dylib only on Snow Leopard.
- Do not rebuild or alter the historical PPC subject.
- Do not rebuild the observer.
- Do not alter the exact-21 Carbon GUI notification broker.
- Do not change any accepted Security, CGS rendezvous, HIToolbox, titlebar, Rosetta, dyld, cache, framework, resource, or kernel artifact.
- Do not patch CoreGraphics or WindowServer.
- Do not rewrite display IDs or the shape payload.
- Do not adapt the later non-inline or ShapeWindow-generated requests in the same run.
- Do not broaden the exact count-9/payload predicate.
- Do not restart WindowServer, Dock, Finder, distnoted, launchd, or the machine.
- Do not rebuild XNU or reboot.
- Run the Snow subject once and the Lion subject once.

## Phase A — pull current runtime and XNU mains

On both systems, update the runtime checkout with a fast-forward-only pull. On Lion also update the XNU companion checkout. Confirm the four runtime Git blobs listed above before proceeding.

No XNU build is authorized.

## Phase B — build the exact combined compatibility dylib on Snow

From current runtime main on Snow Leopard:

```sh
/bin/bash ./scripts/build-ppc-carbon-gui-cgsshapewindow-inline-compat-on-snowleopard.sh   ./pm-carbon-gui-cgsshapewindow-inline-compat.dylib
```

Require all three outputs:

```text
pm-carbon-gui-cgsshapewindow-inline-compat.dylib
pm-carbon-gui-cgsshapewindow-inline-compat.dylib.info.txt
pm-carbon-gui-cgsshapewindow-inline-compat.dylib.sha256
```

Require PPC32, exactly two interpose tuples, the v5 build ID above, the embedded distributed-notification ingress marker, and all CGSShapeWindow-inline compatibility markers.

## Phase C — one Snow passthrough control

Reuse the exact historical PPC subject and exact native observer from the completed WindowServer differential:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-cgsshapewindow-inline-control.sh   ./ppc-carbon-gui-smoketest-private-dyld   ./ppc-carbon-gui-smoketest-private-dyld.sha256   ./pm-carbon-gui-cgsshapewindow-inline-compat.dylib   ./pm-carbon-gui-cgsshapewindow-inline-compat.dylib.sha256   ./cgwindowlist-pid-observer   ./cgwindowlist-pid-observer.sha256   ./ppc-carbon-gui-cgsshapewindow-inline-snow-control.log   ./ppc-carbon-gui-cgsshapewindow-inline-snow-observer.log
```

Require:

```text
PM_CGS_SHAPEWINDOW_INLINE_COMPAT_CALL:index=1 mode=passthrough exact=YES
PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PASSTHROUGH
no ADAPTER_PASS
legacy trace 0x724d / 0x72b1
send / receive 0x50 / 0x2c
subject exit 0
observer PASS
at least one exact-title x=120 y=98 width=400 height=222 observation
RESULT: PPC_CARBON_GUI_CGSSHAPEWINDOW_INLINE_SNOW_CONTROL_PASS
RESULT: PASS
```

Manually confirm the Snow Carbon window is visible.

If the predicate is not exact on Snow, stop. Do not run Lion.

## Phase D — transfer only the new built artifact to Lion

Copy the exact Snow-built files into Lion runtime payload:

```text
payload/pm-carbon-gui-cgsshapewindow-inline-compat.dylib
payload/pm-carbon-gui-cgsshapewindow-inline-compat.dylib.info.txt
payload/pm-carbon-gui-cgsshapewindow-inline-compat.dylib.sha256
```

Do not rebuild the dylib on Lion.

Keep the previously transferred historical PPC subject, observer, Security/CGS/HIToolbox/titlebar artifacts, resource, and exact-21 broker unchanged.

## Phase E — fresh syscall-295 preflight on Lion

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh"   "$XNU_SRC/syscall295-probe"   ./sys295-carbon-gui-cgsshapewindow-inline.log || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase F — exactly one Lion integration

From current runtime main on Lion:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-carbon-gui-cgsshapewindow-inline-integration.sh   ./payload/ppc-carbon-gui-smoketest-private-dyld   ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256   ./payload/pm-carbon-gui-cgsshapewindow-inline-compat.dylib   ./payload/pm-carbon-gui-cgsshapewindow-inline-compat.dylib.sha256   ./payload/ppc-process-manager-security-session-auditinfo-api.dylib   ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256   ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib   ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256   ./dn-carbon-gui-registration-broker   ./dn-carbon-gui-registration-broker.sha256   ./payload/lion-ppc-carbon-gui-cgsshapewindow-inline-integration.log   ./payload/cgwindowlist-pid-observer   ./payload/cgwindowlist-pid-observer.sha256   ./payload/lion-ppc-carbon-gui-cgsshapewindow-inline-observer.log
```

The raw log is created automatically as:

```text
payload/lion-ppc-carbon-gui-cgsshapewindow-inline-integration.raw.log
```

## Lion adapter acceptance

Require exactly one exact adapter transaction:

```text
PM_CGS_SHAPEWINDOW_INLINE_COMPAT_CALL:
  index=1
  mode=lion-inline-id-v1
  exact=YES
  id=0x724d
  send=0x50
  recv=0x2c
  arg1=1
  count=9

PM_CGS_SHAPEWINDOW_INLINE_COMPAT_ADAPTED_REQUEST:
  legacyId=0x724d
  lionId=0x724e
  changedBytes=1
  bodyChangedBytes=0
  sourceChangedBytes=0
  count=9

PM_CGS_SHAPEWINDOW_INLINE_COMPAT_NATIVE_REPLY:
  bits=0x1200
  size=0x24
  id=0x72b2
  result=0
  ndrSwapped=YES
  replyClass=SUCCESS

PM_CGS_SHAPEWINDOW_INLINE_COMPAT_ADAPTED_REPLY:
  nativeId=0x72b2
  legacyId=0x72b1
  changedBytes=1
  bodyChangedBytes=0
  result=0

PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:ADAPTER_PASS
```

Require zero predicate rejects and zero remaining:

```text
MIG: server type check failure: CGSShapeWindow
```

for this exact run.

## Lion geometry acceptance

The same exact observer must report the historical titled window at least once as:

```text
onscreen=YES
layer=0
alpha=1.000
x=120
y=98
width=400
height=222
name=Rosetta PPC Carbon GUI
```

The runner does not require the 1x1 state to be absent from every early sample because a transient pre-shape creation sample is allowed. It requires the restored 400x222 state to be reached onscreen.

Manually record whether the Carbon window is now visible.

## Full-stack regression gates

The Lion runner also requires:

- subject exit 0;
- both historical subject markers exactly once;
- exact historical CPS registration success;
- exact 21 notification registrations, zero rejects, broker PASS/exit 0, no request 22;
- all accepted Security/session/server/CPS/Dock/NewWindow/release-backing/opacity/window-backing/FontServer/color-profile/tracking/order-front/set-front adapter counts unchanged;
- six exact titlebar translations and zero titlebar guard rejects;
- no new crash diagnostic;
- protected system hashes unchanged;
- observer PASS.

Final machine result:

```text
RESULT: PPC_CARBON_GUI_CGSSHAPEWINDOW_INLINE_INTEGRATION_PASS
RESULT: PASS
```

## Decision gate

### Adapter PASS + 400x222 onscreen + manual window visible

The collapsed-window boundary is closed. Do not add any further CGS compatibility in the same phase. The next review should determine whether the original Carbon GUI smoke restoration can now be declared visually complete before expanding to another historical PPC application.

### Adapter PASS + 400x222 onscreen but manual window still invisible

Do not broaden shape translation. Move to a read-only backing/compositor observation, because geometry is proven restored but visual presentation remains absent.

### Adapter PASS but observer never reaches 400x222

The 0x724d collision is real but not sufficient to explain the final geometry. Preserve the raw trace and observer log; review later shape/backing traffic before any second adapter.

### Native Lion inline reply is nonzero or malformed

Stop. Preserve the raw trace. Do not translate the result or payload and do not add another shape adapter.

### Predicate reject

Stop and review the exact live request against the pinned count-9 payload. Do not broaden the predicate.

## Return for review

Return exactly:

```text
pm-carbon-gui-cgsshapewindow-inline-compat.dylib.info.txt
pm-carbon-gui-cgsshapewindow-inline-compat.dylib.sha256
ppc-carbon-gui-cgsshapewindow-inline-snow-control.log
ppc-carbon-gui-cgsshapewindow-inline-snow-observer.log
sys295-carbon-gui-cgsshapewindow-inline.log
lion-ppc-carbon-gui-cgsshapewindow-inline-integration.log
lion-ppc-carbon-gui-cgsshapewindow-inline-integration.raw.log
lion-ppc-carbon-gui-cgsshapewindow-inline-observer.log
```

Also state separately:

```text
Snow manual Carbon window visible: YES/NO
Lion manual Carbon window visible: YES/NO
```

Return any new crash report/core/plist only if the Lion runner explicitly names one.

## Current boundary

```text
Snow static shape audit                         PASS
Lion static shape audit                         PASS
Snow inline set-shape                           0x724d / 0x72b1, bits 0x1513
Lion inline set-shape                           0x724e / 0x72b2, bits 0x1513
Lion non-inline ID collision                    0x724d / 0x72b1, bits 0x80001513
live legacy request                             count 9 / send 0x50
current Lion result                             -304 + CGSShapeWindow type-check
WindowServer current Lion frame                 1x1 at (120,98)
next step                                       one exact inline ID-only compatibility integration
payload/geometry rewrite                        NO
later shape adapters                            HELD
LaunchServices / Finder / Cocoa                 HELD
XNU                                             no source change indicated
```
