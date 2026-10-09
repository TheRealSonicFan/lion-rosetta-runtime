# Distributed notifications protocol schema audit

## Objective

Resolve the exact field/key mapping needed for a narrow process-local compatibility bridge between the Snow Leopard distributed-notifications v2 client protocol and Lion's selected current-user `@Uv3` v3 XPC service.

The completed protocol differential closes the name-only branch. Snow PPC CoreFoundation does not merely look up a differently named service: its private `___CFXNotificationSendToServer` path serializes a CF property-list dictionary, constructs a Mach message with legacy message ID `0x1413`, and sends it with `mach_msg`. The Snow implementation also contains explicit `SendToServer`, `ReceiveFromServer`, `SendToClient`, and `ReceiveFromClient` protocol functions.

Lion's corresponding distributed-notification client path instead builds XPC dictionaries and sends them through an XPC connection. The Lion `distnoted` executable imports XPC dictionary/array and connection send primitives; its stripped i386 executable does not expose the Snow private Mach server entry-point symbol family. Therefore a process-local `.2 -> @Uv3` bootstrap service-name rewrite by itself cannot preserve the Snow wire contract.

The next question is the exact semantic translation:

- Snow legacy binary-plist request keys and operation values from the PPC client, cross-checked against the i386 server-side CoreFoundation implementation;
- Snow callback/reply dictionary keys;
- Lion client XPC request keys and operation values for register, remove/unregister, and post;
- Lion `distnoted` XPC request/response keys and callback payloads;
- which values are strings, uint64 values, XPC data blobs, arrays, tokens, PIDs, flags, or serialized property-list objects.

No live adapter is authorized until those mappings are statically grounded.

## Prepared implementation

Current runtime `main` provides:

```text
scripts/audit-distributed-notifications-protocol-schema.py
docs/distributed-notifications-protocol-schema-audit.md
```

The analyzer is Python-2.6-compatible and static/read-only.

On Snow Leopard it inspects both the PPC CoreFoundation implementation used by the translated client and the i386 CoreFoundation implementation loaded by the native Snow `distnoted` server. It emits the same target family for both slices so request and callback constants can be checked across the actual client/server architectures.

The Snow target family is:

```text
___CFXNotificationSendToServer
___CFXNotificationHandleMessage
___CFXNotificationReceiveFromServer
__CFXNotificationPostNotification
__CFXNotificationPost
__CFXNotificationUnregister
__CFXNotificationRegister
___CFXNotificationSendToClient
___CFXNotificationReceiveFromClient
```

On Lion it inspects the i386 CoreFoundation client implementation and emits complete windows plus resolved constant references for:

```text
__CFXNotificationRegisterObserver
__CFXNotificationPost
___CFXNotificationCenterCreate
___CFXNotificationCenterSetupConnection
_____CFXNotificationCenterSetupConnection_block_invoke_1
__CFXNotificationRemoveObservers
___CFXNotificationPostToken
_____CFXNotificationPostToken_block_invoke_1
____CFXNotificationRegisterObserver_block_invoke_1
```

The analyzer reads Mach-O section metadata from temporary architecture slices, builds addressed `__cstring` and `__cfstring` maps, and resolves PIC-relative constant references in the selected PPC/i386 functions where possible.

For Lion `distnoted`, whose private text symbols are stripped, the analyzer additionally emits:

- the complete short addressed cstring inventory;
- focused XPC/Mach/bootstrap/MIG imports;
- Objective-C metadata from `otool -ov`;
- XPC dictionary/array/data/send callsite contexts with resolved nearby constants where possible;
- explicit validation markers showing whether the executable imports `mach_msg` or bootstrap lookup functions.

The report does not assume that identically named fields have identical semantics. The returned constants and callsites must be reviewed before an adapter schema is written.

## Safety constraints

For this stage:

- do not launch any PowerPC application;
- do not call `CFNotificationCenterGetDistributedCenter` dynamically;
- do not call `NSDistributedNotificationCenter` dynamically;
- do not issue any bootstrap lookup, Mach request, MIG request, or XPC request;
- do not post, register, remove, or intentionally deliver any distributed notification;
- do not rerun the native XPC service-selection trace;
- do not rerun the failed standalone `.2` lookup;
- do not integrate a `.2 -> @Uv3` name rewrite;
- do not create a synthetic notification server port yet;
- do not call `CreateNewWindow`;
- do not restart, signal, unload, load, or modify `distnoted` or `launchd`;
- do not edit launchd plists;
- do not patch CoreFoundation, Foundation, HIToolbox, distnoted, libSystem, Rosetta, dyld, or any shared cache;
- do not broaden the existing Rosetta compatibility interposer;
- do not change XNU.

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
scripts/audit-distributed-notifications-protocol-schema.py
docs/distributed-notifications-protocol-schema-audit.md
```

The reports must begin with:

```text
analyzer_version=1
selected_lion_service=com.apple.distributed_notifications@Uv3
protocol_boundary=name-only translation rejected by prior differential
```

## Phase B — Snow Leopard schema audit

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-protocol-schema.py \
  ./distributed-notifications-protocol-schema-snowleopard.txt
```

Require:

```text
Created: ./distributed-notifications-protocol-schema-snowleopard.txt
No PowerPC application was launched and no system state was modified.
RESULT: PASS
```

If Phase B fails, stop and return only the Snow report.

## Phase C — Lion schema audit

Only after Snow Phase B passes, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-protocol-schema.py \
  ./distributed-notifications-protocol-schema-lion.txt
```

Require the same completion messages and `RESULT: PASS`.

The Lion validation section will also state:

```text
lion_distnoted_imports_mach_msg=...
lion_distnoted_imports_bootstrap_lookup=...
```

These are evidence markers, not pass/fail requirements. Do not infer a legacy server path solely from CoreFoundation's generic Mach imports; the selected `distnoted` XPC server callsites and exact protocol constants are the relevant evidence.

## Phase D — return evidence and stop

Return only:

```text
distributed-notifications-protocol-schema-snowleopard.txt
distributed-notifications-protocol-schema-lion.txt
```

Stop after Phase D.

## Result interpretation

The returned schema reports will choose the next engineering branch:

- If the Snow register/remove/post dictionaries and Lion XPC register/remove/post messages can be mapped completely, including callback/token semantics, the following stage can prepare a **standalone proof-only process-local bridge**. That bridge would own a local Mach receive right for the legacy Snow client, translate only the proven v2 envelopes into the selected `@Uv3` XPC schema, translate callbacks back into the Snow binary-plist Mach envelope, and remain isolated from the normal Rosetta subject until controls pass.
- If request mapping is complete but callback/reply mapping is incomplete, the next stage must resolve the callback schema before any bridge is executed.
- If stripped Lion server code still leaves key semantics ambiguous after this audit, use a narrowly scoped native Lion payload-observation experiment for only the missing fields. Do not guess field meanings from string names or numeric values.

The bridge must not be designed as a global `distnoted` replacement and must not modify launchd state.

## Current boundary

```text
Snow service                                   -> com.apple.distributed_notifications.2
Lion selected service                           -> com.apple.distributed_notifications@Uv3
Snow post-lookup transport                      -> binary-plist payload in legacy Mach messages
Snow legacy request message ID                  -> 0x1413
Lion client transport                           -> XPC dictionaries / XPC connection
Lion distnoted transport surface                -> XPC dictionary/array/send primitives
simple service-name translation                 -> insufficient
next step                                       -> static v2/v3 protocol schema/key mapping
```

No XNU change is indicated.
