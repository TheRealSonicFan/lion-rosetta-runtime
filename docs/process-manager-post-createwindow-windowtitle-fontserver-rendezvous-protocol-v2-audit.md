# Post-CreateNewWindow window-title FontServer rendezvous protocol audit v2

## Objective

Close the exact static gap left by the completed first-RPC audit before any live FontServer compatibility experiment.

The v1 audit passed mechanically, but its decisive evidence is asymmetric:

- Snow Leopard PPC exposes `_XTSendRendezvous`, whose generated client sends request `0x32c8`, uses send/receive `0x18/0x3c`, expects reply `0x332c`, and accepts the successful complex `0x34` form.
- Lion FontRegistry no longer contains a raw `0x32c8` request constant in the required i386 slice.
- Lion instead exports `_XTSendRendezvous2`.
- Lion's `TGlobalFontRegistryImp::RendezvousWithServer()` path calls `_XTSendRendezvous2`.
- Lion contains explicit strings for rendezvous failure and a "Font server protocol version mismatch ... falling back to local fonts" path.
- The launchd `fontd` executable is only a front end; both Snow and Lion link the actual server implementation from `libATSServer.dylib`.

Therefore the first `0x32c8` translated-PPC request is an obsolete Snow rendezvous transaction sent to a Lion FontServer stack whose native client has moved to Rendezvous2. The exact Rendezvous2 request ID/layout, reply contract, server dispatch path, and the meaning of Lion's `-667` response are still unresolved.

Do not design an ID-only adapter from the symbol rename alone.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-fontserver-rendezvous-protocol-v2.py
docs/process-manager-post-createwindow-windowtitle-fontserver-rendezvous-protocol-v2-audit.md
```

Analyzer version:

```text
2
```

This analyzer is Python-2-compatible and read-only. It narrows the previous audit to:

```text
libFontRegistry.dylib
libATSServer.dylib
```

It emits complete function windows for these exact FontRegistry symbols whenever present:

```text
_XTSendRendezvous
_XTSendRendezvous2
TGlobalFontRegistryImp::RendezvousWithServer()
TGlobalFontRegistryImp::GetServerPort()
```

It also:

- inventories every immediate in the `0x3200..0x3400` protocol-ID range across both images;
- attributes each protocol-range immediate to its enclosing text symbol;
- emits complete `libATSServer` windows for rendezvous/font-server/demux/dispatch symbols and every symbol that owns a protocol-range immediate;
- records raw occurrences of `0xfffffd65` (`-667`) and `0xfffffed0` (`-304`) with surrounding bytes;
- emits focused rendezvous/protocol strings and dependencies;
- records full-image and thin-slice SHA-256 provenance.

## Questions this audit must answer

### 1. What exact request replaces Snow 0x32c8 on Lion?

Decode `_XTSendRendezvous2` completely:

- request ID;
- request header bits;
- send size;
- receive size;
- request body fields and offsets;
- descriptor use;
- reply ID;
- accepted simple/complex reply sizes;
- returned scalar/port/data fields;
- local validation/error paths.

### 2. What does Lion RendezvousWithServer pass to Rendezvous2?

Compare Snow's caller of `_XTSendRendezvous` with Lion's caller of `_XTSendRendezvous2`.

Determine whether Lion adds:

- a protocol version;
- process/session identity;
- query/options flags;
- additional output storage;
- a new service or namespace selector;
- or another setup value.

The string `Font server protocol version mismatch (expected:%d got:%d), falling back to local fonts` is a clue, not yet a proven field mapping.

### 3. How does libATSServer dispatch the old and new rendezvous requests?

For Snow and Lion, locate the server-side dispatch entries or handlers corresponding to:

- Snow `0x32c8`;
- the newly decoded Lion Rendezvous2 request;
- replies `+100` where the generated MIG family follows that convention.

Determine whether Lion:

- has removed the old `0x32c8` routine;
- still dispatches it but deliberately returns a service-specific status;
- validates a protocol version/setup state before returning success;
- or routes Rendezvous2 through a different handler family.

### 4. What is -667?

Use client and server binary evidence to determine whether `0xfffffd65` / `-667` is:

- a named/generated FontServer status;
- a protocol-version rejection;
- an obsolete-operation result;
- or another private service condition.

Do not infer the name from decimal value alone.

## Safety constraints

- Static/read-only audit only.
- Do not launch the restored PPC subject.
- Do not run another FontServer transport trace.
- Do not run a native FontRegistry/title probe yet.
- Do not send a custom FontServer request.
- Do not adapt `0x32c8`, Rendezvous2, `0x32d9`, `0x32db`, or any other FontServer RPC.
- Do not change the accepted bootstrap adapter or exact-five notification broker.
- Do not patch FontRegistry, libATSServer, fontd, CoreText, ATS, launchd, Rosetta, dyld, caches, or XNU.
- Do not restart or signal any font service.
- No XNU rebuild or reboot.

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

## Phase B — Snow Leopard focused rendezvous audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-fontserver-rendezvous-protocol-v2.py \
  ./process-manager-fontserver-rendezvous-protocol-v2-snowleopard.txt
```

Require:

```text
Created: ./process-manager-fontserver-rendezvous-protocol-v2-snowleopard.txt
No application was launched and no system state was modified.
RESULT: PASS
```

The required PPC FontRegistry slice must contain `_XTSendRendezvous`. Preserve all available native corroborating slices and `libATSServer` output.

## Phase C — Lion focused rendezvous audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-fontserver-rendezvous-protocol-v2.py \
  ./payload/process-manager-fontserver-rendezvous-protocol-v2-lion.txt
```

Require:

```text
Created: ./payload/process-manager-fontserver-rendezvous-protocol-v2-lion.txt
No application was launched and no system state was modified.
RESULT: PASS
```

The required i386 FontRegistry slice must contain `_XTSendRendezvous2`.

## Phase D — return evidence and stop

Return exactly:

```text
process-manager-fontserver-rendezvous-protocol-v2-snowleopard.txt
process-manager-fontserver-rendezvous-protocol-v2-lion.txt
```

Do not rerun the live PPC title path.

## Decision gate

### Rendezvous2 is a proven structural replacement for 0x32c8

If the client and server windows establish an exact Snow-to-Lion rendezvous mapping, the next step will be a standalone copied-buffer proof for that one rendezvous transaction only. The proof must translate only the binary-confirmed request/reply delta and stop before any `CopyFontForName` request.

### Lion requires a new protocol/setup value before ordinary font RPCs

If Rendezvous2 explicitly negotiates a version, capability, namespace, or session value, isolate that exact setup contract. Do not adapt later font operations until the setup proof succeeds.

### Lion native uses another endpoint

If Rendezvous2 targets `com.apple.FontObjectsServer` or another distinct service right, the next discriminator must reproduce the exact Lion service acquisition and rendezvous semantics. Do not send Rendezvous2 to the already-restored legacy `com.apple.FontServer` port by assumption.

### Static server dispatch remains unresolved

If `libATSServer` is too stripped to prove the handler mapping, the next step will be a minimal native-i386 Lion rendezvous transport trace. It will trace only the native Lion rendezvous and stop before any general font query.

## Current boundary

```text
Snow PPC rendezvous client              -> _XTSendRendezvous
Snow rendezvous request                 -> 0x32c8, 0x18/0x3c
Snow rendezvous result                  -> complex 0x34 success
Lion translated legacy request          -> same 0x32c8
Lion response to legacy request         -> simple 0x24, -667
Lion native rendezvous client           -> _XTSendRendezvous2
Lion FontRegistry raw 0x32c8            -> absent
fontd server implementation             -> libATSServer.dylib dependency
next step                               -> focused client/server rendezvous audit v2
```

No additional XNU change is indicated.


## Observed result — Rendezvous2 client contract decoded; server dispatch still opaque

Both v2 reports completed with `RESULT: PASS`. The corrected true-immediate inventory now resolves the native Lion i386 client contract without relying on request-ID seeding.

Snow Leopard PPC remains:

```text
client          _XTSendRendezvous
request         0x32c8
bits            0x1513
send / receive  0x18 / 0x3c
reply           0x332c
success         complex 0x34
```

Lion i386 `_XTSendRendezvous2` is now decoded as:

```text
request         0x32e7
bits            0x1513
send / receive  0x18 / 0x40
reply           0x334b
success         complex 0x38, descriptor count 1
error           simple 0x24
```

The request remains header-only. `TGlobalFontRegistryImp::RendezvousWithServer()` supplies three output locations to `_XTSendRendezvous2`; after a successful client-stub return it requires the first scalar output to equal protocol version `5`, then requires the returned payload address and length to be nonzero before continuing. This proves a concrete structural change from Snow's rendezvous reply rather than an ID-only rename.

The static server half remains unresolved. With the corrected immediate filter, both Lion `libATSServer.dylib` slices produce zero true protocol-range instruction hits, so this audit does not recover a trustworthy `0x32e7` demux/handler entry and does not establish a semantic name for the translated legacy `-667` result. Do not infer that `-667` is merely a request-ID error.

This selects the existing "static server dispatch remains unresolved" decision gate. The authoritative next stage is:

```text
docs/process-manager-post-createwindow-windowtitle-fontserver-native-rendezvous2-transport-trace-experiment.md
```

That experiment uses Lion's own native i386 FontRegistry path, captures exactly the first `com.apple.FontServer` request/reply, requires the statically decoded `0x32e7/0x334b` contract, records the returned version/payload fields, and terminates immediately before any later font request. No translated-PPC title rerun, FontServer compatibility conversion, or XNU change is authorized before that native capture is reviewed.
