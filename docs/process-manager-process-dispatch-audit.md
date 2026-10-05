# Process Manager / LaunchServices process-dispatch audit

## Objective

Determine why translated PPC still self-aborts inside the first Process Manager identity call after the exact HIServices no-ASN abort control has been disabled successfully inside the test process.

The completed no-ASN discriminator closes the later HIServices abort hypothesis for the observed Lion crash. The next target is the earlier LaunchServices process-services initialization path, especially the state produced by:

- `SetupCoreApplicationServicesCommunicationPort()`;
- `_LSDoInitializeProcessesServices`;
- `getProcessDispatchTable()`;
- `getProcessesServerPort()`;
- session discovery through `GetOurLSSessionIDInit()`.

This stage is read-only. It does not launch another PPC application.

## Evidence established by the no-ASN discriminator

The exact PPC discriminator executable passes on Snow Leopard 10.6.8 with:

- `LSDONOTABORTIFNOASN=0` visible in the process;
- `GetProcessForPID(getpid(), &psn) == noErr`;
- a nonzero returned PSN;
- `RESULT: PASS`.

On Lion 10.7.5, the same executable and bundle environment reach `main()`, verify `LSDONOTABORTIFNOASN=0`, and reach the marker immediately before `GetProcessForPID`. The function never returns and the runner reports:

```text
RESULT: ABORT_BEFORE_GETPROCESSFORPID_RETURN
```

The new crash remains `EXC_CRASH (SIGABRT)` in the same already-decoded Rosetta guest-requested self-abort wrapper family. The subject PID is supplied with signal 6 and the posix flag, and the host-side call returns successfully.

The syscall-295 safety probe still passes and all guarded kernel, LaunchServices, dyld/cache, and PPC executable hashes remain unchanged.

Therefore the observed fatal path is upstream of the later HIServices no-ASN abort controlled by `LSDONOTABORTIFNOASN`.

## Why process-dispatch setup is now the leading boundary

The previous static audit already showed that Snow Leopard PPC LaunchServices `getProcessDispatchTable()` behaves as follows:

1. if its process-services state is absent, call `SetupCoreApplicationServicesCommunicationPort()`;
2. read the process dispatch table;
3. call `abort()` if that table is still null.

`getProcessesServerPort()` uses the same setup path and triggers `LSReCheckInApplication()` if the backing port changes.

The setup function itself performs a session/service initialization sequence around:

- `scCreateSystemServiceVersion`;
- the `LaunchApplicationServices` service name;
- `GetOurLSSessionIDInit()` / `SessionGetInfo`;
- `_LSDoInitializeProcessesServices`;
- process-service version negotiation;
- `CFMachPortCreateWithPort`;
- reconnect registration.

Lion's native i386 implementation has a structurally similar setup path, but the earlier audits did not disassemble the complete InitializeProcessesServices client/server family. That is now the missing comparison.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-process-dispatch.py
docs/process-manager-process-dispatch-audit.md
```

The analyzer is Python-2-compatible and read-only. It records:

- OS/build and the PowerPC architecture handler;
- active `coreservicesd`, WindowServer, and related launchd state;
- the installed `coreservicesd` executable hash, architectures, and dependencies;
- `com.apple.coreservicesd` LaunchDaemon metadata and Mach-service declaration;
- architecture-specific LaunchServices hashes and dependencies;
- symbols/imports and full static windows matching:
  - `SetupCoreApplicationServicesCommunicationPort`;
  - `getProcessDispatchTable`;
  - `getProcessesServerPort`;
  - `GetOurLSSessionID`;
  - `LSNullInitializeProcessesServices`;
  - `LSServerWrapperInitializeProcessesServices`;
  - `LSDaemonModeInitializeProcessesServices`;
  - related InitializeProcessSharedMemory routines;
- mapped cstrings for `LaunchApplicationServices`, process-services initialization/version diagnostics, coreservicesd/session lookup, and `SCDontUseServer`.

Snow Leopard validation requires the relevant PPC/ppc7400 LaunchServices targets. Lion validation requires the corresponding i386 targets; x86_64 is collected as additional native-server context.

## Safety constraints

For this audit:

- do not launch the PPC test application;
- do not repeat the no-ASN discriminator;
- do not set `LSDONOTABORTIFNOASN` globally;
- do not use `SCDontUseServer`;
- do not patch or replace LaunchServices, HIServices, CoreServices, or coreservicesd;
- do not restart, signal, suspend, or replace coreservicesd, WindowServer, pbs, or launchd jobs;
- do not alter the LaunchServices database;
- do not broaden or install the private LaunchServices PPC-admission patch;
- do not modify the Rosetta cache, Rosetta shims, or `/usr/oah/dyld`;
- do not transplant Snow Leopard frameworks or daemons;
- do not modify XNU;
- do not use GDB, DTrace, dtruss, or live code injection.

This stage creates temporary architecture slices only under the system temporary directory and removes them on exit.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-process-manager-process-dispatch.py
docs/process-manager-process-dispatch-audit.md
```

On Lion, the XNU checkout may also be updated for documentation consistency, but no kernel rebuild or reboot is part of this stage.

## Phase B — Snow Leopard process-dispatch audit

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-process-dispatch.py \
  ./process-manager-process-dispatch-snowleopard.txt
```

Require:

```text
Created: ./process-manager-process-dispatch-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return the report unchanged.

## Phase C — Lion process-dispatch audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-process-dispatch.py \
  ./payload/process-manager-process-dispatch-lion.txt
```

Require:

```text
Created: ./payload/process-manager-process-dispatch-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop. Do not compensate by rerunning the PPC application or restarting coreservicesd.

## Phase D — stop and return evidence

Return:

```text
process-manager-process-dispatch-snowleopard.txt
process-manager-process-dispatch-lion.txt
```

Keep the no-ASN discriminator evidence available, especially:

```text
ppc-process-manager-noasn-snowleopard-control.log
lion-ppc-process-manager-noasn-discriminator.log
lion-ppc-process-manager-noasn-milestone.log
RosettaProcessManagerNoASN_*.crash
```

No Apple framework or daemon binary should be uploaded at this stage.

## Decision gate

### A. InitializeProcessesServices contract differs

If the Snow Leopard PPC process-services client expects a materially different initialization request, reply, dispatch-table layout, service/version contract, or shared-memory setup from Lion's native implementation, localize that exact difference before designing any compatibility code.

Any later compatibility experiment must be limited to the failing process-services initialization transaction. Do not replace LaunchServices or coreservicesd wholesale.

### B. Client contract is compatible but Lion server-side policy differs

If the client-side setup is structurally compatible but Lion's server wrapper or daemon-mode path imposes a new session, architecture, audit-token, version, or other requirement, the next audit will isolate that server-side check.

Do not patch the client abort merely to continue with an invalid dispatch table.

### C. Session identity is the differentiator

If `GetOurLSSessionIDInit()`, `SessionGetInfo`, or session-to-coreservicesd mapping differs materially for the translated PPC case, focus next on session compatibility rather than registration or Process Manager APIs.

### D. Static setup is effectively equivalent

If the process-dispatch setup and InitializeProcessesServices family are materially equivalent across the relevant paths, static analysis has reached its useful limit.

Only then prepare a narrowly controlled postmortem/instrumentation step that distinguishes failure of service creation, session lookup, `_LSDoInitializeProcessesServices`, port creation, and dispatch-table installation. Do not broaden system modifications to obtain that distinction.

## Current interpretation to preserve

The no-ASN discriminator is a negative result for the later HIServices no-ASN abort hypothesis, not a regression.

The private LaunchServices admission proof remains valid. The translated PPC process reaches `main()`, sees the exact override, and enters `GetProcessForPID`. The syscall-295 kernel path remains validated. The latest crash is again a guest-requested SIGABRT rather than a missing XNU syscall.

The unresolved boundary is now the user-space LaunchServices/CoreApplicationServices process-services initialization required before Process Manager identity lookup can proceed.

## Non-goals

This audit does not:

- launch Rosetta/PPC code;
- suppress another abort;
- patch the process dispatch table;
- change a service or launchd job;
- alter LaunchServices registration state;
- modify Rosetta or XNU.

It is a read-only differential audit of the process-dispatch initialization path.
