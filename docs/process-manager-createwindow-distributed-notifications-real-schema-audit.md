# Process Manager CreateNewWindow distributed-notifications real-schema audit

## Objective

The first integrated CreateNewWindow run proved that the process-local legacy `.2` ingress is reached, but the native broker rejected all three real legacy requests with status 20 before `CreateNewWindow` could return. In the current broker, status 20 is `BROKER_REJECT_SCHEMA`.

The normal broker was intentionally written for the standalone proof and still contains the proof-only notification-name predicate. That predicate alone is sufficient to reject real HIToolbox/CoreServices distributed-notification traffic. The current log does not show whether additional field/value differences are also present.

This stage therefore captures the exact three real legacy binary-property-list request dictionaries without accepting, posting, registering, unregistering, or synthesizing any notification semantics.

## What the completed integration run established

The returned evidence establishes:

```text
Snow integrated passthrough control              PASS
Lion syscall-295 preflight                       PASS / EBADF / no SIGSYS
exact .2 / pid 0 / flags 8 lookup               observed
process-local receive port                       created
native broker                                    started
legacy Mach request 1                            payload 291 bytes
legacy Mach request 2                            payload 320 bytes
legacy Mach request 3                            payload 299 bytes
broker result for all three                      status 20 / schema reject
broker lifecycle counts                          register=0 post=0 callback=0 unregister=0 rejects=3
M20_BEFORE_CreateNewWindow                       reached
M21_AFTER_CreateNewWindow                        not reached
HIToolbox                                        damage -4960 / abort
subject                                           exit 134
protected hashes                                 unchanged
```

The prior runner reported `CREATENEWWINDOW_DISTNOTIFY_INGRESS_NOT_ESTABLISHED` because one concurrent stderr line containing the local-service result was interleaved with dyld output. That classification is superseded by the intact bridge-ready, broker-ready, and legacy Mach request evidence. Current `main` makes the ingress gate robust to that logging interleave and evaluates broker/protocol rejection before the generic CreateNewWindow no-return gate.

## Prepared files

Current `main` adds:

```text
tests/native-distributed-notifications-createwindow-schema-audit-broker.c
scripts/build-lion-native-distributed-notifications-createwindow-schema-audit-broker.sh
docs/process-manager-createwindow-distributed-notifications-real-schema-audit.md
```

The audit broker build ID is:

```text
distributed-notifications-createwindow-schema-audit-broker-v1
```

The existing integration runner now recognizes audit mode when:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
```

is set. In audit mode it requires exactly three captured legacy requests and returns:

```text
RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_SCHEMA_AUDIT_PASS
```

The audit report contains, for each request, the exact binary payload as hexadecimal plus a CoreFoundation XML property-list rendering. The audit broker performs no distributed-notification operation and sends no callback.

## Safety constraints

For this stage:

- reuse the exact accepted PPC CreateNewWindow subject and all three accepted PPC compatibility dylibs unchanged;
- do not rebuild any PPC artifact;
- build only the native i386 schema-audit broker on Lion;
- do not use the normal notification broker for this run;
- do not register, post, unregister, suspend, session-reset, or synthesize callbacks;
- do not expose a global `.2` service;
- do not alter launchd, distnoted, WindowServer, CoreFoundation, HIToolbox, Rosetta, dyld, shared caches, or XNU;
- do not broaden the real request schema in this stage;
- perform exactly one Lion schema-audit run and stop.

## Phase A — update current main

On Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

No XNU rebuild or reboot is part of this stage.

## Phase B — build the native schema-audit broker on Lion

Syntax-check the builder:

```sh
/bin/bash -n ./scripts/build-lion-native-distributed-notifications-createwindow-schema-audit-broker.sh
```

Then build:

```sh
/bin/bash ./scripts/build-lion-native-distributed-notifications-createwindow-schema-audit-broker.sh \
  ./native-distributed-notifications-createwindow-schema-audit-broker
```

Require:

```text
i386 Mach-O
build_id=distributed-notifications-createwindow-schema-audit-broker-v1
CFPropertyListCreateWithData import
CFPropertyListCreateData import
AUDIT_CAPTURE marker
AUDIT_SUMMARY marker
AUDIT_PASS marker
SHA-256 sidecar
info sidecar
```

## Phase C — repeat the established native safety gate

Repeat the existing syscall-295 compatibility probe and require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

Do not continue if the kernel identity or syscall behavior has changed.

## Phase D — exactly one Lion real-schema capture

Syntax-check the existing integration runner first:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Set the established kernel SHA and run once from the logged-in Aqua console user's Terminal:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<established Lion mach_kernel SHA-256>'

ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT="$PWD/payload/lion-ppc-process-manager-createwindow-distnotify-real-schema-audit.txt" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-schema-audit-broker \
  ./native-distributed-notifications-createwindow-schema-audit-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-distnotify-real-schema-audit.log
```

The audit is successful only if the runner reports:

```text
schema_audit_capture_count=3
legacy_mach_request_count=3
PM_DISTRIBUTED_NOTIFICATIONS_REAL_SCHEMA_AUDIT_SUMMARY:requests=3 failures=0
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:AUDIT_PASS
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_SCHEMA_AUDIT_PASS
```

The subject is still expected not to return from `CreateNewWindow` because the audit broker deliberately performs no registration or callback behavior. Do not treat that expected abort as evidence that the capture failed if the audit-specific result is PASS.

## Phase E — return evidence and stop

Return:

```text
native-distributed-notifications-createwindow-schema-audit-broker.info.txt
native-distributed-notifications-createwindow-schema-audit-broker.sha256
syscall295-probe-process-manager-createwindow-distnotify-real-schema-audit.log
lion-ppc-process-manager-createwindow-distnotify-real-schema-audit.log
lion-ppc-process-manager-createwindow-distnotify-real-schema-audit.raw.log
lion-ppc-process-manager-createwindow-distnotify-real-schema-audit.txt
```

Also return every new crash/core diagnostic named by the Lion runner if it is available.

Stop after Phase E.

## Decision gate

The returned audit payloads will determine the next single compatibility change. Compare all three real dictionaries against the already-proven legacy register/post/unregister mapping and identify, per request:

```text
message_type
name
object presence/type
sessionid
behavior
counter
entry
userinfo/immediately/sux if present
entries/state if present
unexpected keys or value types
```

Do not remove the proof-only name restriction from the normal broker, add real notification names, or broaden operation support until those exact payloads have been reviewed.

No additional XNU change is indicated.
