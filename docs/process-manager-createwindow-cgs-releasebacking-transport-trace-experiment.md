# Process Manager CreateNewWindow CGS release-backing transport trace experiment

## Objective

Validate the first narrow generated-MIG differential exposed by the completed post-NewWindow static audit before introducing any additional compatibility rule.

Both static reports passed. The first post-NewWindow helper named by the live Lion diagnostics, `CGSSetWindowToReleaseBackingOnOrderOut`, has the same visible client geometry on Snow Leopard PPC and Lion i386 except for the generated routine IDs:

```text
                         Snow Leopard PPC     Lion i386
request bits             0x1513               0x1513
request ID               0x724b               0x724c
reply ID                 0x72af               0x72b0
Mach option              0x3                  0x3
send size                0x28                 0x28
receive size             0x2c                 0x2c
accepted reply size      0x24                 0x24
```

The request contains the same NDR record and two scalar words after it. The generated reply path on both systems performs the same NDR-aware scalar decode.

The same audit also found later `CGSShapeWindow` generated-MIG ID movement:

```text
non-inline    0x7367 / 0x73cb  ->  0x736d / 0x73d1
inline        0x7368 / 0x73cc  ->  0x736e / 0x73d2
```

Do **not** trace or adapt those ShapeWindow transactions yet. They occur after the release-backing failure in the current live sequence and may be downstream fallout.

The audited `CGSSetWindowOpacity` and `CGSGetDisplayBounds` public symbol windows do not expose a same-named direct generated-`mach_msg` stub from which a safe ID-only policy can be inferred. They remain out of scope until the first release-backing boundary is resolved.

This stage therefore adds only passive recognition of the Snow/Lion release-backing ID pairs to the existing two-tuple CoreServices `mach_msg` interposer. It does not rewrite the request or reply.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-trace-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Compile-time trace mode:

```text
PM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE
```

Runner modes:

```text
Snow  ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE=passthrough
Lion  ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE=lion-passive-v1
```

Combined build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-trace-v1
```

Trace kinds:

```text
CGS_SET_WINDOW_RELEASE_BACKING_LEGACY   0x724b -> 0x72af
CGS_SET_WINDOW_RELEASE_BACKING_LION     0x724c -> 0x72b0
```

The new build retains the already accepted NewWindow compatibility handler unchanged and still contains exactly two PPC interpose tuples: `bootstrap_look_up2` and `mach_msg`.

## Safety constraints

- Build only the new combined trace dylib on Snow Leopard 10.6.8.
- Reuse the accepted CreateNewWindow subject unchanged.
- Reuse the accepted Security, Dock-aware CGS, HIToolbox Extras, exact-four native notification broker, and staged Snow `Extras.rsrc` unchanged.
- Keep the NewWindow compatibility policy unchanged.
- On Snow, NewWindow remains strict passthrough.
- On Lion, NewWindow remains `lion-inline-id-v1`; the release-backing transaction is observation-only.
- Do not translate `0x724b -> 0x724c` in this experiment.
- Do not trace or adapt ShapeWindow, opacity, display-bounds, or any other newly exposed CGS routine.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, launchd, libSystem, the Rosetta cache, or XNU.
- Do not restart or signal WindowServer or launchd jobs.
- Run the Lion trace exactly once before review.
- Preserve the existing 2026-10-11 Lion crash/core; do not replace or delete it.
- No XNU rebuild or reboot.

## Phase A — update repositories

On Snow Leopard and Lion, pull current runtime `main`. On Lion also pull current XNU `main`.

## Phase B — build only the release-backing trace dylib on Snow Leopard

Run:

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-trace-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-trace-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib.sha256
```

Require a 32-bit PPC dylib, exactly two interpose tuples, the combined build ID above, embedded distributed-notifications ingress v2, all existing NewWindow compatibility markers, and both release-backing trace-kind strings.

Do not rebuild any other accepted artifact.

## Phase C — Snow Leopard full positive control

Unset `ROSETTA_CGS_NEWWINDOW_TRACE_MODE`. Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE=passthrough
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
```

Syntax-check and run the existing Snow full-stack control, changing only the CoreServices dylib pair to the new trace build:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./ppc-process-manager-createwindow-cgs-releasebacking-trace-snowleopard-control.log
```

Hard gate:

```text
NewWindow compatibility call              index=1 mode=passthrough exact=YES
NewWindow result                          PASSTHROUGH
release-backing trace count               1
release-backing request                   bits=0x1513 id=0x724b expectedReply=0x72af
release-backing send / receive            0x28 / 0x2c
release-backing Mach result               0
release-backing reply                     id=0x72af expected=0x72af idMatch=YES
CreateNewWindow                           0
WindowRef                                 nonzero
DisposeWindow                             reached
M24_SUCCESS                               reached
RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Stop if Phase C fails.

## Phase D — transfer only the new trace artifact

Transfer to Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib.sha256
ppc-process-manager-createwindow-cgs-releasebacking-trace-snowleopard-control.log
```

Do not rebuild the PPC dylib on Lion.

## Phase E — repeat syscall-295 safety gate on Lion

Run the established native routing probe and save:

```text
syscall295-probe-process-manager-createwindow-cgs-releasebacking-trace.log
```

Require `result=-1`, `errno=9`, `saw_sigsys=0`, and `RESULT: PASS`.

## Phase F — exactly one Lion passive release-backing trace

Unset `ROSETTA_CGS_NEWWINDOW_TRACE_MODE` and obsolete schema-audit variables. Keep the established expected kernel hash.

Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE=lion-passive-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

Syntax-check and run the existing Lion full-stack runner with only the CoreServices dylib pair changed to the new trace build:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-cgs-releasebacking-trace.log
```

The accepted upstream stack must remain intact through native NewWindow success:

```text
PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:... id=0x000073fe ... size=0x00000038 ... result=0 ... replyClass=SUCCESS
PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS
legacy-facing NewWindow reply 0x73f8 / 0x38 accepted
```

Then require exactly one passive release-backing legacy request:

```text
kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY
bits=0x00001513
id=0x0000724b
expectedReply=0x000072af
option=0x00000003
send=0x00000028
recv=0x0000002c
```

The runner will classify the observed transport without rewriting it.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-trace.dylib.sha256
ppc-process-manager-createwindow-cgs-releasebacking-trace-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-releasebacking-trace.log
lion-ppc-process-manager-createwindow-cgs-releasebacking-trace.log
lion-ppc-process-manager-createwindow-cgs-releasebacking-trace.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner. Stop after Phase G.

## Decision gate

### `CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_LEGACY_REPLY_OBSERVED`

Preserve the exact reply size and raw words. Compare the live Snow and Lion legacy-facing results with the static native `0x724c/0x72b0` contract. If Lion again shows Mach success plus a structurally normal legacy reply carrying a server error, the next stage may be a no-Mach-IPC copied-buffer proof of **only** `0x724b -> 0x724c` and `0x72b0 -> 0x72af`. Do not integrate that conversion until the proof is reviewed.

### `CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_MACH_FAILURE`

Preserve the Mach return and stop. Do not infer a generated-MIG ID policy from a transport failure.

### `CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_REPLY_UNEXPECTED`

Preserve the full reply envelope and words and stop. Do not force the static expected reply ID.

### request not reached / unexpected

Stop. The live post-NewWindow sequence differs from the static model or the previous run and must be reviewed before any broader trace.

## Current boundary

```text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
accepted pre-window compatibility stack         -> PASS
Dock bootstrap compatibility                    -> PASS
NewWindow ID-only live integration              -> native Lion success
public CreateNewWindow return                    -> not reached
first post-NewWindow live diagnostic             -> CGSSetWindowToReleaseBackingOnOrderOut
static release-backing delta                     -> 0x724b/0x72af vs 0x724c/0x72b0
next step                                       -> passive exact release-backing trace only
```

No additional XNU change is indicated.


## Observed result — legacy release-backing reaches Lion and returns -304

The returned evidence closes the passive transport gate.

Artifact provenance:

```text
build ID                         dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-trace-v1
architecture                     ppc7400
interpose section size           0x10 (two PPC tuples)
trace dylib SHA-256              8c87c768fc92e2f2c602c59945371fb5026104ff2b1b299fc242436d8bee3413
Snow control                     PASS
syscall 295                      EBADF / no SIGSYS / PASS
```

The exact Snow control transaction was:

```text
request                          bits=0x1513 id=0x724b option=0x3 send=0x28 recv=0x2c
request words                    off18=0 off1c=0 off20=0x000000ff off24=1
Mach result                      0
reply                            bits=0x1200 size=0x24 id=0x72af
reply raw result                 0x00000000
CreateNewWindow                  0
WindowRef                        nonzero
DisposeWindow / M24              reached
```

The exact Lion transaction, after the already accepted NewWindow adapter returned a native `0x73fe / 0x38 / result 0` success and mapped it back to `0x73f8`, was:

```text
request                          bits=0x1513 id=0x724b option=0x3 send=0x28 recv=0x2c
request words                    off18=0 off1c=0 off20=0x0000020a off24=1
Mach result                      0
reply                            bits=0x1200 size=0x24 id=0x72af
reply raw result                 0xd0feffff
decoded result                   -304
CoreGraphics diagnostic          MIG server type check failure: CGSSetWindowToReleaseBackingOnOrderOut
runner result                    CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_LEGACY_REPLY_OBSERVED
```

The differing first post-NDR scalar (`0xff` on Snow, `0x20a` on Lion) is a per-run object value; the layout and second scalar remain aligned. The important discriminator is that Lion returns Mach success and the normal legacy reply envelope while carrying the same `-304` generated-MIG error pattern previously seen at NewWindow before its ID adaptation.

The exact-four notification registrations and native broker remained PASS, the process again terminated later with status 138 and the same downstream opacity/display-bounds/ShapeWindow diagnostics, and all protected hashes remained unchanged. The syscall-295 safety gate also remained PASS.

The next step is **not** live translation. The authoritative procedure is now:

```text
docs/process-manager-createwindow-cgs-releasebacking-compat-protocol-adapter-experiment.md
```

That stage is a standalone no-Mach-IPC copied-buffer proof of only `0x724b -> 0x724c` and `0x72b0 -> 0x72af`, including preservation of both success result 0 and a modeled nonzero `-304` result. Do not integrate the conversion until that proof is reviewed.
