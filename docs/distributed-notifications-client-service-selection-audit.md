# Distributed notifications client service-selection audit

## Objective

Resolve which Lion v3 distributed-notifications service a normal GUI client selects before any compatibility name translation or second live bootstrap lookup is attempted.

The completed namespace audit establishes a real release-level service split rather than a namespace-only relocation:

Snow Leopard 10.6.8 has one system `distnoted` launch daemon exposing:

```text
com.apple.distributed_notifications.2
```

Lion 10.7.5 has a system `distnoted daemon` exposing:

```text
com.apple.distributed_notifications@0v3
com.apple.distributed_notifications@1v3
```

and a per-user `distnoted agent` exposing:

```text
com.apple.distributed_notifications@Uv3
```

The Lion user's launchctl namespace contains `com.apple.distnoted.xpc.agent`. Lion CoreFoundation contains `@Uv3` and `@1v3` client-side service strings, while `distnoted` itself contains all three v3 names. Snow CoreFoundation contains the legacy `.2` service string.

This is enough to reject a blind `.2 -> arbitrary v3 name` rewrite. The next step must prove the native client selection path first.

## Prepared implementation

Current runtime `main` provides:

```text
scripts/audit-distributed-notifications-client-service-selection.py
docs/distributed-notifications-client-service-selection-audit.md
```

The analyzer is Python 2.6-compatible and read-only. It examines CoreFoundation and Foundation on Snow Leopard and Lion, including:

- binary and architecture provenance;
- addressed distributed-notifications service cstrings;
- static references to those cstring addresses when visible in `otool` disassembly;
- imports and symbols involving distributed notifications, bootstrap lookup, Mach messaging, XPC, and notification-center APIs;
- complete symbol windows, when available, for:
  - `CFNotificationCenterGetDistributedCenter`;
  - observer add/remove operations;
  - notification posting operations;
- Foundation evidence around `NSDistributedNotificationCenter` and `notificationCenterForType:`.

The report is intended to identify whether ordinary per-user distributed-center construction selects `@Uv3`, whether `@1v3` is reserved for all-session behavior or another path, and whether native Lion client initialization has already moved beyond the Snow `.2` service contract.

A passing audit means the required binaries/slices and target evidence were captured; it does not itself authorize a name translation.

## Safety constraints

For this stage:

- do not launch the PPC test application;
- do not call `CFNotificationCenterGetDistributedCenter` or `NSDistributedNotificationCenter` dynamically;
- do not issue any bootstrap lookup or Mach request;
- do not post or register a distributed notification;
- do not rerun the failed Lion standalone lookup;
- do not call `CreateNewWindow`;
- do not restart, signal, or modify `distnoted` or `launchd`;
- do not edit launchd plists;
- do not patch Foundation, CoreFoundation, HIToolbox, Rosetta, dyld, libSystem, or the Rosetta cache;
- do not broaden the compatibility interposer;
- do not change XNU.

## Phase A — update runtime main

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-distributed-notifications-client-service-selection.py
docs/distributed-notifications-client-service-selection-audit.md
```

## Phase B — Snow Leopard static client audit

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-client-service-selection.py \
  ./distributed-notifications-client-service-selection-snowleopard.txt
```

Require:

```text
Created: ./distributed-notifications-client-service-selection-snowleopard.txt
No PowerPC application was launched and no system state was modified.
RESULT: PASS
```

If Phase B reports `RESULT: FAIL`, stop.

## Phase C — Lion static client audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-client-service-selection.py \
  ./distributed-notifications-client-service-selection-lion.txt
```

Require the same completion messages and `RESULT: PASS`.

Do not run a live lookup after the static audit.

## Phase D — return evidence and stop

Return only:

```text
distributed-notifications-client-service-selection-snowleopard.txt
distributed-notifications-client-service-selection-lion.txt
```

Stop after Phase D.

## Result interpretation

The returned static windows will choose the next branch:

- If ordinary Lion distributed-center initialization directly selects `com.apple.distributed_notifications@Uv3`, the following stage will compare the Snow v2 and Lion v3 client/server message contract before any process-local `.2 -> @Uv3` lookup translation is attempted.
- If ordinary initialization selects `@1v3`, the same protocol comparison will target that exact service instead.
- If `@Uv3` and `@1v3` are both used by distinct options (for example current-user versus all-session behavior), the compatibility target must be limited to the path equivalent to the Snow call reached by HIToolbox.
- If the static references remain ambiguous, the next discriminator will be a native Lion trace/probe that observes only service selection; do not guess the target from the suffixes.

Even after the service identity is proven, do not assume v2 and v3 notification message layouts are wire-compatible merely because both endpoints are served by `distnoted`.

## Current boundary

```text
Snow service model                              -> one system distnoted / com.apple.distributed_notifications.2
Lion system daemon services                     -> @0v3 and @1v3
Lion per-user agent service                     -> @Uv3
Lion current-user launchd job                   -> com.apple.distnoted.xpc.agent
Snow CoreFoundation client string               -> .2
Lion CoreFoundation client strings              -> @Uv3 and @1v3
failed Lion .2 native-format lookup              -> BOOTSTRAP_UNKNOWN_SERVICE (1102)
next step                                       -> static Snow/Lion client service-selection differential audit
```

No additional XNU change is indicated.
