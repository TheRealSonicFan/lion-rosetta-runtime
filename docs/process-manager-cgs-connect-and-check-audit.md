# Process Manager CGS connect-and-check differential audit

## Objective

Resolve the first local CoreGraphics boundary after the proven Lion per-session WindowServer port is returned to restored Snow Leopard PPC code.

The completed passive transport trace now proves:

```text
Snow registration:
  legacy session lookup                         -> KERN_SUCCESS
  __CGSNewConnectionPort 0x7469                 -> reached
  reply 0x74cd / Mach success                  -> reached
  GetProcessForPID                              -> 0
  postidentity CoreGraphics connection          -> nonzero

Lion translated PPC:
  native active-root lookup                     -> PASS
  GetSessionPort 0x7151/0x71b5                 -> PASS
  returned session port                         -> live send right
  session-bootstrap adapter                     -> PASS
  __CGSNewConnectionPort 0x7469                 -> NOT REACHED
  GetProcessForPID post-call marker             -> NOT REACHED
  process exit status                           -> 1
  new crash/core diagnostic                     -> none
  protected hashes                              -> unchanged
```

This moves the active boundary earlier than `__CGSNewConnectionPort`.

The already-collected Snow PPC CoreGraphics disassembly shows the exact local sequence:

```text
_CGSNewConnection
  -> _CGSServerPort
     -> _lookupServerPort(0, 0)
     -> _connectAndCheck(...)
     -> cache/publish selected server port
  -> __CGSNewConnectionPort
```

The session-bootstrap adapter replaces only the exact legacy bootstrap lookup result. Because the Lion trace reaches `ADAPTER_PASS` but never reaches `0x7469`, the next question is whether restored Snow PPC `_connectAndCheck` rejects or mishandles the otherwise valid Lion per-session port.

Do not infer a `__CGSNewConnectionPort` mismatch from this result: that transaction was not sent.

## Why a read-only differential audit comes next

`_connectAndCheck` is an internal CoreGraphics helper executed synchronously inside `_CGSServerPort` after the service-port lookup and before the selected port is published for `_CGSNewConnection`.

The static evidence already shows that Lion native CoreGraphics also calls a helper named `_connectAndCheck` in its corresponding server-port path, but its call-site argument setup and surrounding status handling are not identical enough to assume wire compatibility.

The next stage therefore compares the complete Snow PPC and Lion native helper bodies before any further dynamic interposition or request adaptation.

## Analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-cgs-connect-and-check.py
```

Analyzer version:

```text
1
```

The analyzer exact-targets every available copy of:

```text
_CGSServerPort
_connectAndCheck
_lookupServerPort
_CGSLookupSessionPort
_CGSLookupServerRootPort
_getSessionPort
__CGSGetSessionPort
__CGSSessionDeathWatchPort
_CGSSetDenyWindowServerConnections
_CGSNewConnection
__CGSNewConnectionPort
```

For each target it emits:

- every same-name text-symbol address rather than collapsing duplicate local symbols;
- the complete function body through the next text symbol;
- direct call/branch lines;
- immediate-bearing instructions;
- name/address references from the complete disassembly;
- focused WindowServer/bootstrap/Mach imports and strings;
- Rosetta shared-cache provenance.

Required validation targets are:

Snow Leopard PPC:

```text
_CGSServerPort
_connectAndCheck
_lookupServerPort
_CGSNewConnection
__CGSNewConnectionPort
```

Lion i386:

```text
_CGSServerPort
_connectAndCheck
_CGSNewConnection
__CGSNewConnectionPort
_getSessionPort
__CGSGetSessionPort
```

x86_64 and other available slices are emitted as corroboration but are not the hard product gate.

## Questions the returned reports must answer

### A. What exact Snow PPC `_connectAndCheck` contract runs after the adapted session lookup?

Determine:

- argument count and role as established by the `_CGSServerPort` call site;
- whether the helper sends a Mach request;
- request/reply IDs;
- Mach options and send/receive sizes;
- payload fields and output fields;
- return-status mapping;
- whether it writes any data consumed by `_CGSServerPort` before the selected port is cached.

### B. What exact native Lion `_connectAndCheck` contract corresponds to that step?

Determine the same properties for Lion i386, with x86_64 as corroboration.

Do not assume equal symbol names imply equal ABI or wire format.

### C. Does Lion native use a different helper signature or protocol?

A changed argument count, request ID, payload size, output structure, expected reply, or status semantics at this stage would explain why a valid Lion session port can pass the standalone protocol proof yet fail before restored Snow PPC reaches `__CGSNewConnectionPort`.

### D. If the visible helper protocol is identical, what local state differs?

If the wire contract matches, inspect the exact output/state consumed immediately after `_connectAndCheck`, including the value later cached by `_CGSServerPort`. Only after that comparison should a dynamic discriminator be designed.

## Safety constraints

This stage is read-only.

Do not:

- run the PPC Process Manager subject;
- rerun the CGS session-bootstrap integration or passive transport trace;
- send a bootstrap lookup or WindowServer Mach message;
- call `_connectAndCheck` dynamically;
- interpose `_connectAndCheck`;
- adapt any newly discovered request ID;
- adapt `0x7469` or `0x729e`;
- fabricate a connection/server-port record;
- patch CoreGraphics, WindowServer, Rosetta, libSystem, the Rosetta cache, or XNU;
- restart or signal WindowServer or launchd jobs.

The analyzer only reads binaries, creates temporary thin architecture slices under the system temporary directory, and removes them on exit.

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

No rebuild, reboot, or PPC execution is part of this stage.

## Phase B — Snow Leopard audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cgs-connect-and-check.py \
  ./process-manager-cgs-connect-and-check-snowleopard.txt
```

Require:

```text
analyzer_version=1
product_version=10.6.8
RESULT: PASS
```

Do not continue if the analyzer reports a missing required Snow PPC target.

## Phase C — Lion audit

Only after the Snow report passes, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cgs-connect-and-check.py \
  ./process-manager-cgs-connect-and-check-lion.txt
```

Require:

```text
analyzer_version=1
product_version=10.7.5
RESULT: PASS
```

Do not launch a PPC executable during or after the audit.

## Phase D — return evidence and stop

Return exactly:

```text
process-manager-cgs-connect-and-check-snowleopard.txt
process-manager-cgs-connect-and-check-lion.txt
```

Do not run any dynamic follow-up until both reports are reviewed.

## Decision gates after review

### Gate 1 — exact protocol evolution inside `_connectAndCheck`

If Snow PPC and Lion native issue different Mach contracts, the next stage will be a standalone protocol proof for only that helper transaction. Do not install a production interposer immediately.

### Gate 2 — same wire contract, changed local ABI/output semantics

If the Mach contract matches but argument/output handling differs, design a read-only or standalone discriminator for that local state before changing behavior.

### Gate 3 — same helper ABI and wire semantics

If `_connectAndCheck` is materially identical, move one local edge later and audit the exact publication/cache state between its successful return and `__CGSNewConnectionPort`.

### Gate 4 — helper absent or structurally replaced on Lion

If Lion native no longer has a comparable helper body despite the current symbol evidence, audit the native server-port path that replaced it and preserve Snow PPC `_connectAndCheck` as the compatibility boundary candidate.

## Current boundary

```text
syscall 295 compatibility                         -> PASS
CoreServices / Security compatibility             -> PASS
SessionUniverse InitConnection v5                 -> PASS
standalone Lion session-port protocol              -> PASS
registration session-bootstrap adapter             -> PASS
Snow __CGSNewConnectionPort 0x7469/0x74cd         -> PASS
Lion translated-PPC __CGSNewConnectionPort         -> NOT REACHED
Lion GetProcessForPID after adapter                -> clean status-1 early exit
new diagnostic                                     -> none
protected hashes                                   -> unchanged
active local interval                              -> _CGSServerPort after lookup, before 0x7469
leading internal helper                            -> _connectAndCheck
next step                                          -> read-only Snow/Lion helper differential
```

No additional XNU change is indicated.
