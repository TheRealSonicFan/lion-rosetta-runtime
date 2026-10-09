# Distributed notifications service / bootstrap namespace audit

## Objective

Determine why Lion's native-format launchd lookup for the exact Snow-era distributed-notifications service returns a normal launchd error reply instead of a service send right.

The preceding standalone proof is decisive about the current boundary:

- the exact probe and interposer hashes matched on Lion;
- the Snow Leopard passthrough control resolved `com.apple.distributed_notifications.2` with `pid=0`, `flags=8`, and a live send right;
- Lion sent the already-proven launchd lookup request `0x194` with the expected `0xbc/0x6c` geometry;
- `mach_msg` returned success;
- launchd returned reply `0x1f8` as the normal simple-error envelope of size `0x24`;
- the raw PPC-visible result word was `0x4e040000`.

That raw word is the byte-swapped representation of `0x0000044e` (decimal 1102), the bootstrap `BOOTSTRAP_UNKNOWN_SERVICE` result. The current proof-only lookup helper reports the raw scalar without NDR byte-order normalization on this error path, so the logged decimal value `1308884992` must not be interpreted as a distinct launchd status.

The request reached launchd and was understood well enough to return the expected reply ID and error envelope. Therefore the next question is service identity and bootstrap namespace, not another request-layout change.

Earlier read-only system evidence already shows that Lion has both a system `/usr/sbin/distnoted daemon` and a per-user `/usr/sbin/distnoted agent`, while Snow Leopard's earlier process inventory showed the older `/usr/sbin/distnoted` form. This audit compares the launchd definitions, current namespace labels, process topology, and relevant binary/framework strings before any second live lookup is attempted.

## Prepared implementation

Current runtime `main` provides:

```text
scripts/audit-distributed-notifications-service-namespace.py
docs/distributed-notifications-service-namespace-audit.md
```

The analyzer is Python 2.6-compatible and read-only. It records:

- OS/build/user provenance;
- active `launchd` and `distnoted` process rows;
- matching jobs from the current user's read-only `launchctl list`;
- every matching plist under system/local LaunchDaemons and LaunchAgents;
- `/usr/sbin/distnoted` architecture, hash, linked libraries, and matching strings;
- matching distributed-notifications strings from Foundation and CoreFoundation.

The matching filter covers `distnoted`, distributed-notification service strings, distributed-notification APIs, and bootstrap lookup references.

## Safety constraints

For this stage:

- do not launch the PPC test application;
- do not rerun the standalone Lion lookup proof;
- do not call `CreateNewWindow`;
- do not send a distributed notification;
- do not run `launchctl start`, `stop`, `load`, `unload`, `submit`, or any equivalent mutating command;
- do not kill, restart, signal, or relaunch `distnoted` or `launchd`;
- do not edit any LaunchDaemon/LaunchAgent plist;
- do not patch Foundation, CoreFoundation, HIToolbox, launchd, distnoted, Rosetta, dyld, libSystem, or the Rosetta cache;
- do not broaden the compatibility interposer;
- do not change XNU.

The only launchctl operation performed by the prepared analyzer is the read-only current-namespace `launchctl list` query.

## Phase A — update runtime main

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-distributed-notifications-service-namespace.py
docs/distributed-notifications-service-namespace-audit.md
```

## Phase B — Snow Leopard audit

On the validated Snow Leopard 10.6.8 system, from the logged-in user's Terminal:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-service-namespace.py \
  ./distributed-notifications-service-namespace-snowleopard.txt
```

Require:

```text
Created: ./distributed-notifications-service-namespace-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If the analyzer reports `RESULT: FAIL`, stop and return that report.

## Phase C — Lion audit

On Lion 10.7.5, from the same Aqua console user context used by the failed Phase F proof:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-service-namespace.py \
  ./distributed-notifications-service-namespace-lion.txt
```

Require the same read-only completion messages and `RESULT: PASS`.

Do not rerun the PPC lookup proof after this audit.

## Phase D — return evidence and stop

Return only:

```text
distributed-notifications-service-namespace-snowleopard.txt
distributed-notifications-service-namespace-lion.txt
```

Stop after Phase D.

## Reviewed result

Both reports passed and establish a concrete Snow-to-Lion service-model change.

Snow Leopard 10.6.8 runs one system `/usr/sbin/distnoted` and its launch daemon publishes exactly `com.apple.distributed_notifications.2`. Snow CoreFoundation carries that same legacy client service string.

Lion 10.7.5 splits the service. The system `distnoted daemon` publishes `com.apple.distributed_notifications@0v3` and `com.apple.distributed_notifications@1v3`; a UID-501 `distnoted agent` under the user's launchd publishes `com.apple.distributed_notifications@Uv3`; and the current user namespace lists `com.apple.distnoted.xpc.agent`. Lion CoreFoundation carries `@Uv3` and `@1v3`, while `distnoted` itself carries all three v3 names.

Therefore the failed `.2` lookup is explained by service identity evolution, not by a hidden copy of the old service in another obvious Lion launchd domain. Do not choose a replacement name from suffix intuition alone. The authoritative next step is `docs/distributed-notifications-client-service-selection-audit.md`, which statically identifies the native Lion client selection path before any further live lookup or compatibility rewrite.

## Result interpretation

The comparison will determine which branch to take next:

- If Lion publishes the same service name but only in a different launchd/bootstrap scope, the next experiment will target acquisition of that already-existing scope/port without fabricating a service or restarting distnoted.
- If Lion replaced `com.apple.distributed_notifications.2` with a different Mach service name or split daemon/agent services, the next experiment will first prove the native Lion identity used by Foundation/HIToolbox and then decide whether a narrow compatibility name translation is justified.
- If the static definitions and binaries still name the exact Snow service in the same apparent scope, the next step will be a read-only/bootstrap-topology discriminator before another lookup; do not assume the service is absent merely because the current task bootstrap namespace cannot resolve it.
- If no corresponding Lion service contract can be established, do not synthesize a Mach port and do not integrate the failed lookup adapter.

## Current boundary

```text
restored Process Manager / foreground path      -> PASS
CreateNewWindow entry                           -> reached
Snow exact distributed-notifications lookup     -> success / live send right
Lion native-format lookup transport              -> mach_msg success
Lion reply envelope                              -> 0x1f8 / 0x24 simple error
Lion raw result                                  -> 0x4e040000
NDR-decoded bootstrap result                     -> 0x0000044e / 1102 / BOOTSTRAP_UNKNOWN_SERVICE
service port                                     -> null
protected hashes                                 -> unchanged
next step                                        -> static Snow/Lion client service-selection differential audit
```

No additional XNU change is indicated.
