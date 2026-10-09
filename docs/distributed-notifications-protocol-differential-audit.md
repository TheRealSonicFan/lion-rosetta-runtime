# Distributed notifications Snow-v2 / Lion-v3 protocol differential audit

## Objective

Determine whether the Snow Leopard distributed-notifications client/server contract can be made compatible with Lion's selected current-user service by a narrow service-name/bootstrap adaptation, or whether the client/server message protocol itself changed and requires a separate compatibility layer.

The preceding service-selection work is now sufficient to fix the Lion target:

```text
com.apple.distributed_notifications@Uv3
```

The native Lion trace observed that exact name at the first `xpc_connection_create` reached from `CFNotificationCenterGetDistributedCenter`. The original trace interposer then recursively re-entered its own forwarding path and the probe terminated with status 139; that crash is a trace-tool defect, not evidence that another service was selected. Because the first call argument is already captured before the recursive forwarding failure, do not rerun the native trace merely to choose between `@Uv3` and `@1v3`.

The next question is protocol compatibility, not namespace selection.

## Prepared implementation

Current runtime `main` provides:

```text
scripts/audit-distributed-notifications-protocol-differential.py
docs/distributed-notifications-protocol-differential-audit.md
```

The analyzer is Python-2.6-compatible and static/read-only. It inspects:

- Snow Leopard PPC CoreFoundation, which is the actual translated client implementation;
- Snow Leopard i386 `/usr/sbin/distnoted`, the native server-side baseline;
- Lion i386 CoreFoundation, which implements the selected native v3 client path;
- Lion i386 `/usr/sbin/distnoted`, including the `@Uv3` service implementation.

For each relevant slice it records:

- binary provenance and dependencies;
- distributed-notification, Mach/bootstrap, MIG, XPC, property-list, dictionary, array, data, and string symbols/imports;
- focused transport callsite contexts around `bootstrap_look_up*`, `mach_msg`, MIG, XPC connection/send, XPC dictionary/array/data, and distributed-notification operations;
- complete windows for the public CF notification-center operations;
- complete windows for private `CFXNotification` symbols when named;
- focused server-side protocol symbols in `distnoted`.

The purpose is to establish whether Snow's post-lookup traffic is a legacy Mach/MIG contract while Lion's `@Uv3` path is an XPC-object contract, and whether Lion still contains a compatible legacy server entry point that could accept the Snow traffic unchanged.

## Safety constraints

For this stage:

- do not launch any PowerPC application;
- do not call `CFNotificationCenterGetDistributedCenter` dynamically;
- do not call `NSDistributedNotificationCenter` dynamically;
- do not issue any bootstrap lookup, Mach request, MIG request, or XPC request;
- do not post, register, remove, or intentionally deliver any distributed notification;
- do not rerun the native XPC trace;
- do not rerun the failed standalone `.2` lookup;
- do not call `CreateNewWindow`;
- do not restart, signal, unload, load, or modify `distnoted` or `launchd`;
- do not edit launchd plists;
- do not patch CoreFoundation, Foundation, HIToolbox, distnoted, libSystem, Rosetta, dyld, or any shared cache;
- do not broaden the accepted Rosetta compatibility interposer;
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
scripts/audit-distributed-notifications-protocol-differential.py
docs/distributed-notifications-protocol-differential-audit.md
```

## Phase B — Snow Leopard protocol audit

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-protocol-differential.py \
  ./distributed-notifications-protocol-differential-snowleopard.txt
```

Require:

```text
Created: ./distributed-notifications-protocol-differential-snowleopard.txt
No PowerPC application was launched and no system state was modified.
RESULT: PASS
```

If Phase B fails, stop.

## Phase C — Lion protocol audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-protocol-differential.py \
  ./distributed-notifications-protocol-differential-lion.txt
```

Require the same completion messages and `RESULT: PASS`.

The Lion report must identify:

```text
selected_lion_service=com.apple.distributed_notifications@Uv3
```

This is a provenance marker for the already-established target. The analyzer itself does not perform a lookup.

## Phase D — return evidence and stop

Return only:

```text
distributed-notifications-protocol-differential-snowleopard.txt
distributed-notifications-protocol-differential-lion.txt
```

Stop after Phase D.

## Result interpretation

The reports will choose the next branch:

- If Snow PPC client operations construct a legacy Mach/MIG protocol and Lion `@Uv3` server-side code exposes only XPC-object handling with no compatible legacy message entry point, a simple `.2 -> @Uv3` name rewrite is insufficient. The next stage must design a narrow process-local protocol adapter, not integrate a name translation by itself.
- If Lion `@Uv3` still exposes a legacy message path matching the Snow request/reply layouts, the next stage can prepare a standalone proof that translates only the bootstrap service identity and leaves the wire payload unchanged.
- If the static server-side evidence is incomplete because private symbols are stripped, the next discriminator should be a passive native Lion transport trace of a harmless center-construction/registration-free path or another narrowly scoped static extraction. Do not infer compatibility from `xpc_connection_set_legacy` alone.

No PPC subject or window-system retry is authorized by this audit.

## Current boundary

```text
Snow service                                   -> com.apple.distributed_notifications.2
Lion ordinary current-user service             -> com.apple.distributed_notifications@Uv3
native trace first observed XPC target          -> @Uv3
native trace failure                            -> tracer recursive forwarding / status 139
service identity ambiguity                      -> closed
wire/protocol compatibility                     -> unresolved
next step                                      -> static Snow-v2 / Lion-@Uv3 protocol differential
```

No XNU change is indicated.
