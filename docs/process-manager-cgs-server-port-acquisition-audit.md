# Process Manager CGS server-port acquisition audit

## Objective

Resolve the exact WindowServer service-port acquisition contract used by restored Snow Leopard PPC CoreGraphics versus Lion native CoreGraphics before introducing any new compatibility behavior.

The completed default-connection audit passed on both systems and narrows the active failure from the broad default-connection path to the server-port acquisition layer immediately before the existing `__CGSNewConnectionPort` transaction.

## Version-2 correction after the first returned reports

The first Snow Leopard/Lion reports both returned `RESULT: PASS`, but review exposed an analyzer-coverage defect that prevents those version-1 reports from selecting the exact active helper body safely.

`CoreGraphics` contains more than one local static symbol named `_lookupServerPort` in the relevant slices. In the returned Snow PPC report the symbol table contains `_lookupServerPort` at `0x138da8` and `0x169138`; in the returned Lion i386 report it contains `_lookupServerPort` at `0xcd010` and `0x25b290`. Version 1 stored text symbols in a one-address-per-name dictionary, so the later same-name symbol replaced the earlier address before symbol-window emission. The reports therefore prove that the helper family exists, but the emitted `_lookupServerPort` body is not guaranteed to be the copy reached by the default-connection path.

The same review also shows that Snow PPC has `_CGSLookupSessionPort` at `0x138b3c`, immediately adjacent to the `0x138c4c` `_CGSLookupServerRootPort` / `0x138da8` `_lookupServerPort` cluster, but version 1 did not select `_CGSLookupSessionPort` for a complete window. Lion i386, by contrast, exposes `_getSessionPort` and `__CGSGetSessionPort`, and the version-1 report already shows the latter issuing the session-port MIG transaction.

Analyzer version 2 corrects both gaps. It preserves every text-symbol address for duplicate names, emits a duplicate-target inventory plus a complete window for every matching address, exact-targets Snow `_CGSLookupSessionPort`, and requires Lion `__CGSGetSessionPort` evidence. The version-1 reports remain useful provenance and broad-structure evidence, but they do **not** authorize a lookup adapter.

After pulling current `main`, rerun Phases B through D on both systems. The returned reports must contain `analyzer_version=2` and `RESULT: PASS`. Do not run a PPC subject while collecting them.

## What the completed default-connection audit proves

### The WindowServer itself is present on both systems

The read-only process snapshots show a running WindowServer on both Snow Leopard and Lion, together with loginwindow, coreservicesd, and Dock. The translated Lion failure is therefore not explained by an absent WindowServer daemon.

### HIServices ordering remains the same

In both Snow Leopard and Lion native HIServices, `__RegisterApplication` first calls `_CGSDefaultConnection`. Only if that returns nonzero does the code proceed to `__CPSRegisterWithServer`.

This confirms the already-observed translated-PPC diagnostic:

```text
_RegisterApplication(), FAILED TO establish the default connection to the WindowServer,
_CGSDefaultConnection() is NULL.
```

as the active pre-CPS boundary.

### Snow PPC and Lion native default-connection creation have the same high-level shape

Snow PPC `__CGSDefaultConnection` calls:

```text
_CGSNewConnection(0, &connection_id)
```

when no default connection exists.

Lion native CoreGraphics does the same.

Both versions then install a successfully created connection into the default/current connection state. The relevant structural divergence is therefore lower, inside server-port acquisition and connection establishment.

### The NewConnectionPort MIG transaction is not the leading mismatch

The Snow Leopard PPC and Lion i386 `__CGSNewConnectionPort` clients use the same visible wire constants:

```text
request ID             0x7469
expected reply ID      0x74cd
Mach options           0x3
receive size           0x44
send size              aligned client-name length + 0x44
request bits           0x80001513
```

Both clients also accept the same success/error reply-size families and perform the same NDR-aware scalar conversion.

This makes the already-known `__CGSNewConnectionPort` transaction a poor candidate for the *current* null-connection failure. It may still need exact server-side verification later if dynamic evidence reaches it, but no adapter is justified now.

### The server-port lookup strategy changed between Snow Leopard and Lion

Snow Leopard PPC `_CGSLookupServerPort` calls:

```text
_lookupServerPort(0, 1)
```

and then validates the returned port through `__CGSSessionDeathWatchPort`.

Snow Leopard x86_64 corroborates the same `_lookupServerPort` family.

Lion native x86_64 `_CGSLookupServerPort` instead calls:

```text
_getSessionPort(1)
```

and, if that returns zero, falls back to:

```text
_CGSLookupServerRootPort(1)
```

before the same death-watch validation.

Lion CoreGraphics also contains native session-oriented helpers that do not exist in the Snow PPC path, including:

```text
_CGSessionGetWindowServerPort
_CGXActiveWindowServerPort
_CGXRootWindowServerPort
_current_session_set_bootstrap_port
```

and imports `bootstrap_look_up_per_user` plus XPC routines.

This is a concrete service-port acquisition evolution and is now the leading compatibility boundary.

## Why another static audit is required

The prior analyzer intentionally did not exact-target the hidden helper bodies that implement:

```text
_CGSServerPort
_lookupServerPort
_getSessionPort
_CGSLookupServerRootPort
_CGSessionGetWindowServerPort
_CGXActiveWindowServerPort
_CGXRootWindowServerPort
_current_session_set_bootstrap_port
```

It therefore cannot yet prove:

- which exact WindowServer service name the Snow PPC helper requests;
- which bootstrap namespace/port it uses;
- whether it invokes `bootstrap_look_up`, `bootstrap_look_up2`, or another helper;
- whether a failed lookup triggers the root-only on-demand-launch fallback seen dynamically on Lion;
- how Lion native obtains the per-session WindowServer port;
- whether Lion's `bootstrap_look_up_per_user` or XPC path is part of the relevant client-side acquisition;
- or what exact return code/zero-port condition distinguishes the successful Snow path from the translated Lion path.

Those details must be proven before a process-local lookup adapter can be designed.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-cgs-server-port-acquisition.py
docs/process-manager-cgs-server-port-acquisition-audit.md
```

The analyzer is read-only and Python-2-compatible. The authoritative analyzer version for this gate is **2**.

It records:

- OS/build and Rosetta shared-cache provenance;
- CoreGraphics full-file and architecture-slice hashes;
- linked dependencies;
- focused WindowServer/session/bootstrap/XPC/Mach strings;
- addressed `__TEXT,__cstring` entries when the platform `otool` supports them;
- focused imports for bootstrap, XPC, Mach, session, and WindowServer mechanisms;
- all visible text symbols matching the server-port/default-connection helper families;
- complete disassembly windows and references for those helpers;
- helper call/reference lines across the entire CoreGraphics disassembly.

The key target families include:

```text
_CGSServerPort
_lookupServerPort
_getSessionPort
_CGSLookupServerRootPort
_CGSessionGetWindowServerPort
___CGSessionGetWindowServerPort_block_invoke_1
_CGSSessionDeathWatchPort
_CGXActiveWindowServerPort
_CGXRootWindowServerPort
_CGXWindowServerPort
_CGXEnableWindowServerPort*
_current_session_set_bootstrap_port
_CGSLookupServerPort
_CGWindowServerCFMachPort
_CGSNewConnection
__CGSNewConnectionPort
__CGSDefaultConnection
_CGSInitialize
```

## Questions this audit must answer

### 1. What exact Snow PPC service-port lookup is issued?

Derive from `_lookupServerPort` / `_CGSServerPort`:

- service name;
- bootstrap namespace/port source;
- lookup API;
- flags or per-user/session discriminator;
- fallback behavior;
- raw return handling;
- conditions that return a zero WindowServer port.

Pay particular attention to the strings:

```text
com.apple.windowserver.session
com.apple.windowserver.active
com.apple.windowserver
On-demand launch of the Window Server is allowed for root user only.
```

The next stage must not assume which string belongs to which branch until addressed cstrings and helper disassembly prove it.

### 2. What exact native Lion lookup replaces it?

Derive the relationship among:

```text
_getSessionPort
_CGSLookupServerRootPort
_CGSessionGetWindowServerPort
_CGXActiveWindowServerPort
_CGXRootWindowServerPort
_current_session_set_bootstrap_port
```

and determine whether `bootstrap_look_up_per_user`, ordinary bootstrap lookup, or XPC supplies the port used by native Lion `_CGSNewConnection`.

### 3. Does Lion retain the legacy Snow lookup as a valid compatibility route?

If Lion native still contains the old service name/API as a fallback, determine the exact conditions under which it is selected. Do not infer compatibility merely because the string or import still exists.

### 4. Can the root-only diagnostic be tied to one exact legacy fallback?

The translated PPC run emitted:

```text
kCGErrorRangeCheck: On-demand launch of the Window Server is allowed for root user only.
```

The static helper audit must identify the branch that emits this condition and the failed lookup immediately preceding it.

### 5. Is `__CGSNewConnectionPort` wire adaptation still unnecessary?

Reconfirm that both client families reach the same `0x7469/0x74cd` contract after obtaining a valid server port. Do not design a connection-MIG adapter unless this audit reveals a hidden field or server-selection difference not captured by the prior client windows.

## Safety constraints

For this audit:

- do not launch any PPC Process Manager subject;
- do not call `_CGSDefaultConnection`, `_CGSServerPort`, `_CGSLookupServerPort`, or any private CoreGraphics helper;
- do not perform a bootstrap lookup dynamically;
- do not send a Mach request;
- do not restart, signal, or relaunch WindowServer, launchd, loginwindow, Dock, coreservicesd, or pbs;
- do not add a CoreGraphics/CPS/CGS/WindowServer interposer;
- do not write or fabricate a CoreGraphics connection record;
- do not adapt `0x7469` or `0x729e`;
- do not broaden the v5 CoreServices or v1 Security adapters;
- do not modify XNU;
- do not use GDB, DTrace, dtruss, or live code injection.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU documentation checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — Snow Leopard server-port acquisition audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cgs-server-port-acquisition.py \
  ./process-manager-cgs-server-port-acquisition-snowleopard.txt
```

Require:

```text
Created: ./process-manager-cgs-server-port-acquisition-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

Phase B is a hard gate. Confirm the generated report contains `analyzer_version=2`. If it returns `RESULT: FAIL`, stop and return that report unchanged. Do not run Lion until the analyzer is corrected.

## Phase C — Lion server-port acquisition audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cgs-server-port-acquisition.py \
  ./payload/process-manager-cgs-server-port-acquisition-lion.txt
```

Require:

```text
Created: ./payload/process-manager-cgs-server-port-acquisition-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

Confirm the generated report contains `analyzer_version=2`. If it fails, stop. Do not compensate by running another PPC subject.

## Phase D — return evidence

Return only:

```text
process-manager-cgs-server-port-acquisition-snowleopard.txt
process-manager-cgs-server-port-acquisition-lion.txt
```

No Apple framework or daemon binary should be uploaded.

## Decision gate

### A. Snow legacy lookup is rejected by Lion and native Lion uses a different session lookup

If the exact helper bodies prove this, the next controlled experiment should adapt only the proven Snow WindowServer service-port lookup tuple to native Lion semantics.

The preferred location is a process-local interposer/adapter with an exact discriminator. Do not patch CoreGraphics, WindowServer, launchd, or a shared cache.

Before implementing it, establish the exact output-right semantics expected by the Snow caller and the native Lion port acquisition routine.

### B. The service lookup itself is wire-compatible

If Snow and Lion obtain the same usable server port contract, do not add a lookup adapter. Prepare a behavior-preserving dynamic discriminator around `_CGSServerPort` / `__CGSNewConnectionPort` that records the raw port/result boundary without changing behavior.

### C. Lion native requires session metadata absent from the Snow helper

Use the native Lion helper path as the semantic oracle. Determine whether the smallest bridge is a per-session port lookup rather than a bootstrap message rewrite.

Do not bypass session ownership checks.

### D. A hidden `__CGSNewConnectionPort` difference appears

Perform an exact client/server protocol audit for request `0x7469` before any adaptation.

## Current boundary

```text
syscall 295 compatibility                         -> PASS
CoreServices / Security compatibility             -> PASS
SessionUniverse InitConnection v5                 -> PASS
GetProcessForPID / GetProcessPID                  -> PASS
TransformProcessType                              -> PASS
Snow PPC CoreGraphics default connection          -> established
Lion translated-PPC default connection            -> NULL
raw CPSSetFrontProcess on Lion                    -> 0x3eb pre-transport
Snow/Lion __CGSNewConnectionPort IDs              -> both 0x7469 / 0x74cd
Snow PPC server-port lookup family                -> _CGSLookupSessionPort / _lookupServerPort / root fallback
Lion native server-port lookup family             -> _getSessionPort / __CGSGetSessionPort / root fallback
v1 analyzer exact-window status                    -> INSUFFICIENT (duplicate _lookupServerPort names collapsed)
next step                                         -> rerun corrected analyzer v2; no adapter yet
```

No additional XNU change is indicated.
