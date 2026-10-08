# Process Manager SCSessionUniverse InitConnection RPC protocol audit

## Objective

Prove the exact Snow Leopard-to-Lion wire/API evolution at the CarbonCore session-universe initialization boundary that now sits directly under the translated PPC `GetProcessForPID` SIGBUS.

The preceding differential audit materially narrows the failure. The Snow Leopard PPC code that Rosetta executes on Lion uses the same validated Rosetta cache on both systems, but its `__SCSessionUniverseByUIDAcquireAndLock` call site does **not** match Lion's native CarbonCore call shape for `__scclient_SCSessionUniverseInitConnection_rpc`.

Before writing any new compatibility adapter, this stage extracts the generated client/server/MIG stub windows on Snow Leopard and Lion so the exact request ID, request/reply sizes, field ordering, and server validation can be compared.

This is a read-only static audit. It sends no Mach message.

## Evidence entering this stage

Both completed session-universe reports end in `RESULT: PASS`, and both systems use the same validated Rosetta cache and map.

The Snow Leopard PPC `__SCSessionUniverseByUIDAcquireAndLock` call site performs:

```text
getpid()
port = _scGetServerCheckinPort()
__scclient_SCSessionUniverseInitConnection_rpc(
    port,
    pid,
    uid,
    0,
    &out
)
```

The same Snow Leopard CarbonCore native clients confirm the five-argument family:

```text
Snow i386:   port, pid, uid, 2, &out
Snow x86_64: port, pid, uid, 3, &out
```

Lion native CarbonCore has changed the call shape:

```text
Lion i386:   port, uid, 2, &out
Lion x86_64: port, uid, 3, &out
```

The explicit PID argument has disappeared.

This is not merely a compiler calling-convention artifact: on Snow i386 the stack contains five consecutive arguments, including both PID and UID, while on Lion i386 the stack contains four, with UID immediately after the port.

The error handling changed too. Snow PPC tests the RPC return code but, on error, unlocks and continues with the still-null universe pointer. It then calls `_SCGetSessionLocalUniverseInfo` and proceeds into a mutex/state access. Lion native code instead formats/logs the nonzero RPC error and aborts immediately.

That behavior is consistent with the preserved Lion PPC crash:

```text
EXC_BAD_ACCESS (SIGBUS)
KERN_PROTECTION_FAILURE at 0x0000003c
r10 = 0xd0feffff
byte-swapped r10 = 0xfffffed0 = -304 = MIG_BAD_ARGUMENTS
```

The `-304` value is still treated as a correlation clue until the generated RPC stubs prove that the rejected request is this exact InitConnection transaction.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-session-universe-init-rpc-protocol.py
docs/process-manager-session-universe-init-rpc-protocol-audit.md
```

The analyzer is Python-2-compatible and extracts, for every available CarbonCore architecture slice:

- `__SCSessionUniverseByUIDAcquireAndLock`;
- `__scclient_SCSessionUniverseInitConnection_rpc`;
- `__XSCSessionUniverseInitConnection_rpc`;
- `__scserver_SCSessionUniverseInitConnection_rpc`;
- the analogous MapSharedSegment and Disconnect RPC stubs;
- `_SCGetSessionLocalUniverseInfo`;
- `__SCConstructMappedUniverse`;
- `_scGetServerCheckinPort`;
- `scHandleMessage` when visible;
- relevant Mach/MIG/session symbols/imports;
- relevant cstrings;
- Rosetta-cache provenance.

The generated client and server windows are the important evidence. Their immediate constants and stack/register layout should expose:

- request message ID;
- request `msgh_size`;
- reply size and expected reply ID;
- whether PID exists in the request;
- field offsets/order for UID and architecture/layout discriminator;
- server-side size/type checks;
- any NDR conversion path;
- whether Lion's server would reject the Snow request with `MIG_BAD_ARGUMENTS`.

## Safety constraints

- do not launch the PPC subject;
- do not set `LSDONOTABORTIFNOASN`;
- do not call `__SCSessionUniverseByUIDAcquireAndLock` or any private CarbonCore routine;
- do not send a custom InitConnection request;
- do not extend the existing CoreServices interposer yet;
- do not patch CarbonCore, LaunchServices, HIServices, CoreFoundation, coreservicesd, dyld, Rosetta, or the shared cache;
- do not restart or signal coreservicesd;
- do not modify XNU;
- do not use live GDB, DTrace, or dtruss.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No rebuild, reboot, or daemon restart is required.

## Phase B — Snow Leopard protocol audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-session-universe-init-rpc-protocol.py \
  ./process-manager-session-universe-init-rpc-protocol-snowleopard.txt
```

Require:

```text
Created: ./process-manager-session-universe-init-rpc-protocol-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If the audit reports `RESULT: FAIL`, stop and return the complete report. Do not run the Lion phase until the tooling issue is reviewed.

## Phase C — Lion protocol audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-session-universe-init-rpc-protocol.py \
  ./payload/process-manager-session-universe-init-rpc-protocol-lion.txt
```

Require:

```text
Created: ./payload/process-manager-session-universe-init-rpc-protocol-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

## Phase D — return evidence

Return exactly:

```text
process-manager-session-universe-init-rpc-protocol-snowleopard.txt
process-manager-session-universe-init-rpc-protocol-lion.txt
```

Do not rerun the crashing PPC subject.

## Decision gate

### Legacy request layout is conclusively rejected by Lion

If the generated Snow PPC client stub and Lion server stub prove a request-layout/size mismatch that explains `MIG_BAD_ARGUMENTS`, the next controlled compatibility experiment will adapt **only** `SCSessionUniverseInitConnection_rpc`.

The preferred architecture would be to extend the existing process-local CoreServices `mach_msg` adapter rather than replace CarbonCore or patch coreservicesd. The adapter would translate the legacy Snow PPC request into the Lion request form and translate the Lion reply back only as needed by the unchanged Snow client.

That design will not be implemented until the exact wire fields are proven by this audit.

### Message shape is compatible

If the request/reply layouts are actually compatible, the `-304` register value is not sufficient proof of this RPC failure. The next step would localize the return code dynamically without changing behavior.

### Different routine owns the mismatch

If the generated dispatcher shows InitConnection itself is compatible but a nested or subsequent MapSharedSegment transaction changed, move the boundary to that exact RPC only.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo adaptation -> PASS
LaunchServices process-dispatch setup -> PASS
GetProcessForPID -> enters registration/check-in
CarbonCore session-universe path -> SIGBUS at 0x3c
Snow InitConnection call shape -> port,pid,uid,arch/layout,out
Lion InitConnection call shape -> port,uid,arch/layout,out
exact InitConnection MIG request/reply layout -> next proof
```

No additional XNU change is indicated.


## Observed completed result

Both Snow Leopard and Lion protocol reports completed with `RESULT: PASS`.

The generated stubs prove the InitConnection mismatch conclusively.

Snow Leopard PPC uses:

```text
request ID = 0x00002712
send size  = 0x0000002c
receive    = 0x00000034

0x18..0x1f  NDR
0x20        PID
0x24        UID
0x28        architecture/layout
```

Its generated dispatcher requires `msgh_size == 0x2c`, byte-swaps all three scalar fields when NDR conversion is required, and emits `MIG_BAD_ARGUMENTS (-304)` on the request-shape failure path.

Lion keeps the same request and reply IDs but changes the request:

```text
request ID = 0x00002712
send size  = 0x00000028
receive    = 0x00000034

0x18..0x1f  NDR
0x20        UID
0x24        architecture/layout
```

Lion's generated dispatcher requires `msgh_size == 0x28` before dispatching and writes `0xfffffed0` / `MIG_BAD_ARGUMENTS` into the reply on failure. Therefore an untouched Snow PPC `0x2c` request is deterministically rejected by Lion before the server implementation is called.

The reply contract remains compatible for this boundary:

```text
reply ID       = 0x00002776
success size   = 0x0000002c
error size     = 0x00000024
receive buffer = 0x00000034
```

No reply translation is indicated.

The Lion server path receives the caller audit token and derives caller identity server-side, so no replacement PID field is required in the Lion request.

This turns the preserved translated-PPC `r10=0xd0feffff` from a correlation clue into an exact protocol explanation: the PPC-generated stub observes the byte-swapped form of Lion's `-304/MIG_BAD_ARGUMENTS` rejection, Snow CarbonCore then continues without a mapped universe, and the later `0x3c` SIGBUS follows from that invalid state.

The authoritative next stage is:

```text
docs/process-manager-session-universe-init-adapter-experiment.md
```

That experiment uses a new v4 process-local CoreServices interposer to translate only this exact legacy request from `0x2c [PID,UID,layout]` to `0x28 [UID,layout]`, leaving the reply untouched.

Do not set `LSDONOTABORTIFNOASN=0`, do not adapt MapSharedSegment yet, and do not change XNU.
