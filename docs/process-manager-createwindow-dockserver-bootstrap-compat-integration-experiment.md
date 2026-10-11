# Process Manager CreateNewWindow Dock-server bootstrap compatibility integration

## Objective

Integrate only the now-proven `com.apple.dock.server` launchd request-layout adaptation into the existing process-local CGS bootstrap compatibility interposer, then perform one guarded CreateNewWindow run with every previously accepted component held constant.

The standalone Dock bootstrap discriminator is complete:

- Snow Leopard 10.6.8 resolved `com.apple.dock.server` through the ordinary PPC `bootstrap_look_up` path with `kr=0` and a nonzero service port.
- Lion 10.7.5 accepted the already-established UUID-expanded request: ID `0x194`, size `0xbc`, target PID 0, zero instance UUID, flags 0.
- Lion returned the expected complex `0x28` reply with ID `0x1f8`, one nonzero service-port descriptor, and a valid send right.
- No new crash/core diagnostic appeared, protected identities remained unchanged, and syscall 295 remained a clean EBADF/no-SIGSYS PASS.

Therefore the prior CreateNewWindow `-304` at `com.apple.dock.server` is no longer an unproven protocol hypothesis. The smallest next experiment is to replace only that exact lookup inside the already accepted CGS bootstrap interposer.

## Scope of the prepared change

Current runtime `main` extends:

```text
tests/ppc-process-manager-cgs-session-bootstrap-compat-interposer.c
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

and adds:

```text
scripts/build-ppc-process-manager-cgs-dockserver-bootstrap-compat-on-snowleopard.sh
docs/process-manager-createwindow-dockserver-bootstrap-compat-integration-experiment.md
```

The source retains the historical v1 build when compiled normally. The new builder opts into:

```text
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT=1
```

and produces build ID:

```text
cgs-session-bootstrap-dockserver-compat-v2
```

The existing `com.apple.windowserver.session` adaptation is unchanged. The v2 build adds one exact second predicate:

```text
service name = com.apple.dock.server
mode         = lion-dockserver-v1
request ID   = 0x194
send size    = 0xbc
receive size = 0x6c
target PID   = 0
instance UUID= all zero
flags        = 0
reply ID     = 0x1f8
```

Every other `bootstrap_look_up` name still uses the original function.

The new Dock path returns only the real send right supplied by Lion launchd. It does not fabricate a Mach port, register a launchd service, or issue any Dock RPC itself.

## Safety constraints

For this stage:

- rebuild only the Dock-aware CGS bootstrap interposer on Snow Leopard;
- do not rebuild the PPC CreateNewWindow subject;
- do not rebuild the accepted combined CoreServices/CPS/distributed-notifications interposer;
- do not rebuild the accepted Security interposer;
- reuse the exact four-registration native i386 broker already accepted on Lion;
- reuse the exact Snow Leopard HIToolbox `Extras.rsrc` and its established SHA-256 unchanged;
- run a full Snow Leopard CreateNewWindow control with the v2 interposer in Dock passthrough mode before any Lion integration;
- on Lion enable the Dock adapter only for `com.apple.dock.server`;
- preserve the existing `com.apple.windowserver.session` native-session-port adaptation unchanged;
- do not broaden the Dock predicate to another service name, target PID, UUID, or flags value;
- do not call any new private Dock RPC directly;
- do not patch launchd, Dock, CoreGraphics, HIToolbox, CoreFoundation, Rosetta, dyld, shared caches, or XNU;
- do not modify notification policy beyond the four already reviewed names;
- perform exactly one Lion CreateNewWindow integration run before review.

No XNU rebuild or reboot is part of this stage.

## Phase A — update current main

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

Confirm the new builder and this document are present.

## Artifact/result identity hard gate

This integration experiment is **not** the earlier standalone Dock bootstrap protocol-adapter experiment. Before continuing, verify that you are using the integration artifacts and runners from this document.

The following filenames belong to the completed standalone proof and are **not** evidence for this integration stage:

```text
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-dockserver-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-dockserver-bootstrap-protocol-adapter-snowleopard-control.log
lion-ppc-process-manager-dockserver-bootstrap-protocol-adapter.log
lion-ppc-process-manager-dockserver-bootstrap-protocol-adapter.raw.log
RESULT: DOCKSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS
```

If Phase F produces `RESULT: DOCKSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS`, stop: the standalone adapter was rerun and the CreateNewWindow integration has **not** been executed. Do not advance the investigation from that result.

This integration stage must instead build and use:

```text
ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib
ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256
```

and its Lion report must be named distinctly, for example:

```text
lion-ppc-process-manager-createwindow-dockserver-bootstrap-compat.log
lion-ppc-process-manager-createwindow-dockserver-bootstrap-compat.raw.log
```

## Phase B — build only the Dock-aware CGS interposer on Snow Leopard

Syntax-check:

```sh
/bin/bash -n ./scripts/build-ppc-process-manager-cgs-dockserver-bootstrap-compat-on-snowleopard.sh
```

Build:

```sh
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-cgs-dockserver-bootstrap-compat-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib
```

Require:

```text
32-bit PPC Mach-O dylib
exactly one __interpose tuple
build_id=cgs-session-bootstrap-dockserver-compat-v2
com.apple.windowserver.session
com.apple.windowserver.active
com.apple.dock.server
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_REQUEST
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS
SHA-256 sidecar
info sidecar
```

Do not rebuild the PPC subject or the other accepted PPC compatibility dylibs.

## Phase C — full Snow Leopard CreateNewWindow passthrough control

Use the accepted PPC subject, CoreServices/CPS/distributed-notifications compatibility dylib, Security compatibility dylib, exact Snow `Extras.rsrc` compatibility dylib, and staged resource unchanged. Replace only the CGS interposer argument with the new v2 artifact.

Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
```

Syntax-check:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Run the established Snow control with these CGS arguments:

```text
./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib
./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256
```

and use a new report such as:

```text
ppc-process-manager-createwindow-dockserver-bootstrap-compat-snowleopard-control.log
```

Require all existing CreateNewWindow control gates plus:

```text
PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:cgs-session-bootstrap-dockserver-compat-v2
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_CALL:index=1 mode=passthrough ... name=com.apple.dock.server
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=DOCK_SNOW_PASSTHROUGH ... name=com.apple.dock.server
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=0 ... servicePort=nonzero
no PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS
PM_POSTIDENTITY_STATUS:CreateNewWindow=0
nonzero WindowRef
M23_AFTER_DisposeWindow
M24_SUCCESS
RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_SNOW_CONTROL_PASS
RESULT: PASS
```

Phase C is a hard gate. If Snow fails, stop and return that report before running Lion.

## Phase D — transfer only the new CGS artifact to Lion

Transfer privately:

```text
ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib
ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256
ppc-process-manager-createwindow-dockserver-bootstrap-compat-snowleopard-control.log
```

Place the dylib and sidecars under the Lion runtime checkout or `payload/` as appropriate.

Do not rebuild the PPC dylib on Lion.

## Phase E — repeat the syscall-295 safety gate on Lion

Repeat the established native routing probe and preserve it under:

```text
syscall295-probe-process-manager-createwindow-dockserver-bootstrap-compat.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

Stop if the kernel identity or routing result changed.

## Phase F — exactly one Lion CreateNewWindow run with Dock adaptation

Do not enable the obsolete CFBundle trace and do not enable either notification schema-audit report.

Set:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<established Lion mach_kernel SHA-256>'

unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT

export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1

export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

Syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Run the CreateNewWindow integration runner itself, **not** the standalone Dock protocol-adapter runner. From the runtime repository root, an explicit invocation using the established artifact names is:

```sh
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-dockserver-bootstrap-compat.log
```

If your accepted artifacts live at different paths, substitute only those paths; keep the argument order unchanged. The seventh and eighth arguments must be the new v2 Dock-aware CGS interposer and its SHA sidecar. The ninth and tenth arguments must remain the exact-four native broker and its SHA sidecar.

A correct Phase F report begins with the restored-stack CreateNewWindow integration heading and includes the v2 CGS build marker. It must **not** begin with `== Lion PPC DockServer bootstrap protocol adapter ==`.

Use the fresh report path:

```text
payload/lion-ppc-process-manager-createwindow-dockserver-bootstrap-compat.log
```

The Dock adapter must show:

```text
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_CALL:index=1 mode=lion-dockserver-v1 ... name=com.apple.dock.server
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_REQUEST:... name=com.apple.dock.server id=0x00000194 send=0x000000bc recv=0x0000006c pid=0 uuid=ZERO flags=0x0000000000000000
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MACH_RETURN:kr=0
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_REPLY:... id=0x000001f8
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_COMPLEX_REPLY:descriptor_count=1 servicePort=nonzero
PM_CGS_SESSION_BOOTSTRAP_COMPAT_RIGHT:... send=YES
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_ADAPTER_RETURN:index=1 kr=0 ... servicePort=nonzero
PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS
```

The previously accepted gates must remain true:

```text
PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS
four exact distributed-notification registrations
zero notification rejects
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
mode=lion-fallback-external-v1 original=NULL fallback=NONNULL
protected_hashes_unchanged=YES
```

Do not broaden any policy if a new downstream boundary appears.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256
ppc-process-manager-createwindow-dockserver-bootstrap-compat-snowleopard-control.log
syscall295-probe-process-manager-createwindow-dockserver-bootstrap-compat.log
lion-ppc-process-manager-createwindow-dockserver-bootstrap-compat.log
lion-ppc-process-manager-createwindow-dockserver-bootstrap-compat.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if one is produced and available.

Do not return or upload the proprietary `SnowLeopard-HIToolbox-Extras.rsrc`.

Stop after Phase G.

## Decision gate

### `CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_PASS`

The exact Dock bootstrap adaptation worked in the restored stack and CreateNewWindow completed successfully through a nonzero `WindowRef`, `DisposeWindow`, and `M24_SUCCESS`. This would close the current CreateNewWindow compatibility chain. The next investigation should then advance beyond window construction rather than add more bootstrap or notification compatibility.

### `CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_ADAPTER_PASS_CREATEWINDOW_ERROR`

The Dock lookup itself is fixed, but CreateNewWindow returned another explicit error. Preserve the complete raw log and stop; the first post-Dock error becomes the next boundary.

### `CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_PASS_NO_RETURN`

The Dock lookup succeeded but CreateNewWindow did not return. Preserve diagnostics and stop before another run.

### `CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_ADAPTER_FAILED`

The integrated lookup did not reproduce the standalone proof. Stop and compare the exact request/reply markers and bootstrap port against the standalone adapter result.

### notification protocol rejection

If a fifth or otherwise unreviewed notification appears, preserve that exact request and stop. Do not broaden the four-name allowlist in the same run.

## Observed completed result — Dock adaptation accepted, CGS NewWindow is next

The guarded integration returned:

```text
RESULT: CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_ADAPTER_PASS_CREATEWINDOW_ERROR
```

The v2 interposer reproduced the standalone Dock proof in the real CreateNewWindow stack: the exact `com.apple.dock.server` Lion-format request completed with Mach success, reply ID `0x1f8`, one nonzero service-port descriptor, a valid send right, and `PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS`. The four reviewed distributed-notification registrations remained exact with zero rejects, the native broker passed, and the exact Snow HIToolbox `Extras.rsrc` fallback remained active.

The first error after those accepted gates is now explicit:

```text
MIG: server type check failure: CGSNewWindowWithOpaqueShape: Cannot create window
CreateNewWindow=-304
WindowRef=NULL
```

No new crash/core diagnostic appeared and protected hashes remained unchanged. This closes the Dock bootstrap boundary. Do not broaden bootstrap or notification compatibility further.

The authoritative next procedure is:

```text
docs/process-manager-createwindow-cgs-newwindow-protocol-audit.md
```

That stage is a static Snow-PPC versus Lion-i386 CoreGraphics differential for the exact NewWindow wrapper/transport helpers. It does not run CreateNewWindow and does not introduce a NewWindow adapter.

## Current boundary

```text
PPC execution / Rosetta                                      -> PASS
syscall 295                                                  -> PASS
CoreServices / Security / CGS pre-window compatibility       -> PASS
exact Snow HIToolbox Extras.rsrc fallback                    -> PASS
four reviewed distributed-notification registrations         -> PASS
Snow com.apple.dock.server ordinary lookup                   -> PASS
standalone Lion-format com.apple.dock.server lookup          -> PASS, valid send right
integrated Lion CreateNewWindow Dock lookup                   -> PASS, valid send right
CreateNewWindow                                              -> -304 / NULL WindowRef
CGSNewWindowWithOpaqueShape                                  -> MIG server type-check failure
next step                                                     -> static Snow-PPC vs Lion-i386 NewWindow protocol differential
```

No additional XNU change is indicated.
