# Lion native distributed-notifications service-selection trace

## Objective

Resolve the remaining Lion client-selection ambiguity without launching a PowerPC process and without posting, registering, or removing any distributed notification.

The reviewed analyzer-v3 reports establish:

- Snow Leopard PPC Foundation `defaultCenter` / `notificationCenterForType:` are present and the local distributed-center type reaches `__CFXNotificationGetHostCenter`;
- Lion Foundation follows the same high-level host-center path for its ordinary distributed notification center;
- Lion `CFNotificationCenterGetDistributedCenter` initializes through `___CFXNotificationCenterCreate`;
- Lion CoreFoundation contains both `com.apple.distributed_notifications@Uv3` and `com.apple.distributed_notifications@1v3`;
- the static cstring-reference pass still reports zero direct references for both names.

That leaves one unresolved fact: which service name Lion actually supplies when the ordinary native distributed center establishes its XPC connection.

This experiment observes that choice in a native i386 Lion process by interposing only `xpc_connection_create`, logging distributed-notification service names, and forwarding the original call unchanged.

## Prepared implementation

Current runtime `main` provides:

```text
tests/native-distributed-notifications-service-selection-probe.m
tests/native-distributed-notifications-xpc-trace-interposer.c
scripts/build-lion-native-distributed-notifications-service-selection.sh
scripts/run-lion-native-distributed-notifications-service-selection.sh
docs/distributed-notifications-native-service-selection-trace-experiment.md
```

The native probe has two fresh-process modes:

```text
cf          -> CFNotificationCenterGetDistributedCenter()
foundation  -> [NSDistributedNotificationCenter defaultCenter]
```

Neither mode posts, registers, removes, or deliberately delivers a notification.

The trace dylib interposes only `xpc_connection_create`. It does not rewrite the name, flags, target queue, return value, or any later message; it logs names beginning with `com.apple.distributed_notifications` and forwards the original call.

The runner requires the CF and Foundation modes to select exactly one distinct distributed-notifications service each, requires the two modes to agree, and accepts only the two Lion client-side candidates already established by the static audit:

```text
com.apple.distributed_notifications@Uv3
com.apple.distributed_notifications@1v3
```

It does not assume which one will win.

## Safety constraints

For this stage:

- run on Lion 10.7.5 only;
- run from the logged-in Aqua console user's Terminal session;
- do not launch any PowerPC application;
- do not run the Rosetta subject;
- do not call `CreateNewWindow`;
- do not post, register, remove, or intentionally deliver any distributed notification;
- do not interpose or rewrite `bootstrap_look_up2`;
- do not change any distributed-notification service name;
- do not synthesize a Mach port or XPC connection;
- do not restart, signal, unload, load, or modify `distnoted` or `launchd`;
- the existing Lion `distnoted daemon` and per-user `distnoted agent` must already be running; the runner refuses to use this trace to launch either one and requires the same distnoted PID/role set before and after;
- do not edit launchd plists;
- do not patch Foundation, CoreFoundation, HIToolbox, Rosetta, dyld, libSystem, the Rosetta cache, or any system binary;
- do not broaden the accepted Rosetta compatibility interposer;
- do not change XNU.

## Phase A — update runtime main

On Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm that the five prepared files listed above are present.

## Phase B — build the native i386 probe and trace dylib

From the runtime repository root on Lion:

```sh
./scripts/build-lion-native-distributed-notifications-service-selection.sh \
  ./native-distributed-notifications-service-selection-probe \
  ./native-distributed-notifications-xpc-trace.dylib
```

Require both artifacts to be reported as built and as i386 Mach-O files.

The build script also requires these embedded provenance markers:

```text
PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_BUILD_ID:distributed-notifications-native-service-selection-probe-v1
PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_TRACE_BUILD_ID:distributed-notifications-native-xpc-trace-v1
```

If Phase B fails, stop and return the terminal output; do not run Phase C.

## Phase C — run the native service-selection trace

Before running, confirm you are in the same logged-in Aqua session used for the namespace audit. The runner will verify that both the existing `distnoted daemon` and `distnoted agent` are already active and will fail rather than trigger this experiment when either is absent.

Ensure these variables are unset before the runner:

```sh
unset DYLD_INSERT_LIBRARIES
unset DYLD_FORCE_FLAT_NAMESPACE
unset PM_DISTNOTIFY_PROBE_MODE
```

Then run:

```sh
./scripts/run-lion-native-distributed-notifications-service-selection.sh \
  ./native-distributed-notifications-service-selection-probe \
  ./native-distributed-notifications-xpc-trace.dylib \
  ./distributed-notifications-native-service-selection-lion.txt
```

The report must contain successful probe completion for both modes and trace records of this form:

```text
PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_CREATE:mode=CF name=...
PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_CREATE:mode=FOUNDATION name=...
```

For a passing run, the report will also contain:

```text
cf_distinct_service_count=1
foundation_distinct_service_count=1
selected_service=...
RESULT: PASS
```

The runner fails rather than guessing if the pre-existing distnoted daemon/agent are absent or change PID/role set, no service is observed, more than one distinct service is observed in either mode, the two modes disagree, or a service outside the two statically established Lion candidates appears.

Do not run the PPC subject or another lookup after this trace.

## Phase D — return evidence and stop

Return only:

```text
distributed-notifications-native-service-selection-lion.txt
```

Stop after Phase D.

## Result interpretation

- If `selected_service=com.apple.distributed_notifications@Uv3`, the next stage will compare the Snow v2 distributed-notification client/server contract against Lion's `@Uv3` v3 contract before any process-local `.2 -> @Uv3` compatibility translation is considered.
- If `selected_service=com.apple.distributed_notifications@1v3`, the protocol comparison will target `@1v3` instead.
- If the runner reports disagreement or no observed service, do not infer a target. The trace mechanism or mode semantics must be refined first.

Even a successful service-selection trace does not establish wire compatibility between Snow v2 and Lion v3.

## Current boundary

```text
Snow legacy service                             -> com.apple.distributed_notifications.2
Snow ordinary Foundation center                 -> __CFXNotificationGetHostCenter path
Lion ordinary Foundation center                 -> __CFXNotificationGetHostCenter path
Lion CF distributed-center initializer          -> ___CFXNotificationCenterCreate
Lion client service strings                     -> @Uv3 and @1v3
static direct cstring references                 -> unresolved / zero
next step                                       -> native Lion XPC service-selection trace
```

No XNU change is indicated.
