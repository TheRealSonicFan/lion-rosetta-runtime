# Process Manager GetCurrentProcess validation experiment

## Objective

Revisit the original translated-PPC Process Manager identity boundary only after the complete registration, CoreGraphics connection, foreground-selection, and public front-process state have been restored.

The immediately preceding validation now proves:

```text
CPS application registration              PASS
GetProcessForPID                          PASS
GetProcessPID                             exact PID round-trip PASS
TransformProcessType(...foreground...)     PASS
SetFrontProcess                           PASS
GetFrontProcess                           PASS
front PSN                                 exact match with current-process PSN
new diagnostic                            none
protected hashes                          unchanged
RESULT                                    GETFRONTPROCESS_VALIDATION_PASS
```

Earlier in the investigation, `GetCurrentProcess` was the first shell-launched Carbon boundary to self-request SIGABRT before returning. That observation predates every registration/session/CoreGraphics repair now active. This stage therefore retests `GetCurrentProcess` directly under the fully restored stack without adding any new compatibility behavior.

## Subject

Current runtime `main` adds:

```text
tests/ppc-process-manager-postidentity-getcurrentprocess.c
scripts/build-ppc-process-manager-getcurrentprocess-on-snowleopard.sh
```

The subject build ID is:

```text
cps-getcurrentprocess-validation-v1
```

The executable basename remains exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

That basename remains required because the accepted CPS registration adapter is deliberately predicate-gated to the exact previously traced application-registration string. This experiment does not broaden that predicate.

The subject performs exactly:

```text
GetProcessForPID(getpid())
GetProcessPID(returned PSN)
TransformProcessType(returned PSN, foreground)
SetFrontProcess(returned PSN)
GetFrontProcess(&frontPSN)
require frontPSN == returned PSN
GetCurrentProcess(&currentPSN)
require currentPSN == returned PSN
exit
```

It calls `GetCurrentProcess` exactly once, after every earlier public state check has succeeded.

## Compatibility stack

Reuse unchanged:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

The combined CoreServices compatibility build must remain:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-v1
```

No GetCurrentProcess-specific interposer, `mach_msg` rewrite, abort suppression, or PSN synthesis is part of this stage.

Snow uses passthrough for every compatibility mode. Lion uses the accepted modes unchanged:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1
ROSETTA_CPS_SETFRONT_COMPAT_MODE=lion-setfront-v1
```

## Success condition

Before `GetCurrentProcess`, require the entire accepted sequence:

```text
registration adapter                      PASS on Lion
GetProcessForPID                          PASS
GetProcessPID                             exact PID round-trip PASS
TransformProcessType                      PASS
SetFront adapter                          PASS on Lion
SetFrontProcess                           0
GetFrontProcess                           0
front PSN                                 exact match
no second registration call
no second SetFront compatibility call
```

Then require:

```text
GetCurrentProcess                         0
returned current PSN                      exact match with expected PSN
PM_POSTIDENTITY_RESULT:GETCURRENTPROCESS_MATCH_PASS
PM_POSTIDENTITY_MILESTONE:M19_SUCCESS
```

## Safety constraints

- build only the new PPC subject on Snow Leopard 10.6.8;
- reuse all accepted compatibility dylibs unchanged;
- require the Snow control before Lion;
- keep `LSDONOTABORTIFNOASN` unset;
- call `GetCurrentProcess` exactly once;
- do not interpose or suppress `abort` or `kill`;
- do not synthesize a ProcessSerialNumber;
- do not add a GetCurrentProcess-specific Mach-message adapter;
- do not broaden the CPS registration or SetFrontProcess predicates;
- do not create a window or enter an event loop;
- do not patch HIServices, LaunchServices, CoreGraphics, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer, coreservicesd, securityd, or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection;
- run Lion exactly once before review.

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

## Phase B — build the GetCurrentProcess subject on Snow Leopard

Build only the new subject:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-getcurrentprocess-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

Require:

```text
build_id=cps-getcurrentprocess-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
architecture=ppc7400
LC_LOAD_DYLINKER=/usr/oah/dyld
imports GetProcessForPID
imports GetProcessPID
imports TransformProcessType
imports SetFrontProcess
imports GetFrontProcess
imports GetCurrentProcess
```

If Phase B fails, stop.

## Phase C — Snow Leopard passthrough control

Keep the accepted compatibility dylibs and SHA sidecars beside the new subject.

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-getcurrentprocess-control.sh
```

Require final `RESULT: PASS` and:

```text
registration compatibility               passthrough
SetFront compatibility                   passthrough
GetProcessForPID                         PASS
GetProcessPID                            exact PID round-trip PASS
TransformProcessType                     PASS
SetFrontProcess                          0
GetFrontProcess                          0
front PSN                                match=YES
GetCurrentProcess                        0
current PSN                              match=YES
PM_POSTIDENTITY_RESULT:GETCURRENTPROCESS_MATCH_PASS
PM_POSTIDENTITY_MILESTONE:M19_SUCCESS
```

Phase C is a hard gate.

## Phase D — transfer the exact new subject to Lion

Transfer:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-getcurrentprocess-snowleopard-control.log
```

Reuse unchanged on Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Do not rebuild any compatibility dylib on Lion.

## Phase E — repeat Lion native safety gates

Run the established native commpage probe and preserve the syscall-295 result as:

```text
syscall295-probe-process-manager-getcurrentprocess-validation.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion GetCurrentProcess validation

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-getcurrentprocess-validation.sh
```

The desired result is:

```text
registration adapter                    PASS
GetProcessForPID                        PASS
GetProcessPID                           exact PID round-trip PASS
TransformProcessType                    PASS
SetFront adapter                        PASS
SetFrontProcess                         0
GetFrontProcess                         0
front PSN                               exact match
M16_GETFRONTPROCESS_SUCCESS             reached
M17_BEFORE_GetCurrentProcess            reached
M18_AFTER_GetCurrentProcess             reached
GetCurrentProcess                       0
current PSN                             exact match
GETCURRENTPROCESS_MATCH_PASS            reached
M19_SUCCESS                             reached
new diagnostic                          none
protected hashes                        unchanged

RESULT: GETCURRENTPROCESS_VALIDATION_PASS
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-getcurrentprocess-snowleopard-control.log
syscall295-probe-process-manager-getcurrentprocess-validation.log
lion-ppc-process-manager-getcurrentprocess-validation.log
lion-ppc-process-manager-getcurrentprocess-validation.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `GETCURRENTPROCESS_VALIDATION_PASS`

The original GetCurrentProcess boundary is no longer present under the restored registration/foreground stack: the public API returns the same exact PSN already proven by PID identity and front-process state. This closes the historic Process Manager identity abort for this controlled sequence.

Do not automatically broaden any adapter. Review the result before moving to window creation or an event loop.

### `GETCURRENTPROCESS_NO_RETURN`

The historic no-return boundary remains active even after registration and foreground state are restored. Preserve the new crash/core evidence and stop; do not suppress the abort.

### `GETCURRENTPROCESS_RETURNED_ERROR`

The API now returns normally but still exposes a semantic boundary. Preserve the exact OSStatus and stop.

### `GETCURRENTPROCESS_PSN_MISMATCH`

The API returns success but identifies a different process. Preserve both PSNs and stop; do not synthesize a match.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
default CoreGraphics connection             -> established
CPS registration                            -> accepted
GetProcessPID                               -> PASS
TransformProcessType                        -> PASS
SetFrontProcess integration                 -> PASS
GetFrontProcess                             -> PASS
next step                                   -> retest historic GetCurrentProcess boundary
window creation / event loop                -> held until this gate is reviewed
```

No additional XNU change is indicated.
