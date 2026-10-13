# ShowWindow exact seventh distributed-notification registration

## Objective

Accept only the exact seventh legacy distributed-notification registration proven by the preceding capture, then rerun the unchanged Lion PPC ShowWindow subject exactly once to identify the next boundary.

The seventh-request schema audit passed. The captured 322-byte binary plist is an ordinary eight-key `register` dictionary:

```text
message_type  register
client        ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
name          com.apple.ColorSync.DisplayProfileNotification
object        kCFNotificationAnyObject
behavior      4
counter       1
entry         positive run-time registration identity
sessionid     current established session
```

In the captured run:

```text
entry         3540864 / 0x003606c0
sessionid     78
```

The audit broker retained the six previously reviewed registrations, captured exactly one seventh request, deliberately returned status 25, reported zero capture failures and zero unexpected rejects, and produced the expected audit PASS. The accepted WindowBackingInfo, ColorProfileClient, ResolveColorProfile, FontServer rendezvous, and earlier notification paths all remained intact.

This is a **new reviewed notification name**, not a duplicate of an existing tuple. The new broker therefore extends the sequence by exactly one tuple. It does not authorize arbitrary ColorSync notifications, arbitrary object scopes, arbitrary suspension behaviors, arbitrary counters, or additional requests.

## Prepared files

Current runtime `main` provides:

```text
tests/native-dn-showwindow-7-registration-broker.c
scripts/build-lion-dn-showwindow-7-registration-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-showwindow-seventh-notification-registration.md
```

Native broker build ID:

```text
distributed-notifications-showwindow-seventh-registration-broker-v1
```

Runner registration mode:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-seventh-register-v1
```

Short broker artifact name:

```text
dn-showwindow-7-registration-broker
```

The broker is sequence-gated to these exact seven registration records:

```text
request  allowed tuple                                        behavior  counter
1        MCX management status                                1         1
2        CFPreferences domains changed                        1         1
3        AppleColorPreferencesChangedNotification             4         1
4        AppleAquaColorVariantChanged                         4         1
5        com_apple_CoreText_FontManagerChangedNotification    1         1
6        AppleAquaColorVariantChanged                         4         2
7        com.apple.ColorSync.DisplayProfileNotification       4         1
```

Request 7 must use `kCFNotificationAnyObject`, a positive unique entry, the established client/session scope, and legacy behavior 4, which maps to the already reviewed public `CFNotificationSuspensionBehaviorCoalesce` behavior. Any eighth request or sequence/filter/counter mismatch remains rejected.

## Safety constraints

- Do not rerun Snow Leopard. The new evidence is a Lion user-space registration boundary and the prior Snow/ShowWindow controls remain accepted.
- Reuse the existing `pm-wbi-compat.dylib` and its SHA sidecar unchanged.
- Reuse the PPC subject, Security interposer, FontServer rendezvous interposer, HIToolbox Extras compatibility artifact/resource, and all accepted ShowWindow compatibility modes unchanged.
- Build only the new native i386 exact-seven broker on Lion.
- Repeat syscall 295 before the one Lion subject run.
- Accept exactly the seven-request sequence above.
- Do not generalize the ColorSync name or AnyObject scope.
- Do not generalize behavior 4 or counter 1.
- Do not accept an eighth request.
- Do not change the WindowBackingInfo one-call cap or any backing-info output.
- Do not modify ColorProfileClient or ResolveColorProfile compatibility.
- Do not adapt `CGSShapeWindow`.
- Do not work around RawCamera or CoreUI diagnostics in the same run.
- Do not patch CoreGraphics, ColorSync, CoreUI, WindowServer, Rosetta, dyld, caches, launchd, distnoted, or XNU.
- Do not restart or signal WindowServer, distnoted, fontd, Dock, launchd, or related jobs.
- No kernel rebuild or reboot.
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

## Phase B — build only the exact-seven broker

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/bin/bash -n ./scripts/build-lion-dn-showwindow-7-registration-broker.sh || exit 1
/bin/bash ./scripts/build-lion-dn-showwindow-7-registration-broker.sh || exit 1
```

Expected outputs:

```text
dn-showwindow-7-registration-broker
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
```

Require:

```text
architecture            i386
build ID                distributed-notifications-showwindow-seventh-registration-broker-v1
sixth policy marker     index=6 allowed=3 counter=2
seventh policy marker   index=7 allowed=5 counter=1
ColorSync name          com.apple.ColorSync.DisplayProfileNotification
AnyObject sentinel      present
CoreFoundation observer imports present
```

Stop if Phase B fails.

## Phase C — syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-dn7-reg.log" || exit 1
```

Require:

```text
mach_kernel_sha256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase D — exactly one Lion exact-seven registration run

On Lion:

```sh
cd "$RUNTIME" || exit 1

unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT
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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-seventh-register-v1
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
  ./dn-showwindow-7-registration-broker \
  ./dn-showwindow-7-registration-broker.sha256 \
  ./payload/lion-dn7-reg.log
```

Do not run the Lion subject a second time.

## Acceptance discriminator

Before deciding the next boundary, require the established chain:

```text
WindowBackingInfo compatibility                  ADAPTER_PASS exactly once
backing-data shmem mapping failure                absent
_CGSLockWindow failure                            absent
ColorProfileClient compatibility                 ADAPTER_PASS exactly once
ResolveColorProfile compatibility                ADAPTER_PASS exactly once
FontServer rendezvous compatibility              ADAPTER_PASS exactly once
first six notification registrations             accepted exactly
S00_BEFORE_ShowWindow                            reached
```

Then require the seventh registration:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:
  index=7
  allowed=5
  behavior=4
  publicBehavior=2
  anyObject=YES
  positive unique entry
  counter=0x1

seventh_notification_registration_accept_count=1
```

The broker must not accept any unreviewed eighth request.

## Decision gates

### `POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS`

Require:

```text
register summary        register=7 callback=... rejects=0 exact=YES
broker result           PASS
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
T04_BEFORE_CFRelease
T05_AFTER_CFRelease
M22_BEFORE_DisposeWindow
M23_AFTER_DisposeWindow
M24_SUCCESS
process exit            0
protected hashes        unchanged
no new crash/core diagnostic
```

This closes the current ShowWindow gate. Stop and review before adding any later Carbon operation.

### `POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_PASS_EIGHTH_PROTOCOL_REJECTED`

The exact seventh registration is accepted, but an eighth unreviewed distributed-notification request becomes the new causal boundary. Do not broaden the broker. Preserve its Mach request geometry and status; the next stage will capture/decode that exact eighth request.

### `POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_PASS_SHOWWINDOW_NO_RETURN`

The exact-seven broker reaches `register=7 ... exact=YES` and PASS with no eighth rejection, but ShowWindow still does not return. Preserve the first subsequent diagnostic/request and all named crash/core artifacts. Do not assume the known RawCamera/CoreUI output is causal until the post-seventh chronology is reviewed.

### Any compatibility or broker mismatch

Stop. Do not relax the sequence, name, object, behavior, counter, entry, session, or existing compatibility predicates.

## Return

Return these five primary artifacts:

```text
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
sys295-dn7-reg.log
lion-dn7-reg.log
lion-dn7-reg.raw.log
```

Also return any newly named crash plist/crash/core diagnostic if the runner reports one. Do not return the native broker executable unless specifically requested.

## Current boundary

```text
WindowBackingInfo compatibility               live-proven
backing-data shmem mapping failure             cleared
ColorProfileClient compatibility               live-proven
ResolveColorProfile compatibility              live-proven
sixth notification registration               accepted
seventh request schema                         reviewed register
seventh name                                   com.apple.ColorSync.DisplayProfileNotification
seventh object                                 kCFNotificationAnyObject
seventh behavior                               4 / Coalesce
seventh counter                                1
next step                                      accept exact seventh once
eighth notification request                    unreviewed / reject
CGSShapeWindow                                 held
RawCamera / CoreUI                             held
XNU                                            no change indicated
```


## Observed result — exact-seven broker passes; post-seventh crash is next

The exact-seven integration completed its intended notification proof. The new broker was i386 with build ID `distributed-notifications-showwindow-seventh-registration-broker-v1`; its SHA-256 `7360bcd68e0b5bc473540143e1bd7fb1cb1544a60f530d1c2f6df57469db46a9` matched the sidecar and the runner's expected/actual broker hashes. Syscall 295 remained healthy on the accepted kernel.

The seventh reviewed registration was accepted exactly once:

```text
index=7
allowed=5
behavior=4
publicBehavior=2
anyObject=YES
entry=0x3797d0
counter=0x1
```

The broker then completed:

```text
register=7 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
```

No eighth legacy notification request was observed. `S01_AFTER_ShowWindow` and `SHOWWINDOW_PASS` were not reached.

The accepted WindowBackingInfo, ColorProfileClient, and ResolveColorProfile adapters each passed exactly once; the prior backing-data shmem mapping and `_CGSLockWindow` failures remained absent. The subject terminated with exit status 139. Immediately after the seventh registration, the only visible diagnostics were three CoreUI `Invalid ArtFile Path!` messages. The runner preserved the matching crash report and `/cores/core.89664`.

The returned final result label, `POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_PREDICATE_NOT_REACHED`, is not the new causal boundary. AddTrackingArea, OrderFrontConditionally, and SetFrontWindow simply were not reached before this post-seventh termination. Runtime `main` now classifies this exact state before those later adapter gates.

The authoritative next procedure is:

```text
docs/process-manager-showwindow-post-dn7-postmortem.md
```

Do not rerun the PPC subject. Run the read-only collector against the preserved exact-seven crash/core and return the three short postmortem artifacts. No XNU change is indicated.
