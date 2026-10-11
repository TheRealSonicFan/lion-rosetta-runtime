# Process Manager post-CreateNewWindow FontServer bootstrap protocol adapter experiment

## Objective

Resolve the first newly exposed boundary inside `SetWindowTitleWithCFString` without broadening the distributed-notification broker or changing any accepted CreateNewWindow compatibility path.

The Snow Leopard window-title control passed. Immediately after:

```text
PM_POSTWINDOWTITLE_MILESTONE:T02_BEFORE_SetWindowTitleWithCFString
```

Snow loaded `libFontRegistry.dylib`, performed the ordinary legacy lookup:

```text
bootstrap_look_up(..., "com.apple.FontServer", ...)
```

and obtained:

```text
kr=0
servicePort=nonzero
```

The title call then returned 0, CFRelease completed, DisposeWindow completed, and M24 succeeded.

The corresponding Lion run also reached T02, but the first changed operation was the same untouched Snow-PPC lookup:

```text
name=com.apple.FontServer
kr=-304
servicePort=0
```

This happened before the newly observed fifth distributed-notification request. Lion then repeatedly retried the FontServer lookup and CoreText reported invalid font-server IPC destinations. The fifth notification request was later rejected by the deliberately exact-four broker with status 25, but it is not the first divergence from the passing Snow control and is therefore not the next compatibility target.

This experiment asks one narrow question: does the already established Lion launchd lookup schema resolve the exact `com.apple.FontServer` service when sent from the translated PPC process?

## Why this is the next discriminator

The generic Snow Leopard-to-Lion launchd lookup layout change is already established elsewhere in the project:

```text
request ID        0x194
Snow send size    0xac
Lion send size    0xbc
Lion extra field  16-byte instance UUID
reply ID          0x1f8
receive size      0x6c
```

For ordinary `bootstrap_look_up`, the already accepted Lion-format request uses:

```text
target PID        0
instance UUID     all zero
flags             0
```

The Dock and SecurityServer standalone discriminators already proved that an untouched Snow-PPC ordinary lookup can fail with `MIG_BAD_ARGUMENTS (-304)` while the exact `0xbc` Lion-format request succeeds.

The current FontServer failure has the same transport signature, but the exact service/namespace transaction has not yet been tested. A standalone lookup proof is therefore narrower and more informative than either broadening the notification allowlist or integrating another bootstrap adapter directly into the window-title run.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-fontserver-bootstrap-protocol-adapter.c
scripts/build-ppc-process-manager-fontserver-bootstrap-protocol-adapter-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-fontserver-bootstrap-protocol-adapter-control.sh
scripts/run-lion-ppc-process-manager-fontserver-bootstrap-protocol-adapter.sh
docs/process-manager-post-createwindow-fontserver-bootstrap-protocol-adapter-experiment.md
```

The PPC subject has two modes:

- `snow-control`: ordinary `bootstrap_look_up(bootstrap_port, "com.apple.FontServer", &port)`, requiring success and a nonzero send right.
- `lion-adapter`: exactly one Lion-format launchd lookup request for `com.apple.FontServer`, validating the reply shape and returned send right.

It does not call `SetWindowTitleWithCFString`, CreateNewWindow, HIToolbox, CoreGraphics window APIs, FontServer RPC methods, or distributed-notification APIs.

## Exact Lion request under test

```text
service       = com.apple.FontServer
request ID    = 0x00000194
send size     = 0x000000bc
receive size  = 0x0000006c
target PID    = 0
instance UUID = 00000000-0000-0000-0000-000000000000
flags         = 0x0000000000000000
reply ID      = 0x000001f8
```

Do not change the service spelling or capitalization. The live failing request and passing Snow control both use exactly `com.apple.FontServer`.

## Safety constraints

- Build the PPC subject only on Snow Leopard 10.6.8.
- Run the Snow positive control first.
- Transfer the exact hashed PPC artifact to Lion; do not rebuild it on Lion.
- Repeat the established native commpage and syscall-295 safety gates.
- Keep `DYLD_INSERT_LIBRARIES` unset for the standalone FontServer test.
- Send exactly one Lion-format FontServer lookup request.
- Do not call a method on the returned FontServer port.
- Do not run the window-title subject in this stage.
- Do not broaden the exact-four distributed-notification broker.
- Do not capture/accept the fifth notification yet.
- Do not change the accepted NewWindow, release-backing, opacity create-alpha, Dock, HIToolbox, Process Manager, or notification compatibility paths.
- Do not restart, signal, register, or replace FontServer, WindowServer, Dock, launchd, or related jobs.
- Do not patch libSystem, liblaunch, CoreText, ATS, CoreGraphics, HIToolbox, Rosetta, dyld, shared caches, or XNU.
- Run the Lion adapter exactly once before review.
- No XNU rebuild or reboot.

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

## Phase B — build the standalone FontServer probe on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-fontserver-bootstrap-protocol-adapter-on-snowleopard.sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-fontserver-bootstrap-protocol-adapter-control.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-fontserver-bootstrap-protocol-adapter-on-snowleopard.sh
```

Expected artifacts:

```text
ppc-process-manager-fontserver-bootstrap-protocol-adapter-private-dyld
ppc-process-manager-fontserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-fontserver-bootstrap-protocol-adapter-private-dyld.sha256
```

Require a thin 32-bit PPC Mach-O, `LC_LOAD_DYLINKER=/usr/oah/dyld`, and imports for `bootstrap_look_up`, `bootstrap_port`, `mig_get_reply_port`, and `mach_msg`.

## Phase C — Snow Leopard positive control

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-fontserver-bootstrap-protocol-adapter-control.sh
```

Require:

```text
PM_FONTSERVER_BOOTSTRAP_ADAPTER_LAYOUT:PASS
request_id=0x00000194
send_size=0x000000bc
recv_size=0x0000006c
flags=0x0000000000000000
PM_FONTSERVER_BOOTSTRAP_ADAPTER_SNOW_RETURN:kr=0 ... servicePort=nonzero
PM_FONTSERVER_BOOTSTRAP_ADAPTER_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

If Snow cannot resolve `com.apple.FontServer`, stop. The integrated Snow evidence says it should resolve; a standalone failure would invalidate the test setup.

## Phase D — transfer exact artifacts to Lion

Transfer:

```text
payload/ppc-process-manager-fontserver-bootstrap-protocol-adapter-private-dyld
payload/ppc-process-manager-fontserver-bootstrap-protocol-adapter-private-dyld.info.txt
payload/ppc-process-manager-fontserver-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-fontserver-bootstrap-protocol-adapter-snowleopard-control.log
```

Do not rebuild the PPC subject on Lion.

## Phase E — repeat native Lion safety gates

Repeat the validated commpage probe and syscall-295 routing probe. Preserve the syscall output as:

```text
syscall295-probe-process-manager-fontserver-bootstrap-protocol-adapter.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion FontServer lookup

First syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-fontserver-bootstrap-protocol-adapter.sh
```

Then run:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-fontserver-bootstrap-protocol-adapter.sh
```

A protocol-layout success requires:

```text
PM_FONTSERVER_BOOTSTRAP_ADAPTER_LAYOUT:PASS
PM_FONTSERVER_BOOTSTRAP_ADAPTER_MILESTONE:L00_BEFORE_LION_FORMAT_MACH_MSG
PM_FONTSERVER_BOOTSTRAP_ADAPTER_MACH_MSG_RETURN:kr=0
PM_FONTSERVER_BOOTSTRAP_ADAPTER_MILESTONE:L01_AFTER_LION_FORMAT_MACH_MSG
PM_FONTSERVER_BOOTSTRAP_ADAPTER_REPLY:... id=0x000001f8
PM_FONTSERVER_BOOTSTRAP_ADAPTER_COMPLEX_REPLY:descriptor_count=1 servicePort=nonzero
PM_FONTSERVER_BOOTSTRAP_ADAPTER_RIGHT:... send=YES
PM_FONTSERVER_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_LOOKUP_PASS
RESULT: FONTSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS
```

Stop after the one lookup. Do not rerun SetWindowTitle in the same stage.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-fontserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-fontserver-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-fontserver-bootstrap-protocol-adapter-snowleopard-control.log
syscall295-probe-process-manager-fontserver-bootstrap-protocol-adapter.log
lion-ppc-process-manager-fontserver-bootstrap-protocol-adapter.log
lion-ppc-process-manager-fontserver-bootstrap-protocol-adapter.raw.log
```

Also return any new crash/core diagnostic explicitly named by the standalone Lion runner.

## Decision gate

### `FONTSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS`

The live `com.apple.FontServer -> -304` failure is another exact launchd request-layout mismatch. The next stage may integrate only this service-name adaptation into the existing bootstrap compatibility interposer and rerun the window-title validation once, keeping the exact-four notification broker unchanged. The fifth notification remains unreviewed and must not be accepted preemptively.

### `ADAPTER_MIG_BAD_ARGUMENTS`

The prepared Lion schema is still rejected. Reconcile the exact request layout before changing the live interposer.

### `ADAPTER_SERVER_ERROR`

Mach transport and request type were accepted but launchd returned a server error. Treat the exact code as evidence of a service/namespace difference on Lion rather than an automatic request-layout problem. Do not integrate an adapter.

### zero port, invalid right, or reply-shape failure

Preserve the raw reply and stop. A malformed or unusable right is not success.

## Current boundary

```text
PPC execution / Rosetta                                -> PASS
syscall 295                                            -> PASS
Process Manager / notification / HIToolbox / Dock      -> PASS through CreateNewWindow
NewWindow / release-backing / create-alpha             -> native Lion success
CreateNewWindow                                        -> 0, nonzero WindowRef
CFStringCreateWithCString                              -> PASS
Snow SetWindowTitle FontServer lookup                  -> kr=0, nonzero port
Lion SetWindowTitle FontServer legacy lookup           -> -304, zero port
fifth distributed notification on Lion                 -> later status-25 reject; secondary for this gate
SetWindowTitleWithCFString on Lion                     -> does not return
next step                                              -> isolated FontServer lookup schema proof
```

No additional XNU change is indicated.
