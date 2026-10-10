# Distributed notifications bridge preflight audit

## Objective

Close the final static gate before a standalone distributed-notifications compatibility proof.

Analyzer v1 has now passed on Snow Leopard and Lion. Its decisive result is architectural: Lion's XPC implementation is available to native i386/x86_64 code, but no inspected Lion library exposes a PowerPC slice with the required XPC connection-create/send surface. A translated PPC process therefore must not attempt to synthesize Lion XPC messages in-process.

The selected design is a **native i386 broker**, but the broker should also avoid reimplementing Lion's private XPC dictionary contract. Instead it should reconstruct the equivalent **public CoreFoundation distributed-notification API calls** in native i386 code and let Lion CoreFoundation own its private XPC protocol, option quirks, connection lifecycle, and callback dispatch.

Analyzer v2 remains static/read-only. It proves that this public-API reconstruction boundary is valid and constrains the first proof to the subset whose semantics are already grounded.

## Reviewed analyzer-v1 result

Both v1 reports passed.

### Architecture is closed

Snow Leopard:

- PPC CoreFoundation has no XPC create/send imports.
- Snow libSystem provides PPC code but no XPC connection-create/send surface.
- no standalone libxpc exists at the inspected Snow paths.

Lion:

- native i386 CoreFoundation imports XPC connection-create/send.
- `/usr/lib/system/libxpc.dylib` is i386/x86_64 and provides native XPC create/send.
- Lion libSystem and libxpc expose no PPC slice.
- `ppc_callable_xpc_surface=NO`.

Therefore:

```text
in-process PPC raw-XPC bridge          -> rejected
native i386 broker/helper              -> required
raw private Lion XPC synthesis         -> unnecessary for first proof
native Lion public CF notification API -> selected broker boundary
```

### Why the v1 semantic warning did not authorize a bridge yet

The v1 report printed the relevant disassembly, but it did not resolve enough addressed protocol constants or cross-check the Snow i386 server path to turn these observations into explicit gates:

- public `CFNotificationSuspensionBehavior` -> Snow internal `behavior` mapping;
- public post option bits -> Snow `immediately` and session scope;
- how the first proof should treat the legacy `sux` field;
- whether Lion's public AddObserver/PostWithOptions paths really feed the native private distributed-notification implementation.

Analyzer v2 adds those checks.

## Selected translation strategy

The broker should translate the proven Snow v2 request into Lion's **public** distributed notification API rather than constructing the Lion XPC dictionary itself.

### Registration

Snow's public API encodes suspension behavior into the private v2 `behavior` field as:

```text
public DeliverImmediately (1) -> legacy internal 2
public Drop               (2) -> legacy internal 4
public Coalesce           (3) -> legacy internal 8
public Hold               (4) -> legacy internal 1
```

The broker can invert that mapping:

```text
legacy internal 1 -> public Hold               (4)
legacy internal 2 -> public DeliverImmediately (1)
legacy internal 4 -> public Drop               (2)
legacy internal 8 -> public Coalesce           (3)
```

The broker then calls Lion's native `CFNotificationCenterAddObserver`. Lion CoreFoundation converts the public suspension behavior into whatever private XPC `options` representation Lion requires and owns the native registration token internally.

The bridge must separately retain the Snow `entry/counter` identity so a Lion callback can be reconstructed as the unchanged Snow callback dictionary.

### Posting

Snow's private post path derives:

```text
public option bit 0 (0x1) -> immediately
public option bit 1 (0x2) -> all-session scope
```

The first proof is deliberately narrower:

- current-session posts only;
- preserve only public option bit 0 as the immediate-delivery option;
- reject all-session posts (bit 1) rather than guessing a cross-session Lion mapping;
- require the legacy `sux` condition to be false/ordinary; reject true or unrecognized `sux` semantics.

The broker then calls Lion's native `CFNotificationCenterPostNotificationWithOptions`.

### Callback and unregister state

The previously reviewed ABI still supplies the bridge state model:

```text
Snow register (entry,counter)
       -> broker registration record
       -> Lion public CF observer

Lion public CF callback
       -> look up broker record
       -> Snow post callback dictionary with stored entry/counter

Snow unregister entries[]
       -> remove the corresponding broker observer records
       -> Lion public CF remove-observer operation
```

The first proof therefore does not need to fabricate Lion private XPC tokens or copy the `tokens[]` wire format itself.

### Operations intentionally excluded from the first proof

Reject and log, without forwarding:

- `session_reset` — Lion's analogous reset path is loginwindow-only;
- `suspend` / `unsuspend` — not needed for the minimum register/post/callback/unregister proof;
- all-session posts;
- `sux=true` or any unknown `sux` form;
- unknown legacy `message_type` values.

## Prepared analyzer v2

Current runtime `main` provides:

```text
scripts/audit-distributed-notifications-bridge-preflight.py
docs/distributed-notifications-bridge-preflight-audit.md
```

The analyzer reports:

```text
analyzer_version=2
```

It is Python-2.6-compatible and performs no live notification, bootstrap, Mach, MIG, or XPC operation.

### Snow Leopard coverage

It analyzes both:

- PPC CoreFoundation — actual translated client semantics;
- i386 CoreFoundation — native Snow server-side parsing/callback semantics.

Required PPC targets:

```text
_CFNotificationCenterAddObserver
_CFNotificationCenterPostNotificationWithOptions
__CFXNotificationPostNotification
__CFXNotificationRegister
__CFXNotificationUnregister
```

Required Snow i386 server targets:

```text
___CFXNotificationReceiveFromClient
___CFXNotificationHandleMessage
```

It resolves addressed `__cstring` / `__cfstring` references and validates:

```text
public_behavior_1_to_legacy_internal_2=YES
public_behavior_2_to_legacy_internal_4=YES
public_behavior_3_to_legacy_internal_8=YES
public_behavior_4_to_legacy_internal_1=YES
public_post_options_passed_to_private_sender=YES
post_option_bit_0_controls_immediately=YES
post_option_bit_1_controls_session_scope=YES
```

The report also prints `sux` reference counts and the conservative first-proof policy.

### Lion coverage

Required Lion i386 CoreFoundation targets:

```text
_CFNotificationCenterAddObserver
_CFNotificationCenterPostNotificationWithOptions
__CFXNotificationRegisterObserver
__CFXNotificationPost
___checkDelivImmed
```

The analyzer validates:

```text
public_addobserver_routes_to_native_register=YES
public_post_with_options_routes_to_native_post=YES
native_checkDelivImmed_present=YES
broker_translation_layer=Snow-v2 dictionary -> Lion public CFNotificationCenter API
raw_lion_xpc_dictionary_synthesis=NO
native_corefoundation_owns_xpc_option_quirks=YES
```

It retains the library architecture matrix and must still show on Lion:

```text
ppc_callable_xpc_surface=NO
selected_bridge_architecture=native_i386_broker_using_Lion_public_CFNotificationCenter_API
```

## Safety constraints

For analyzer v2:

- do not launch any PowerPC application;
- do not run the Rosetta subject;
- do not call a notification-center API dynamically;
- do not create or send an XPC message;
- do not issue a bootstrap lookup or Mach request;
- do not register, post, remove, suspend, or deliver a notification;
- do not create a synthetic legacy notification port;
- do not build or launch the native broker yet;
- do not rerun the failed standalone `.2` lookup;
- do not rerun the retired native service-selection tracer;
- do not load a compatibility dylib into the real PPC subject;
- do not retry `CreateNewWindow`;
- do not restart, signal, unload, load, or modify `distnoted` or `launchd`;
- do not patch CoreFoundation, Foundation, HIToolbox, libSystem, Rosetta, dyld, any shared cache, or XNU.

Temporary architecture slices are created only under the system temporary directory and removed on exit.

## Phase A — update runtime main

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-distributed-notifications-bridge-preflight.py
docs/distributed-notifications-bridge-preflight-audit.md
```

## Phase B — Snow Leopard analyzer-v2 preflight

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-bridge-preflight.py \
  ./distributed-notifications-bridge-preflight-snowleopard.txt
```

Require:

```text
Created: ./distributed-notifications-bridge-preflight-snowleopard.txt
No PowerPC application was launched and no system state was modified.
RESULT: PASS
```

The report must contain:

```text
analyzer_version=2
product_version=10.6.8
public_behavior_1_to_legacy_internal_2=YES
public_behavior_2_to_legacy_internal_4=YES
public_behavior_3_to_legacy_internal_8=YES
public_behavior_4_to_legacy_internal_1=YES
public_post_options_passed_to_private_sender=YES
post_option_bit_0_controls_immediately=YES
post_option_bit_1_controls_session_scope=YES
first_proof_sux_policy=require_false; reject true/unknown
first_proof_post_scope=current-session only; reject all-session
```

If Phase B fails, stop and return only the Snow report.

## Phase C — Lion analyzer-v2 preflight

Only after Snow passes, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-bridge-preflight.py \
  ./distributed-notifications-bridge-preflight-lion.txt
```

Require:

```text
Created: ./distributed-notifications-bridge-preflight-lion.txt
No PowerPC application was launched and no system state was modified.
RESULT: PASS
```

The report must contain:

```text
analyzer_version=2
product_version=10.7.5
public_addobserver_routes_to_native_register=YES
public_post_with_options_routes_to_native_post=YES
native_checkDelivImmed_present=YES
ppc_callable_xpc_surface=NO
selected_bridge_architecture=native_i386_broker_using_Lion_public_CFNotificationCenter_API
raw_xpc_bridge=REJECTED
first_proof_scope=register -> current-session post -> callback -> unregister
```

If an unexpected PPC XPC surface appears, stop and return the report; do not change architecture automatically.

## Phase D — return evidence and stop

Return only the regenerated analyzer-v2 reports:

```text
distributed-notifications-bridge-preflight-snowleopard.txt
distributed-notifications-bridge-preflight-lion.txt
```

Stop after Phase D.

## Decision gate after analyzer v2

If both reports pass with the required markers, the following stage may prepare a **standalone native i386 broker proof**. That proof may exercise only:

```text
legacy register
-> native Lion CF registration
-> current-session post
-> callback translation
-> unregister
```

It must have strict negative controls for the excluded operations and remain separate from `CreateNewWindow` and the real PPC application.

Do not integrate the broker into the Process Manager/window-system path until the standalone proof passes and its artifacts are reviewed.

## Current boundary

```text
Snow v2 wire                                  -> binary plist in legacy Mach envelope
Lion private wire                             -> XPC, owned by native Lion CoreFoundation
PPC-callable XPC on Lion                      -> none found
selected bridge architecture                  -> native i386 broker
selected translation boundary                 -> Lion public CFNotificationCenter APIs
raw private-XPC synthesis                     -> rejected
registration behavior mapping                 -> deterministic public-enum inversion
post immediate bit                            -> public option bit 0
all-session post                              -> reject in first proof
legacy sux                                    -> require ordinary/false; reject true/unknown
session_reset                                 -> reject in first proof
suspend/unsuspend                             -> defer from first proof
next step                                     -> rerun static bridge preflight analyzer v2
```

No XNU change is indicated.
