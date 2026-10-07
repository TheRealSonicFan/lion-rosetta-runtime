# Process Manager SecurityServer bootstrap protocol adapter experiment

## Objective

Prove whether Lion accepts the already-binary-confirmed UUID-expanded launchd lookup request for the exact Security first-use service `com.apple.SecurityServer`.

The completed Security-session RPC discriminator has now localized the live Lion failure *before any legacy Security ucsp request is sent*:

```text
PM_SECURITY_SESSION_TRACE_BOOTSTRAP_REQUEST:... name=com.apple.SecurityServer
PM_SECURITY_SESSION_TRACE_BOOTSTRAP_REPLY:... kr=-304 ... servicePort=0
PM_SECURITY_SESSION_STATUS:SessionGetInfo=1
```

The exact Snow Leopard control obtains a nonzero SecurityServer port and then proceeds through `verifyPrivileged2`, `setup`, and `getSessionInfo(0x428)`.

Therefore the immediate failure is not yet `getSessionInfo`, setup, or privileged verification. It is the legacy Snow Leopard PPC `bootstrap_look_up` transaction itself.

## Why no new static bootstrap audit is required

The earlier Process Manager bootstrap investigation already preserved the necessary shipped-binary evidence:

- Snow Leopard PPC `vproc_mig_look_up2` sends request ID `0x194`, size `0xac`, with target PID followed directly by 64-bit flags;
- Lion's native client uses request ID `0x194`, size `0xbc`, with a 16-byte instance UUID inserted before the flags;
- the reply contract remains ID `0x1f8`, receive size `0x6c`;
- a standalone PPC Lion-format request with the added UUID field was already accepted by Lion for the coreservicesd service.

Public launchd source and the shipped client symbols also establish that `bootstrap_look_up(bp,name,sp)` funnels through the same lookup family with target PID 0 and flags 0.

The new Security trace returns the identical `MIG_BAD_ARGUMENTS` code at `bootstrap_look_up`, before any SecurityServer RPC exists to inspect. The remaining unproven case is therefore narrow: the same Lion request schema, but for `com.apple.SecurityServer` with flags 0.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-securityserver-bootstrap-protocol-adapter.c
scripts/build-ppc-process-manager-securityserver-bootstrap-protocol-adapter-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-securityserver-bootstrap-protocol-adapter-control.sh
scripts/run-lion-ppc-process-manager-securityserver-bootstrap-protocol-adapter.sh
docs/process-manager-securityserver-bootstrap-protocol-adapter-experiment.md
```

The PPC subject has two modes:

- `snow-control`: calls the ordinary Snow Leopard `bootstrap_look_up` for `com.apple.SecurityServer`;
- `lion-adapter`: sends exactly one binary-confirmed Lion-format `vproc_mig_look_up2` request for the same service, with target PID 0, zero instance UUID, and flags 0.

It never calls Security, `SessionGetInfo`, CarbonCore, LaunchServices process services, or Process Manager.

## Safety constraints

For this experiment:

- build the PPC subject only on Snow Leopard 10.6.8;
- run one Snow Leopard positive control before Lion;
- transfer the exact hashed PPC subject to Lion;
- repeat the established Lion native commpage and syscall-295 safety gates;
- perform exactly one Lion PPC adapter transaction before review;
- keep `SECURITYSERVER` unset;
- keep `DYLD_INSERT_LIBRARIES` unset;
- do not load the Security-session RPC tracer or CoreServices compatibility interposer;
- do not call `SessionGetInfo` or another SecuritySession API;
- do not send `verifyPrivileged2`, setup, setupThread, or `getSessionInfo`;
- do not restart, signal, suspend, or replace securityd or launchd;
- do not patch libSystem, launchd, Security, securityd, Rosetta, private dyld, the Rosetta cache, or XNU;
- do not use GDB, DTrace, dtruss, or live injection;
- do not rerun the Lion phase until the first result has been reviewed.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — build on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-securityserver-bootstrap-protocol-adapter-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld
ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld.sha256
```

Require:

- 32-bit PPC;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- imports for `bootstrap_look_up`, `bootstrap_port`, `mig_get_reply_port`, and `mach_msg`.

If the build fails, stop and return the complete build output.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-securityserver-bootstrap-protocol-adapter-control.sh
```

Require:

```text
PM_SECURITY_BOOTSTRAP_ADAPTER_LAYOUT:PASS
request_id=0x00000194
send_size=0x000000bc
recv_size=0x0000006c
flags=0x0000000000000000
PM_SECURITY_BOOTSTRAP_ADAPTER_SNOW_RETURN:kr=0 ... servicePort=nonzero
PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

This proves the exact PPC subject can resolve `com.apple.SecurityServer` through the ordinary Snow Leopard API before the Lion-format transaction is attempted.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld
ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-securityserver-bootstrap-protocol-adapter-snowleopard-control.log
```

Place the executable and SHA sidecar under runtime `payload/`, or pass explicit paths.

Do not rebuild the PPC subject on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel identity:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require its existing `RESULT: PASS`.

Then run the established syscall-295 probe and preserve it under a SecurityServer-bootstrap-specific filename, for example:

```text
syscall295-probe-process-manager-securityserver-bootstrap-protocol-adapter.log
```

Require the established EBADF/no-SIGSYS PASS.

Do not continue if either native safety gate fails.

## Phase F — one Lion SecurityServer bootstrap transaction

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-securityserver-bootstrap-protocol-adapter.sh
```

The prepared request is exactly:

```text
service = com.apple.SecurityServer
request ID = 0x194
send size = 0xbc
receive size = 0x6c
target PID = 0
instance UUID = all zero
flags = 0
```

The subject sends one such transaction and exits. It does not call Security afterward.

Do not rerun Phase F before review.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-securityserver-bootstrap-protocol-adapter-snowleopard-control.log
syscall295-probe-process-manager-securityserver-bootstrap-protocol-adapter.log
lion-ppc-process-manager-securityserver-bootstrap-protocol-adapter.log
lion-ppc-process-manager-securityserver-bootstrap-protocol-adapter.raw.log
```

Also return every new crash report or core listed by the Lion runner, if any.

## Result interpretation

### `SECURITYSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS`

Lion accepted the UUID-expanded PPC request and returned a nonzero SecurityServer service port.

This would directly establish that the current `SessionGetInfo=1` boundary is another manifestation of the already-proven Snow-Leopard-to-Lion launchd lookup schema change, now at Security's first-use bootstrap lookup.

Stop there.

The next stage would integrate only this exact SecurityServer bootstrap adaptation into the existing Security-only discriminator and then let the untouched Snow Leopard PPC Security client continue. That follow-on run would determine the next live boundary among `verifyPrivileged2`, setup/setupThread, and `getSessionInfo(0x428)`.

Do not build that integration before this standalone result is reviewed.

### `ADAPTER_MIG_BAD_ARGUMENTS`

Lion still rejects the prepared request at MIG validation.

Stop. Reconcile the exact flags/instance semantics and shipped native wrapper before broadening the request.

### `ADAPTER_SERVER_ERROR`

The request passed Mach transport but launchd returned another explicit server error.

Preserve the exact code; that becomes the immediate boundary.

### `ADAPTER_MACH_MSG_ERROR`

The transaction failed at Mach transport. Do not retry before review.

### reply-shape or zero-port failure

Preserve the raw reply and stop. Do not infer success from a zero port or malformed reply.

## Current boundary

The active sequence is now:

```text
PPC execution / Rosetta -> PASS
syscall 295 -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
CarbonCore FindService -> PASS
Security SessionGetInfo entry -> reached
SecurityServer bootstrap_look_up -> MIG_BAD_ARGUMENTS (-304)
legacy Security ucsp RPCs -> not reached on Lion
```

No additional XNU change is indicated.


## Observed result — Lion accepts the corrected SecurityServer lookup

The completed experiment ended with:

```text
RESULT: SECURITYSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS
```

The Snow Leopard positive control used the ordinary `bootstrap_look_up` path for `com.apple.SecurityServer` and returned a nonzero service port.

On Lion 10.7.5, the exact PPC subject sent the already-binary-confirmed Lion lookup form:

- request ID `0x194`;
- send size `0xbc`;
- receive size `0x6c`;
- target PID 0;
- zero 16-byte instance UUID;
- flags 0;
- service name `com.apple.SecurityServer`.

`mach_msg` returned success. Lion returned the expected complex `0x28` reply with reply ID `0x1f8`, descriptor count 1, and a nonzero SecurityServer service port.

No crash/core diagnostic was generated. The kernel, translator, private dyld, native Lion dyld, securityd, Rosetta cache, and PPC subject identities remained unchanged. The native syscall-295 probe also remained a clean EBADF/no-SIGSYS PASS.

This directly proves that the immediate Security first-use bootstrap failure is the same Snow-Leopard-to-Lion launchd request-layout mismatch already established elsewhere in the Process Manager work. It is no longer necessary to investigate the failing `bootstrap_look_up` itself.

The authoritative next stage is:

```text
docs/process-manager-security-session-bootstrap-compat-integration-experiment.md
```

That stage integrates only this proven SecurityServer bootstrap adaptation into the existing Security-only `SessionGetInfo` probe and passively traces the untouched Security ucsp requests that follow. It does not modify those requests.

Do not patch Security/securityd or make another XNU change before that post-bootstrap trace is reviewed.
