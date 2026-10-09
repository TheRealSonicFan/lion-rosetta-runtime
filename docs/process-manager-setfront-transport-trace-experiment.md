# Process Manager postregistration SetFrontProcess transport trace experiment

## Objective

Dynamically observe the first SetFrontProcess transaction after the complete CPS registration repair has been proven live.

The immediately preceding postidentity validation now establishes, under the accepted Lion compatibility stack:

```text
CPS application registration              accepted
GetProcessForPID                           PASS
GetProcessPID                              exact PID round-trip PASS
TransformProcessType(...foreground...)     PASS
second registration call                  not observed
new diagnostic                            none
protected hashes                          unchanged
```

The previously completed static CPS/CGS audit already proved a later protocol difference:

```text
Snow PPC __CGSSetFrontProcess
  request                                 0x729e
  reply                                   0x7302
  send                                    0x30
  receive                                 0x2c

Lion native __CGSSetFrontProcess
  request                                 0x72a1
  reply                                   0x7305
  send                                    0x30
  receive                                 0x2c
```

That difference was formerly latent because translated PPC never had a valid default CoreGraphics connection. The default connection and application registration are now both restored, and GetProcessPID plus TransformProcessType have been revalidated after that repair. The active question is therefore whether the untranslated Snow PPC client now reaches its legacy 0x729e wire call on Lion and what Lion WindowServer returns.

This stage is passive with respect to SetFrontProcess. It does not rewrite 0x729e, synthesize 0x72a1, alter a reply ID, or change the public SetFrontProcess result.

## Prepared implementation

Current runtime main provides:

```text
tests/ppc-process-manager-postidentity-setfrontprocess.c
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c

scripts/build-ppc-process-manager-cps-registration-setfront-trace-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-setfront-transport-trace-control.sh
scripts/run-lion-ppc-process-manager-setfront-transport-trace.sh
```

The subject build ID is:

```text
cps-registration-setfront-trace-v1
```

The subject is deliberately built with the exact basename:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

because the accepted CPS registration adapter remains narrowly gated to that exact previously traced registration string. This experiment does not broaden the registration predicate.

The trace interposer build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-trace-v1
```

It still contains exactly two PPC interpose tuples:

```text
bootstrap_look_up2
mach_msg
```

and retains all accepted compatibility behavior:

```text
CoreServices bootstrap / ServerCheckin / SessionInit
CGS server-version normalization
CPS application-registration request/reply conversion
```

The only new behavior is passive recognition and logging of:

```text
legacy SetFrontProcess request/reply       0x729e / 0x7302
native Lion SetFrontProcess request/reply  0x72a1 / 0x7305
```

No SetFrontProcess request or reply is modified.

## Subject sequence

The subject performs exactly:

```text
GetProcessForPID(getpid())
GetProcessPID(returned PSN)
TransformProcessType(returned PSN, foreground)
SetFrontProcess(returned PSN)
exit
```

It does not call GetFrontProcess or GetCurrentProcess, create a window, or enter an event loop.

## Snow control

Snow runs every compatibility mode in passthrough mode.

The control must prove that the unchanged Snow PPC client reaches the known legacy wire transaction:

```text
request bits                            0x1513
request ID                              0x729e
mach_msg option                         0x3
send size                               0x30
receive size                            0x2c
Mach result                             0
reply ID                                0x7302
reply result word                       0
SetFrontProcess                         0
```

No native 0x72a1 request may appear on Snow.

## Lion observation

Lion enables the accepted compatibility stack exactly as in the successful registration/postidentity validation:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1
```

Before SetFrontProcess, the runner re-requires:

```text
session-port adapter                     PASS
server-version adapter                   PASS
NewConnection                            PASS
registration adapter                     PASS
registration error -304                  absent
GetProcessForPID                         PASS
GetProcessPID                            exact PID round-trip PASS
TransformProcessType                     PASS
second registration call                absent
```

The SetFrontProcess trace then records the unchanged legacy request envelope and the raw Mach/reply outcome.

The experiment intentionally does not require a particular public SetFrontProcess OSStatus on Lion. The point of this stage is to identify the exact transport result before any adapter is designed.

## Safety constraints

- keep LSDONOTABORTIFNOASN unset;
- build on Snow Leopard 10.6.8 only;
- require the Snow passthrough control before Lion;
- reuse the accepted Security and session-bootstrap interposers unchanged;
- do not modify the accepted CPS registration conversion policy;
- call public SetFrontProcess exactly once;
- do not call private CPSSetFrontProcess separately;
- do not call GetFrontProcess or GetCurrentProcess;
- do not create a window or enter an event loop;
- do not rewrite 0x729e to 0x72a1;
- do not rewrite 0x7305 to 0x7302;
- do not fabricate a server result, PSN, Mach right, or connection record;
- do not patch CoreGraphics, HIServices, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection;
- run the Lion phase exactly once before review.

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

## Phase B — build the subject and passive trace dylib on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-cps-registration-setfront-trace-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256

ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib.sha256
```

Require:

```text
subject build_id=cps-registration-setfront-trace-v1
subject required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
subject architecture=ppc7400
subject LC_LOAD_DYLINKER=/usr/oah/dyld
subject imports GetProcessForPID, GetProcessPID, TransformProcessType, SetFrontProcess

trace build_id=dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-trace-v1
trace architecture=ppc7400
trace __interpose size=0x10
trace contains CPS_SET_FRONT_PROCESS_LEGACY and CPS_SET_FRONT_PROCESS_LION markers
```

If Phase B fails, stop.

## Phase C — Snow Leopard positive control

Keep the accepted Security and CGS session-bootstrap interposers and sidecars beside the new subject/trace dylib.

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-setfront-transport-trace-control.sh
```

Require final:

```text
registration passthrough                         PASS
GetProcessForPID                                 PASS
GetProcessPID                                    exact PID round-trip PASS
TransformProcessType                             PASS
PM_POSTIDENTITY_MILESTONE:M11_BEFORE_SetFrontProcess
PM_POSTIDENTITY_MILESTONE:M12_AFTER_SetFrontProcess
PM_POSTIDENTITY_STATUS:SetFrontProcess=0
PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS

kind=CPS_SET_FRONT_PROCESS_LEGACY
id=0x0000729e expectedReply=0x00007302
option=0x00000003 send=0x00000030 recv=0x0000002c
kind=CPS_SET_FRONT_PROCESS_LEGACY kr=0
id=0x00007302 expected=0x00007302 idMatch=YES
off20=0x00000000

RESULT: PASS
```

Phase C is a hard gate. If it fails, do not run Lion.

## Phase D — transfer exact artifacts

Transfer:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256

ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib.sha256

ppc-process-manager-setfront-transport-trace-snowleopard-control.log
```

Reuse unchanged:

```text
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel identity and run the established native commpage probe.

Then preserve the syscall-295 probe as:

```text
syscall295-probe-process-manager-setfront-transport-trace.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion passive SetFrontProcess trace

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-setfront-transport-trace.sh
```

The runner must observe the exact legacy request envelope before any result is considered useful:

```text
kind=CPS_SET_FRONT_PROCESS_LEGACY
id=0x0000729e expectedReply=0x00007302
option=0x00000003 send=0x00000030 recv=0x0000002c
```

No CPS_SET_FRONT_PROCESS_LION request is expected because this stage contains no SetFrontProcess compatibility adapter.

If Mach transport succeeds and a legacy reply is logged, the runner ends with one of:

```text
RESULT: SETFRONT_TRACE_LEGACY_REPLY_OBSERVED_PUBLIC_ERROR
RESULT: SETFRONT_TRACE_LEGACY_REPLY_OBSERVED_PUBLIC_PASS
RESULT: SETFRONT_TRACE_LEGACY_REPLY_OBSERVED_NO_PUBLIC_RETURN
```

Any of those three is a completed passive observation and must be returned for review before another run.

Other result labels identify an earlier transport/envelope/diagnostic boundary and must also be returned unchanged.

Do not rerun Phase F before review.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib.sha256
ppc-process-manager-setfront-transport-trace-snowleopard-control.log
syscall295-probe-process-manager-setfront-transport-trace.log
lion-ppc-process-manager-setfront-transport-trace.log
lion-ppc-process-manager-setfront-transport-trace.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### Legacy request and expected 0x7302 reply observed

This dynamically proves that the repaired translated process now reaches the previously latent Snow PPC SetFrontProcess transaction on Lion. Review the raw reply result/NDR and public SetFrontProcess status against the static Lion-native 0x72a1/0x7305 contract.

Only after that review may an exact 0x729e -> 0x72a1 / 0x7305 -> 0x7302 copied-buffer policy proof be designed.

### Legacy Mach failure

The request reaches mach_msg but not a normal reply. Preserve the numeric Mach result and stop.

### Legacy request not observed

The active boundary is still local before __CGSSetFrontProcess despite the restored registration stack. Do not design a message-ID adapter.

### Native 0x72a1 request unexpectedly observed

Stop. The premise that the Snow PPC client is still emitting its legacy contract would be false for this run.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
__CGSNewConnectionPort 0x7469/0x74cd        -> PASS
CPS registration 0x7372 -> 0x73c1           -> accepted
GetProcessForPID                             -> PASS
GetProcessPID                               -> PASS
TransformProcessType                        -> PASS
next step                                   -> passive live SetFrontProcess transport trace
known static Snow/Lion wire difference       -> 0x729e/0x7302 vs 0x72a1/0x7305
SetFrontProcess adaptation                   -> not yet authorized
```

No additional XNU change is indicated.
