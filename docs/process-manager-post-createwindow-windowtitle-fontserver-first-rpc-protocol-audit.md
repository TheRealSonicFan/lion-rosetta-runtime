# Post-CreateNewWindow window-title FontServer first-RPC protocol audit

## Objective

Resolve the first actual FontServer protocol divergence exposed by the completed passive Snow/Lion transport trace before any RPC adapter is designed.

The trace proves that the first FontServer RPC is not the later `CopyFontForName` request. Both systems first send the same no-body request:

```text
request ID  = 0x000032c8
send size   = 0x00000018
receive     = 0x0000003c
reply ID    = 0x0000332c
mach_msg    = KERN_SUCCESS
```

Snow Leopard returns a complex `0x34` reply and `SetWindowTitleWithCFString` completes successfully.

Lion returns a simple `0x24` reply to the same `0x32c8` request. The raw four bytes at reply offset `0x20` are:

```text
65 fd ff ff
```

The same PPC-facing trace later records `d0 fe ff ff` for request `0x32d9`, while CoreText reports that later status as `FFFFFED0`. That establishes the byte-order interpretation for this trace: the first `0x32c8` reply encodes `0xfffffd65` (signed `-667`). Do not assign a semantic name to `-667` until the shipped binaries identify the routine and server-side status.

After the `0x32c8` failure Lion retries it, then issues additional legacy FontServer requests. Request `0x32d9` returns the simple `-304/MIG_BAD_ARGUMENTS` reply associated with the logged `CopyFontForName` failures, while `0x32cb` receives a complex `0x34` reply. Those are downstream evidence. The first divergence to explain remains `0x32c8`.

## Why this stage is static

The live transport is now sufficiently localized:

```text
FontServer bootstrap lookup              PASS
FontServer service send right            valid
mach_msg transport for 0x32c8            PASS
Snow 0x32c8 reply                        complex success, size 0x34
Lion 0x32c8 reply                        simple status, size 0x24, raw 0x65fdffff
Snow title                               returns 0
Lion title                               does not reach T03
```

An ID-only or body adapter is not yet justified. The missing evidence is the generated/client/server meaning of `0x32c8`, whether Lion native code still uses it, whether the corresponding Lion operation moved to another request ID or endpoint, and what `-667` means in the Lion server contract.

Do not skip directly to adapting `0x32d9`: that request occurs only after the earlier `0x32c8` divergence.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-fontserver-first-rpc-protocol.py
docs/process-manager-post-createwindow-windowtitle-fontserver-first-rpc-protocol-audit.md
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and read-only. It inspects:

```text
libFontRegistry.dylib
CoreText
ATS
FontServer/fontd launchd plist candidates
any service Program/ProgramArguments binary discovered from those plists
```

For the required Snow PPC and Lion i386 client slices, plus available corroborating native slices, it records:

- full-image and thin-slice SHA-256 provenance;
- dependencies;
- focused FontServer/font-registry/CoreText symbols and strings;
- exact instruction references to captured request IDs `0x32c8`, `0x32cb`, `0x32d9`, and `0x32db`;
- exact references to their standard reply IDs `0x332c`, `0x332f`, `0x333d`, and `0x333f`;
- raw big- and little-endian occurrences of those IDs with file-offset context;
- complete enclosing function windows when symbols permit;
- local disassembly windows when the image is stripped;
- static launchd service-label/program discovery for `FontServer` and `fontd`.

The purpose is to identify the exact old `0x32c8` method and the corresponding Lion native client/server path, not merely count constants.

## Questions this audit must answer

### 1. What is Snow PPC request 0x32c8?

Determine the client stub/function that sends:

```text
ID       0x32c8
send     0x18
receive  0x3c
body     none beyond the Mach header
```

Decode its success reply contract and the meaning of the returned complex descriptor/state.

### 2. What does Lion native code use for the same operation?

Determine whether Lion i386:

- still sends `0x32c8`;
- sends a different request ID;
- obtains the corresponding object/port through a different FontServer endpoint;
- or has retired the old operation entirely.

Do not assume that the later successful translated-PPC `0x32cb` reply is the native replacement for `0x32c8`; prove or reject that possibility from the shipped binaries.

### 3. What does Lion's -667 response mean?

Locate the server/client handling of the first `0x32c8` reply and any visible constant or branch corresponding to `0xfffffd65`.

Determine whether it is:

- a service-specific status;
- a client-version/session/setup rejection;
- an operation-retired status;
- or another protocol precondition.

Do not relabel it as a generic MIG error without binary evidence.

### 4. How do later 0x32d9 / 0x32db failures relate?

Map the later requests only after the first `0x32c8` contract is understood. The trace already shows:

```text
0x32d9 -> 0x333d simple 0xfffffed0 / -304
0x32db -> 0x333f simple 0xfffffed0 / -304
0x32cb -> 0x332f complex 0x34 reply
```

These may help identify method-family ordering, but they are not authorization to adapt multiple methods at once.

## Safety constraints

- Read-only/static audit only.
- Do not launch the PPC restored-stack subject.
- Do not run another FontServer RPC trace.
- Do not send any custom FontServer request.
- Do not call `SetWindowTitleWithCFString`.
- Do not alter FontServer bootstrap compatibility.
- Do not alter the exact-five notification broker.
- Do not adapt `0x32c8`, `0x32cb`, `0x32d9`, `0x32db`, or any other FontServer RPC yet.
- Do not patch CoreText, ATS, FontRegistry, fontd/FontServer, launchd, Rosetta, dyld, shared caches, or XNU.
- Do not restart, signal, suspend, or replace any system service.
- Do not use GDB, DTrace, dtruss, or live injection.
- No XNU rebuild or reboot.

The previous Lion trace named a crash report and `/cores/core.50552`; the exact diagnostic artifacts were not present in the returned set. They are not required to run this static audit. Preserve them if still available, but do not rerun the crashing title path to recreate them.

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

## Phase B — Snow Leopard static audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-fontserver-first-rpc-protocol.py \
  ./process-manager-fontserver-first-rpc-protocol-snowleopard.txt
```

Require:

```text
Created: ./process-manager-fontserver-first-rpc-protocol-snowleopard.txt
No application was launched and no system state was modified.
RESULT: PASS
```

Do not run any PPC title test after this audit.

## Phase C — Lion static audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-fontserver-first-rpc-protocol.py \
  ./payload/process-manager-fontserver-first-rpc-protocol-lion.txt
```

Require:

```text
Created: ./payload/process-manager-fontserver-first-rpc-protocol-lion.txt
No application was launched and no system state was modified.
RESULT: PASS
```

## Phase D — return evidence

Return exactly:

```text
process-manager-fontserver-first-rpc-protocol-snowleopard.txt
process-manager-fontserver-first-rpc-protocol-lion.txt
```

Do not rerun the live FontServer trace before review.

## Decision gate

### Lion native equivalent is the same method under a different request ID/layout

Design a separate copied-buffer proof for only the first `0x32c8` operation. Translate only the proven request/reply delta and stop before allowing later FontServer RPCs to drive a title completion test.

### Lion still uses 0x32c8 but server semantics/preconditions changed

Do not perform an ID translation. Isolate the exact missing setup/session/version precondition identified by the audit.

### Lion retired the old 0x32c8 operation or moved it to a different endpoint

Design compatibility around the native Lion semantic replacement, not around replaying an obsolete Snow server method.

### Static evidence is insufficient

The next discriminator will be a minimal native-i386 Lion FontRegistry/title transport trace focused on the corresponding native call. Do not broaden the translated-PPC interposer first.

### 0x32c8 is compatible and the -667 result comes from an earlier hidden setup dependency

Move the boundary to that exact prerequisite only; the later `0x32d9/-304` path remains downstream until the prerequisite is repaired.

## Current boundary

```text
PPC execution / Rosetta                     -> PASS
syscall 295                                 -> PASS
CreateNewWindow                             -> PASS
FontServer bootstrap                        -> PASS
distributed notifications 1-5              -> PASS
FontServer first request                    -> 0x32c8, transport PASS
Snow 0x32c8                                 -> complex success 0x34
Lion 0x32c8                                 -> simple status 0x24, raw word 65fdffff
later Lion CopyFont requests                -> 0x32d9/0x32db, -304
next step                                   -> static Snow/Lion first-RPC protocol audit
```

No additional XNU change is indicated.
