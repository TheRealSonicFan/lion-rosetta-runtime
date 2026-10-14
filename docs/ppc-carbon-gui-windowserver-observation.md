# Carbon GUI WindowServer observation differential

## Status

**NEXT CONTROLLED STEP.** The exact historical Carbon GUI subject now passes the complete restored compatibility stack on Lion: CPS registration succeeds, all 21 distributed-notification registrations are accepted exactly, the subject reaches both historical markers, exits 0, produces no new diagnostic, preserves protected hashes, and retains all accepted CGS/titlebar adapter counts. The process appears in the Dock, but the **Rosetta PPC Carbon GUI** window is still not visually observable.

This means no known client-policy compatibility gate remains intentionally held. The next question is purely observational: **what does WindowServer itself report for the historical window while the application claims IsWindowVisible(window) == true?**

Do not patch any CGS transaction yet. The Lion raw trace still contains older diagnostics such as CGSGetDisplayBounds (display 0), CGSShapeWindow type-check failure, invalid display 0x0 color-space lookup, and repeated _CGSLockWindow backing synchronization failures. Those signatures also occurred during earlier Process Manager validation runs, so the current evidence does not isolate any one of them as the cause of the manual visibility discrepancy.

## Objective

Use one native, read-only CGWindowListCopyWindowInfo() observer against the **same exact PPC smoke binary** on:

1. Snow Leopard 10.6.8 / 10K549, as the positive visual baseline; then
2. Lion 10.7.5 / 11G63 with the complete accepted restored stack.

The observer records, for every WindowServer window owned by the target PID:

~~~
window number
kCGWindowIsOnscreen
layer
alpha
bounds
sharing state
store type
memory usage
owner name
window name/title
~~~

It also records the native main display ID and active-display bounds. It does not modify the PPC process, WindowServer, display configuration, or any compatibility policy.

## Exact reused artifacts

Historical PPC subject:

~~~
ppc-carbon-gui-smoketest-private-dyld
SHA-256:
fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067
~~~

Lion CPS/full-stack PPC compatibility artifact:

~~~
pm-carbon-gui-cps-registration-compat.dylib
SHA-256:
519bd455d9f343821b2bd7d4eb22222bb18379f9c30bdc0d3a225ca9ac3d4c30
~~~

Lion Carbon GUI exact-21 notification broker:

~~~
dn-carbon-gui-registration-broker
build_id=distributed-notifications-carbon-gui-registration-broker-v1
SHA-256:
ba7477848f84bbefdbdaa188f847aa8c369ccb0d63c9ac88bbbd752fc7bed5ac
~~~

Accepted Lion kernel:

~~~
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
~~~

## Pinned implementation

Current runtime main:

~~~
tests/native-cgwindowlist-pid-observer.c
Git blob b89ee954c89f66b2f9d7f41aef104d2b0fd1a0e9

scripts/build-native-cgwindowlist-pid-observer-on-snowleopard.sh
Git blob 3f616430bf5d3c735cc1fc62416f47bcdf7d4aa8

scripts/run-snowleopard-ppc-carbon-gui-windowserver-observation-control.sh
Git blob 570d972b0135bbef67deb2cd93b2c74bb58b706b

scripts/run-lion-ppc-carbon-gui-windowserver-observation.sh
Git blob b4eb57796207de34a79f884ddc0cc195bef5f147
~~~

Observer build ID:

~~~
cgwindowlist-pid-observer-v1
~~~

The observer is built **once on Snow Leopard as i386** and the exact built binary is transferred unchanged to Lion. This holds the observation implementation constant across the differential.

## Safety constraints

- Snow: 10.6.8 / 10K549 only.
- Lion: 10.7.5 / 11G63 only.
- Run from the logged-in Aqua console user's Terminal on both systems.
- Do not rebuild the historical PPC subject.
- Do not rebuild the already accepted Lion PPC compatibility artifact.
- Do not modify or rebuild the accepted Carbon GUI notification broker for this step.
- Do not add any new CGS compatibility rule.
- Do not alter display resolution, Spaces, window ordering manually, system frameworks, Rosetta, dyld, caches, or XNU.
- The observer is read-only and must use public CGWindowListCopyWindowInfo / display-query APIs only.
- Run the Snow subject once and the Lion subject once before review.
- Record manual visual observation separately on both systems.

## Phase A — update and pin

On Snow Leopard:

~~~sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/native-cgwindowlist-pid-observer.c)" = \
  "b89ee954c89f66b2f9d7f41aef104d2b0fd1a0e9" || exit 1
test "$(git hash-object ./scripts/build-native-cgwindowlist-pid-observer-on-snowleopard.sh)" = \
  "3f616430bf5d3c735cc1fc62416f47bcdf7d4aa8" || exit 1
test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-windowserver-observation-control.sh)" = \
  "570d972b0135bbef67deb2cd93b2c74bb58b706b" || exit 1

/bin/bash -n ./scripts/build-native-cgwindowlist-pid-observer-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-windowserver-observation-control.sh || exit 1
~~~

On Lion:

~~~sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-windowserver-observation.sh)" = \
  "b4eb57796207de34a79f884ddc0cc195bef5f147" || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-windowserver-observation.sh || exit 1
~~~

Also pull the current XNU companion checkout and leave it unchanged.

## Phase B — build the observer on Snow Leopard

~~~sh
cd /path/to/lion-rosetta-runtime || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-native-cgwindowlist-pid-observer-on-snowleopard.sh \
  ./cgwindowlist-pid-observer || exit 1
~~~

Require:

~~~
cgwindowlist-pid-observer
cgwindowlist-pid-observer.info.txt
cgwindowlist-pid-observer.sha256
~~~

The info file must show build_id=cgwindowlist-pid-observer-v1, architecture i386, and imports for the public WindowServer observation surface.

## Phase C — Snow positive-control observation

Use the exact historical subject and the newly built observer:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-windowserver-observation-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-windowserver-snow-control.log \
  ./ppc-carbon-gui-windowserver-snow-observer.log
~~~

The Snow control requires the normal application markers, observer success, at least one target-PID window sample, at least one onscreen=YES sample, and at least one exact-title sample.

Also state whether the window was manually visible. If the Snow observer cannot see an onscreen exact-title window, **stop before Lion** and return the Snow evidence; the observation control itself is not valid.

## Phase D — transfer the exact observer to Lion

Copy these three files unchanged:

~~~
cgwindowlist-pid-observer
cgwindowlist-pid-observer.info.txt
cgwindowlist-pid-observer.sha256
~~~

to the Lion runtime payload/ directory.

Verify the transferred observer SHA against its Snow sidecar before the Lion run.

## Phase E — verify the already accepted Lion stack

Require the exact hashes above for:

~~~
payload/ppc-carbon-gui-smoketest-private-dyld
payload/pm-carbon-gui-cps-registration-compat.dylib
dn-carbon-gui-registration-broker
~~~

Keep all Security, CGS/FontServer, HIToolbox Extras, titlebar, private dyld, cache, CoreGraphics, translator, and kernel identities at their already accepted values.

## Phase F — fresh syscall-295 preflight

~~~sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  ./sys295-carbon-gui-windowserver-observation.log || exit 1
~~~

Require EBADF without SIGSYS and final RESULT: PASS.

## Phase G — exactly one Lion observation run

~~~sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-carbon-gui-windowserver-observation.sh \
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
  ./payload/lion-ppc-carbon-gui-windowserver-observation.log \
  ./payload/cgwindowlist-pid-observer \
  ./payload/cgwindowlist-pid-observer.sha256 \
  ./payload/lion-ppc-carbon-gui-windowserver-observer.log
~~~

Do not rerun before review.

## Existing restored-stack gates

The Lion run must still satisfy all previously closed gates:

~~~
CPS registration exact / native result 0 / adapter PASS
21 notification registrations accepted
register=21 callback=0 rejects=0 exact=YES
notification broker PASS / exit 0
no request 22
both historical application markers once
subject exit 0
all accepted adapter counts exact
six titlebar translations / zero guard rejects
no new crash/core diagnostic
protected hashes unchanged
~~~

The runner must finish:

~~~
RESULT: PPC_CARBON_GUI_WINDOWSERVER_OBSERVATION_COMPLETE
visual_window_observation=MANUAL_REQUIRED
RESULT: PASS
~~~

This result means the observation run was valid; it does **not** claim that the Carbon window was visually presented.

## WindowServer evidence to review

The observer emits:

~~~
CGWINDOW_OBSERVER_MAIN_DISPLAY:
CGWINDOW_OBSERVER_ACTIVE_DISPLAY:
CGWINDOW_OBSERVER_WINDOW:
CGWINDOW_OBSERVER_SAMPLE:
CGWINDOW_OBSERVER_SUMMARY:
CGWINDOW_OBSERVER_RESULT:PASS
~~~

Compare Snow and Lion for the exact target PID/title, especially samplesWithWindows, samplesWithOnscreen, samplesWithExactTitle, maxWindows, maxOnscreen, maxExactTitle, window number, onscreen state, layer, alpha, bounds, owner/name, and native main display ID/bounds.

Do not infer a fix until this comparison is reviewed.

## Interpretation boundary

- **Snow onscreen exact-title window; Lion no target window at all:** the PPC Carbon object is not materializing as a WindowServer window on Lion; investigate the earliest window-registration/backing transaction after NewWindow.
- **Lion target window exists but onscreen=NO:** investigate ordering, display assignment, or visibility state before any backing compatibility change.
- **Lion is onscreen but alpha is zero:** investigate opacity/alpha state.
- **Lion is onscreen with nonzero alpha but bounds are off-display:** investigate geometry/display selection.
- **Lion is onscreen, nonzero alpha, expected bounds/title, yet still manually invisible:** move to backing/compositor state. At that point the existing CGSShapeWindow / _CGSLockWindow diagnostics become high-priority rather than merely correlated.
- A differing native main display ID may make the old display 0 diagnostics relevant, but no display-ID rewrite is authorized from the current evidence alone.

## Return for review

Return exactly:

~~~
cgwindowlist-pid-observer.info.txt
cgwindowlist-pid-observer.sha256
ppc-carbon-gui-windowserver-snow-control.log
ppc-carbon-gui-windowserver-snow-observer.log
lion-ppc-carbon-gui-windowserver-observation.log
lion-ppc-carbon-gui-windowserver-observation.raw.log
lion-ppc-carbon-gui-windowserver-observer.log
sys295-carbon-gui-windowserver-observation.log
~~~

Also state separately:

~~~
Snow manual Carbon window visible: YES/NO
Lion manual Carbon window visible: YES/NO
~~~

Return any new crash/core diagnostic named by either runner.

## Current boundary

~~~
historical subject / full restored stack            MACHINE-PROVEN PASS
historical CPS registration                         LIVE-PROVEN PASS
historical-client exact-21 notifications            LIVE-PROVEN PASS
manual Lion Carbon window                           NOT OBSERVED
WindowServer Snow/Lion window-state differential    NEXT: read-only observation
new CGS/display compatibility                       NO
LaunchServices / Finder / Cocoa                     HELD
XNU                                                  no source change indicated
~~~
