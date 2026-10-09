# Process Manager CGS server-version passive trace experiment

> **Completed historical stage.** The returned trace-v2 result is `CGS_TRACE_SERVER_VERSION_REPLY_OBSERVED_CLEAN_EARLY_EXIT_RC1`, and the Snow/Lion reply differential confirms server-version skew. The subsequent standalone normalization proof also passed. Do not rerun this trace. The authoritative next procedure is `docs/process-manager-cgs-server-version-compat-integration-experiment.md`.


## Objective

Resolve the exact dynamic outcome of the private CoreGraphics server-version validation that runs after the proven Lion session-port bridge and before `__CGSNewConnectionPort`.

The corrected v2 static differential proves that Snow Leopard PPC and Lion native CoreGraphics use the same visible MIG envelope for `__CGSGetCoreGraphicsServerVersion`:

```text
request ID        0x7148
expected reply    0x71ac
request bits      0x1513
mach_msg options  0x3
send size         0x24
receive size      0x48
request payload   NDR + pid
```

Both helpers accept simple and complex MIG replies, perform NDR/endian handling, and return decoded version fields to `_connectAndCheck`.

The static reports also expose a strong but still unproven failure hypothesis:

```text
Snow Leopard CoreGraphics current version  545.0.0
Lion CoreGraphics current version           600.0.0
```

Snow PPC `_connectAndCheck` compares the values returned by `__CGSGetCoreGraphicsServerVersion` with the local values from `_CGSGetCoreGraphicsVersion`. If they differ and the existing CoreGraphics defaults path does not permit the mismatch, it destroys the selected port and returns `0x3f0`. Snow PPC `_CGSServerPort` handles `0x3f0` by calling `exit(1)`.

That local path exactly matches the already-observed Lion symptom—session adapter PASS, no `0x7469`, status 1, no crash diagnostic—but the returned static reports do not prove what the Lion WindowServer actually replies to the translated PPC `0x7148` request.

This experiment therefore extends the existing behavior-preserving `mach_msg` trace by one exact transaction only. It does **not** alter the request, reply, local version values, defaults, or control flow.

## Trace v2

Current runtime `main` updates the existing CoreServices trace variant to build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v2
```

It passively records three CGS request classes:

```text
SERVER_VERSION   0x7148 -> 0x71ac
DEATHWATCH       0x714c -> 0x71b0
NEW_CONNECTION   0x7469 -> 0x74cd
```

For each matched request the trace logs:

- unchanged request header and Mach arguments;
- raw request words from offset `0x18`, capped at `0x44`;
- raw `mach_msg` return;
- reply header, size, ID and ID-match result;
- raw reply words from offset `0x18`, capped at `0x44`.

Every request is passed to the original `mach_msg` unchanged.

The trace still contains exactly two PPC interpose tuples: `bootstrap_look_up2` and `mach_msg`. No additional interposition surface is introduced.

## Safety constraints

For this stage:

- build only trace-v2 on Snow Leopard;
- require the Snow control before Lion;
- reuse the accepted registration subject, Security v1 interposer, and CGS session-bootstrap v1 interposer unchanged;
- do not modify CoreGraphics defaults or set any version-mismatch override;
- do not interpose `_connectAndCheck` or `__CGSGetCoreGraphicsServerVersion`;
- do not adapt `0x7148`, `0x714c`, `0x7469`, or `0x729e`;
- do not fabricate server-version values, ports, or connection records;
- do not patch CoreGraphics, WindowServer, Rosetta, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer or launchd jobs;
- do not use a debugger, DTrace, dtruss, or live injection;
- run the Lion translated-PPC trace exactly once before review.

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

## Phase B — build trace-v2 on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-coreservices-sessioninit-cgs-trace-on-snowleopard.sh
```

Require:

```text
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.sha256
```

The info/build validation must show:

```text
build_id=dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v2
32-bit PPC
two __interpose tuples
SERVER_VERSION trace marker
PM_CGS_CONNECTION_TRACE_REQUEST_WORDS
```

Do not reuse the old trace-v1 dylib.

## Phase C — Snow Leopard positive control

Keep the previously accepted registration-only subject, Security v1 interposer, CGS session-bootstrap v1 interposer, and SHA sidecars in the same directory, then run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cgs-connection-trace-control.sh
```

Require:

```text
server_version_observed=YES
new_connection_observed=YES
RESULT: PASS
```

The hard gate now requires:

```text
SERVER_VERSION request 0x7148     -> observed
mach_msg                          -> KERN_SUCCESS
reply 0x71ac                      -> ID match
NEW_CONNECTION request 0x7469     -> observed
reply 0x74cd                      -> ID match
GetProcessForPID                  -> 0
postidentity connection           -> nonzero
```

Preserve the raw Snow `SERVER_VERSION` request/reply words. They are the positive-control oracle for Lion.

If Phase C fails, stop and do not run Lion.

## Phase D — transfer exact artifacts

Transfer the trace-v2 artifact and sidecars plus the Snow control log to Lion.

Reuse, without rebuilding:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

with their accepted SHA sidecars.

## Phase E — native safety gates

Repeat the established native commpage check and syscall-295 probe under the validated kernel identity.

Preserve the syscall probe as:

```text
syscall295-probe-process-manager-cgs-server-version-trace.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion trace-v2 run

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cgs-connection-trace.sh
```

The runner still enables only the already-proven compatibility modes:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib.sha256
ppc-process-manager-cgs-connection-trace-snowleopard-control.log
syscall295-probe-process-manager-cgs-server-version-trace.log
lion-ppc-process-manager-cgs-connection-trace.log
lion-ppc-process-manager-cgs-connection-trace.raw.log
```

Also return every new diagnostic named by the runner.

Do not run another PPC experiment until these files are reviewed.

## Result interpretation

### `CGS_TRACE_NO_SERVER_VERSION_AFTER_SESSION_ADAPTER`

The adapted session port returns to restored Snow PPC CoreGraphics, but `_connectAndCheck` never sends its expected first remote validation. Audit the immediate local call/argument path before the MIG helper.

### `CGS_TRACE_SERVER_VERSION_MACH_FAILURE`

The exact `0x7148` transaction is reached but transport fails. Compare remote/reply ports and request words against Snow before changing anything.

### `CGS_TRACE_SERVER_VERSION_REPLY_ID_MISMATCH`

Lion replies, but not with the expected `0x71ac`. This becomes the exact protocol boundary.

### `CGS_TRACE_SERVER_VERSION_REPLY_OBSERVED_CLEAN_EARLY_EXIT_RC1`

This is the leading expected outcome. Compare Snow and Lion raw `0x71ac` reply words before making any compatibility change.

If the Lion reply contains valid but different server-version values, that directly explains the local `0x3f0 -> exit(1)` path. The next stage would then be a standalone proof of the narrowest version-compatibility policy; do not rewrite the integrated reply yet.

### `CGS_TRACE_SERVER_VERSION_REPLY_OBSERVED_NO_NEWCONNECTION`

The version RPC returned but the process stopped differently from the prior clean status-1 case. Preserve the exact exit/diagnostic state and compare raw reply words before proceeding.

### Existing NewConnection classifications

If trace-v2 unexpectedly proceeds to `0x7469`, stop and review the SERVER_VERSION words and possible observation effect before proceeding farther.

## Current boundary

```text
syscall 295                                  -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
standalone session-port protocol            -> PASS
registration session-bootstrap adapter      -> PASS
Snow server-version visible wire contract   -> 0x7148/0x71ac
Lion native server-version visible contract -> 0x7148/0x71ac
Snow CoreGraphics current version           -> 545.0.0
Lion CoreGraphics current version           -> 600.0.0
Lion translated PPC NewConnection           -> not reached
observed process stop                       -> status 1, no diagnostic
leading hypothesis                          -> valid 0x71ac reply exposes version skew, causing Snow PPC 0x3f0 -> exit(1)
next step                                   -> passive SERVER_VERSION trace-v2; no adaptation
```

No additional XNU change is indicated.


## Observed trace-v2 result — version skew confirmed dynamically

The Snow control passed and established the exact positive-control reply:

```text
SERVER_VERSION request                    0x7148
SERVER_VERSION reply                      0x71ac
reply bits / size                         0x80001200 / 0x40
raw word 0x30                             0x21020000
decoded first version field               545
raw word 0x34                             0x00000000
decoded second version field              0
NewConnection 0x7469/0x74cd              PASS
registration                             PASS
```

The Lion translated-PPC run reached the same server-version transaction after the proven session-bootstrap adapter:

```text
SERVER_VERSION request                    0x7148
SERVER_VERSION reply                      0x71ac
reply bits / size                         0x80001200 / 0x40
raw word 0x30                             0x58020000
decoded first version field               600
raw word 0x34                             0x00000000
decoded second version field              0
NewConnection 0x7469                      NOT REACHED
process exit                              1
new diagnostic                            none
protected hashes                          unchanged
```

The request envelope, complex reply shape, descriptor disposition/type bytes, NDR representation, auxiliary word at `0x38`, and flags word at `0x3c` match the Snow oracle. The expected Mach port names and request PID naturally differ. The only compatibility-significant server-version field difference is the first decoded version value: Snow returns `545`, Lion returns `600`.

Because the reply's NDR integer representation differs from the PPC client's native representation, the raw words decode by byte swap:

```text
Snow 0x21020000 -> 0x00000221 -> 545
Lion 0x58020000 -> 0x00000258 -> 600
```

This closes the previous hypothesis. The clean Lion status-1 exit is the already-audited Snow PPC version-mismatch path: `_connectAndCheck` sees a server version different from its local Snow PPC CoreGraphics version, returns `0x3f0`, and `_CGSServerPort` calls `exit(1)` before `__CGSNewConnectionPort`.

Do not patch the integrated reply yet. Current `main` prepares the standalone NDR-aware compatibility proof:

```text
docs/process-manager-cgs-server-version-compat-protocol-adapter-experiment.md
```

That proof first reproduces Snow `545/0`, then on Lion reproduces original `600/0` and normalizes only a copied standalone reply buffer to `545/0`, requiring zero changes outside the version-word region. No CoreGraphics consumer sees the adapted buffer during that stage.
