# Process Manager CGS connection-transport passive trace experiment

> **Completed historical stage.** Do not execute the trace-v1 build/run phases below against current `main`. The completed result is `CGS_TRACE_NO_NEWCONNECTION_AFTER_SESSION_ADAPTER`. Current `main` has advanced the same trace implementation to build ID `dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v2` so it can observe the newly localized `SERVER_VERSION 0x7148 -> 0x71ac` boundary. The authoritative next procedure is `docs/process-manager-cgs-server-version-transport-trace-experiment.md`.


## Objective

Localize the first failure **after** the now-proven Lion session-bootstrap compatibility adapter without changing any CGS request or reply.

The completed registration integration reached all established compatibility layers and the new session-port bridge, but `GetProcessForPID` did not return. The important observed order was:

```text
SessionInit v5                                      -> PASS
legacy bootstrap_look_up("com.apple.windowserver.session")
Lion active-root lookup 0x194                      -> PASS
GetSessionPort 0x7151 -> 0x71b5                    -> PASS
returned session right                             -> live send right
session-bootstrap adapter                          -> PASS
GetProcessForPID M06_AFTER                         -> not reached
process exit status                                -> 1
new crash/core diagnostic                          -> none
protected hashes                                   -> unchanged
```

The prior runner labeled every `M05_BEFORE_GetProcessForPID` without `M06_AFTER` as `GETPROCESSFORPID_ABORT_OR_CRASH`. That label was too broad for this result: exit status 1 with no diagnostic is a clean early process exit, not evidence of a signal or crash. The original runner has been corrected for future use.

The next unresolved boundary is now between the successful returned session port and completion of Snow PPC CoreGraphics default-connection creation. Static audits previously showed two immediate downstream Mach transactions:

```text
DeathWatch              0x714c -> 0x71b0
__CGSNewConnectionPort  0x7469 -> 0x74cd
```

This experiment passively records whether those transactions are reached and their raw replies. It does not adapt either one.

## Corrected registration-path gate after the first Snow control

The first Snow Leopard Phase C run completed the subject successfully but the runner reported `RESULT: FAIL`. The returned control proves that the trace itself was behavior-preserving:

```text
SessionInit passthrough                         -> PASS
legacy com.apple.windowserver.session lookup    -> KERN_SUCCESS
NewConnection request                           -> 0x7469
NewConnection mach_msg                          -> KERN_SUCCESS
NewConnection reply                             -> 0x74cd, ID match
reply size                                      -> 0x3c
GetProcessForPID                                -> 0
postidentity CoreGraphics connection            -> nonzero
subject exit                                    -> 0
```

No `0x714c` DeathWatch request appeared in that registration run. That is consistent with the already-collected Snow PPC static evidence and exposes a control-harness overconstraint, not a platform failure:

```text
_CGSNewConnection
  -> _CGSServerPort
     -> _lookupServerPort(0, 0)
  -> __CGSNewConnectionPort

_CGSLookupServerPort
  -> __CGSSessionDeathWatchPort
  -> _lookupServerPort(0, 1)
  -> __CGSSessionDeathWatchPort
```

The default-connection registration path reaches `_CGSServerPort`, not the separate `_CGSLookupServerPort` validation helper. Therefore DeathWatch is **optional trace evidence** in this experiment and must not be a Phase C or Lion classification gate. The authoritative transport boundary for this registration path is `__CGSNewConnectionPort 0x7469 -> 0x74cd`.

Current `main` corrects both runners accordingly:

- Snow Phase C requires successful `0x7469 -> 0x74cd`, successful `GetProcessForPID`, and a nonzero postidentity connection record;
- Snow records `deathwatch_observed=YES/NO` without using it as a pass/fail condition;
- Lion records DeathWatch as optional corroboration if it happens;
- Lion classification now proceeds directly from the proven session-bootstrap adapter to whether `0x7469` is reached and how `0x74cd` returns.

The trace interposer itself is unchanged and remains build ID `dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v1`. The already-built PPC trace dylib with its accepted SHA may be reused. Pull current `main` and repeat **Phase C only**; no Phase B rebuild is required unless the artifact identity differs.

## Prepared tracing variant

Current runtime `main` adds a compile-time passive trace mode to the already-proven CoreServices SessionInit v5 interposer:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-coreservices-sessioninit-cgs-trace-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-cgs-connection-trace-control.sh
scripts/run-lion-ppc-process-manager-cgs-connection-trace.sh
```

The trace build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v1
```

The default non-trace build remains `dual-bootstrap-servercheckin-sessioninit-v5`.

The trace variant retains the same two interpose tuples and the same CoreServices behavior. Its only added behavior is logging when the existing `mach_msg` interposer sees request ID `0x714c` or `0x7469`. For each candidate it records:

- request ID and expected reply ID;
- header bits and observed header size;
- Mach options, send/receive sizes, remote/reply/receive ports;
- raw `mach_msg` return;
- reply bits, size, ID, and ID-match result;
- raw 32-bit reply words from offset `0x18` through the actual received reply size, capped at `0x44`.

The request and reply are passed through unchanged. No field is rewritten.

## Reused accepted artifacts

This stage reuses the already accepted registration-only subject, Security v1 interposer, and CGS session-bootstrap v1 interposer:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

Do not rebuild those artifacts merely for this trace if the previously accepted files and SHA sidecars are still available.

## Safety constraints

For this experiment:

- build only the new passive CoreServices trace interposer on Snow Leopard;
- require the Snow trace control before Lion;
- do not modify the accepted registration subject, Security adapter, or CGS session-bootstrap adapter;
- keep `LSDONOTABORTIFNOASN` unset;
- do not call `GetProcessPID`, `TransformProcessType`, `SetFrontProcess`, `CPSSetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`;
- do not create a window or run an event loop;
- do not adapt `0x714c`, `0x7469`, or `0x729e`;
- do not fabricate a CoreGraphics connection record;
- do not patch CoreGraphics, WindowServer, launchd, libSystem, Rosetta, private dyld, the Rosetta cache, or XNU;
- do not restart or signal WindowServer, coreservicesd, pbs, loginwindow, Dock, or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection;
- run the Lion trace exactly once before review.

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

## Phase B — build only the passive trace interposer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-coreservices-sessioninit-cgs-trace-on-snowleopard.sh
```

Require exactly:

```text
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.sha256
```

Require the info file to show:

- build ID `dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v1`;
- 32-bit PPC;
- exactly two PPC `__interpose` tuples;
- imports of `bootstrap_look_up2`, `mach_msg`, and `mig_get_reply_port`;
- the passive CGS trace markers.

If Phase B fails, stop and return the complete build output.

## Phase C — Snow Leopard passive trace control

Keep the previously accepted registration subject, Security v1 interposer, CGS session-bootstrap v1 interposer, and their SHA sidecars in the same directory, then run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cgs-connection-trace-control.sh
```

Require:

```text
RESULT: PASS
```

The control is a hard gate. It must prove that replacing the ordinary v5 CoreServices interposer with the trace build changes no behavior:

```text
SessionInit                            -> passthrough
legacy WindowServer session lookup    -> passthrough
NewConnection request 0x7469          -> observed
NewConnection reply 0x74cd            -> Mach success, ID match
GetProcessForPID                      -> returns 0
postidentity connection slot          -> nonzero
subject                               -> exits before later Process Manager APIs
```

`DeathWatch 0x714c/0x71b0` may be logged if some path calls `_CGSLookupServerPort`, but its absence is expected for the observed registration path through `_CGSServerPort` and is not a failure.

Preserve the complete Snow control; its `0x74cd` raw reply words are the positive-control oracle for the Lion trace.

If Phase C fails, stop and do not run Lion.

## Phase D — transfer exact artifacts

Transfer the new trace artifact and its sidecars:

```text
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.sha256
ppc-process-manager-cgs-connection-trace-snowleopard-control.log
```

Also ensure Lion still has the exact previously accepted files and SHA sidecars for:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

Do not rebuild any artifact on Lion.

## Phase E — repeat native safety gates

Use the validated syscall-295 kernel identity:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require its existing PASS.

Then run the established syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-cgs-connection-trace.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion passive trace

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cgs-connection-trace.sh
```

The runner enables the same compatibility modes as the failed integration:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
```

The only behavioral difference is passive logging around `mach_msg` requests `0x714c` and `0x7469`. The registration-path decision gate is `0x7469 -> 0x74cd`; `0x714c -> 0x71b0` is optional corroboration only.

Run Phase F once only.

## Phase G — return evidence

Return:

```text
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.sha256
ppc-process-manager-cgs-connection-trace-snowleopard-control.log
syscall295-probe-process-manager-cgs-connection-trace.log
lion-ppc-process-manager-cgs-connection-trace.log
lion-ppc-process-manager-cgs-connection-trace.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

## Result interpretation

### `CGS_TRACE_NO_NEWCONNECTION_AFTER_SESSION_ADAPTER`

The integrated process accepted the native session port but did not reach `__CGSNewConnectionPort`. Audit the local transition from `_CGSServerPort` back into `_CGSNewConnection`. Absence of DeathWatch is not evidence of failure on this registration path.

If optional DeathWatch evidence appears, preserve it, but do not use it to override the NewConnection classification.

### `CGS_TRACE_NEWCONNECTION_MACH_FAILURE`

The legacy client reaches `0x7469`, but the Mach transport itself fails. Preserve the raw Mach status; do not adapt the request until the cause is localized.

### `CGS_TRACE_NEWCONNECTION_REPLY_ID_MISMATCH`

The server replies on the connection-creation transaction but not with expected `0x74cd`. This becomes an exact wire/server-version boundary.

### `CGS_TRACE_NEWCONNECTION_REPLY_OBSERVED_CLEAN_EARLY_EXIT_RC1`

The session-bootstrap adapter passed and `__CGSNewConnectionPort` reaches the server and receives the expected reply ID, but the Snow PPC client exits during reply interpretation or immediate connection initialization. Compare the Snow/Lion raw reply words first. Do **not** infer compatibility from the reply ID alone and do not patch the connection record.

### `CGS_TRACE_CONNECTION_ESTABLISHED`

The passive trace unexpectedly allows the registration to complete with a nonzero connection record. Stop and review for an observation effect before proceeding to CPS/SetFrontProcess.

## Current boundary

```text
syscall 295                                      -> PASS
CoreServices / Security                         -> PASS
SessionUniverse InitConnection v5               -> PASS
standalone Lion session-port protocol            -> PASS
registration session-bootstrap adapter           -> PASS
GetProcessForPID after adapter                    -> clean early exit status 1
new diagnostic                                   -> none
protected hashes                                 -> unchanged
Snow registration DeathWatch                     -> not observed; optional on this path
Snow registration __CGSNewConnectionPort         -> 0x7469/0x74cd PASS
Lion integrated __CGSNewConnectionPort           -> not yet observed
next step                                        -> passive 0x7469/0x74cd Lion trace
```

No additional XNU change is indicated.


## Observed Lion Phase F result — no NewConnection after the proven session adapter

The corrected Snow control passed with the expected registration-path transport:

```text
__CGSNewConnectionPort request 0x7469            -> observed
mach_msg                                           -> KERN_SUCCESS
reply ID 0x74cd                                    -> matched
reply size                                         -> 0x3c
GetProcessForPID                                   -> 0
postidentity CoreGraphics connection               -> nonzero
DeathWatch                                         -> not observed, optional
RESULT                                             -> PASS
```

The corresponding Lion trace advanced through every established compatibility layer and through the complete session-bootstrap adapter:

```text
SessionInit v5                                     -> PASS
active-root lookup                                 -> PASS
GetSessionPort 0x7151/0x71b5                      -> PASS
returned session right                            -> live send right
session-bootstrap adapter                          -> ADAPTER_PASS
DeathWatch                                         -> not observed
__CGSNewConnectionPort 0x7469                     -> not observed
process exit status                               -> 1
new crash/core diagnostic                         -> none
protected hashes                                  -> unchanged
RESULT                                             -> CGS_TRACE_NO_NEWCONNECTION_AFTER_SESSION_ADAPTER
```

This is a real boundary result, not a runner defect. The restored Snow PPC client receives a valid Lion session port but stops inside the local server-port path before `__CGSNewConnectionPort` is called.

The already-collected Snow PPC disassembly identifies the immediate local helper:

```text
_CGSNewConnection
  -> _CGSServerPort
     -> _lookupServerPort(0, 0)
     -> _connectAndCheck(...)
     -> selected-port publication/cache
  -> __CGSNewConnectionPort
```

Therefore this transport-trace stage is complete. Do not broaden the `mach_msg` trace and do not adapt `0x7469`.

The authoritative next stage is:

```text
docs/process-manager-cgs-connect-and-check-audit.md
```

It is a read-only Snow/Lion CoreGraphics differential that exact-targets `_connectAndCheck`, its `_CGSServerPort` call sites, and the immediately adjacent lookup/NewConnection helpers to determine whether the internal helper ABI, Mach contract, reply semantics, or local output state evolved between Snow Leopard PPC and Lion native CoreGraphics.

Do not rerun the PPC subject until those two static reports are reviewed. No additional XNU change is indicated.
