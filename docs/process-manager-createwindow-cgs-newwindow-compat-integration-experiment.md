# Process Manager CreateNewWindow CGS NewWindow compatibility integration experiment

## Objective

Integrate the proven inline NewWindow request/reply ID conversion into the accepted combined CoreServices compatibility dylib and determine whether Lion WindowServer accepts the native routine ID for the exact CreateNewWindow transaction that currently returns -304.

The prerequisite evidence is now complete. The passive trace established the live legacy transaction on Lion:

~~~text
legacy request / reply       0x7394 / 0x73f8
bits                          0x1513
send / receive                0x68 / 0x40
Mach result                   0
legacy reply size             0x24
decoded result                -304
public CreateNewWindow        -304
~~~

The static Lion i386 audit established native IDs 0x739a / 0x73fe with the same visible request construction and accepted 0x38 success / 0x24 error reply family. The completed standalone policy proof then showed that changing only 0x7394 -> 0x739a and 0x73fe -> 0x73f8 changes exactly one byte in each copied message, changes zero body bytes, leaves the source request untouched, and preserves a nonzero error result unchanged.

This stage performs the first live native-ID NewWindow request. No payload field, Mach port, size, NDR, or server result is fabricated.

## Prepared implementation

Current runtime main provides:

~~~text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-createwindow-cgs-newwindow-compat-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
~~~

Compile-time mode:

~~~text
PM_CGS_NEWWINDOW_COMPAT_INTEGRATION
~~~

Runtime modes:

~~~text
Snow  ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough
Lion  ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
~~~

Integration build ID:

~~~text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-v1
~~~

The dylib still contains exactly two PPC interpose tuples: bootstrap_look_up2 and mach_msg.

## Exact live predicate and policy

The NewWindow handler is eligible only for the first exact legacy inline transaction after exactly one accepted CPS registration compatibility call and one accepted SetFrontProcess compatibility call. It requires:

~~~text
bits                         0x1513
request ID                   0x7394
option                       0x3
send / receive               0x68 / 0x40
remote port                  nonzero
reply port                   receive port, nonzero
timeout                      0
notify                       MACH_PORT_NULL
NDR                          exact local NDR
visible word 0x20            0x00000002
visible word 0x24            0x00000009
visible word 0x28            0x80000000
visible word 0x2c            0x00000002
visible word 0x30            0x00000062
visible word 0x34            0x00000004
visible word 0x38            0x00000078
visible word 0x3c            0x00000079
visible word 0x40            0x00000063
registration calls           1
SetFront compatibility calls 1
NewWindow compatibility calls 1
~~~

On Lion the adapter:

1. copies the exact 0x68-byte request to a private buffer;
2. changes only request ID 0x7394 to 0x739a;
3. requires exactly one changed request byte, zero body-byte changes, and zero source-buffer changes;
4. calls the original mach_msg with the unchanged option, 0x68 send size, 0x40 receive size, ports, timeout, and notify;
5. accepts only native reply ID 0x73fe with bits 0x1200, cross-endian NDR, and either:
   - 0x38 success reply with decoded result 0; or
   - 0x24 error reply with a nonzero decoded result;
6. changes only native reply ID 0x73fe to legacy 0x73f8;
7. requires exactly one changed reply byte and zero reply-body changes;
8. copies the legacy-facing reply back to the untouched PPC caller.

A native error is propagated unchanged. The adapter never rewrites a result scalar to zero.

## Safety constraints

- Build only the new combined NewWindow compatibility dylib on Snow Leopard 10.6.8.
- Reuse the accepted CreateNewWindow subject unchanged.
- Reuse the accepted Security, Dock-aware CGS, HIToolbox Extras, exact-four notification broker, and staged Snow Extras.rsrc unchanged.
- Require the full Snow CreateNewWindow passthrough control before Lion.
- Repeat the established syscall-295 safety gate on Lion.
- Keep the passive-trace runner mode unset during this integration experiment.
- Do not broaden the exact NewWindow predicate.
- Do not translate any non-NewWindow CGS transaction beyond the already accepted compatibility stack.
- Do not normalize or suppress a nonzero native NewWindow result.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, launchd, or XNU.
- Do not restart or signal WindowServer or launchd jobs.
- Run the Lion integration exactly once before review.
- No XNU rebuild or reboot.

## Phase A — update repositories

On Snow Leopard and Lion:

~~~sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
~~~

On Lion also update the documentation checkout:

~~~sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
~~~

## Phase B — build only the NewWindow integration dylib on Snow Leopard

~~~sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-newwindow-compat-integration-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-newwindow-compat-integration-on-snowleopard.sh
~~~

Expected outputs:

~~~text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib.sha256
~~~

Require a 32-bit PPC dylib, exactly two interpose tuples, the integration build ID above, embedded distributed-notifications ingress v2, the legacy/native NewWindow trace markers, and all NewWindow compatibility call/request/native-reply/adapted-reply/PASS/PASSTHROUGH markers.

Do not rebuild any other accepted artifact.

## Phase C — Snow Leopard full CreateNewWindow passthrough control

Unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE. Set:

~~~sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
~~~

Syntax-check and run the existing Snow full-stack control, changing only the CoreServices dylib pair:

~~~sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./ppc-process-manager-createwindow-cgs-newwindow-compat-integration-snowleopard-control.log
~~~

Hard gate:

~~~text
PM_CGS_NEWWINDOW_COMPAT_CALL:index=1 mode=passthrough exact=YES
PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH
no PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS
legacy 0x7394 -> 0x73f8 trace remains successful
CreateNewWindow=0
nonzero WindowRef
DisposeWindow
M24_SUCCESS
RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_SNOW_CONTROL_PASS
RESULT: PASS
~~~

Stop if Phase C fails.

## Phase D — transfer only the new integration artifact

Transfer to Lion:

~~~text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib.sha256
ppc-process-manager-createwindow-cgs-newwindow-compat-integration-snowleopard-control.log
~~~

Do not rebuild the PPC dylib on Lion.

## Phase E — repeat the established syscall-295 safety gate on Lion

Run the same native routing probe and save:

~~~text
syscall295-probe-process-manager-createwindow-cgs-newwindow-compat-integration.log
~~~

Require result=-1, errno=9, saw_sigsys=0, and RESULT: PASS.

## Phase F — exactly one Lion live NewWindow compatibility integration

Unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE and obsolete schema-audit variables. Keep the established expected kernel hash.

Set:

~~~sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
~~~

Syntax-check the existing Lion integration runner, then run it with only the CoreServices dylib pair changed to the new integration build:

~~~sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-cgs-newwindow-compat-integration.log
~~~

Require all accepted upstream gates to remain true: session bootstrap, server-version normalization, CPS registration, SetFrontProcess, GetFrontProcess/GetCurrentProcess, exact-four distributed-notification registrations, native broker PASS, exact Extras fallback, Dock adapter PASS, syscall-295 PASS, and protected hashes unchanged.

The NewWindow adapter must show exactly one exact call, one-byte request-ID conversion with zero source/body changes, Mach success, and one-byte reply-ID conversion with zero body changes.

### Desired success branch

~~~text
native reply             0x73fe / 0x38 / result 0 / SUCCESS
legacy-facing reply      0x73f8 / 0x38 / result 0
public CreateNewWindow   0
WindowRef                nonzero
DisposeWindow            reached
M24_SUCCESS              reached
RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_INTEGRATION_PASS
~~~

### Native error branch

If Lion returns native 0x73fe / 0x24 with a nonzero result, the adapter must preserve that result while changing only the reply ID back to 0x73f8. The runner reports:

~~~text
RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_NATIVE_ERROR_PRESERVED
~~~

Stop there. Do not normalize the server result.

## Phase G — return evidence and stop

Return:

~~~text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat.dylib.sha256
ppc-process-manager-createwindow-cgs-newwindow-compat-integration-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-newwindow-compat-integration.log
lion-ppc-process-manager-createwindow-cgs-newwindow-compat-integration.log
lion-ppc-process-manager-createwindow-cgs-newwindow-compat-integration.raw.log
~~~

Also return every new crash/core diagnostic named by the runner. Stop after Phase G.

## Decision gate

### CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_INTEGRATION_PASS

The native inline ID is sufficient for this exact live CreateNewWindow transaction and the first actual window can be created through the restored translated-PPC stack. Preserve the full trace and review the next post-window/event-loop boundary before broadening the NewWindow predicate.

### CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_NATIVE_ERROR_PRESERVED

The ID conversion is structurally correct but not sufficient. The exact native error result becomes the next boundary; do not change its scalar or broaden payload adaptation.

### Predicate or reply-shape failure

Preserve the exact message and stop. The live geometry differs from the proven policy.

### Mach failure

Preserve the Mach return and stop. Do not infer server semantics.

## Current boundary

~~~text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
accepted pre-window compatibility stack         -> PASS
Dock bootstrap compatibility                    -> PASS
legacy live NewWindow on Lion                   -> 0x7394 / 0x73f8 / -304
standalone NewWindow ID-only policy             -> PASS
next step                                       -> one exact live 0x7394 -> 0x739a integration
~~~

No additional XNU change is indicated.
