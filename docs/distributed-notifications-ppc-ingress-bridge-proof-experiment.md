# Distributed notifications PPC ingress bridge proof experiment

## Objective

Prove the remaining cross-architecture edge between the unchanged Snow Leopard PowerPC distributed-notification client and the already-proven native i386 Lion broker boundary.

The standalone native broker proof has now passed on both Snow Leopard and Lion. It established that synthetic Snow-v2 dictionaries can be translated into Lion's public distributed-notification API, that a current-session immediate post reaches exactly one callback, that the callback can be reconstructed with the original Snow `entry/counter` identity, and that unregister plus all negative controls behave as designed.

The missing boundary is now only:

```text
unchanged Snow PPC CoreFoundation
  -> legacy .2 bootstrap lookup
  -> legacy Mach + binary-plist request
  -> process-local cross-architecture adapter
  -> native i386 public CFNotificationCenter broker
  -> callback
  -> legacy binary-plist + Mach callback
  -> unchanged Snow PPC callback handler
```

This experiment proves that boundary without running the real Process Manager subject and without publishing any global legacy service.

## Why this architecture is now justified

The Snow client-to-server envelope is already proven:

```text
msgh_bits = 0x1413
msgh_id   = 4
remote    = distributed-notification server port
local     = Snow client's callback receive port
length    = byte-swapped uint32 at +0x1c
payload   = binary property list at +0x20
```

On the Snow server receive path, the received header's send right back to the client is taken from header offset `+0x08` and wrapped as the client's callback `CFMachPort`. Snow's server-to-client callback envelope is:

```text
msgh_bits = 0x13
msgh_id   = 4
remote    = saved client callback send right
length    = byte-swapped uint32 at +0x1c
payload   = binary property list at +0x20
```

The unchanged Snow PPC receive path parses that binary plist and calls `___CFXNotificationHandleMessage`, which consumes `message_type=post`, `name`, `object`, `userinfo`, `counter`, and `entry`.

Therefore the PPC side does not need to call a private CoreFoundation callback routine. It only has to preserve the proven legacy Mach envelope.

## Prepared implementation

Current `main` provides:

```text
tests/ppc-distributed-notifications-ingress-probe.c
tests/ppc-distributed-notifications-ingress-interposer.c
tests/native-distributed-notifications-ppc-ingress-broker.c
scripts/build-ppc-distributed-notifications-ingress-on-snowleopard.sh
scripts/build-lion-native-distributed-notifications-ppc-ingress-broker.sh
scripts/run-snowleopard-ppc-distributed-notifications-ingress-control.sh
scripts/run-lion-ppc-distributed-notifications-ingress-proof.sh
docs/distributed-notifications-ppc-ingress-bridge-proof-experiment.md
```

### PPC probe

The PPC proof subject uses only public CoreFoundation APIs:

```text
CFNotificationCenterGetDistributedCenter
CFNotificationCenterAddObserver
CFNotificationCenterPostNotificationWithOptions
CFNotificationCenterRemoveObserver
```

It registers one unique process-specific proof name using public suspension behavior `DeliverImmediately`, posts exactly one current-session notification with `kCFNotificationDeliverImmediately`, requires exactly one valid callback, removes the observer, and exits.

The probe is not the Process Manager subject and never calls `CreateNewWindow`.

### PPC ingress interposer

The interposer replaces only `bootstrap_look_up2`.

Its adaptation predicate is exact:

```text
service = com.apple.distributed_notifications.2
pid     = 0
flags   = 8
mode    = lion-ppc-ingress-v1
```

All non-target lookups pass through unchanged.

On Lion, the exact target creates a process-local Mach receive right and returns a send right to unchanged Snow PPC CoreFoundation. It does **not** call launchd for `.2` and does not publish the port globally.

A PPC server thread receives only the proven legacy `msgh_id=4` envelope, preserves the callback send right supplied by Snow CoreFoundation, extracts the binary-plist bytes without parsing them, and forwards those bytes through an inherited `AF_UNIX` `socketpair`.

The native broker is launched with `posix_spawn`. The child environment is scrubbed of `DYLD_INSERT_LIBRARIES` and the proof-specific Rosetta variables so the i386 broker cannot inherit the PPC-only interposer.

A second PPC thread receives broker callback frames, reconstructs exactly the proven Snow server-to-client `0x13 / id 4` envelope, and sends it to the callback right supplied by unchanged Snow CoreFoundation.

### Native i386 broker

The broker parses the forwarded binary property list using public CoreFoundation property-list APIs.

It accepts only the unique proof-name prefix:

```text
com.openai.rosetta.distnotify.ppcingress.
```

The first proof supports only:

```text
register
post
unregister
```

The broker enforces:

- one registration only;
- proven legacy `behavior` inversion into the public suspension enum;
- `sux=false`;
- current-session posting only;
- post `sessionid` must equal the session ID captured from the registration request;
- exactly the registered `entry` must appear in the unregister `entries[]`;
- unknown, suspend, and session_reset operations are rejected;
- no private XPC objects are constructed.

Using the registration session ID as the current-session discriminator avoids guessing Snow's private all-session sentinel.

On callback, the broker reconstructs:

```text
message_type = post
name
object
userinfo
counter = stored Snow counter
entry   = stored Snow entry
```

and serializes it as a binary property list for the PPC side.

## Reviewed Phase B linker failure

The first Phase B attempt stopped while linking the PPC ingress interposer:

```text
Undefined symbols:
  "_environ", referenced from:
      _environ$non_lazy_ptr
ld: symbol(s) not found
```

This is a build-tooling failure, not a distributed-notification protocol result. The PPC probe had already linked and its `LC_LOAD_DYLINKER` had been patched, but the interposer dylib never linked, so Phase C was never reached.

The cause is the interposer's direct `extern char **environ` reference. In this PPC dynamic-library build, that produces an unresolved `_environ` data import. Darwin's dynamic-library-safe interface is `_NSGetEnviron()` from `<crt_externs.h>`; the Snow Leopard SDK declares that accessor for this purpose.

Current `main` corrects only the child-environment acquisition path:

- the interposer now reads the process environment through `_NSGetEnviron()`;
- the environment filtering policy is unchanged;
- the broker is still launched with `posix_spawn`;
- the proof's bootstrap predicate, Mach envelope handling, socketpair framing, and callback path are unchanged;
- the interposer build ID is bumped to version 2;
- the Snow builder requires the `__NSGetEnviron` import and rejects any direct `_environ` import;
- both Snow and Lion runners reject stale version-1 interposers.

Do not preserve or transfer artifacts from the failed Phase B attempt. Pull current `main` and rerun Phase B from the beginning; the build script removes/recreates the partial outputs. Do not proceed to Phase C unless the corrected interposer links and all build-time validation passes.

## Reviewed Phase B architecture-validator failure

The second Phase B attempt built the PPC probe and interposer far enough to reach the artifact architecture gate, then stopped with:

```text
error: not a 32-bit PPC Mach-O: ./ppc-distributed-notifications-ingress-probe-private-dyld
./ppc-distributed-notifications-ingress-probe-private-dyld: Mach-O executable ppc
```

This is another build-validator defect, not an artifact-architecture or distributed-notification failure. The compiler was invoked with `-arch ppc`, and `file` independently identified the resulting probe as a PPC Mach-O. The failing helper relied on `lipo -verify_arch`; on this Snow Leopard toolchain/run it returned failure for the thin PPC artifact even though the artifact is PPC.

Current `main` replaces that gate with explicit `lipo -info` parsing. For the Snow-built artifacts the builder now requires the thin-file form to report exactly `architecture: ppc`, corroborates it with `file`, and separately exercises a generic `lipo -info` architecture parser. The Lion runner uses the same parser for the transferred PPC probe/interposer and native i386 broker, so this false negative cannot reappear during Phase F.

During review of the failed path, a separate latent shell-structure defect was also found in the previous builder revision: the direct-`_environ` rejection block had been inserted with a malformed quote and duplicated the remainder of the script. The user run stopped at the earlier architecture check before reaching that block. Current `main` reconstructs the builder cleanly, preserving the version-2 `_NSGetEnviron` fix and all prior build-time checks.

No protocol, Mach-envelope, bootstrap predicate, IPC framing, callback translation, or broker logic changed. Discard the partial artifacts from this failed attempt, pull current `main`, and rerun Phase B from the beginning.

## Reviewed Phase B PPC-subtype naming failure

The third Phase B attempt again reached only the artifact validator:

```text
error: expected a thin 32-bit PPC Mach-O: ./ppc-distributed-notifications-ingress-probe-private-dyld
./ppc-distributed-notifications-ingress-probe-private-dyld: Mach-O executable ppc
Non-fat file: ./ppc-distributed-notifications-ingress-probe-private-dyld is architecture: ppc7400
```

This is a naming/subtype mismatch in the validator, not an architecture failure. Snow Leopard's cctools may report a concrete PowerPC CPU subtype such as `ppc7400` for a binary produced with `-arch ppc`. The artifact is still a 32-bit `CPU_TYPE_POWERPC` Mach-O; `ppc7400` is not `ppc64`.

Current `main` now treats the known 32-bit cctools PowerPC names as one PPC32 family:

```text
ppc
ppc601
ppc603
ppc603e
ppc603ev
ppc604
ppc604e
ppc750
ppc7400
ppc7450
ppc970
```

The builder still requires a **thin** Mach-O and corroborates it with `file`; it explicitly does not accept `ppc64`. The Snow control runner and Lion proof runner use the same family-aware matcher, so a transferred `ppc7400` artifact will not be rejected later merely because the caller asked for the generic `ppc` family.

No compiler flags, Mach-O patching, protocol logic, bootstrap predicate, Mach envelope, IPC framing, callback translation, or broker behavior changed. Discard the partial artifacts from this attempt, pull current `main`, and rerun Phase B from the beginning.

## Safety constraints

For this stage:

- run only the standalone PPC ingress proof subject;
- do not run the Process Manager / Carbon GUI subject;
- do not call `CreateNewWindow`;
- do not load this interposer into the real application;
- do not combine this interposer with the normal CoreServices/CGS compatibility interposer;
- do not publish `com.apple.distributed_notifications.2` through launchd;
- do not call `bootstrap_register` or `bootstrap_check_in`;
- do not restart, signal, unload, load, or modify `distnoted` or `launchd`;
- do not synthesize private Lion XPC dictionaries;
- do not enable all-session posting;
- do not forward `sux=true`;
- do not forward suspend or session_reset;
- do not patch CoreFoundation, Foundation, HIToolbox, libSystem, libxpc, Rosetta, dyld, a shared cache, or XNU.

The Lion proof intentionally performs one isolated registration, one current-session post, one callback, and one unregister through the native broker.

## Phase A — update current main

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm all prepared files listed above exist.

## Phase B — build PPC proof artifacts on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime
/bin/bash ./scripts/build-ppc-distributed-notifications-ingress-on-snowleopard.sh \
  ./ppc-distributed-notifications-ingress-probe-private-dyld \
  ./ppc-distributed-notifications-ingress-interposer.dylib
```

Require creation of the two PPC binaries plus their `.sha256` and `.info.txt` files. The builder must report each artifact as a thin 32-bit PPC-family Mach-O using `lipo -info`/`file`. `ppc7400` and the other documented 32-bit PowerPC subtype names are valid family members and must not be confused with `ppc64`; the builder normalizes this distinction explicitly. The interposer must carry build ID version 2, import `__NSGetEnviron`, and contain no direct `_environ` import; the build script enforces these conditions.

If the linker still reports `_environ`, or if the rebuilt artifact is not reported by `lipo -info` as a recognized 32-bit PowerPC family member (for example `ppc` or `ppc7400`), stop and return the exact Phase B output. Do not continue to Phase C.

Do not rebuild the PPC artifacts on Lion.

## Phase C — Snow Leopard passthrough control

Still on Snow Leopard, using the newly rebuilt version-2 interposer:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-distributed-notifications-ingress-control.sh \
  ./ppc-distributed-notifications-ingress-probe-private-dyld \
  ./ppc-distributed-notifications-ingress-interposer.dylib \
  ./distributed-notifications-ppc-ingress-snowleopard-control.txt
```

Require:

```text
Created: ./distributed-notifications-ppc-ingress-snowleopard-control.txt
RESULT: PASS
```

The control must show:

```text
mode=passthrough
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:PASSTHROUGH kr=0
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_REGISTER:behavior=4
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_POST:options=0x1
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_CALLBACK_SUMMARY:count=1 valid=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_RESULT:PASS
protected_hashes_unchanged=YES
RESULT: PASS
```

It must **not** contain `PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY`.

If Snow fails, stop and return only the Snow report.

## Phase D — transfer the Snow-built PPC artifacts to Lion

Transfer these exact files without rebuilding them:

```text
ppc-distributed-notifications-ingress-probe-private-dyld
ppc-distributed-notifications-ingress-probe-private-dyld.sha256
ppc-distributed-notifications-ingress-interposer.dylib
ppc-distributed-notifications-ingress-interposer.dylib.sha256
```

Place them under a convenient Lion path, for example `lion-rosetta-runtime/payload/`.

The Lion runner verifies the hashes before launch.

## Phase E — build the native i386 broker on Lion

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
/bin/bash ./scripts/build-lion-native-distributed-notifications-ppc-ingress-broker.sh \
  ./native-distributed-notifications-ppc-ingress-broker
```

Require creation of:

```text
native-distributed-notifications-ppc-ingress-broker
native-distributed-notifications-ppc-ingress-broker.sha256
native-distributed-notifications-ppc-ingress-broker.info.txt
```

## Phase F — Lion PPC ingress / native broker proof

Run from the logged-in Aqua console user's Terminal session.

As with the prior Rosetta proof runners, set the already-established expected Lion kernel hash:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<your established Lion kernel SHA-256>'
```

Then run:

```sh
/bin/bash ./scripts/run-lion-ppc-distributed-notifications-ingress-proof.sh \
  ./payload/ppc-distributed-notifications-ingress-probe-private-dyld \
  ./payload/ppc-distributed-notifications-ingress-probe-private-dyld.sha256 \
  ./payload/ppc-distributed-notifications-ingress-interposer.dylib \
  ./payload/ppc-distributed-notifications-ingress-interposer.dylib.sha256 \
  ./native-distributed-notifications-ppc-ingress-broker \
  ./native-distributed-notifications-ppc-ingress-broker.sha256 \
  ./distributed-notifications-ppc-ingress-lion.txt
```

Require:

```text
RESULT: DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_PROOF_PASS
RESULT: PASS
```

The report must prove:

```text
legacy .2 lookup intercepted exactly
local process-only service port returned
native i386 broker spawned
one legacy register Mach request forwarded
legacy behavior 1 -> public behavior 4
one current-session immediate post forwarded
one Lion public CF callback received
one legacy 0x13 / id-4 callback sent to PPC
unchanged PPC callback validated exactly once
one unregister forwarded
broker rejects = 0
legacy Mach requests = 3
legacy Mach callbacks = 1
broker exit = 0
protected hashes unchanged
probe exit = 0
```

If Lion fails, stop. Do not broaden the broker, retry the Process Manager subject, or add any launchd registration.

## Phase G — return evidence and stop

Return only:

```text
distributed-notifications-ppc-ingress-snowleopard-control.txt
distributed-notifications-ppc-ingress-lion.txt
```

Stop after Phase G.

## Decision gate after this proof

If both reports pass, the entire distributed-notification compatibility chain will have been proven independently:

```text
Snow PPC legacy request generation
-> exact process-local .2 interception
-> legacy Mach envelope receive
-> binary-plist transport across private socketpair
-> native i386 public CFNotificationCenter broker
-> Lion @Uv3 native path
-> native callback
-> reconstructed Snow callback dictionary
-> legacy callback Mach envelope
-> unchanged Snow PPC callback handler
```

Only after that result is reviewed should the adapter be merged into the normal Process Manager compatibility stack and `CreateNewWindow` retried.

That later integration must preserve the same exact service predicate and proof-name-independent protocol guards, and it must remain process-local. It must not create a system-wide `.2` service.

If either report fails, the integration stage is not authorized.

## Current boundary

```text
native broker proof                            -> PASS on Snow and Lion
PPC legacy request envelope                    -> proven
PPC callback envelope                          -> proven
cross-architecture IPC                         -> prepared via inherited socketpair
global legacy service                          -> not used
raw Lion XPC synthesis                         -> not used
real PPC Process Manager subject               -> not used
current next step                              -> standalone PPC ingress/native broker proof
CreateNewWindow integration                    -> not yet authorized
XNU                                            -> unchanged
```
