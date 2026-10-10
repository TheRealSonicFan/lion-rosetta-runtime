# Process Manager CreateNewWindow distributed-notifications integration experiment

## Objective

Merge the independently proven process-local distributed-notifications ingress/native-broker bridge into the already accepted Process Manager compatibility stack, then retry exactly one `CreateNewWindow` call on Lion.

The standalone PPC ingress proof is now complete:

```text
Snow Leopard 10.6.8 passthrough control        -> PASS
Lion 10.7.5 exact .2 interception              -> PASS
local process-only Mach service                -> PASS
legacy register request                         -> PASS
legacy behavior 1 -> public behavior 4          -> PASS
current-session immediate post                  -> PASS
native Lion public CF callback                  -> PASS
legacy callback envelope                        -> PASS
unchanged PPC callback handling                 -> PASS
legacy unregister                               -> PASS
native broker exit                              -> PASS
protected hashes                                -> unchanged
```

The Lion proof also showed the complete lifecycle with one lookup, three legacy Mach requests, one callback, zero broker rejects, broker exit 0, and subject exit 0.

This authorizes integration into the normal Process Manager test stack. It does **not** authorize a global `.2` service, a launchd modification, private XPC synthesis, or any broad notification compatibility mode.

## Important receive-side Mach-header observation

The static Snow audit proved that the client constructs its outgoing legacy message with sender-side `msgh_bits=0x1413` and `msgh_id=4`. The live PPC ingress proof observed the message at the local receive port as `msgh_bits=0x1111`, `msgh_id=4`.

The integration gate must therefore not incorrectly require receive-side `msgh_bits=0x1413`. The sender-side construction remains authoritative for the old client ABI, while the live receiver evidence is authoritative for what the process-local bridge actually receives. The integration continues to validate message ID, payload length/shape, callback port, decoded property list, and the exact translated lifecycle.

## Why the bridge must be merged into the CoreServices compatibility interposer

The accepted Process Manager CoreServices dylib already owns the process-local `bootstrap_look_up2` interpose tuple used for the CoreServices lookup compatibility path. The standalone distributed-notifications ingress dylib also interposes `bootstrap_look_up2`.

Loading both independent interposers would create an ambiguous duplicate replacement for the same imported function. This experiment therefore does **not** stack the two dylibs.

Current `main` instead:

- makes the proven distributed-notifications ingress implementation embeddable without its own `__interpose` tuple;
- compiles that implementation into a new combined Process Manager CoreServices compatibility dylib;
- keeps the existing two CoreServices interpose tuples only: `bootstrap_look_up2` and `mach_msg`;
- dispatches only the exact tuple
  `com.apple.distributed_notifications.2, pid=0, flags=8`
  into the proven ingress bridge;
- preserves the existing CoreServices/CGS/CPS lookup and Mach compatibility code unchanged for every other request;
- preserves Snow Leopard passthrough mode;
- uses the same native i386 broker and public Lion `CFNotificationCenter` backend already proven standalone;
- explicitly excludes the obsolete name-only distributed-notifications lookup adapter.

## Prepared files

Current `main` provides:

```text
scripts/build-ppc-process-manager-createwindow-distnotify-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
tests/ppc-distributed-notifications-ingress-interposer.c
docs/process-manager-createwindow-distributed-notifications-integration-experiment.md
```

The combined CoreServices build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-v1
```

The embedded ingress implementation remains:

```text
distributed-notifications-ppc-ingress-interposer-v2
```

The native broker remains:

```text
distributed-notifications-ppc-ingress-broker-v1
```

## Safety constraints

For this stage:

- reuse the accepted CreateNewWindow PPC subject unchanged;
- reuse the accepted Security and CGS compatibility dylibs unchanged;
- rebuild only the new combined CoreServices + distributed-notifications compatibility dylib on Snow Leopard;
- run the Snow control before Lion;
- on Lion build/reuse only the native i386 broker from the already-proven source;
- do not load the standalone distributed-notifications ingress dylib together with the combined CoreServices dylib;
- do not enable the obsolete `ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE`;
- intercept only `com.apple.distributed_notifications.2`, pid 0, flags 8;
- do not publish a system-wide `.2` service;
- do not call `bootstrap_register` or `bootstrap_check_in`;
- do not modify launchd or distnoted;
- do not synthesize private Lion XPC messages;
- do not enable all-session posting;
- do not accept `sux=true`;
- do not add suspend/session_reset support;
- call `CreateNewWindow` exactly once and dispose the returned window immediately;
- do not show/select/title the window and do not enter an event loop;
- do not patch HIToolbox, CoreGraphics, CoreFoundation, Foundation, libSystem, libxpc, Rosetta, dyld, shared caches, or XNU;
- perform exactly one Lion integration run before review.

## Phase A — update current main

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm the prepared files listed above exist.

On Lion, the XNU checkout may also be updated for documentation provenance, but no kernel rebuild or reboot is part of this experiment.

## Phase B — build the combined PPC compatibility dylib on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-createwindow-distnotify-integration-on-snowleopard.sh \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib
```

Require creation of:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.sha256
```

The build must prove:

```text
32-bit PPC-family Mach-O
combined build ID present
embedded ingress v2 build marker present
exactly two PPC interpose tuples / __interpose size 0x10
bootstrap_look_up2 import present
mach_msg import present
mig_get_reply_port import present
posix_spawn import present
pthread_create import present
_NSGetEnviron import present
exactly one supported socketpair import
no direct _environ import
obsolete name-only notification adapter marker absent
```

If Phase B fails, stop and return the complete build output.

## Phase C — Snow Leopard integrated passthrough control

Keep beside the new combined dylib the exact accepted artifacts from the CreateNewWindow Snow control:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-bootstrap-compat.dylib \
  ./ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256 \
  ./ppc-process-manager-createwindow-distnotify-integration-snowleopard-control.log
```

Require:

```text
distributed notification lookup mode=passthrough
distributed notification lookup result kr=0
no local ingress bridge started
no native broker started
all previous CoreServices/CGS/CPS compatibility paths remain passthrough
CreateNewWindow=0
nonzero WindowRef
DisposeWindow returned
M24_SUCCESS
RESULT: CREATENEWWINDOW_DISTNOTIFY_INTEGRATION_SNOW_CONTROL_PASS
RESULT: PASS
```

Phase C is a hard gate.

## Phase D — transfer exact PPC artifacts to Lion

Transfer the exact Snow-built combined dylib and its sidecars together with the Snow control log:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.sha256
ppc-process-manager-createwindow-distnotify-integration-snowleopard-control.log
```

Reuse the exact accepted PPC CreateNewWindow subject, Security dylib, and CGS dylib. Do not rebuild PPC artifacts on Lion.

Do **not** transfer or load the standalone distributed-notifications ingress dylib for this experiment.

## Phase E — build/reuse the native Lion broker and repeat safety gates

On Lion 10.7.5, build the native broker from current `main` if an exact current artifact is not already available:

```sh
/bin/bash ./scripts/build-lion-native-distributed-notifications-ppc-ingress-broker.sh \
  ./native-distributed-notifications-ppc-ingress-broker
```

Require its i386 architecture, build marker, and SHA-256 sidecar.

Repeat the established native commpage/syscall-295 safety gate and require the existing PASS result before the PPC run.

Set the already-established Lion kernel SHA only for the runner:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<your established Lion kernel SHA-256>'
```

## Phase F — exactly one Lion integrated CreateNewWindow run

First syntax-check the runner:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Require status 0 and no output.

Then run exactly once:

```sh
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-ppc-ingress-broker \
  ./native-distributed-notifications-ppc-ingress-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-distnotify-integration.log
```

The integration must retain every previously accepted Process Manager/CGS/CPS prerequisite and additionally prove:

```text
M20_BEFORE_CreateNewWindow reached
exact distributed-notifications .2/pid0/flags8 lookup observed
local service returned
native broker started
no ingress Mach reject
no IPC request/callback reject
no broker reject
CreateNewWindow returned
CreateNewWindow=0
WindowRef nonzero
DisposeWindow returned
M24_SUCCESS reached
broker result PASS
broker wait exit 0
protected hashes unchanged
no new diagnostic
subject exit 0
RESULT: CREATENEWWINDOW_DISTNOTIFY_INTEGRATION_PASS
```

If the real CreateNewWindow path produces an operation outside the proven one-register/one-post/one-unregister broker subset, the runner must stop with an integration-specific failure. Do not broaden the broker in the same run.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.sha256
ppc-process-manager-createwindow-distnotify-integration-snowleopard-control.log
syscall295-probe-process-manager-createwindow-distnotify-integration.log
lion-ppc-process-manager-createwindow-distnotify-integration.log
lion-ppc-process-manager-createwindow-distnotify-integration.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Decision gate

If Lion reports `CREATENEWWINDOW_DISTNOTIFY_INTEGRATION_PASS`, the previously identified distributed-notification boundary is closed in the real restored Process Manager path. The next stage may advance beyond immediate window creation/disposal to the next single Carbon window operation, still under the same process-local compatibility stack.

If CreateNewWindow still does not return, preserve the exact ingress/broker markers and crash diagnostics. Do not assume a WindowServer transport problem until the new first active boundary is identified.

If the broker rejects an operation or schema, return that evidence and perform only the narrow protocol analysis required by the rejected request. Do not broaden to suspend, session_reset, all-session, or sux handling without proof.

## Current boundary

```text
standalone native broker                         -> PASS
standalone PPC ingress/native broker             -> PASS
Snow .2 passthrough                              -> PASS
Lion exact .2 process-local bridge               -> PASS
legacy register/post/callback/unregister chain   -> PASS
global .2 service                                -> not used
private Lion XPC synthesis                       -> not used
combined Process Manager integration             -> prepared
CreateNewWindow retry                            -> next single live gate
XNU                                              -> unchanged
```

No additional XNU change is indicated.


## Observed Phase F result — ingress established, broker schema rejected

The returned integrated run does not support the literal runner label `CREATENEWWINDOW_DISTNOTIFY_INGRESS_NOT_ESTABLISHED`. The intact evidence shows that the exact `.2` lookup was intercepted, the process-local bridge was created, the native broker reached READY, and three legacy Mach requests crossed the ingress boundary. The local-service result line itself was corrupted by concurrent stderr interleaving with dyld output, which caused the old runner's exact-string gate to fail.

All three real legacy requests reached the broker and returned status 20. In the native broker, status 20 is `BROKER_REJECT_SCHEMA`; lifecycle counts remained `register=0 post=0 callback=0 unregister=0 rejects=3`. The subject then reached `M20_BEFORE_CreateNewWindow`, did not reach M21, emitted the known HIToolbox damage -4960 abort, exited 134, and left protected hashes unchanged.

The standalone proof broker still contains a proof-only notification-name predicate, so real HIToolbox/CoreServices request names cannot be accepted by that broker as written. The existing evidence does not establish whether name gating is the only schema difference.

Current `main` therefore fixes the runner's failure classification and advances to:

```text
docs/process-manager-createwindow-distributed-notifications-real-schema-audit.md
```

That audit captures the exact three real binary-property-list dictionaries without performing notification operations. Do not broaden the normal broker before the capture is reviewed.
