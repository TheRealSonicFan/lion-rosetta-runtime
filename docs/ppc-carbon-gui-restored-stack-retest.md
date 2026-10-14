# Original PPC Carbon GUI restored-stack retest

## Objective

Rerun the **exact original Snow-positive Carbon GUI smoke binary** that first exposed the Lion Process Manager failure, now under the complete accepted restored stack.

All constituent live boundaries used by that original subject are now independently closed on Lion:

```text
GetCurrentProcess / foreground conversion / SetFrontProcess       PASS
CreateNewWindow and title/show/select/visibility                   PASS
NewEventLoopTimerUPP / GetMainEventLoop / InstallEventLoopTimer    PASS
RunApplicationEventLoop with timer-side QuitApplicationEventLoop   PASS
all 21 reviewed distributed-notification registrations             PASS
RemoveEventLoopTimer                                                PASS
DisposeEventLoopTimerUPP                                            PASS
CFRelease(title) / DisposeWindow / lifecycle completion             PASS
```

The next question is therefore end-to-end and deliberately uninstrumented at the application layer: does the same original smoke subject that historically self-SIGABRTed on Lion now show its Carbon window, run the timer-driven event loop, clean up, print its final success marker, and exit 0 without any new compatibility rule?

## Exact historical subject

Use the original Snow Leopard-positive-control executable unchanged:

```text
payload/ppc-carbon-gui-smoketest-private-dyld
SHA-256:
fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067
```

Historical Snow control for this exact executable already passed on 10.6.8 / 10K549 and printed both:

```text
Rosetta PPC Carbon GUI window shown:
Rosetta PPC Carbon GUI smoke test:
```

The old Lion run of this exact binary is the original failure: it aborted before the first marker. Do **not** rebuild or instrument the subject for this retest. The purpose is to close that historical failure with the exact same guest executable.

If the exact binary or its SHA sidecar is no longer present in `payload/`, stop. Recover the preserved original artifact rather than substituting a newly built binary.

## Pinned repository implementation

Current runtime `main` provides:

```text
tests/ppc-carbon-gui-smoketest.c
scripts/build-ppc-carbon-gui-smoketest-on-snowleopard.sh
scripts/run-lion-ppc-carbon-gui-restored-stack.sh
tests/native-dn-runapplicationeventloop-remaining-registration-broker.c
scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh
```

Pinned blobs:

```text
original Carbon GUI source             5f75cad34e52dac60d1ebddd1a6f0d0eeb386989
historical Snow builder                b67640c2c19e4c4c6d019ce5279031254e8621b3
restored-stack Lion runner             b493ea536a9a1646f16d2b3837fba082965a9515
exact twenty-one broker source         03504584b0d1e9e97c1fd3663ee4590c692ab940
exact twenty-one broker builder        5f10c92f15d2a79c76bf07ae68eae58228d0e486
XNU syscall-295 runner                 eaecc9bfbf4d780664c7e66471a832a0289aebb6
```

Accepted fixed identities:

```text
CoreServices / CGS compatibility
28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578

Security interposer
9aed61996fd5079299f7b8971a77efcfc25908636618e4754866ea8267306b51

CGS / FontServer interposer
f7dbcb98cbf5d64f95a33af222432d5a86ba273b475f5e3de83fff6d6c3c931b

exact twenty-one broker
d7912d9761049f1382028ad0d16854915aa531fe0963df67be5678efb413b5d4

HIToolbox Extras compatibility
a5b385d29bb5a6d887122ba0b2a7b1e78c45a1b69bfceb687c9cb2c77cc70572

Snow HIToolbox Extras resource
a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197

exact-six titlebar compatibility
6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72

private PPC dyld
963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb

accepted Lion kernel
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Run from the logged-in Aqua console user's Terminal.
- Use the exact historical subject SHA-256 above; do not rebuild it.
- Rebuild only the native exact-twenty-one broker.
- Use only the already accepted compatibility artifacts and modes.
- Do not add or modify a compatibility rule.
- Do not broaden the exact-six titlebar policy.
- Reject any notification request after index 21.
- Do not alter Rosetta, dyld, system frameworks, resources, caches, LaunchServices, or XNU.
- No kernel rebuild or reboot.
- Do not use `open`, Finder, LaunchServices, Cocoa, or another PPC application in this step.
- Execute the PPC smoke subject exactly once before review.

## Phase A — update and pin

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-carbon-gui-smoketest.c)" = \
  "5f75cad34e52dac60d1ebddd1a6f0d0eeb386989" || exit 1
test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-restored-stack.sh)" = \
  "b493ea536a9a1646f16d2b3837fba082965a9515" || exit 1
test "$(git hash-object ./tests/native-dn-runapplicationeventloop-remaining-registration-broker.c)" = \
  "03504584b0d1e9e97c1fd3663ee4590c692ab940" || exit 1
test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh)" = \
  "5f10c92f15d2a79c76bf07ae68eae58228d0e486" || exit 1

/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-restored-stack.sh || exit 1
/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh || exit 1

cd "$ROSETTA_XNU" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git hash-object ./tools/run_syscall295_probe.sh)" = \
  "eaecc9bfbf4d780664c7e66471a832a0289aebb6" || exit 1
```

Stop if Phase A fails.

## Phase B — verify the exact original smoke subject

On Lion:

```sh
cd "$RUNTIME" || exit 1

test -x ./payload/ppc-carbon-gui-smoketest-private-dyld || exit 1
test -f ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256 || exit 1
test "$(/usr/bin/shasum -a 256 ./payload/ppc-carbon-gui-smoketest-private-dyld | /usr/bin/awk '{print $1}')" = \
  "fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067" || exit 1
test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256)" = \
  "fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067" || exit 1

/usr/bin/otool -l ./payload/ppc-carbon-gui-smoketest-private-dyld | \
  /usr/bin/grep -A3 LC_LOAD_DYLINKER | \
  /usr/bin/grep -Fq 'name /usr/oah/dyld ' || exit 1
```

If the exact historical binary is missing, stop rather than rebuilding it in this phase.

## Phase C — rebuild only the exact twenty-one native broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh \
  ./dn-runapplicationeventloop-remaining-registration-broker || exit 1
```

Require:

```text
build_id=distributed-notifications-runapplicationeventloop-remaining-registration-broker-v1
architecture=i386
SHA-256=d7912d9761049f1382028ad0d16854915aa531fe0963df67be5678efb413b5d4
```

Do not alter the broker policy.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-carbon-gui-restored-stack.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one original Carbon GUI restored-stack run

Confirm these accepted payload files are present:

```text
payload/pm-selectwindow-orderfront-compat.dylib
payload/pm-selectwindow-orderfront-compat.dylib.sha256
payload/ppc-process-manager-security-session-auditinfo-api.dylib
payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256
payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib
payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256
payload/ppc-hitoolbox-extras-resource-compat.dylib
payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256
payload/SnowLeopard-HIToolbox-Extras.rsrc
payload/pm-titlebar-bsearch-six-key-compat.dylib
payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256
```

Then:

```sh
cd "$RUNTIME" || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-carbon-gui-restored-stack.sh \
  ./payload/ppc-carbon-gui-smoketest-private-dyld \
  ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./payload/pm-selectwindow-orderfront-compat.dylib \
  ./payload/pm-selectwindow-orderfront-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./dn-runapplicationeventloop-remaining-registration-broker \
  ./dn-runapplicationeventloop-remaining-registration-broker.sha256 \
  ./payload/lion-ppc-carbon-gui-restored-stack.log
```

The runner supplies the accepted full compatibility environment itself. Do not add extra `ROSETTA_*` modes or another `DYLD_INSERT_LIBRARIES` entry.

A small window titled **Rosetta PPC Carbon GUI** should appear for about two seconds and close automatically. Visual observation is supporting evidence; the logged discriminators remain authoritative.

Do not run the subject a second time before review.

## Acceptance discriminator

Require the exact original application markers once:

```text
Rosetta PPC Carbon GUI window shown:
Rosetta PPC Carbon GUI smoke test:
carbon_gui_exec_status=0
```

Require the exact notification policy:

```text
21 registration accepts
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=21 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=21 callbacks=0
notification_request22_count=0
```

Require the accepted adapters to fire with the runner's exact counts, including:

```text
security/session/server-version/CPS-registration/CPS-setfront = 1 each
DockServer/NewWindow/ReleaseBacking/opacity-alpha = 1 each
WindowBackingInfo/FontServer/rendezvous = 1 each
ColorProfileClient/ResolveColorProfile = 1 each
AddTrackingArea/SetFrontWindow = 1 each
OrderFrontConditionally = 2
```

Require titlebar:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
```

Require no new crash/core diagnostic and:

```text
protected_hashes_unchanged=YES
RESULT: PPC_CARBON_GUI_RESTORED_STACK_PASS
RESULT: PASS
```

## Failure classification

- Exact subject hash mismatch: wrong historical artifact; stop.
- Failure before `Rosetta PPC Carbon GUI window shown:`: historical early GUI path remains unresolved; preserve diagnostic/raw log.
- First marker present but final smoke marker absent: event-loop or cleanup regression; preserve raw log.
- Notification request 22 or broker reject: do not broaden the broker; preserve evidence.
- Adapter-count or titlebar mismatch: do not broaden compatibility; preserve evidence.
- Any new crash/core diagnostic: return it with the requested logs.
- Any protected-hash change: stop immediately.

## Return evidence

Return exactly:

```text
payload/ppc-carbon-gui-smoketest-private-dyld.info.txt
payload/ppc-carbon-gui-smoketest-private-dyld.sha256
dn-runapplicationeventloop-remaining-registration-broker.info.txt
dn-runapplicationeventloop-remaining-registration-broker.sha256
sys295-carbon-gui-restored-stack.log
payload/lion-ppc-carbon-gui-restored-stack.log
payload/lion-ppc-carbon-gui-restored-stack.raw.log
```

Also state whether the **Rosetta PPC Carbon GUI** window was visually observed, and return any new crash report or core file named by the runner.

## Current boundary

```text
incremental restored Carbon GUI lifecycle           LIVE-PROVEN through full cleanup
exact 21 Lion notification registrations            LIVE-PROVEN PASS
original Snow-positive Carbon GUI smoke binary      historically failed on Lion
original smoke under completed restored stack       NEXT: one exact historical-binary run
new compatibility families                          NO
titlebar policy broadening                          NO
LaunchServices / Finder / Cocoa / real applications HELD
XNU                                                  no source change indicated
```


## Reviewed Lion result

The exact historical Snow-positive subject SHA-256 `fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067` executed to completion on Lion: it printed both `Rosetta PPC Carbon GUI window shown: ... visible=1` and `Rosetta PPC Carbon GUI smoke test: ... timer=1`, exited 0, produced no new diagnostic, preserved protected hashes, kept all six titlebar translations exact, and retained the accepted downstream CGS adapter counts. The process appeared in the Dock, but no Carbon window was visually observed.

The run did **not** validate the intended full restored stack. Its legacy CPS CheckInApplication request was `id=0x7372`, `send=0x68`, `recv=0x2c`, `stringLength=0x26`; the accepted `lion-create-application-v1` predicate is deliberately pinned to the longer Process Manager validation basename/request, so it reported `exact=NO`, passed through unchanged, and Lion returned `-304 / MIG_BAD_ARGUMENTS`. The log explicitly reported failure to register the process with CPS/CoreGraphics. This is the current visual-presentation boundary.

The exact-21 notification broker was also client-bound to the Process Manager validation basename and therefore rejected all 21 registrations with schema status 20. Because the subject still reached both markers and exit 0, notification policy is held rather than broadened in the next step.

Current `main` advances to `docs/ppc-carbon-gui-cps-registration-integration.md`, which changes only the exact CPS registration predicate for `ppc-carbon-gui-smoketest-private-dyld` and deliberately leaves the 21 notification schema rejects unchanged for isolation.
