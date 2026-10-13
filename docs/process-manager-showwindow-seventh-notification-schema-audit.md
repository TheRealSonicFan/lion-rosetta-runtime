# ShowWindow seventh distributed-notification schema audit

## Objective

Capture and decode exactly the seventh legacy distributed-notification request reached by the Lion PPC ShowWindow path after the accepted WindowBackingInfo compatibility conversion.

The preceding WindowBackingInfo experiment is conclusive. The first exact legacy backing-info call used the learned ShowWindow application port and was adapted once:

```text
legacy request             0x7263
Lion request               0x7264
send / receive             0x24 / 0x3c
native reply               0x72c8 / 0x34 / result 0
PPC-facing reply           0x72c7 / 0x34 / result 0
request body changes       0
reply body changes         0
adapter result             PASS
```

The former `_CGSBindWindowBacking: cannot map backing data shmem` and `_CGSLockWindow: Unable to lock window` cascade does not recur. The accepted ColorProfileClient and ResolveColorProfile adapters still pass later in the same run.

The next controlled boundary is a seventh distributed-notification request:

```text
request index              7
Mach bits                  0x00001111
message id                 4
Mach message size          356
binary-plist payload       322
exact-six broker status    25 / BROKER_REJECT_NAME
```

Status 25 proves only that the request's notification name is outside the current exact-six allowlist. It does not establish the request's decoded name, object, behavior, counter, entry, session, or whether it should be accepted. Do not infer or whitelist it from the payload length or reject code.

The next safe step is therefore a read-only schema capture: keep the six reviewed registrations active, capture the seventh payload byte-for-byte plus XML, deliberately return the same status 25, and stop for review.

## Prepared files

Current runtime `main` provides:

```text
tests/native-distnotify-showwindow-seventh-schema-audit-broker.c
scripts/build-lion-dn-showwindow-7-schema-audit-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-showwindow-seventh-notification-schema-audit.md
```

Native broker build ID:

```text
distributed-notifications-showwindow-seventh-schema-audit-broker-v1
```

Short artifact name:

```text
dn-showwindow-7-schema-audit-broker
```

Audit report environment variable:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT
```

The broker keeps the established exact-six sequence unchanged:

```text
1  com.apple.MCX._managementStatusChangedForDomains
   object=com.apple.MCX
   legacy behavior=1
   counter=1

2  com.apple.CFPreferences._domainsChangedExternally
   object=com.apple.CFPreferences
   legacy behavior=1
   counter=1

3  AppleColorPreferencesChangedNotification
   object=kCFNotificationAnyObject
   legacy behavior=4
   counter=1

4  AppleAquaColorVariantChanged
   object=kCFNotificationAnyObject
   legacy behavior=4
   counter=1

5  com_apple_CoreText_FontManagerChangedNotification
   object=kCFNotificationAnyObject
   legacy behavior=1
   counter=1

6  AppleAquaColorVariantChanged
   object=kCFNotificationAnyObject
   legacy behavior=4
   counter=2
```

Only after all six are accepted does it capture the next request. It does not parse that request into an acceptance decision, does not register it with the native notification center, and deliberately returns status 25.

## Safety constraints

- Do not rerun Snow Leopard. The WindowBackingInfo Snow control and Lion adapter result are already decisive.
- Reuse the previously built `pm-wbi-compat.dylib` and its SHA sidecar unchanged.
- Reuse the PPC ShowWindow subject, Security interposer, FontServer rendezvous interposer, HIToolbox Extras compatibility artifact/resource, and accepted exact-six registration semantics unchanged.
- Build only the new native i386 seventh-request audit broker on Lion.
- Repeat syscall 295 before the one Lion audit run.
- Keep WindowBackingInfo, ColorProfileClient, and ResolveColorProfile compatibility enabled.
- Keep the six reviewed distributed-notification registrations exact and active.
- Capture exactly one seventh request.
- Preserve the observed status-25 rejection for the seventh request.
- Do not accept, register, edit, synthesize, replay, or translate the seventh request in this stage.
- Do not broaden the notification allowlist.
- Do not adapt `CGSShapeWindow` in this stage.
- Do not work around RawCamera or CoreUI diagnostics in this stage.
- Do not change CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, distnoted, or XNU.
- No kernel rebuild, reboot, service restart, or daemon signal.
- Run the Lion subject exactly once before review.

## Phase A — update repositories

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD

cd "$ROSETTA_XNU" || exit 1
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build only the seventh-request audit broker on Lion

```sh
cd "$RUNTIME" || exit 1

/bin/bash -n ./scripts/build-lion-dn-showwindow-7-schema-audit-broker.sh || exit 1
/bin/bash ./scripts/build-lion-dn-showwindow-7-schema-audit-broker.sh || exit 1
```

Expected outputs:

```text
dn-showwindow-7-schema-audit-broker
dn-showwindow-7-schema-audit-broker.info.txt
dn-showwindow-7-schema-audit-broker.sha256
```

Require:

```text
architecture                          i386
build ID                              distributed-notifications-showwindow-seventh-schema-audit-broker-v1
exact-six policy marker               present
seventh capture marker                present
seventh intentional-reject marker     present
seventh audit-summary marker          present
POST_SHOWWINDOW_SEVENTH_AUDIT_PASS    present
```

Stop if Phase B fails.

## Phase C — syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-dn7-audit.log" || exit 1
```

Require:

```text
mach_kernel_sha256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Runner syntax correction

A runner-generation defect in runtime commit `f8583686c3e2d9b20ffaf08690903140654aa3b1` duplicated part of the integration runner and truncated the single-quoted request-6 regular expression. On Lion this presents at the Phase D syntax gate as an unexpected EOF while looking for a matching single quote.

Runtime commit `3c1bdfcaefef4a83a4a6b7f5a9bb9f19ca056a95` repairs the runner by removing the duplicated tail and restoring the complete seventh-audit result block. The repaired runner blob is `ad74ae6a1639d291056f1f9038373b1326e87a01`. Repository-side lexical validation confirms balanced shell quoting, one terminal runner block, one seventh-audit result block, and no truncated request-6 expression.

If Phase D stopped at `/bin/bash -n` with the quoted EOF error, no PPC subject run occurred. Pull current `main`, confirm the repaired runtime head is present, and resume Phase D at the syntax-check command. Do not repeat the Phase B broker build or Phase C syscall-295 preflight solely because of this parser failure if those phases already passed and their artifacts remain unchanged.

## Phase D — exactly one Lion seventh-request audit

On Lion:

```sh
cd "$RUNTIME" || exit 1

unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=lion-rendezvous-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-sixth-register-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT="$PWD/payload/lion-dn7-schema-audit.txt"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/pm-wbi-compat.dylib \
  ./payload/pm-wbi-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./dn-showwindow-7-schema-audit-broker \
  ./dn-showwindow-7-schema-audit-broker.sha256 \
  ./payload/lion-dn7-schema-audit.log
```

Do not run the Lion subject a second time.

## Acceptance discriminator

The runner must preserve the accepted chain through:

```text
CreateNewWindow                                      PASS
WindowBackingInfo compatibility                     ADAPTER_PASS exactly once
backing-data shmem mapping failure                   absent
_CGSLockWindow failure                               absent
ColorProfileClient compatibility                    ADAPTER_PASS exactly once
ResolveColorProfile compatibility                   ADAPTER_PASS exactly once
first six notification registrations                accepted exactly
S00_BEFORE_ShowWindow                                reached
```

Then require:

```text
legacy Mach request count                            7
request index 7                                      bits=0x1111
request index 7                                      id=4
request index 7                                      size=356
request index 7                                      payload=322
POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_CAPTURE         exactly 1
intentional reject                                   status=25
registration summary                                 register=6 callback=0 rejects=0 exact=YES
audit summary                                        captures=1 failures=0 unexpectedRejects=0 exact=YES
broker result                                        POST_SHOWWINDOW_SEVENTH_AUDIT_PASS
protected hashes                                     unchanged
RESULT                                               POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_SCHEMA_AUDIT_PASS
```

The subject may again exit 139 and may load RawCamera or print CoreUI diagnostics after the intentional reject. Those are downstream of the deliberately preserved seventh-request boundary and do not authorize workarounds.

## Phase E — inspect the audit report, then stop

The audit report must contain exactly one block:

```text
=== SHOWWINDOW_SEVENTH_REQUEST 1 BEGIN ===
binary_length=322
xml_length=...
binary_hex=...
<?xml ...>
...
=== SHOWWINDOW_SEVENTH_REQUEST 1 END ===
```

Do not add a seventh notification policy yet. Return the evidence for review.

## Return

Return these six primary artifacts:

```text
dn-showwindow-7-schema-audit-broker.info.txt
dn-showwindow-7-schema-audit-broker.sha256
sys295-dn7-audit.log
lion-dn7-schema-audit.log
lion-dn7-schema-audit.raw.log
lion-dn7-schema-audit.txt
```

Also retain and return any crash/plist/core diagnostic named by the runner if available. Do not return the native broker executable unless specifically requested.

## Decision gate

### `POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_SCHEMA_AUDIT_PASS`

Review the XML and exact binary bytes before deciding whether the seventh request extends a known registration tuple or introduces a new notification/schema. Only an exact reviewed request may become a compatibility policy.

### Capture, provenance, or accepted-chain mismatch

Do not modify the allowlist. Resolve the mismatch first. In particular, do not continue if WindowBackingInfo, ColorProfileClient, or ResolveColorProfile fails its existing one-call adapter gate.

## Current boundary

```text
WindowBackingInfo compatibility               live-proven
backing-data shmem mapping failure             cleared
ColorProfileClient compatibility               live-proven
ResolveColorProfile compatibility              live-proven
sixth notification registration               accepted
ShowWindow Lion                                entered, no return
seventh legacy notification request            id=4 size=356 payload=322
exact-six broker result                        status 25 / name reject
next step                                      capture/decode exact seventh binary plist
CGSShapeWindow                                 held
RawCamera / CoreUI                             held
XNU                                            no change indicated
```


## Observed result — seventh request is ColorSync display-profile registration

The corrected audit procedure completed successfully. The native broker was i386, used build ID `distributed-notifications-showwindow-seventh-schema-audit-broker-v1`, and the returned broker SHA matched its sidecar. Syscall 295 remained on the accepted kernel path and returned EBADF without SIGSYS.

The Lion subject preserved the accepted compatibility chain: WindowBackingInfo, ColorProfileClient, ResolveColorProfile, and FontServer rendezvous each passed their exact existing adapters; the former backing-data shmem mapping and `_CGSLockWindow` failures did not recur; and the first six notification registrations were accepted.

Exactly one seventh legacy request was captured:

```text
Mach bits      0x1111
message id     4
message size   356
payload size   322
```

The binary plist decodes as:

```text
message_type  register
client        ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
name          com.apple.ColorSync.DisplayProfileNotification
object        kCFNotificationAnyObject
behavior      4
counter       1
entry         3540864 / 0x003606c0 in this run
sessionid     78 in this run
```

The broker intentionally preserved status 25 for that unreviewed name, reported `register=6 callback=0 rejects=0 exact=YES`, exactly one capture, zero capture failures, zero unexpected rejects, and `POST_SHOWWINDOW_SEVENTH_AUDIT_PASS`. Protected hashes remained unchanged. The subject still exited 139 after the deliberate seventh-request rejection; RawCamera loading and CoreUI invalid-art-file diagnostics remain downstream of that closed boundary.

This exact schema is sufficient to prepare one narrow sequence extension. It does not authorize arbitrary ColorSync names, objects, behaviors, counters, or an eighth request.

The authoritative next procedure is:

```text
docs/process-manager-showwindow-seventh-notification-registration.md
```

Build only the new short native exact-seven broker, repeat syscall 295, and perform exactly one Lion run with all accepted ShowWindow compatibility modes unchanged. Accept only the reviewed seventh tuple above. Reject any eighth request and stop for another schema audit; if no eighth request appears but ShowWindow still does not return, preserve the first later diagnostic and crash/core evidence for review. No XNU change is indicated.

## Completed boundary

```text
seventh schema audit                          PASS
seventh request operation                     register
seventh name                                  com.apple.ColorSync.DisplayProfileNotification
seventh object                                kCFNotificationAnyObject
seventh behavior                              4 / Coalesce
seventh counter                               1
seventh entry                                 positive per-run identity
seventh session                               established session
WindowBackingInfo compatibility               PASS
ColorProfileClient compatibility              PASS
ResolveColorProfile compatibility             PASS
backing-map failure                           absent
next step                                     exact-seven registration run
eighth notification request                   unreviewed / reject
CGSShapeWindow                                held
RawCamera / CoreUI                            held
XNU                                           unchanged
```
