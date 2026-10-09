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

## Reviewed analyzer-v1 result

Both returned analyzer-v1 reports passed their structural validation, but they do **not** yet prove which Lion v3 service is selected.

The useful v1 evidence is:

- Snow PPC `CFNotificationCenterGetDistributedCenter` remains the legacy path and returns through `__CFXNotificationGetHostCenter`;
- Lion `CFNotificationCenterGetDistributedCenter` instead uses `dispatch_once`;
- Lion contains a private `___CFNotificationCenterGetDistributedCenter_block_invoke_1` initializer that calls `xpc_connection_create`, `xpc_connection_set_legacy`, and `xpc_connection_set_privileged`;
- Lion contains both `com.apple.distributed_notifications@1v3` and `com.apple.distributed_notifications@Uv3`;
- however the v1 cstring-reference scan reports zero direct references for both Lion service strings;
- v1 emitted only the public getter window, not the complete private initializer block that actually creates the Lion connection;
- v1 also listed Foundation's `defaultCenter` and `notificationCenterForType:` symbols without emitting their complete bodies.

A PASS from analyzer v1 therefore means only that the intended binaries and broad targets were captured. It is insufficient to choose `@Uv3` or `@1v3`.

The previously reviewed `main` upgraded the analyzer to version 2. Version 2 emits the complete Lion private distributed-center initializer and the complete Foundation `defaultCenter` / `notificationCenterForType:` windows, and makes those exact targets part of the required evidence. This is still a static/read-only audit; no live lookup is added.

Discard or overwrite the v1 reports and rerun the documented Snow and Lion phases with current `main`.

## Reviewed analyzer-v2 Phase B failure

The Snow Leopard analyzer-v2 failure is a parser false negative, not missing Foundation functionality.

The v2 report itself contains the PPC text symbols:

```text
+[NSDistributedNotificationCenter defaultCenter]
+[NSDistributedNotificationCenter notificationCenterForType:]
```

but the analyzer reported both exact-target counts as zero and failed validation. The cause was `parse_symbols()`: it used the final whitespace-delimited token from each `nm -nm` row as the symbol name. That works for ordinary C symbols, but truncates Objective-C method names containing spaces; for example `+[NSDistributedNotificationCenter defaultCenter]` was recorded only as `defaultCenter]`.

Current `main` fixes that parser by preserving the complete symbol name following the `(__TEXT,__text)` scope/type fields and advances the analyzer marker to version 3. The evidence requirements are unchanged; only symbol-name parsing is corrected. Snow still runs first, and Lion must not be run unless the corrected Snow report passes.

Discard or overwrite the analyzer-v2 Snow report and rerun Phase B with current `main`.

## Reviewed analyzer-v3 result

The corrected analyzer-v3 reports pass on both Snow Leopard and Lion and close the parser issue, but the static evidence still does not identify the final Lion service name.

The decisive v3 observations are:

- Snow PPC Foundation's ordinary distributed-center path reaches `__CFXNotificationGetHostCenter`;
- Lion Foundation's `notificationCenterForType:` likewise reaches `__CFXNotificationGetHostCenter` for the ordinary local distributed-center type;
- Lion `CFNotificationCenterGetDistributedCenter` uses a one-time initializer whose private block calls `___CFXNotificationCenterCreate`;
- Lion CoreFoundation still contains both `com.apple.distributed_notifications@1v3` and `com.apple.distributed_notifications@Uv3`;
- the static cstring-reference scan reports zero direct references for both names in both Lion architecture slices.

Therefore the static audit has reached its intended ambiguity branch. Do **not** choose a replacement from the suffixes. The next discriminator is the native Lion trace in:

```text
docs/distributed-notifications-native-service-selection-trace-experiment.md
```

That experiment launches only native i386 Lion probe processes, observes the service name passed to `xpc_connection_create`, forwards the call unchanged, and performs no notification post/register/remove operation.

## Prepared implementation

Current runtime `main` provides:

```text
scripts/audit-distributed-notifications-client-service-selection.py
docs/distributed-notifications-client-service-selection-audit.md
```

The analyzer is Python 2.6-compatible, read-only, and currently reports `analyzer_version=3`. It examines CoreFoundation and Foundation on Snow Leopard and Lion, including:

- binary and architecture provenance;
- addressed distributed-notifications service cstrings;
- static references to those cstring addresses when visible in `otool` disassembly;
- imports and symbols involving distributed notifications, bootstrap lookup, Mach messaging, XPC, and notification-center APIs;
- complete symbol windows, when available, for:
  - `CFNotificationCenterGetDistributedCenter`;
  - Lion's private `___CFNotificationCenterGetDistributedCenter_block_invoke_1` initializer when present;
  - observer add/remove operations;
  - notification posting operations;
- complete Foundation windows for `+[NSDistributedNotificationCenter defaultCenter]` and `+[NSDistributedNotificationCenter notificationCenterForType:]`.

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

The regenerated reports must begin with:

```text
analyzer_version=3
```

Do not submit analyzer-v1 or analyzer-v2 reports for this corrected rerun.

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

If Phase B reports `RESULT: FAIL`, stop. Otherwise confirm `analyzer_version=3` before continuing.

## Phase C — Lion static client audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-client-service-selection.py \
  ./distributed-notifications-client-service-selection-lion.txt
```

Require `analyzer_version=3`, the same completion messages, and `RESULT: PASS`.

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

Analyzer v3 reached the final ambiguity branch above. Proceed to `docs/distributed-notifications-native-service-selection-trace-experiment.md`; do not rerun the static audit unless that trace documentation explicitly asks for it. Even after the service identity is proven, do not assume v2 and v3 notification message layouts are wire-compatible merely because both endpoints are served by `distnoted`.

## Current boundary

```text
Snow service model                              -> one system distnoted / com.apple.distributed_notifications.2
Lion system daemon services                     -> @0v3 and @1v3
Lion per-user agent service                     -> @Uv3
Lion current-user launchd job                   -> com.apple.distnoted.xpc.agent
Snow CoreFoundation client string               -> .2
Lion CoreFoundation client strings              -> @Uv3 and @1v3
failed Lion .2 native-format lookup              -> BOOTSTRAP_UNKNOWN_SERVICE (1102)
next step                                       -> native Lion XPC service-selection trace
```

No additional XNU change is indicated.
