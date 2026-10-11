# Process Manager CreateNewWindow Dock server bootstrap protocol adapter experiment

## Objective

Prove, in isolation, whether Lion accepts the already established UUID-expanded launchd lookup request for the exact newly exposed CreateNewWindow service:

```text
com.apple.dock.server
```

The preceding exact-four distributed-notification registration experiment has closed the notification sequence as the immediate blocker. On Lion, all four reviewed registrations are accepted with zero rejects and the exact Snow Leopard HIToolbox `Extras.rsrc` fallback remains active, but the untouched Snow PPC `bootstrap_look_up` path then reaches:

```text
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=NON_TARGET ... name=com.apple.dock.server
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=-304 ... servicePort=0
PM_POSTIDENTITY_STATUS:CreateNewWindow=-304
RESULT: CREATENEWWINDOW_POST_EXTRAS_REGISTRATIONS_ESTABLISHED_DOCK_SERVER_MINUS304
```

The matching Snow Leopard CreateNewWindow controls resolve the same service through the ordinary legacy lookup with `kr=0` and a nonzero port, after which window creation succeeds.

This stage does **not** integrate another compatibility path into CreateNewWindow. It asks one smaller question first: does the exact Lion launchd request schema, already proved elsewhere in this project, resolve `com.apple.dock.server` successfully from the translated PPC process?

## Why another broad static bootstrap audit is not required

The project has already closed the generic Snow Leopard-to-Lion launchd lookup layout change from shipped binaries and live discriminators:

- Snow Leopard PPC uses request ID `0x194`, send size `0xac`, with target PID followed directly by the 64-bit flags field.
- Lion uses the same request family and reply contract but sends `0xbc`, inserting a 16-byte instance UUID before the flags.
- The expected reply ID remains `0x1f8` and the receive size remains `0x6c`.
- A standalone PPC Lion-format lookup has already succeeded for CoreServices.
- The later SecurityServer bootstrap experiment proved that ordinary Snow PPC `bootstrap_look_up` is affected by the same layout mismatch: the legacy call failed with `MIG_BAD_ARGUMENTS (-304)`, while the exact `0xbc` Lion-format request with PID 0, zero UUID, and flags 0 returned a valid SecurityServer port.

The current Dock failure has the same externally visible signature: ordinary `bootstrap_look_up`, `-304/MIG_BAD_ARGUMENTS`, and a zero service port. Therefore the unproven variable is now the exact service/namespace transaction, not the generic request layout.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-dockserver-bootstrap-protocol-adapter.c
scripts/build-ppc-process-manager-dockserver-bootstrap-protocol-adapter-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-dockserver-bootstrap-protocol-adapter-control.sh
scripts/run-lion-ppc-process-manager-dockserver-bootstrap-protocol-adapter.sh
docs/process-manager-createwindow-dockserver-bootstrap-protocol-adapter-experiment.md
```

The PPC subject has two explicit modes:

- `snow-control`: calls ordinary Snow Leopard `bootstrap_look_up(bootstrap_port, "com.apple.dock.server", &port)`, requires success and a nonzero port, deallocates it, and exits.
- `lion-adapter`: sends exactly one Lion-format launchd lookup request for `com.apple.dock.server`, validates the reply and the returned send right, deallocates it, and exits.

It does not call CreateNewWindow, HIToolbox, CoreGraphics window creation, Dock RPCs, Process Manager, or any notification API.

## Exact Lion request under test

The Lion transaction is fixed to:

```text
service       = com.apple.dock.server
request ID    = 0x00000194
send size     = 0x000000bc
receive size  = 0x0000006c
target PID    = 0
instance UUID = 00000000-0000-0000-0000-000000000000
flags         = 0x0000000000000000
reply ID      = 0x000001f8
```

Flags 0 are intentional: the failing call is ordinary `bootstrap_look_up`, not the privileged-server `bootstrap_look_up2(..., flags=8)` transaction used for the native Lion WindowServer active-root lookup.

## Safety constraints

For this stage:

- build the PPC subject only on Snow Leopard 10.6.8;
- run the Snow Leopard positive control first;
- transfer the exact hashed PPC artifact to Lion;
- repeat the established native commpage and syscall-295 safety gates on Lion;
- send exactly one Lion-format Dock service lookup request;
- do not run CreateNewWindow in this stage;
- do not load the existing Process Manager compatibility interposers;
- do not call any Dock service method after acquiring the port;
- do not register, restart, signal, suspend, or replace Dock or launchd;
- do not alter any launchd namespace or service registration;
- do not patch libSystem, liblaunch, CoreGraphics, HIToolbox, Dock, Rosetta, dyld, shared caches, or XNU;
- do not make the CGS bootstrap interposer recognize `com.apple.dock.server` yet;
- do not rerun the Lion adapter transaction before the first result is reviewed.

No XNU rebuild or reboot is part of this stage.

## Phase A — update current repositories

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

Confirm the five prepared files above exist.

## Phase B — build the PPC Dock bootstrap probe on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-dockserver-bootstrap-protocol-adapter-on-snowleopard.sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-dockserver-bootstrap-protocol-adapter-control.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-dockserver-bootstrap-protocol-adapter-on-snowleopard.sh
```

Expected artifacts:

```text
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld.sha256
```

Require:

- a thin 32-bit PowerPC Mach-O (known PPC32 subtype names such as `ppc7400` are valid);
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- imports for `bootstrap_look_up`, `bootstrap_port`, `mig_get_reply_port`, and `mach_msg`;
- an info sidecar and SHA-256 sidecar.

If the build or validation fails, stop and preserve the complete output.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-dockserver-bootstrap-protocol-adapter-control.sh
```

Require:

```text
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_LAYOUT:PASS
request_id=0x00000194
send_size=0x000000bc
recv_size=0x0000006c
flags=0x0000000000000000
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_SNOW_RETURN:kr=0 ... servicePort=nonzero
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

Phase C is a hard gate. If Snow does not resolve the exact service in this standalone subject, do not run Lion.

## Phase D — transfer the exact Snow-built artifacts to Lion

Transfer privately:

```text
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-dockserver-bootstrap-protocol-adapter-snowleopard-control.log
```

Place the executable and SHA sidecar under runtime `payload/`, or pass explicit paths to the Lion runner.

Do not rebuild the PPC subject on Lion.

## Phase E — repeat Lion native safety gates

Use the already validated kernel identity and repeat the established native commpage probe and syscall-295 routing probe. Preserve the syscall result under a Dock-specific filename such as:

```text
syscall295-probe-process-manager-dockserver-bootstrap-protocol-adapter.log
```

Require the existing syscall-295 result:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

Do not continue if either native safety gate fails.

## Phase F — exactly one Lion Dock bootstrap transaction

First syntax-check the runner:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-dockserver-bootstrap-protocol-adapter.sh
```

Then, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-dockserver-bootstrap-protocol-adapter.sh
```

The subject sends exactly one request described in the fixed schema above. A successful result requires:

```text
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_LAYOUT:PASS
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_MILESTONE:L00_BEFORE_LION_FORMAT_MACH_MSG
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_MACH_MSG_RETURN:kr=0
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_MILESTONE:L01_AFTER_LION_FORMAT_MACH_MSG
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_REPLY:... id=0x000001f8
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_COMPLEX_REPLY:descriptor_count=1 servicePort=nonzero
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_RIGHT:... send=YES
PM_DOCKSERVER_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_LOOKUP_PASS
RESULT: DOCKSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS
```

Stop after this one transaction. Do not immediately rerun CreateNewWindow even if it passes.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-dockserver-bootstrap-protocol-adapter-snowleopard-control.log
syscall295-probe-process-manager-dockserver-bootstrap-protocol-adapter.log
lion-ppc-process-manager-dockserver-bootstrap-protocol-adapter.log
lion-ppc-process-manager-dockserver-bootstrap-protocol-adapter.raw.log
```

Also return any new crash report or core diagnostic named by the Lion runner, if one is produced and available.

## Decision gate

### `DOCKSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS`

The exact Dock service lookup is another instance of the already proven Snow-Leopard-to-Lion launchd request-layout mismatch. The next stage may integrate **only** this exact service-name adaptation into the existing CGS bootstrap compatibility interposer and then perform one guarded CreateNewWindow rerun with the accepted four-registration notification broker and exact Snow `Extras.rsrc` fallback unchanged.

Do not integrate that change before this standalone result is reviewed.

### `ADAPTER_MIG_BAD_ARGUMENTS`

Lion still rejects the prepared `0xbc` request. Stop and reconcile the request/namespace assumptions before changing any interposer.

### `ADAPTER_SERVER_ERROR`

The request passed Mach transport but launchd returned a different server error. Preserve the exact code. A service/namespace selection difference, rather than request-layout rejection, becomes the immediate boundary.

### `ADAPTER_ZERO_PORT`, `ADAPTER_PORT_RIGHT_ERROR`, or reply-shape failure

Preserve the raw reply and stop. Do not treat a malformed or unusable right as successful resolution.

## Current boundary

```text
PPC execution / Rosetta                                  -> PASS
syscall 295                                              -> PASS
CoreServices / Security / CGS compatibility              -> PASS through current pre-window path
exact Snow HIToolbox Extras.rsrc fallback                -> PASS
four reviewed distributed-notification registrations     -> PASS, zero rejects
Snow com.apple.dock.server legacy lookup                 -> PASS, nonzero port
Lion translated-PPC com.apple.dock.server legacy lookup -> MIG_BAD_ARGUMENTS (-304), zero port
CreateNewWindow on Lion                                  -> returns -304
next step                                                -> isolated Dock lookup schema proof
```

No additional XNU change is indicated.
