# Distributed notifications bootstrap compatibility protocol experiment

## Objective

Isolate the first failure reached by restored translated-PPC Carbon window creation and test the smallest already-understood bootstrap protocol correction without rerunning `CreateNewWindow`.

The completed restored-stack window test now proves that all Process Manager prerequisites succeed on Lion through:

```text
CPS registration                          PASS
GetProcessForPID                          PASS
GetProcessPID                             exact PID round-trip PASS
TransformProcessType                      PASS
SetFrontProcess                           PASS
GetFrontProcess                           exact PSN match
GetCurrentProcess                         exact PSN match
```

Immediately after `M20_BEFORE_CreateNewWindow`, the unchanged Snow PPC client performs:

```text
bootstrap_look_up2
name=com.apple.distributed_notifications.2
pid=0
flags=8
```

Snow Leopard returns success and a nonzero service port. Lion, with the same legacy PPC lookup left as a non-target passthrough, returns `-304` and a null port. HIToolbox then reports that it cannot copy its framework resource URL, reports damage error `-4960` with TTheme instance 0, and aborts before `CreateNewWindow` returns.

The crash is therefore downstream of a concrete bootstrap lookup failure, not a regression in the now-restored Process Manager identity or SetFrontProcess path.

The existing CoreServices compatibility interposer already contains a generic, proven Lion launchd lookup formatter for request/reply `0x194/0x1f8`. It is currently restricted to the exact `com.apple.CoreServices.coreservicesd` lookup. This experiment tests that same formatter against exactly one additional service name in a standalone probe.

It does not modify HIToolbox, does not call `CreateNewWindow`, and does not integrate a new production predicate yet.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-distributed-notifications-bootstrap-probe.c
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c

scripts/build-ppc-distributed-notifications-bootstrap-compat-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-distributed-notifications-bootstrap-compat-protocol-control.sh
scripts/run-lion-ppc-distributed-notifications-bootstrap-compat-protocol.sh
```

Probe build ID:

```text
distributed-notifications-bootstrap-probe-v1
```

Protocol interposer build ID:

```text
distributed-notifications-bootstrap-compat-protocol-v1
```

The interposer still contains exactly two PPC interpose tuples:

```text
bootstrap_look_up2
mach_msg
```

## Exact target

Only this tuple is eligible:

```text
service name                            com.apple.distributed_notifications.2
target pid                              0
flags                                   0x0000000000000008
call count                              1
```

Snow mode is strict passthrough.

Lion proof mode uses the already-established Lion launchd lookup wire contract:

```text
request ID                              0x194
reply ID                                0x1f8
send size                               0xbc
receive size                            0x6c
pid                                     0
uuid                                    all zero
flags                                   8
```

The proof requires a successful lookup, a nonzero returned service port, and a live send right. The right is deallocated immediately.

No distributed-notification message is sent to the returned service.

## Safety constraints

- build on Snow Leopard 10.6.8;
- require the Snow passthrough control before Lion;
- run from the logged-in Aqua console user on Lion;
- keep `LSDONOTABORTIFNOASN` unset;
- do not run `CreateNewWindow` in this stage;
- do not modify the accepted Process Manager / CGS / registration compatibility dylib;
- do not broaden the existing CoreServices lookup target in the normal integration build;
- do not send a notification to the returned service port;
- do not fabricate a Mach right or launchd reply;
- do not patch HIToolbox, Foundation, CoreFoundation, launchd, Rosetta, dyld, libSystem, the Rosetta cache, or XNU;
- do not restart or signal launchd, distnoted, WindowServer, coreservicesd, or securityd;
- do not use GDB, DTrace, dtruss, or live injection;
- perform exactly one Lion proof before review.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU documentation checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — build the standalone probe and protocol interposer on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-distributed-notifications-bootstrap-compat-protocol-on-snowleopard.sh
```

Expected outputs:

```text
ppc-distributed-notifications-bootstrap-probe-private-dyld
ppc-distributed-notifications-bootstrap-probe-private-dyld.info.txt
ppc-distributed-notifications-bootstrap-probe-private-dyld.sha256

ppc-distributed-notifications-bootstrap-compat-protocol.dylib
ppc-distributed-notifications-bootstrap-compat-protocol.dylib.info.txt
ppc-distributed-notifications-bootstrap-compat-protocol.dylib.sha256
```

Require:

```text
probe architecture                       ppc7400
probe LC_LOAD_DYLINKER                   /usr/oah/dyld
probe imports                            bootstrap_look_up2
protocol architecture                    ppc7400
protocol build ID                        distributed-notifications-bootstrap-compat-protocol-v1
protocol __interpose size                0x10
exact service-name markers               present
adapter-request/result markers           present
```

If Phase B fails, stop.

## Phase C — Snow Leopard passthrough control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-distributed-notifications-bootstrap-compat-protocol-control.sh
```

Require:

```text
mode                                    passthrough
exact service name                      com.apple.distributed_notifications.2
pid                                     0
flags                                   8
passthrough return                      0
service port                            nonzero
port has send right                     YES
probe result                            PASS
adapter-pass marker                     absent
RESULT                                  PASS
```

Phase C is a hard gate.

## Phase D — transfer exact artifacts to Lion

Transfer the six probe/interposer files from Phase B and:

```text
ppc-distributed-notifications-bootstrap-compat-protocol-snowleopard-control.log
```

Do not rebuild them on Lion.

## Phase E — repeat the Lion syscall-295 safety gate

Run the established native syscall-295 probe and preserve it as:

```text
syscall295-probe-distributed-notifications-bootstrap-compat-protocol.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion standalone lookup proof

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-distributed-notifications-bootstrap-compat-protocol.sh
```

Desired result:

```text
exact target                            YES
mode                                    lion-lookup-v1
Lion lookup request ID                  0x194
send / receive                          0xbc / 0x6c
pid / uuid / flags                      0 / zero / 8
Mach result                             0
lookup result                           PASS
service port                            nonzero
port has send right                     YES
protected hashes                        unchanged

RESULT: DISTRIBUTED_NOTIFICATIONS_COMPAT_POLICY_PROOF_PASS
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-distributed-notifications-bootstrap-probe-private-dyld.info.txt
ppc-distributed-notifications-bootstrap-probe-private-dyld.sha256
ppc-distributed-notifications-bootstrap-compat-protocol.dylib.info.txt
ppc-distributed-notifications-bootstrap-compat-protocol.dylib.sha256
ppc-distributed-notifications-bootstrap-compat-protocol-snowleopard-control.log
syscall295-probe-distributed-notifications-bootstrap-compat-protocol.log
lion-ppc-distributed-notifications-bootstrap-compat-protocol.log
lion-ppc-distributed-notifications-bootstrap-compat-protocol.raw.log
```

Stop after Phase G.

## Result interpretation

### `DISTRIBUTED_NOTIFICATIONS_COMPAT_POLICY_PROOF_PASS`

Lion still publishes the exact Snow-era distributed-notifications service in the current Aqua bootstrap namespace, and the failure seen under `CreateNewWindow` is the already-known PPC-to-Lion launchd lookup protocol mismatch. The next stage may integrate this one exact service tuple into the normal CoreServices compatibility build and rerun the restored-stack `CreateNewWindow` test.

### `DISTRIBUTED_NOTIFICATIONS_COMPAT_ADAPTER_FAILED`

Do not integrate anything. Preserve the exact native-format launchd reply/result and audit the Lion service identity/namespace before another live lookup.

### Predicate or provenance failure

Stop and correct the proof setup. Do not broaden the target.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
CPS registration                            -> accepted
SetFrontProcess                             -> PASS
GetFrontProcess                             -> PASS
GetCurrentProcess                           -> PASS
CreateNewWindow                             -> aborts before return
immediate observed failure                  -> legacy bootstrap_look_up2("com.apple.distributed_notifications.2") returns -304
Snow exact lookup                           -> success / live send right
next step                                   -> standalone Lion-format lookup proof for this exact service
```

No additional XNU change is indicated.
