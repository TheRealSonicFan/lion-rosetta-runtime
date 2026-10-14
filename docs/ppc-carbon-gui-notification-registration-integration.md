# Original Carbon GUI notification registration integration

## Status

**NEXT CONTROLLED STEP.** The historical-client CPS registration adaptation is now live-proven on Lion. The exact `0x68` CheckInApplication request matched, translated to Lion CreateApplication, returned native result zero, translated back to the legacy reply, and eliminated the prior `-304/MIG_BAD_ARGUMENTS` failure. The process still appeared in the Dock without a visually observed Carbon window.

The only deliberately held restored-stack difference is now distributed-notification client identity. The unchanged historical subject sent 21 registration requests, but the Process Manager exact-21 broker was pinned to:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

so every request returned schema status 20 before the broker could establish exact acceptance. This phase changes **only** that broker client identity.

## Objective

Run the exact original Snow-positive Carbon GUI binary once with:

- the already proven historical-client CPS registration compatibility artifact unchanged;
- the same exact 21 reviewed distributed-notification names, objects, behaviors, counters, ordering, and callback policy;
- a dedicated broker whose only intended policy difference is:
  `EXPECTED_CLIENT="ppc-carbon-gui-smoketest-private-dyld"`.

If the 21 requests are otherwise identical to the reviewed sequence, the broker must end:

```text
register=21 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
```

If any request differs in operation, name, object, behavior, counter, session state, ordering, or post-21 traffic, stop on the broker failure; do not broaden the schema.

## Exact reused artifacts

Historical subject:

```text
ppc-carbon-gui-smoketest-private-dyld
SHA-256:
fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067
```

Proven CPS-registration/full-stack compatibility artifact:

```text
pm-carbon-gui-cps-registration-compat.dylib
SHA-256:
519bd455d9f343821b2bd7d4eb22222bb18379f9c30bdc0d3a225ca9ac3d4c30
```

Accepted Lion kernel:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Do not rebuild either PPC artifact for this phase.

## Pinned implementation

Current runtime `main`:

```text
tests/native-dn-carbon-gui-registration-broker.c
Git blob e0c6c95368ffd0ac307c93a886d3d40723df3650

scripts/build-lion-dn-carbon-gui-registration-broker.sh
Git blob 65be80ace852ae1b5b2ea50ca184b75fdeb9bac6

scripts/run-lion-ppc-carbon-gui-notification-registration-integration.sh
Git blob e937cd839bad82e24edecb646f6f3228dc245e52
```

XNU probe runner:

```text
tools/run_syscall295_probe.sh
Git blob eaecc9bfbf4d780664c7e66471a832a0289aebb6
```

Dedicated broker build ID:

```text
distributed-notifications-carbon-gui-registration-broker-v1
```

Dedicated expected client:

```text
ppc-carbon-gui-smoketest-private-dyld
```

The broker preserves the exact reviewed 21-registration policy from the previously proven Process Manager broker.

## Safety constraints

- Use Lion 10.7.5 / 11G63.
- Run from the logged-in Aqua console user's Terminal.
- Reuse the exact historical PPC subject and exact proven CPS compatibility dylib.
- Build only the new native i386 notification broker on Lion.
- Do not modify the broker's 21 allowed registration names, objects, behaviors, counters, ordering, or callback policy.
- Do not add an audit fallback or wildcard client acceptance.
- Do not change titlebar, CGS, HIToolbox, Security, LaunchServices, Finder, Cocoa, dyld, caches, or XNU.
- Run exactly once before review.
- Report separately whether the **Rosetta PPC Carbon GUI** window is visually visible. The subject's `visible=1` marker is not accepted as a substitute for manual observation.

## Phase A — update and pin

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/native-dn-carbon-gui-registration-broker.c)" = \
  "e0c6c95368ffd0ac307c93a886d3d40723df3650" || exit 1
test "$(git hash-object ./scripts/build-lion-dn-carbon-gui-registration-broker.sh)" = \
  "65be80ace852ae1b5b2ea50ca184b75fdeb9bac6" || exit 1
test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-notification-registration-integration.sh)" = \
  "e937cd839bad82e24edecb646f6f3228dc245e52" || exit 1

/bin/bash -n ./scripts/build-lion-dn-carbon-gui-registration-broker.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-notification-registration-integration.sh || exit 1
```

Also update the XNU companion checkout and verify:

```sh
cd /path/to/lion-rosetta-xnu || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git hash-object ./tools/run_syscall295_probe.sh)" = \
  "eaecc9bfbf4d780664c7e66471a832a0289aebb6" || exit 1
```

Stop if any pin or syntax gate fails.

## Phase B — verify exact reused PPC artifacts

In the runtime checkout:

```sh
test "$(shasum -a 256 ./payload/ppc-carbon-gui-smoketest-private-dyld | awk '{print $1}')" = \
  "fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067" || exit 1

test "$(shasum -a 256 ./payload/pm-carbon-gui-cps-registration-compat.dylib | awk '{print $1}')" = \
  "519bd455d9f343821b2bd7d4eb22222bb18379f9c30bdc0d3a225ca9ac3d4c30" || exit 1
```

Their existing sidecars must match exactly. Do not rebuild them.

## Phase C — build the dedicated Carbon GUI exact-21 broker

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/bin/bash ./scripts/build-lion-dn-carbon-gui-registration-broker.sh \
  ./dn-carbon-gui-registration-broker || exit 1
```

Require:

```text
dn-carbon-gui-registration-broker
dn-carbon-gui-registration-broker.info.txt
dn-carbon-gui-registration-broker.sha256
```

The info file must show an i386 Mach-O and build ID:

```text
distributed-notifications-carbon-gui-registration-broker-v1
```

The binary must contain the exact historical client string and all 21 already reviewed notification-schema literals.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  ./sys295-carbon-gui-notification-registration.log || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
RESULT: PASS
```

## Phase E — exactly one Lion run

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-carbon-gui-notification-registration-integration.sh \
  ./payload/ppc-carbon-gui-smoketest-private-dyld \
  ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./payload/pm-carbon-gui-cps-registration-compat.dylib \
  ./payload/pm-carbon-gui-cps-registration-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./dn-carbon-gui-registration-broker \
  ./dn-carbon-gui-registration-broker.sha256 \
  ./payload/lion-ppc-carbon-gui-notification-registration.log
```

Do not rerun before review.

## Notification acceptance discriminator

Require exactly 21:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:
```

Require exactly once:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=21 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=21 callbacks=0
```

Require zero:

```text
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:FAIL
request index 22
```

The broker's internal exact-sequence checks remain authoritative. If the historical client differs from the reviewed sequence beyond its client string, this phase must fail rather than widening policy.

## CPS-registration discriminator

The already proven CPS path must remain exact:

```text
PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=lion-create-application-carbon-smoketest-v1 exact=YES
PM_CPS_REGISTRATION_COMPAT_NATIVE_REPLY:index=1 ... id=0x00007425 result=0
PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS
```

Require no:

```text
PM_CPS_REGISTRATION_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH
_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304
```

## Other acceptance gates

Require:

```text
Rosetta PPC Carbon GUI window shown: ... visible=1
Rosetta PPC Carbon GUI smoke test: ... timer=1
carbon_gui_exec_status=0
protected_hashes_unchanged=YES
titlebar_translated_count=6
titlebar_guard_reject_count=0
RESULT: PPC_CARBON_GUI_NOTIFICATION_REGISTRATION_INTEGRATION_PASS
visual_window_observation=MANUAL_REQUIRED
RESULT: PASS
```

All previously accepted adapter counts must remain at the runner's exact expected values.

After the run, state separately whether the Carbon GUI window was actually visible. If all machine gates pass but no window is visually visible, notification client identity is closed and the next investigation must move to the WindowServer/display-state boundary rather than broadening more known compatibility policy.

## Return for review

Return:

```text
dn-carbon-gui-registration-broker.info.txt
dn-carbon-gui-registration-broker.sha256
lion-ppc-carbon-gui-notification-registration.log
lion-ppc-carbon-gui-notification-registration.raw.log
sys295-carbon-gui-notification-registration.log
pm-carbon-gui-cps-registration-compat.dylib.info.txt
pm-carbon-gui-cps-registration-compat.dylib.sha256
ppc-carbon-gui-smoketest-private-dyld.info.txt
ppc-carbon-gui-smoketest-private-dyld.sha256
```

Also return any new crash/core diagnostic named by the runner and state the manual window observation.

## Current boundary

```text
historical Carbon smoke subject                     exact / exits 0
historical CPS registration                         LIVE-PROVEN PASS
historical app marker visible=1                     observed
manual visual window                                NOT OBSERVED
Process Manager-bound notification broker           21 schema rejects
historical-client exact-21 notification broker      NEXT
titlebar / CGS compatibility                        held at accepted state
LaunchServices / Finder / Cocoa                     HELD
XNU                                                  no source change indicated
```
