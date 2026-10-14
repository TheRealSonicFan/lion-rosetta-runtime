# Original Carbon GUI CPS registration integration

## Status

**COMPLETE — PASS.** The dedicated historical-client CPS registration mode matched exactly on Lion, translated the `0x68` legacy CheckInApplication request to Lion CreateApplication, received a native success reply, translated it back to the legacy reply, and eliminated the prior `-304/MIG_BAD_ARGUMENTS` registration failure. The Carbon process still appeared in the Dock without a visually observed window, so the next controlled variable is the still-held notification client identity.

The exact historical subject still completed its Carbon code path and exited 0, but no window was visually observed. The decisive trace is earlier: its legacy `CPS_CHECKIN_APPLICATION` request used:

```text
id=0x00007372
send=0x00000068
recv=0x0000002c
stringLength=0x00000026
client="ppc-carbon-gui-smoketest-private-dyld"
```

while the accepted `lion-create-application-v1` predicate was intentionally pinned to the longer Process Manager validation basename and a `0x84`-byte legacy request. The predicate therefore returned `exact=NO`, passed the request through unchanged, and Lion returned `-304 / MIG_BAD_ARGUMENTS`. The log then printed:

```text
_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304
```

This provides a concrete explanation for the Dock process with no visually presented Carbon window, but causality is not yet considered proven. The next run changes **only** the exact client-specific CPS registration adaptation.

The previous run also sent 21 distributed-notification registration requests through a broker whose schema includes the Process Manager validation client basename. All 21 therefore returned broker schema status 20. The application nevertheless reached both historical smoke markers and exited 0. Notification policy is deliberately **held** in this step: do not broaden or replace the exact-21 broker while testing the CPS-registration boundary.

## Objective

Add one exact CPS-registration compatibility predicate for the unchanged historical subject:

```text
ppc-carbon-gui-smoketest-private-dyld
SHA-256:
fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067
```

The dedicated mode accepts only the observed `0x68`-byte legacy CheckInApplication request with the exact basename and NUL-inclusive string length `0x26`. It converts the request to Lion CreateApplication by changing only the request ID in the common bytes and appending the already proven 12-byte Lion tail:

```text
legacy request id   0x00007372
Lion request id     0x000073c1
legacy send size    0x00000068
Lion send size      0x00000074
tail                00000000 00000000 00000010
```

The native Lion reply must be success `0x00007425`, then be translated back to the legacy reply ID `0x000073d6`.

No notification acceptance change is authorized in this phase.

## Pinned implementation

Current runtime `main`:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
Git blob 1e37385966b51bbd3fc4f53771b2d67b2f595c1e

scripts/build-ppc-carbon-gui-cps-registration-compat-on-snowleopard.sh
Git blob 68d289ade40f9d2ee8cb498a7062e14410d08949

scripts/run-lion-ppc-carbon-gui-cps-registration-integration.sh
Git blob 0eab8721cc51fdbd8f750eb51636f10687a289b5

tests/native-dn-runapplicationeventloop-remaining-registration-broker.c
Git blob 03504584b0d1e9e97c1fd3663ee4590c692ab940

scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh
Git blob 5f10c92f15d2a79c76bf07ae68eae58228d0e486
```

XNU runner:

```text
tools/run_syscall295_probe.sh
Git blob eaecc9bfbf4d780664c7e66471a832a0289aebb6
```

New combined compatibility build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v4
```

Dedicated CPS mode:

```text
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-carbon-smoketest-v1
```

## Safety constraints

- Keep the original smoke executable bit-for-bit unchanged.
- Build the new PPC compatibility dylib on Snow Leopard 10.6.8 / 10K549 with Xcode 3.2.6 GCC.
- Keep all other accepted compatibility artifacts unchanged.
- Keep the existing exact-21 notification broker unchanged even though it is expected to reject this different client identity.
- Do not accept or audit notification payloads in the same run.
- Do not change titlebar policy.
- Do not modify system frameworks, caches, dyld, LaunchServices, Finder behavior, or XNU.
- Run exactly once on Lion before review.
- Report whether the **Rosetta PPC Carbon GUI** window is actually visible; the historical application marker is not sufficient to establish visual presentation.

## Phase A — update and pin

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c)" = \
  "1e37385966b51bbd3fc4f53771b2d67b2f595c1e" || exit 1
test "$(git hash-object ./scripts/build-ppc-carbon-gui-cps-registration-compat-on-snowleopard.sh)" = \
  "68d289ade40f9d2ee8cb498a7062e14410d08949" || exit 1
/bin/bash -n ./scripts/build-ppc-carbon-gui-cps-registration-compat-on-snowleopard.sh || exit 1
```

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-cps-registration-integration.sh)" = \
  "0eab8721cc51fdbd8f750eb51636f10687a289b5" || exit 1
test "$(git hash-object ./tests/native-dn-runapplicationeventloop-remaining-registration-broker.c)" = \
  "03504584b0d1e9e97c1fd3663ee4590c692ab940" || exit 1
test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh)" = \
  "5f10c92f15d2a79c76bf07ae68eae58228d0e486" || exit 1

/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-cps-registration-integration.sh || exit 1
/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh || exit 1
```

Stop if any pin or syntax gate fails.

## Phase B — build the new exact PPC compatibility artifact on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-carbon-gui-cps-registration-compat-on-snowleopard.sh \
  ./pm-carbon-gui-cps-registration-compat.dylib || exit 1
```

Require:

```text
pm-carbon-gui-cps-registration-compat.dylib
pm-carbon-gui-cps-registration-compat.dylib.info.txt
pm-carbon-gui-cps-registration-compat.dylib.sha256
```

The info report must show the v4 build ID above, a 32-bit PPC Mach-O, the current source hashes, and the generated binary SHA-256. The binary strings must contain:

```text
lion-create-application-carbon-smoketest-v1
ppc-carbon-gui-smoketest-private-dyld
```

Do not rebuild the historical smoke executable.

Transfer the exact three compatibility artifacts to Lion under `payload/`.

## Phase C — verify the unchanged historical subject and fixed accepted artifacts on Lion

Require the subject SHA-256:

```text
fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067
```

The dedicated runner verifies the new compatibility dylib against its transferred sidecar and build marker, and retains all fixed accepted hashes for Security, CGS/FontServer, HIToolbox Extras, titlebar compatibility, private dyld, cache, CoreGraphics, translator, and kernel.

## Phase D — rebuild only the unchanged exact-21 broker

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh \
  ./dn-runapplicationeventloop-remaining-registration-broker || exit 1
```

Require the established broker build ID and SHA-256:

```text
distributed-notifications-runapplicationeventloop-remaining-registration-broker-v1
d7912d9761049f1382028ad0d16854915aa531fe0963df67be5678efb413b5d4
```

Do not edit its expected client. This phase deliberately preserves the known 21 schema rejects so the only compatibility change is CPS registration.

## Phase E — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  ./sys295-carbon-gui-cps-registration.log || exit 1
```

Require EBADF without SIGSYS and final `RESULT: PASS`.

## Phase F — exactly one Lion run

From the logged-in Aqua console user's Terminal:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-carbon-gui-cps-registration-integration.sh \
  ./payload/ppc-carbon-gui-smoketest-private-dyld \
  ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./payload/pm-carbon-gui-cps-registration-compat.dylib \
  ./payload/pm-carbon-gui-cps-registration-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./dn-runapplicationeventloop-remaining-registration-broker \
  ./dn-runapplicationeventloop-remaining-registration-broker.sha256 \
  ./payload/lion-ppc-carbon-gui-cps-registration.log
```

Do not rerun before review.

## Required CPS discriminator

Require exactly once:

```text
PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=lion-create-application-carbon-smoketest-v1 exact=YES ... send=0x00000068 recv=0x0000002c ... stringLength=0x00000026
PM_CPS_REGISTRATION_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x00007372 lionId=0x000073c1 legacySend=0x00000068 lionSend=0x00000074 changedCommonBytes=1 sourceChangedBytes=0 tailByte=0x00 tailU32_0=0x00000000 tailU32_1=0x00000010
PM_CPS_REGISTRATION_COMPAT_NATIVE_REPLY:index=1 ... id=0x00007425 result=0 ... raw20=0x00000000
PM_CPS_REGISTRATION_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x00007425 legacyId=0x000073d6 ... result=0
PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS
```

Require zero:

```text
PM_CPS_REGISTRATION_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH
_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304
```

## Held notification discriminator

This is deliberately **not** a notification-policy pass. Require the already observed held behavior:

```text
notification_register_accept_count=0
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=0 callback=0 rejects=21 exact=NO
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:FAIL
21 x PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:status=20
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=21 callbacks=0
notification_request22_count=0
```

A change in that held behavior is a stop condition; do not reinterpret it as authorization to broaden the broker.

## Other acceptance gates

Require:

```text
Rosetta PPC Carbon GUI window shown: ... visible=1
Rosetta PPC Carbon GUI smoke test: ... timer=1
carbon_gui_exec_status=0
protected_hashes_unchanged=YES
titlebar_translated_count=6
titlebar_guard_reject_count=0
RESULT: PPC_CARBON_GUI_CPS_REGISTRATION_INTEGRATION_PASS
RESULT: PASS
```

All previously accepted adapter counts must retain the runner's exact expected values.

The runner also emits:

```text
visual_window_observation=MANUAL_REQUIRED
```

State separately whether the **Rosetta PPC Carbon GUI** window was actually visible. This manual observation decides whether successful CPS registration closes the visual presentation discrepancy or whether a later WindowServer/display-state boundary remains.

## Return for review

Return:

```text
pm-carbon-gui-cps-registration-compat.dylib.info.txt
pm-carbon-gui-cps-registration-compat.dylib.sha256
lion-ppc-carbon-gui-cps-registration.log
lion-ppc-carbon-gui-cps-registration.raw.log
sys295-carbon-gui-cps-registration.log
dn-runapplicationeventloop-remaining-registration-broker.info.txt
dn-runapplicationeventloop-remaining-registration-broker.sha256
ppc-carbon-gui-smoketest-private-dyld.info.txt
ppc-carbon-gui-smoketest-private-dyld.sha256
```

Also state whether the Carbon GUI window was visually observed and return any new crash/core diagnostic named by the runner.

## Current boundary

```text
historical Carbon smoke executable                 reaches both markers / exit 0
historical Carbon smoke visual window               NOT OBSERVED
historical CPS CheckInApplication on Lion            native -304 due exact predicate mismatch
exact original-smoke CPS registration adaptation    NEXT
original-client notification registrations          HELD; 21 schema rejects expected
new notification policy                             NO
titlebar broadening                                 NO
LaunchServices / Finder / Cocoa                     HELD
XNU                                                  no source change indicated
```


## Reviewed Lion result

The Lion run passed every gate of this phase. The historical subject remained exact at SHA-256 `fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067`; the dedicated compatibility artifact SHA-256 was `519bd455d9f343821b2bd7d4eb22222bb18379f9c30bdc0d3a225ca9ac3d4c30`. The CPS predicate reported `exact=YES` for the observed `0x68` request and `0x26` name length, adapted request ID `0x7372 -> 0x73c1`, received native reply ID `0x7425` with result zero, translated the reply to `0x73d6`, and emitted `PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS`. The prior `_RegisterApplication() ... err=-304` message was absent.

The application again reached `Rosetta PPC Carbon GUI window shown: ... visible=1` and the final smoke marker, exited 0, produced no new diagnostic, preserved all protected hashes, retained every accepted CGS/titlebar adapter count, and ended with `RESULT: PPC_CARBON_GUI_CPS_REGISTRATION_INTEGRATION_PASS` / `RESULT: PASS`. Nevertheless, no Carbon GUI window was visually observed.

The intentionally held Process Manager-bound notification broker rejected all 21 registrations: `register=0 callback=0 rejects=21 exact=NO`, broker `FAIL`, no request 22, and ingress exit `requests=21 callbacks=0`. With CPS registration now proven, this is the only deliberately unresolved compatibility difference in the restored-stack run.

Current work therefore advances to `docs/ppc-carbon-gui-notification-registration-integration.md`. That step changes only the broker's exact client identity from the Process Manager validation basename to `ppc-carbon-gui-smoketest-private-dyld` while preserving the same 21 reviewed names, objects, behaviors, counters, order, and callback policy. No titlebar, CGS, LaunchServices, Cocoa, or XNU broadening is authorized.
