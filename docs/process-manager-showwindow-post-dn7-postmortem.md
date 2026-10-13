# ShowWindow post-exact-seven crash postmortem

## Objective

Analyze the preserved Lion crash/core from the exact-seven distributed-notification registration run **without rerunning the PPC subject**.

The exact-seven registration experiment closed the notification boundary that had been held since the WindowBackingInfo fix. The seventh request was accepted with the reviewed ColorSync tuple, the broker finished exact and PASS, no eighth request appeared, and `ShowWindow` still did not return. The first visible diagnostics after the accepted seventh registration are three CoreUI `Invalid ArtFile Path!` messages followed by process exit status 139.

This stage determines the actual faulting thread, exception, guest/host call path, and crash PC before deciding whether CoreUI, RawCamera, another framework path, or Rosetta itself is the next compatibility boundary.

## Evidence entering this stage

The returned exact-seven broker build is valid:

```text
build_id      distributed-notifications-showwindow-seventh-registration-broker-v1
architecture  i386
broker SHA    7360bcd68e0b5bc473540143e1bd7fb1cb1544a60f530d1c2f6df57469db46a9
source SHA    a778330832c2e23dcf10ce3999aaafff7fa57994810b7fa37c8c6066c2e649f1
```

The SHA sidecar matches the broker SHA recorded by the build-info file and by the Lion runner.

Syscall 295 remains on the accepted kernel:

```text
mach_kernel_sha256  fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
result              -1
errno               9
saw_sigsys          0
probe_exit_status   0
RESULT              PASS
```

The exact-seven run re-proved the current upstream chain:

```text
WindowBackingInfo adapter       PASS exactly once
backing-data shmem map failure  absent
_CGSLockWindow failure          absent
ColorProfileClient adapter      PASS exactly once
ResolveColorProfile adapter     PASS exactly once
FontServer rendezvous           PASS
registration 6                  accepted
registration 7                  accepted
broker summary                  register=7 callback=0 rejects=0 exact=YES
broker result                   PASS
protected hashes                unchanged
```

The reviewed seventh request was:

```text
Mach request index  7
bits                0x1111
id                  4
size                356
payload             322
allowed tuple       5
name                com.apple.ColorSync.DisplayProfileNotification
object              kCFNotificationAnyObject
behavior            4
public behavior     2 / Coalesce
counter             1
entry               0x3797d0 in this run
```

There is **no request index 8** in the returned raw log.

After request 7 is accepted, the only application-visible diagnostics before termination are:

```text
CoreUI: Invalid ArtFile Path! A6 13 16 1F 7A 00 00 00 west.clear.colorsrgb.determinate.scrollbars
CoreUI: Invalid ArtFile Path! A6 16 1F 56 7A 00 00 00 west.colorsrgb.determinate.minus.scrollbars
CoreUI: Invalid ArtFile Path! A6 16 1F 7A B6 00 00 00 west.colorsrgb.determinate.scrollbars
```

The subject then exits 139 and never reaches:

```text
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
```

The runner named these preserved diagnostics:

```text
$HOME/Library/Logs/DiagnosticReports/ppc-process-manager-cgs-session-bootstrap-integration-private-dy_2026-10-12-235958_Andys-Mac.crash
/cores/core.89664
```

The hidden crash plist may remain preserved but is not needed by the collector.

## Important result-label correction

The returned integration report ends with:

```text
RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_PREDICATE_NOT_REACHED
```

That label is a runner-ordering artifact for this exact-seven run, not evidence that the previously proven SetFrontWindow adapter regressed. The process terminates after the accepted seventh registration and before AddTrackingArea, OrderFrontConditionally, or SetFrontWindow are reached in this execution.

Runtime `main` now classifies this exact state earlier as:

```text
POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_PASS_TERMINATED_BEFORE_RETURN
```

Do **not** rerun the subject merely to obtain the improved label. The preserved raw log and crash/core are sufficient.

## Prepared collector

Current runtime `main` provides:

```text
scripts/collect-lion-dn7-showwindow-core.sh
docs/process-manager-showwindow-post-dn7-postmortem.md
```

The collector is read-only. It:

- requires Mac OS X 10.7.5;
- verifies the accepted Rosetta translator SHA-256;
- opens only the preserved core with Apple GDB in batch/postmortem mode;
- records x86 register state, the selected backtrace, all-thread backtraces, and loaded shared libraries;
- records instructions and raw bytes around the actual core EIP;
- records stack/frame memory;
- embeds the preserved Apple crash report;
- extracts a 512-byte host crash window around EIP and records its SHA-256;
- never attaches to a live process;
- does not modify the PPC subject, frameworks, services, Rosetta, dyld, caches, or XNU.

## Safety constraints

- Do not rerun the exact-seven PPC subject.
- Do not rebuild the exact-seven broker.
- Do not accept an eighth notification request.
- Do not alter the WindowBackingInfo one-call cap.
- Do not alter ColorProfileClient or ResolveColorProfile compatibility.
- Do not adapt AddTrackingArea, OrderFrontConditionally, or SetFrontWindow merely because they were not reached in this run.
- Do not adapt `CGSShapeWindow`.
- Do not patch or replace CoreUI assets.
- Do not patch RawCamera.
- Do not copy Snow Leopard CoreUI or RawCamera binaries/resources onto Lion.
- Do not attach GDB to a live Rosetta process.
- Do not use DTrace or dtruss.
- Do not restart WindowServer, distnoted, fontd, Dock, launchd, or related jobs.
- Do not change XNU, rebuild the kernel, or reboot for this stage.
- Preserve `/cores/core.89664` and the matching crash report until the postmortem result is reviewed.

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

No Snow Leopard action is required.

## Phase B — confirm the preserved crash/core

On Lion:

```sh
CORE=/cores/core.89664
CRASH="$HOME/Library/Logs/DiagnosticReports/ppc-process-manager-cgs-session-bootstrap-integration-private-dy_2026-10-12-235958_Andys-Mac.crash"

ls -lh "$CORE" "$CRASH" || exit 1
```

If either file is missing, stop and report which file is unavailable. Do **not** rerun the PPC subject to recreate it.

## Phase C — syntax-check the collector

```sh
cd "$RUNTIME" || exit 1
/bin/bash -n ./scripts/collect-lion-dn7-showwindow-core.sh || exit 1
```

## Phase D — run the read-only postmortem collector

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/collect-lion-dn7-showwindow-core.sh \
  "$CORE" \
  "$CRASH" \
  ./payload/lion-dn7-postmortem.txt
```

Require:

```text
Created:
  .../lion-dn7-postmortem.txt
  .../lion-dn7-crash.bin
  .../lion-dn7-crash.bin.sha256
No live process was attached and no system file was modified.
RESULT: PASS
```

If the collector reports a failed GDB pass, preserve the generated text report and stop.

## Phase E — return evidence

Return exactly these three postmortem artifacts:

```text
lion-dn7-postmortem.txt
lion-dn7-crash.bin
lion-dn7-crash.bin.sha256
```

Do not upload the full core unless specifically requested after this report is reviewed.

## Review gate

### Fault localizes to CoreUI/theme-art rendering

If the crash report/PPC stack places the failure in CoreUI or the HIToolbox/CoreUI theme rendering path immediately after one of the observed `Invalid ArtFile Path!` diagnostics, the next stage will be a read-only Snow-Leopard-versus-Lion CoreUI/theme-resource differential. Do not patch asset identifiers or substitute Snow resources until that differential identifies the exact contract difference.

### Fault localizes to RawCamera/ImageIO

If the crash stack instead places the failure in RawCamera, ImageIO, or plug-in initialization, the next stage will audit that exact caller/resource/ABI path. RawCamera loading by itself is not proof of causality.

### Fault localizes to another PPC framework path

Follow the actual PPC stack. The new faulting function and its immediate inputs become the next boundary; the CoreUI strings remain observational only.

### Fault is Rosetta host-side without a meaningful PPC stack

Use the host EIP/registers, translator backtrace, stack memory, and extracted crash window to determine whether the failure is a translator execution fault or a guest-requested signal path before considering any user-space framework compatibility.

### Crash/core mismatch or unreadable evidence

Stop. Treat it as a provenance/evidence problem. Do not create a new live experiment merely to obtain cleaner diagnostics.

## Current boundary

```text
syscall 295 compatibility                         PASS
WindowBackingInfo compatibility                   PASS
backing-data shmem mapping failure                 cleared
ColorProfileClient compatibility                  PASS
ResolveColorProfile compatibility                 PASS
exact-seven notification broker                   PASS
seventh ColorSync registration                    accepted
eighth notification request                       not observed
S01_AFTER_ShowWindow                              absent
first visible post-seventh diagnostic              CoreUI Invalid ArtFile Path x3
process exit                                       139
crash/core                                         preserved
next step                                          read-only crash/core postmortem
AddTrackingArea / OrderFront / SetFrontWindow      not reached in this run; prior proofs retained
CGSShapeWindow                                     held
CoreUI / RawCamera modification                    held
XNU                                                no change indicated
```
