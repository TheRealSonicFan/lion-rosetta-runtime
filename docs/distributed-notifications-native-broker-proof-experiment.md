# Distributed notifications native broker proof experiment

## Objective

Prove the selected compatibility boundary before any translated PowerPC client is connected to it.

The completed bridge-preflight analyzer v2 passed on both systems and closed the static design gate:

- Lion has no PPC-callable XPC create/send surface;
- the bridge must therefore use native i386 code;
- the native component should reconstruct Lion's public CoreFoundation distributed-notification API calls rather than synthesize private XPC dictionaries;
- Snow's public suspension-behavior conversion and post option bits are now explicit;
- the first proof is limited to register -> current-session post -> callback -> unregister;
- suspend, session_reset, all-session posting, and sux=true remain excluded.

This stage is the first live distributed-notification compatibility proof after the static audits. It is still **standalone**: it launches no PowerPC program, does not expose a synthetic `com.apple.distributed_notifications.2` Mach service, does not alter launchd, and does not call `CreateNewWindow`.

## Important enum-label correction

Analyzer v2 proved the Snow numeric conversion:

```text
public behavior 1 -> legacy internal 2
public behavior 2 -> legacy internal 4
public behavior 3 -> legacy internal 8
public behavior 4 -> legacy internal 1
```

CoreFoundation's public enum contract names those public values:

```text
1 -> Drop
2 -> Coalesce
3 -> Hold
4 -> DeliverImmediately
```

Therefore the correct inverse conversion for a v2 request is:

```text
legacy internal 1 -> DeliverImmediately (4)
legacy internal 2 -> Drop               (1)
legacy internal 4 -> Coalesce           (2)
legacy internal 8 -> Hold               (3)
```

An earlier preflight-document draft attached the wrong names to the four already-correct numeric values. Current `main` corrects that wording. The proof program additionally checks the installed CoreFoundation enum/option values at runtime before registering any notification.

## What this proof tests

Current `main` provides:

```text
tests/native-distributed-notifications-broker-proof.c
scripts/build-native-distributed-notifications-broker-proof.sh
scripts/run-native-distributed-notifications-broker-proof.sh
docs/distributed-notifications-native-broker-proof-experiment.md
```

The proof is an i386 executable.

It uses synthetic dictionaries with the already-proven Snow v2 field names as broker input, but it does **not** send the Snow Mach/binary-plist wire protocol. The purpose of this stage is to prove the native broker's translation and callback state model independently from the future PPC ingress adapter.

The positive path is:

```text
synthetic Snow-v2 register dictionary
  message_type=register
  name/object
  behavior=1
  counter=<fixed proof counter>
  entry=<fixed proof entry>
        |
        | inverse Snow behavior conversion
        v
native CFNotificationCenterAddObserver
  suspensionBehavior=DeliverImmediately (4)
        |
        | child exec, same i386 proof binary
        v
synthetic Snow-v2 post dictionary
  message_type=post
  name/object/userinfo
  immediately=true
  sux=false
  normalized scope=current session
        |
        | public option conversion
        v
native CFNotificationCenterPostNotificationWithOptions
  options=kCFNotificationDeliverImmediately
        |
        | native distnoted / Lion CoreFoundation path
        v
public CF callback
        |
        | broker-owned registration state
        v
synthetic Snow-v2 callback dictionary
  message_type=post
  name/object/userinfo
  counter=<stored proof counter>
  entry=<stored proof entry>
        |
        v
CFNotificationCenterRemoveObserver
```

The child poster is created with `posix_spawn`, avoiding a post-fork CoreFoundation process state entirely. This makes the notification cross a process boundary rather than relying on same-process callback behavior.

## Negative controls

Before any distributed center is obtained, the proof verifies that the broker rejects all currently excluded inputs without making a notification API call:

```text
sux=true                 -> reject
all-session normalized scope -> reject
message_type=suspend     -> reject
message_type=session_reset -> reject
legacy behavior=3        -> reject as unsupported internal encoding
```

Required marker:

```text
negative_api_call_count=0
```

The current proof deliberately treats current/all-session scope as a **normalized ingress property**. It does not claim to identify Snow's raw all-session `sessionid` sentinel. That wire-ingress detail remains for the later PPC shim/IPC stage. No all-session public CoreFoundation call is made here.

## Snow Leopard control

Snow Leopard runs the same native i386 source as a control. Its public CoreFoundation API reaches Snow's native v2 implementation. This confirms that the proof harness, behavior inversion, callback reconstruction, and negative controls are valid before the Lion run.

## Lion target

Lion runs the identical native i386 proof. Its public CoreFoundation API reaches the already-audited `@Uv3` implementation, so a PASS establishes that the selected native broker boundary can perform the minimum register/post/callback/unregister lifecycle without directly constructing private XPC objects.

## Safety constraints

For this experiment:

- run only the provided native i386 proof;
- do not launch a PowerPC application;
- do not run the normal Rosetta subject;
- do not create a synthetic legacy Mach receive service;
- do not register or rewrite `com.apple.distributed_notifications.2` in launchd;
- do not call `bootstrap_register`, `bootstrap_check_in`, or a compatibility bootstrap lookup;
- do not synthesize Lion private XPC dictionaries;
- do not use `DYLD_INSERT_LIBRARIES`;
- do not call `CreateNewWindow`;
- do not restart, signal, unload, load, or modify `distnoted` or `launchd`;
- do not edit launchd plists;
- do not patch CoreFoundation, Foundation, HIToolbox, libSystem, libxpc, Rosetta, dyld, a shared cache, or XNU.

The proof intentionally performs one isolated distributed notification registration, one current-session post with a unique process-specific name, one callback, and one unregister. The runner verifies that protected framework/service binaries are unchanged.

## Phase A — update current main

On both systems:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
tests/native-distributed-notifications-broker-proof.c
scripts/build-native-distributed-notifications-broker-proof.sh
scripts/run-native-distributed-notifications-broker-proof.sh
docs/distributed-notifications-native-broker-proof-experiment.md
```

Do not reuse an older proof binary.

## Phase B — Snow Leopard build and control

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime
/bin/bash ./scripts/build-native-distributed-notifications-broker-proof.sh \
  ./native-distributed-notifications-broker-proof
```

Require the build to report the i386 binary and its SHA-256.

Then run:

```sh
/bin/bash ./scripts/run-native-distributed-notifications-broker-proof.sh \
  ./native-distributed-notifications-broker-proof \
  ./distributed-notifications-native-broker-proof-snowleopard.txt
```

Require:

```text
Created: ./distributed-notifications-native-broker-proof-snowleopard.txt
RESULT: PASS
```

The report must contain:

```text
proof_version=1
product_version=10.6.8
proof_arch=i386
translation_boundary=synthetic Snow-v2 dictionary -> native public CFNotificationCenter API
raw_private_xpc_synthesis=NO
ppc_subject_launched=NO
create_new_window_called=NO
enum_contract=PASS
negative_controls=PASS
negative_api_call_count=0
register_translation=PASS
poster_api_call_count=1
poster_result=PASS
post_translation=PASS
callback_translation=PASS
callback_count=1
callback_valid=YES
unregister_translation=PASS
positive_api_call_count=2
protected_hashes_unchanged=PASS
RESULT: DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_PASS
RESULT: PASS
```

If Snow fails, stop and return only the Snow report.

## Phase C — Lion build and proof

Only after the Snow control passes, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
/bin/bash ./scripts/build-native-distributed-notifications-broker-proof.sh \
  ./native-distributed-notifications-broker-proof
```

Then run:

```sh
/bin/bash ./scripts/run-native-distributed-notifications-broker-proof.sh \
  ./native-distributed-notifications-broker-proof \
  ./distributed-notifications-native-broker-proof-lion.txt
```

Require the same markers, with:

```text
product_version=10.7.5
```

If Lion fails, return the Lion report without retrying the PPC subject or broadening the proof.

## Phase D — return evidence and stop

Return only:

```text
distributed-notifications-native-broker-proof-snowleopard.txt
distributed-notifications-native-broker-proof-lion.txt
```

Stop after Phase D.

## Decision gate after this proof

If both reports pass, the native public-API broker boundary is proven. The following stage should then prepare a **process-local PPC ingress/IPC proof**, still separate from `CreateNewWindow`.

That later stage must prove only the missing cross-architecture edge:

```text
unchanged Snow PPC distributed-notification request
  -> narrow PPC-side interception for the exact legacy notification service path
  -> local private IPC to native i386 broker
  -> proven public Lion CFNotificationCenter operation
  -> broker callback
  -> local private IPC to PPC side
  -> unchanged Snow callback handling
```

It must not globally replace `distnoted`, publish a system-wide legacy service, or alter launchd state.

If the native broker proof fails, do not design the PPC ingress yet. Localize the failure to registration, posting, callback reconstruction, or unregister first.

## Current boundary

```text
preflight analyzer v2                         -> PASS on Snow and Lion
PPC-callable Lion XPC                         -> NO
native broker architecture                    -> REQUIRED
broker's Lion backend                         -> public CFNotificationCenter API
raw Lion XPC synthesis                        -> REJECTED
Snow legacy behavior 1                        -> public DeliverImmediately (4)
Snow legacy behavior 2                        -> public Drop (1)
Snow legacy behavior 4                        -> public Coalesce (2)
Snow legacy behavior 8                        -> public Hold (3)
post immediate                                -> kCFNotificationDeliverImmediately
post all sessions                             -> excluded from proof
sux=true                                      -> excluded from proof
suspend/session_reset                         -> excluded from proof
current next step                             -> standalone native i386 broker lifecycle proof
CreateNewWindow integration                   -> not yet authorized
XNU                                           -> unchanged
```
