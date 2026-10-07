# Process Manager launchd/bootstrap protocol audit

## Objective

Confirm the exact shipped bootstrap/MIG protocol mismatch that now precedes CarbonCore `ServerCheckin`.

The guarded PPC bootstrap discriminator returned on Lion:

```text
kr=-304
servicePort=0
RESULT: BOOTSTRAP_LOOKUP_ERROR
```

while the exact same PPC executable returned `kr=0` and a nonzero service port on Snow Leopard.

The immediate task is now static and read-only: correlate the shipped Snow Leopard PPC bootstrap client with Lion's native bootstrap/launchd protocol and recover the exact request-layout change before any compatibility adapter is attempted.

## Evidence established by the live discriminator

The exact PPC bootstrap subject has SHA-256:

```text
6c1e9728fd3f30889217bb5bd5e55778cbcdc0a652e8739143d5512e068e2dbc
```

On Snow Leopard 10.6.8:

- the subject uses `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- `bootstrap_port` is nonzero;
- both compatibility-changing environment variables are unset;
- the exact service name is `com.apple.CoreServices.coreservicesd`;
- target PID is 0;
- flags are `0x8`;
- `bootstrap_look_up2` returns 0;
- the returned service port is nonzero;
- `RESULT: PASS`.

On Lion 10.7.5, the exact same subject:

- has a nonzero `bootstrap_port`;
- sees the same clean environment;
- asks for the same service name with the same target PID and flags;
- returns normally from `bootstrap_look_up2`;
- receives `kr=-304` / `0xfffffed0`;
- receives service port zero;
- generates no crash/core diagnostic;
- preserves all protected hashes;
- ends with `RESULT: BOOTSTRAP_LOOKUP_ERROR`.

The native syscall-295 safety probe remains a clean PASS.

## Meaning of -304

Darwin Mach/MIG defines `-304` as:

```text
MIG_BAD_ARGUMENTS
```

This is not `BOOTSTRAP_UNKNOWN_SERVICE` and is not a simple service-name lookup miss. It indicates that the MIG request was rejected as having invalid arguments/layout before the requested operation could complete normally.

That result must be reconciled with the exact request schema before another live test.

## Apple OSS source correlation

The public Apple launchd sources for the two exact OS baselines expose a concrete protocol evolution.

### Snow Leopard 10.6.8 — launchd-329.3.3

The `protocol_vproc.defs` `look_up2` request contains:

- bootstrap/job port;
- service name;
- output service port;
- user audit token;
- target PID;
- 64-bit flags.

The Snow Leopard `bootstrap_look_up2` implementation calls that legacy `vproc_mig_look_up2` directly.

### Lion 10.7.5 — launchd-392.39

The same `look_up2` routine retains its position in the `protocol_vproc` subsystem but adds:

```text
instanceid : uuid_t
```

between `targetpid` and `flags`.

Lion's public `bootstrap_look_up2` API keeps the same five-argument signature, but internally calls `bootstrap_look_up3`, which supplies an instance UUID to the newer `vproc_mig_look_up2` request.

Therefore a Snow Leopard PPC client can remain source/API-compatible at the `bootstrap_look_up2` layer while emitting an older MIG request that Lion's launchd type checker no longer accepts.

The live `MIG_BAD_ARGUMENTS` result is directly consistent with that source-level schema change, but the shipped binary layouts must still be compared before a process-local adapter is designed.

## Phase C analyzer correction

The first Lion Phase C run ended in:

```text
validation_issue=i386 bootstrap client target missing: vproc_mig_look_up2
RESULT: FAIL
```

That failure is an analyzer validation defect, not evidence against the bootstrap protocol hypothesis.

The Lion report already proves that the installed i386 `liblaunch.dylib` contains both exported `bootstrap_look_up3` and `bootstrap_look_up2`. Inside `bootstrap_look_up3`, the same unnamed non-stub direct callee is invoked twice: once for the initial lookup and again after the per-user-context fallback. On the supplied Lion binary that target is `0x7967`. The surrounding control flow compares the first return value with `0x44b` before the per-user fallback, exactly matching the `VPROC_ERR_TRY_PER_USER` structure of Apple's Lion `bootstrap_look_up3` source.

Lion strips the private generated `vproc_mig_look_up2` symbol name from this client binary. Requiring the private symbol name to survive in `nm` was therefore incorrect.

Analyzer version 2 now:

- still uses the named `vproc_mig_look_up2` symbol when it exists;
- on stripped Lion liblaunch, locates `bootstrap_look_up3`;
- finds its unique repeated, non-stub direct callee outside the caller body;
- records that address as the inferred `vproc_mig_look_up2` body;
- emits a synthetic disassembly window beginning at that inferred target;
- accepts the Lion client when `bootstrap_look_up2`, `bootstrap_look_up3`, and either a named or uniquely inferred MIG lookup body are present.

This inference is intentionally narrow. It is not a generic symbol guess and is only used when the private MIG symbol is absent but the exported `bootstrap_look_up3` call structure provides one unique repeated non-stub callee.

The Snow Leopard report is unaffected: its PPC `vproc_mig_look_up2` symbol is present explicitly and Phase B already passed.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-bootstrap-protocol.py
docs/process-manager-bootstrap-protocol-audit.md
```

The analyzer is Python-2-compatible, read-only, and currently reports `analyzer_version=2`.

It inspects:

- the installed bootstrap client implementation, preferring `/usr/lib/system/liblaunch.dylib` and falling back to `/usr/lib/libSystem.B.dylib`;
- `/sbin/launchd`;
- i386, x86_64, and ppc7400 slices where present;
- `bootstrap_look_up2`;
- `bootstrap_look_up3`;
- `vproc_mig_look_up2`;
- visible launchd `job_mig_look_up2` / server-side lookup symbols where not stripped;
- Mach-message/MIG helper imports;
- installed bootstrap/MIG headers when present.

The purpose is to recover from the shipped binaries:

- request message ID;
- request size;
- reply size/ID;
- service-name field handling;
- target-PID placement;
- UUID/instance field presence or absence;
- 64-bit flags placement;
- generated MIG type-check expectations;
- whether the local installed binaries match the Apple OSS 329.3.3 versus 392.39 source evolution.

## Safety constraints

For this audit:

- do not launch any PPC application;
- do not rerun the bootstrap discriminator;
- do not call `bootstrap_look_up2`;
- do not send a custom Mach message;
- do not call `ServerCheckin`;
- do not call `FindService`;
- do not call CarbonCore, Security, LaunchServices process services, or Process Manager;
- do not set `CORESERVICESD_SERVICE_NAME` or `SCDontUseServer`;
- do not restart, signal, suspend, or replace launchd, coreservicesd, pbs, securityd, or WindowServer;
- do not patch liblaunch, libSystem, launchd, CarbonCore, or any framework;
- do not modify Rosetta, dyld, the shared cache, or XNU;
- do not use GDB, DTrace, dtruss, interposition, or live injection.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-process-manager-bootstrap-protocol.py
docs/process-manager-bootstrap-protocol-audit.md
```

No reboot or kernel rebuild is part of this stage.

## Phase B — Snow Leopard bootstrap protocol audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-bootstrap-protocol.py \
  ./process-manager-bootstrap-protocol-snowleopard.txt
```

Require:

```text
Created: ./process-manager-bootstrap-protocol-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return the report unchanged.

## Phase C — Lion bootstrap protocol audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-bootstrap-protocol.py \
  ./payload/process-manager-bootstrap-protocol-lion.txt
```

Require:

```text
Created: ./payload/process-manager-bootstrap-protocol-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

The corrected Lion report must also show:

```text
analyzer_version=2
-- stripped MIG lookup inference --
inferred_vproc_mig_look_up2=0x...
inference_basis=repeated non-stub direct callee from bootstrap_look_up3
repeated_call_count=2
```

If `RESULT: FAIL` appears, stop. Do not compensate by rerunning the PPC bootstrap probe.

Because the previously returned Snow Leopard report already passed and contains an explicit PPC `vproc_mig_look_up2` window, it does not need to be rerun solely for this analyzer correction. After pulling current `main`, rerun Phase C on Lion and return the corrected Lion report while keeping the Snow Leopard PASS report available.

## Phase D — stop and return evidence

Return:

```text
process-manager-bootstrap-protocol-snowleopard.txt
process-manager-bootstrap-protocol-lion.txt
```

Keep the completed bootstrap-discriminator logs available.

No Apple system binary should be uploaded.

## Decision gate

### A. Shipped binaries confirm the UUID-expanded Lion request

If Snow Leopard PPC emits the legacy `look_up2` request and Lion's native client/server path confirms the added UUID/instance field and larger type-checked request, the bootstrap mismatch is closed as the immediate compatibility defect.

The next stage will be a private, process-local protocol-adapter experiment limited to this exact bootstrap lookup transaction.

That adapter must not replace libSystem or launchd and must not broaden to other bootstrap routines.

### B. Binary layout does not match the OSS source evolution

If the installed binaries contradict the 329.3.3/392.39 source schemas, stop.

Do not design an adapter from source assumptions. The binary evidence becomes authoritative.

### C. launchd server symbols are stripped

This is acceptable if the client-side native Lion stub exposes the UUID-expanded request and the installed release identities match the OSS baseline.

The report must preserve all visible launchd metadata and any server-side windows that are available.

## Current interpretation to preserve

The active failure is no longer merely "coreservicesd unavailable."

The translated PPC process has a valid bootstrap port and reaches the lookup RPC, but Lion returns `MIG_BAD_ARGUMENTS` for a request that succeeds unchanged on Snow Leopard.

Public Apple OSS source shows a concrete same-routine schema evolution: Lion inserted a UUID/instance field into `vproc_mig_look_up2` while preserving the public `bootstrap_look_up2` API.

This is now the leading explanation for CarbonCore's earlier `CHECKIN_SESSION_UNAVAILABLE`.

The syscall-295/XNU boundary remains closed. No additional XNU change is indicated.

## Non-goals

This audit does not:

- prove an adapter works;
- send a Lion-format lookup request from PPC;
- bypass launchd validation;
- call CoreServices `ServerCheckin`;
- acquire `LaunchApplicationServices`;
- patch any system component;
- modify Rosetta or XNU.

It is the final read-only binary confirmation before a narrowly scoped bootstrap protocol adapter is considered.


## Observed result — shipped binaries confirm the UUID-expanded Lion request

The corrected Lion analyzer completed with `RESULT: PASS`.

The binary comparison now confirms the source-level protocol evolution.

### Snow Leopard PPC

The explicit PPC `_vproc_mig_look_up2` client body uses:

- request ID `0x194`;
- send size `0xac`;
- receive size `0x6c`;
- expected reply ID `0x1f8`;
- service-name field at request offset `0x20`;
- target PID at request offset `0xa0`;
- 64-bit flags beginning at request offset `0xa4`.

There is no intervening UUID field.

### Lion i386

Lion strips the private generated symbol name, but analyzer version 2 identifies the unique repeated non-stub callee of `bootstrap_look_up3` as the MIG lookup body at `0x7967`.

That body uses:

- request ID `0x194`;
- send size `0xbc`;
- receive size `0x6c`;
- expected reply ID `0x1f8`;
- service-name field at request offset `0x20`;
- target PID at request offset `0xa0`;
- a copied 16-byte field beginning at request offset `0xa4`;
- 64-bit flags beginning at request offset `0xb4`.

The send-size delta is exactly `0x10`, matching the inserted 16-byte `instanceid : uuid_t` field in launchd-392.39.

The earlier Lion live result of `MIG_BAD_ARGUMENTS` is therefore explained by a concrete request-layout mismatch: the restored Snow Leopard PPC client sends a `0xac` legacy request where Lion's generated server expects the UUID-expanded `0xbc` form.

The static bootstrap protocol boundary is now closed.

The authoritative next stage is the guarded, one-transaction experiment in:

```text
docs/process-manager-bootstrap-protocol-adapter-experiment.md
```

That experiment constructs exactly one Lion-format PPC lookup request in a private test process and stops before CoreServices `ServerCheckin`.

Do not rerun the legacy lookup discriminator, patch libSystem/launchd, or proceed to `ServerCheckin` before the adapter result is reviewed.
