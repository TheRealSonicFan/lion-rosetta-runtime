# Process Manager bootstrap compatibility integration experiment

## Objective

Test whether the now-proven Lion-format bootstrap request is sufficient to let the restored Snow Leopard PPC CarbonCore establish its normal coreservicesd client session and proceed to the already-audited `ServerCheckin -> FindService` path.

The preceding one-transaction adapter experiment completed with:

```text
RESULT: BOOTSTRAP_PROTOCOL_ADAPTER_PASS
```

Lion accepted the PPC-generated Lion-format `look_up2` request, returned the expected complex reply, and supplied a nonzero coreservicesd service port.

That closes the bootstrap wire-format hypothesis itself. The remaining question is now integration:

> If only the exact Snow Leopard PPC `bootstrap_look_up2("com.apple.CoreServices.coreservicesd", target_pid=0, flags=0x8)` call is adapted to Lion's UUID-expanded request, does unmodified PPC CarbonCore then establish its own server check-in session and obtain `LaunchApplicationServices`?

This experiment answers only that question.

## Evidence from the completed adapter proof

The validated PPC adapter subject has SHA-256:

```text
41a9fc6583259af9eab0fdff56ea578ca9fa22fc1f0fcb155cea8e0cb8ae763c
```

On Snow Leopard 10.6.8:

- the exact subject used `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- the in-memory Lion request layout self-check passed;
- the ordinary Snow Leopard PPC legacy lookup returned `kr=0`;
- the returned coreservicesd service port was nonzero;
- `RESULT: PASS`.

On Lion 10.7.5:

- the same subject and hash were verified;
- request ID `0x194`, send size `0xbc`, receive size `0x6c`, service offset `0x20`, PID offset `0xa0`, UUID offset `0xa4`, and flags offset `0xb4` all matched the binary audit;
- the request used target PID 0, a zero instance UUID, and flags `0x8`;
- `mach_msg` returned success;
- the reply was complex, ID `0x1f8`, size `0x28`, descriptor count 1;
- the returned coreservicesd service port was nonzero;
- no crash/core diagnostic appeared;
- all protected hashes remained unchanged;
- `RESULT: BOOTSTRAP_PROTOCOL_ADAPTER_PASS`.

The syscall-295 safety probe immediately beforehand remained a clean EBADF/no-SIGSYS PASS.

## Why the next experiment uses process-local dyld interposition

A standalone custom lookup is no longer enough. CarbonCore must receive the corrected service port through the call it already makes so that its own unmodified code can continue naturally into:

```text
ServerCheckin -> SCClientSession -> FindService
```

The experiment therefore uses one private PPC dynamic library loaded only into the dedicated test process through:

```text
DYLD_INSERT_LIBRARIES
```

The dylib contains a classic `__DATA,__interpose` tuple supported by the Snow Leopard dyld used at `/usr/oah/dyld`.

It interposes only `bootstrap_look_up2`.

The replacement is deliberately narrow:

- exact service name must be `com.apple.CoreServices.coreservicesd`;
- target PID must be 0;
- flags must be exactly `0x8`;
- Lion adapter mode permits only one adapted exact call;
- every non-target call is passed through to the original Snow Leopard PPC `bootstrap_look_up2`;
- a second exact Lion-adapted call is blocked and recorded instead of sending another custom request.

No global flat namespace is used. `DYLD_FORCE_FLAT_NAMESPACE` is not used.

The Lion-format request preserves the public Lion `bootstrap_look_up2` privileged-server behavior: it requests the audit trailer, extracts the server effective UID, and rejects a non-root server when the `0x8` privileged-server flag is present.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-bootstrap-compat-interposer.c
scripts/build-ppc-process-manager-bootstrap-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-bootstrap-integration-control.sh
scripts/run-lion-ppc-process-manager-bootstrap-integration.sh
docs/process-manager-bootstrap-integration-experiment.md
```

The build script also reuses the existing, already-controlled CoreServices stage subject source and builder:

```text
tests/ppc-process-manager-systemservice-stage-discriminator.c
scripts/build-ppc-process-manager-systemservice-stage-on-snowleopard.sh
```

No Apple binary is modified or committed.

## Safety constraints

For this experiment:

- build both PPC artifacts only on Snow Leopard;
- run one Snow Leopard positive control first;
- transfer the exact hashed executable and interposer to Lion;
- repeat the established native commpage and syscall-295 safety gates;
- run the Lion integrated PPC subject exactly once;
- use the private interposer only through the runner-provided child-process environment;
- do not install the interposer into any system directory;
- do not set `DYLD_INSERT_LIBRARIES` globally or in the login environment;
- do not use `DYLD_FORCE_FLAT_NAMESPACE`;
- do not patch libSystem, liblaunch, launchd, CarbonCore, CoreServices, or coreservicesd;
- do not call `ServerCheckin` directly;
- do not call `FindService` directly;
- do not call Security, LaunchServices process-services initialization, or Process Manager;
- do not set `CORESERVICESD_SERVICE_NAME` or `SCDontUseServer`;
- do not restart, signal, suspend, or replace launchd, coreservicesd, pbs, securityd, or WindowServer;
- do not modify the Rosetta cache, private dyld, system dyld, or XNU;
- do not use GDB, DTrace, dtruss, or live code injection.

This is the first intentionally authorized dyld interposition stage in the Process Manager investigation. Its scope is the single dedicated test process and the one exact bootstrap call above.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm the five prepared files listed above.

After any correction to this experiment, Phase A must be repeated before rebuilding. On Snow Leopard, also confirm the current interposer source contains the corrected build identity `interpose-replacee-v3` and does not contain a `dlsym` call. The Phase B builder enforces both conditions and will stop if the checkout is stale.

On Lion also update XNU:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — build the PPC stage subject and private interposer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-bootstrap-integration-on-snowleopard.sh \
  ./ppc-process-manager-bootstrap-integration-stage-private-dyld \
  ./ppc-process-manager-bootstrap-compat-interposer.dylib
```

Expected outputs:

```text
ppc-process-manager-bootstrap-integration-stage-private-dyld
ppc-process-manager-bootstrap-integration-stage-private-dyld.info.txt
ppc-process-manager-bootstrap-integration-stage-private-dyld.sha256
ppc-process-manager-bootstrap-compat-interposer.dylib
ppc-process-manager-bootstrap-compat-interposer.dylib.info.txt
ppc-process-manager-bootstrap-compat-interposer.dylib.sha256
```

Require:

- both artifacts are 32-bit PowerPC;
- the stage executable uses `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- the stage executable links the CoreServices umbrella;
- the interposer contains a `__DATA,__interpose` section;
- the interposer references `bootstrap_look_up2`, `mach_msg`, and `mig_get_reply_port`, and contains the private replacement symbol used by its `__DATA,__interpose` tuple;
- the interposer build report contains `compat_build_id=interpose-replacee-v3`;
- the interposer build report contains `interposer_source_sha256=...`;
- the compiled dylib contains the exact literal `PM_BOOTSTRAP_COMPAT_BUILD_ID:interpose-replacee-v3`;
- the interposer does **not** import `_dlsym`;
- the newly generated interposer SHA-256 is **not** the obsolete pre-fix hash `7c2e202c4fc80a33954902ccf59d66c11859e38ce59632f3184a9c71875e225b`.

The builder records `interposer_source_sha256` and `runtime_git_head` in the interposer info report. If the checkout has no `.git` metadata, the latter is recorded as `UNAVAILABLE_NON_GIT_CHECKOUT`; the source SHA-256 still provides artifact provenance.

If the build fails, or if the obsolete hash/import appears, stop and return the complete build output.

## Phase C correction — original implementation resolution

The first Snow Leopard Phase C run did not reach Lion and did not expose a CoreServices compatibility failure. The interposer loaded and the exact CarbonCore lookup was intercepted, but the control then recorded:

```text
PM_BOOTSTRAP_COMPAT_ORIGINAL_UNAVAILABLE:reason=SNOW_CONTROL_EXACT_TARGET
PM_SYSTEMSERVICE_STAGE_RESULT:CHECKIN_SESSION_UNAVAILABLE
control_status=20
RESULT: FAIL
```

The failure was in the test interposer's pass-through resolver.

The original implementation was being recovered with `dlsym(RTLD_NEXT, "bootstrap_look_up2")`. Under the Snow Leopard dyld interposition model used by `/usr/oah/dyld`, that lookup is not a reliable way to recover the pre-interposed function address: the resolved address can itself reflect the active interposition mapping.

The `__DATA,__interpose` tuple already contains the exact pre-interposed replacee address that dyld used when installing the replacement. The corrected interposer therefore uses its own tuple's `replacee` field as the original Snow Leopard PPC `bootstrap_look_up2` address and no longer uses `dlsym` for pass-through resolution.

This is narrower than adding another symbol-lookup mechanism: it uses the exact address already recorded in the interpose tuple and does not search any other image or namespace.

The corrected control emits:

```text
PM_BOOTSTRAP_COMPAT_ORIGINAL_RESOLUTION:source=interpose_replacee ...
```

and must not emit `PM_BOOTSTRAP_COMPAT_ORIGINAL_UNAVAILABLE`.

Because the interposer binary changes, repeat Phase B to rebuild it and regenerate its SHA-256 sidecar before rerunning Phase C. The stage executable source is unchanged, but using the Phase B builder again preserves the paired-artifact provenance.

Do not proceed to Lion until the revised Snow Leopard Phase C ends in `RESULT: PASS`.

## Second Phase C submission — stale pre-fix interposer identified

The second submitted Snow Leopard control did not exercise the corrected `interpose_replacee` resolver.

The evidence is explicit:

- the interposer SHA-256 is still `7c2e202c4fc80a33954902ccf59d66c11859e38ce59632f3184a9c71875e225b`, exactly the pre-fix binary identity;
- the interposer build report still lists an undefined `_dlsym` import;
- the control still emits `PM_BOOTSTRAP_COMPAT_ORIGINAL_UNAVAILABLE:reason=SNOW_CONTROL_EXACT_TARGET`;
- the control does not emit `PM_BOOTSTRAP_COMPAT_ORIGINAL_RESOLUTION:source=interpose_replacee`.

The corrected source on current `main` contains no `dlsym` call. Therefore this result does not test, and cannot falsify, the corrected pass-through resolver.

The procedural gap was that repeating Phase B/Phase C after the first correction was not sufficient unless Phase A was repeated first to pull the corrected source. The build/control tooling now enforces corrected-artifact provenance instead of relying on that assumption.

The corrected interposer has the build identity:

```text
interpose-replacee-v3
```

The builder now refuses stale source, refuses any rebuilt dylib that still imports `_dlsym`, embeds/logs the build identity, and records the runtime Git HEAD. The Snow Leopard and Lion runners independently reject an interposer that lacks this identity or still imports `_dlsym`.

The old interposer and sidecar with SHA-256 `7c2e202c4fc80a33954902ccf59d66c11859e38ce59632f3184a9c71875e225b` must not be reused.

The stage executable source is unchanged, so its SHA-256 may legitimately remain:

```text
aef485ca23cdc4b7a235add955835926cf6091c9fabcf6a1335b33ec0be61978
```

Repeat Phase A, then Phase B, then Phase C. Do not proceed to Lion until the corrected Snow Leopard control passes.

## Third Phase C submission — build-marker validation false negative

The third submitted Snow Leopard artifacts are different from the obsolete pre-fix interposer and do contain the corrected tuple-based resolver.

The evidence is explicit:

- the interposer SHA-256 changed to `0d4a34b0df4e8bab07645a434c5f35f81bb788d7c18bbb9b2d8130df139ccb15`;
- the build report contains `compat_build_id=interpose-replacee-v2`;
- the build report no longer contains an undefined `_dlsym` import;
- the control stops before launching the PPC subject with `error: corrected interposer build marker is missing`.

That failure is another harness validation bug, not a resolver failure.

The v2 interposer logged its build ID with a formatted call equivalent to:

```text
"PM_BOOTSTRAP_COMPAT_BUILD_ID:%s" + COMPAT_BUILD_ID
```

At runtime that would print the desired combined marker, but the preflight used `strings(1)` to search the binary for the already-concatenated text. Because the format string and build-ID string were separate constants in the binary, `strings` could not find the combined runtime text and rejected a valid corrected artifact before execution.

The v3 correction makes the full marker a single compile-time string literal:

```text
PM_BOOTSTRAP_COMPAT_BUILD_ID:interpose-replacee-v3
```

The builder and both runners now validate that exact embedded literal.

The builder also records:

```text
interposer_source_sha256=...
runtime_git_head=...
```

If the checkout has no `.git` metadata, `runtime_git_head` is recorded as `UNAVAILABLE_NON_GIT_CHECKOUT` rather than left blank. The source SHA-256 remains available for artifact provenance in either case.

The submitted v2 hash `0d4a34b0df4e8bab07645a434c5f35f81bb788d7c18bbb9b2d8130df139ccb15` must not be reused for the v3 control because the source and embedded marker have changed.

Repeat Phase A, then Phase B, then Phase C. The corrected Phase C must reach the PPC process; a preflight-only "build marker is missing" result is no longer expected.

## Phase C — Snow Leopard positive control with pass-through interposition

Before running, confirm the parent shell has none of these set:

```text
CORESERVICESD_SERVICE_NAME
SCDontUseServer
ROSETTA_BOOTSTRAP_COMPAT_MODE
DYLD_INSERT_LIBRARIES
```

The runner enforces this.

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-bootstrap-integration-control.sh \
  ./ppc-process-manager-bootstrap-integration-stage-private-dyld \
  ./ppc-process-manager-bootstrap-integration-stage-private-dyld.sha256 \
  ./ppc-process-manager-bootstrap-compat-interposer.dylib \
  ./ppc-process-manager-bootstrap-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-bootstrap-integration-snowleopard-control.log
```

For this control only, the runner sets:

```text
ROSETTA_BOOTSTRAP_COMPAT_MODE=passthrough
DYLD_INSERT_LIBRARIES=<absolute private interposer path>
```

The exact coreservicesd lookup must be visibly intercepted and then delegated to the original Snow Leopard PPC implementation.

Require:

```text
PM_BOOTSTRAP_COMPAT_BUILD_ID:interpose-replacee-v3
PM_BOOTSTRAP_COMPAT_EXACT_CALL:index=1 mode=passthrough
PM_BOOTSTRAP_COMPAT_ORIGINAL_RESOLUTION:source=interpose_replacee ...
PM_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=0 ...
PM_SYSTEMSERVICE_STAGE_RESULT:STAGE_CONTROL_PASS
RESULT: PASS
```

Also require nonzero service ports in both the interposer pass-through return and the normal CoreServices stage output. `PM_BOOTSTRAP_COMPAT_ORIGINAL_UNAVAILABLE` must not appear.

This control proves that the private dyld loads the interposer, that the `__interpose` tuple actually reaches CarbonCore's bootstrap call, that the tuple's replacee address resolves the original Snow Leopard PPC implementation, and that pass-through remains functional.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
ppc-process-manager-bootstrap-integration-stage-private-dyld
ppc-process-manager-bootstrap-integration-stage-private-dyld.info.txt
ppc-process-manager-bootstrap-integration-stage-private-dyld.sha256
ppc-process-manager-bootstrap-compat-interposer.dylib
ppc-process-manager-bootstrap-compat-interposer.dylib.info.txt
ppc-process-manager-bootstrap-compat-interposer.dylib.sha256
ppc-process-manager-bootstrap-integration-snowleopard-control.log
```

Place the executable, interposer, and SHA sidecars in the Lion runtime `payload/` directory or pass explicit paths to the runner.

Do not rebuild either PPC artifact on Lion.

## Phase E — repeat the native Lion safety gates

Use the validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

The validated kernel SHA-256 remains:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Run the established native commpage safety probe and require its existing `RESULT: PASS`.

Then:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-process-manager-bootstrap-integration.log"
```

Require the established syscall-295 PASS result.

Do not continue if either native safety gate fails.

## Phase F — run the single Lion bootstrap-integrated CoreServices stage

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-bootstrap-integration.sh
```

The runner verifies:

- Lion 10.7.5;
- clean parent environment;
- validated kernel;
- PowerPC architecture handler;
- translator identity;
- exact stage executable hash;
- exact interposer hash;
- PPC architecture of both artifacts;
- `LC_LOAD_DYLINKER=/usr/oah/dyld` on the stage subject;
- CoreServices umbrella linkage;
- interposer `__DATA,__interpose` section;
- private/system dyld identities;
- validated Rosetta cache/map identities;
- CarbonCore and libSystem membership in the Rosetta cache map.

For the single child process only, the runner sets:

```text
ROSETTA_BOOTSTRAP_COMPAT_MODE=lion-adapter
DYLD_INSERT_LIBRARIES=<absolute private interposer path>
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_INTERPOSING=1
DYLD_PRINT_LIBRARIES=1
```

The interposer may send only one Lion-format exact coreservicesd lookup. A second exact lookup is blocked and reported.

After the adapted lookup returns, no custom code invokes CoreServices RPCs. The existing Snow Leopard PPC CarbonCore continues its own normal code path.

Do not rerun Phase F before review.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-bootstrap-integration-stage-private-dyld.info.txt
ppc-process-manager-bootstrap-integration-stage-private-dyld.sha256
ppc-process-manager-bootstrap-compat-interposer.dylib.info.txt
ppc-process-manager-bootstrap-compat-interposer.dylib.sha256
ppc-process-manager-bootstrap-integration-snowleopard-control.log
syscall295-probe-process-manager-bootstrap-integration.log
lion-ppc-process-manager-bootstrap-integration.log
lion-ppc-process-manager-bootstrap-integration.raw.log
```

Also return every new crash report or core listed by the Lion runner.

## Result interpretation

### `BOOTSTRAP_COMPAT_SYSTEMSERVICE_PASS`

The interposer supplied a valid Lion-format coreservicesd lookup result, then unmodified PPC CarbonCore successfully completed its own client check-in and returned a nonzero `LaunchApplicationServices` service port.

This would prove the bootstrap schema mismatch was the prerequisite defect blocking the CarbonCore client session.

Stop there.

The next stage would return to the Process Manager boundary with the same private process-local bootstrap compatibility layer, but it must first be designed separately. Do not call Process Manager in this experiment.

### `BOOTSTRAP_COMPAT_SERVERCHECKIN_FAILURE`

The adapted bootstrap lookup returned a valid nonzero coreservicesd port, but CarbonCore still ended with both its server-checkin port and requested service port at zero.

That localizes the next live failure specifically to CarbonCore's existing legacy PPC `ServerCheckin` transaction or its result handling.

Do not proceed to `FindService`.

### `BOOTSTRAP_COMPAT_FIND_SERVICE_FAILURE`

The adapted bootstrap lookup succeeded and CarbonCore acquired a nonzero server-checkin port, but `LaunchApplicationServices` remained zero.

That proves the legacy PPC `ServerCheckin` path worked live against Lion.

The next target becomes only the existing `FindService("LaunchApplicationServices", 0x00010000,...)` transaction or returned service status.

### `BOOTSTRAP_COMPAT_MULTIPLE_EXACT_LOOKUPS`

CarbonCore attempted the exact adapted bootstrap call more than once.

The interposer intentionally sends only the first custom request and blocks the second.

Preserve the log and stop before broadening the adapter.

### interposer loading/trigger failures

`BOOTSTRAP_COMPAT_INTERPOSER_NOT_LOADED` or `BOOTSTRAP_COMPAT_INTERPOSER_NOT_TRIGGERED` means the process-local interposition plumbing did not reach the expected call on Lion.

Do not fall back to flat namespace or patch the shared cache.

### adapter-internal, Mach, policy, or reply failure

Preserve the exact marker and stop. The already-proven one-shot adapter behavior must be reconciled before continuing.

### abort/crash classifications

Any abort/crash during the integrated service-acquisition call is new evidence. Preserve every generated diagnostic and stop.

## Current interpretation to preserve

The bootstrap protocol defect itself is now experimentally proven:

```text
legacy Snow Leopard PPC request: 0xac
Lion UUID-expanded request:       0xbc
standalone Lion-format PPC request: accepted
```

This experiment does not retest that fact in isolation.

It asks whether correcting only that transaction is sufficient for the unmodified restored PPC CarbonCore to advance.

Lion's server-side static audit already showed explicit compatibility handling for the legacy PPC `ServerCheckin` form, but that path has not yet been demonstrated live after a corrected bootstrap lookup.

No additional XNU change is indicated.

## Non-goals

This experiment does not:

- install a permanent bootstrap compatibility layer;
- modify libSystem or liblaunch;
- patch launchd;
- replace CarbonCore;
- call `ServerCheckin` from custom code;
- call `FindService` from custom code;
- initialize Security;
- initialize LaunchServices process services;
- call Process Manager;
- broaden the private LaunchServices PPC-admission patch;
- modify Rosetta or XNU.

It is one process-local integration discriminator between the now-proven bootstrap compatibility fix and CarbonCore's next native client-session stages.


## Observed Lion result — bootstrap integration succeeds, ServerCheckin remains blocked

The completed Lion Phase F run reached the intended integration boundary.

The validated v3 interposer was loaded and triggered once. Its Lion-format bootstrap request completed successfully:

```text
PM_BOOTSTRAP_COMPAT_ADAPTER_MACH_MSG:kr=0
PM_BOOTSTRAP_COMPAT_ADAPTER_REPLY:bits=0x80001200 size=0x00000028 id=0x000001f8
PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:LOOKUP_PASS servicePort=nonzero serverEuid=0
```

Unmodified PPC CarbonCore then returned from `scCreateSystemServiceVersion` with both the requested service port and its server-checkin port still zero, process options `0x00000002`, and:

```text
RESULT: BOOTSTRAP_COMPAT_SERVERCHECKIN_FAILURE
```

No crash/core diagnostic was produced and all protected hashes remained unchanged.

The Snow Leopard control for the same v3 interposer is a clean PASS: tuple-based pass-through resolves the original PPC `bootstrap_look_up2`, CarbonCore obtains a nonzero service/check-in port, and process options remain zero.

### Correction to the earlier ServerCheckin static interpretation

Re-reading the already-collected Lion i386 `__XServerCheckin` disassembly reveals that the prior statement that Lion retained compatibility for Snow Leopard PPC's complex descriptor-bearing request was incorrect.

Lion's i386 server wrapper:

- rejects a request when the Mach complex bit is set;
- accepts only a simple request of size `0x18`;
- otherwise returns `MIG_BAD_ARGUMENTS`.

Snow Leopard PPC `__scclient_ServerCheckin`, by contrast, sends a complex `0x28` request with one port descriptor.

Lion's own i386 client sends the simple `0x18` form.

This provides a concrete protocol explanation for the live integration result and moves the active boundary from bootstrap to ServerCheckin request shape.

The authoritative next stage is:

```text
docs/process-manager-servercheckin-protocol-adapter-experiment.md
```

It first proves the exact native Lion simple ServerCheckin request in a standalone PPC subject after the already-proven adapted bootstrap lookup. It does not modify the existing integration interposer and does not call `FindService`.

Do not rerun the bootstrap integration experiment before the standalone ServerCheckin result is reviewed.


## Follow-up — standalone ServerCheckin proof passed

The subsequent standalone ServerCheckin protocol adapter experiment completed successfully.

After the already-proven Lion-format bootstrap lookup returned a nonzero coreservicesd port, the translated PPC subject sent Lion's native simple `0x18` ServerCheckin request and received the expected complex `0x34` reply with a nonzero session port. The Snow Leopard legacy `0x28` control also passed.

Therefore the `BOOTSTRAP_COMPAT_SERVERCHECKIN_FAILURE` result from this experiment is now explained by a second confirmed request-shape mismatch rather than by an unknown server-state failure.

The next stage is no longer another standalone RPC probe. It is the guarded dual integration in:

```text
docs/process-manager-coreservices-compat-integration-experiment.md
```

That stage combines only the two proven adaptations and observes whether unmodified PPC CarbonCore completes its existing `FindService("LaunchApplicationServices")` path.
