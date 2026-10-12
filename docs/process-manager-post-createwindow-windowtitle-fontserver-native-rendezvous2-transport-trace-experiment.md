# Post-CreateNewWindow window-title native Lion FontServer Rendezvous2 transport trace

## Objective

Resolve the one remaining gap from the completed Rendezvous v2 static audit before any translated-PPC FontServer RPC adapter is designed.

The static comparison now establishes the client-side contracts:

```text
Snow PPC client                       _XTSendRendezvous
Snow request                          0x32c8
Snow bits                             0x1513
Snow send / receive                   0x18 / 0x3c
Snow reply                            0x332c, complex 0x34

Lion native i386 client               _XTSendRendezvous2
Lion request                          0x32e7
Lion bits                             0x1513
Lion send / receive                   0x18 / 0x40
Lion reply                            0x334b
Lion complex success size             0x38
Lion simple error size                0x24
Lion rendezvous caller requirement    protocol version == 5
```

The Lion native request remains header-only. Its successful reply adds one scalar to the Snow-style rendezvous result: the global registry caller requires the first returned scalar to equal 5 and also requires nonzero returned payload address and length before continuing.

The static server side is not authoritative enough to approve a conversion. The corrected v2 analyzer finds no true `0x3200..0x3400` protocol-range instruction immediate in either Lion `libATSServer.dylib` slice, so it cannot prove the native dispatch entry or connect the observed translated-PPC `-667` reply to the new method.

This activates the v2 audit's "static server dispatch remains unresolved" decision gate. The next discriminator is therefore one native-i386 Lion trace of the native Rendezvous2 transaction itself.

## Prepared tooling

Current runtime `main` provides:

```text
tests/native-i386-process-manager-fontserver-rendezvous2-title-probe.c
tests/native-i386-process-manager-fontserver-rendezvous2-trace-interposer.c
scripts/build-native-i386-process-manager-fontserver-rendezvous2-trace-on-snowleopard.sh
docs/process-manager-post-createwindow-windowtitle-fontserver-native-rendezvous2-transport-trace-experiment.md
```

The probe is a thin native i386 Carbon process. It creates a document window and enters `SetWindowTitleWithCFString` only to make Lion's own FontRegistry perform its normal rendezvous.

The trace dylib interposes only:

```text
bootstrap_look_up
mach_msg
```

It remembers only the successfully resolved `com.apple.FontServer` service port. The first `mach_msg` sent to that exact port must match the statically decoded Lion contract:

```text
request ID       0x32e7
bits             0x1513
send argument    0x18
receive argument 0x40
mach_msg option  0x3
```

Important: the generated MIG stub does **not** initialize the in-buffer `msgh_size` word or the reserved header word before calling the public `mach_msg` wrapper. The authoritative request length at this interception point is the `send_size` argument passed to `mach_msg`, not the pre-wrapper value stored at header offset `0x04`. The corrected tracer records those two header words only as non-authoritative observations and must not reject the request because they contain stale stack bytes.

It then records the request, calls the original `mach_msg`, records exactly one reply, validates the expected `0x334b` reply family, and terminates the native process immediately. A complex `0x38` reply is decoded only far enough to report descriptor count, OOL address/descriptor size, the protocol-version scalar at reply offset `0x30`, and the explicit payload-size scalar at `0x34`. The process exits before FontRegistry can issue any later FontServer request.

Expected terminal success marker:

```text
PM_NATIVE_FONTSERVER_RENDEZVOUS2_RESULT:CAPTURED_COMPLEX_V5
```

## Safety constraints

- Native i386 Lion discriminator only. Do not launch the restored translated-PPC title subject.
- Do not load any Rosetta compatibility dylib into this native probe.
- Do not alter, copy, or replace FontRegistry, CoreText, ATS, `libATSServer.dylib`, `fontd`, launchd, Rosetta, dyld, caches, or XNU.
- Do not send a handcrafted FontServer request. The request must originate from Lion's shipped i386 FontRegistry path.
- Capture only the first message to the exact `com.apple.FontServer` port.
- Terminate immediately after that first reply; do not allow a general font query to run.
- Do not show/select the window or enter an event loop.
- Do not restart or signal any service.
- Do not interpret `-667` beyond the evidence already captured.
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

## Phase B — build the native i386 probe and one-shot tracer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-native-i386-process-manager-fontserver-rendezvous2-trace-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-native-i386-process-manager-fontserver-rendezvous2-trace-on-snowleopard.sh
```

Require six created files:

```text
native-i386-process-manager-fontserver-rendezvous2-title-probe
native-i386-process-manager-fontserver-rendezvous2-title-probe.info.txt
native-i386-process-manager-fontserver-rendezvous2-title-probe.sha256
native-i386-process-manager-fontserver-rendezvous2-trace.dylib
native-i386-process-manager-fontserver-rendezvous2-trace.dylib.info.txt
native-i386-process-manager-fontserver-rendezvous2-trace.dylib.sha256
```

Require both Mach-O artifacts to be thin `i386`. The trace dylib must have exactly two 32-bit `__interpose` tuples and the expected request/reply/result markers.

Do not run the probe on Snow Leopard; Snow's native FontRegistry uses the older rendezvous family.

## Phase C — transfer and verify

Transfer the six Phase-B artifacts to Lion without modifying them.

On Lion:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/shasum -a 256 -c ./payload/native-i386-process-manager-fontserver-rendezvous2-title-probe.sha256
/usr/bin/shasum -a 256 -c ./payload/native-i386-process-manager-fontserver-rendezvous2-trace.dylib.sha256
```

If the checksum files contain Snow-side relative paths that do not resolve after transfer, compare the recorded hashes manually and stop if either differs.

Also require:

```sh
/usr/bin/lipo -info ./payload/native-i386-process-manager-fontserver-rendezvous2-title-probe
/usr/bin/lipo -info ./payload/native-i386-process-manager-fontserver-rendezvous2-trace.dylib
```

Both must report `i386`.

## Phase D — run exactly one native Lion trace

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/bin/rm -f ./payload/process-manager-fontserver-native-rendezvous2-lion.log

DYLD_INSERT_LIBRARIES="$PWD/payload/native-i386-process-manager-fontserver-rendezvous2-trace.dylib" \
./payload/native-i386-process-manager-fontserver-rendezvous2-title-probe \
  > ./payload/process-manager-fontserver-native-rendezvous2-lion.log 2>&1

status=$?
echo "native_probe_exit_status=$status" >> ./payload/process-manager-fontserver-native-rendezvous2-lion.log
```

Require:

```text
PM_NATIVE_FONTSERVER_RENDEZVOUS2_BOOTSTRAP:kr=0 ... nonzero port
PM_NATIVE_FONTSERVER_RENDEZVOUS2_REQUEST:index=1 id=0x000032e7 bits=0x00001513 ... headerPreWrapperAuthoritative=NO send=0x00000018 recv=0x00000040 ... option=0x00000003
PM_NATIVE_FONTSERVER_RENDEZVOUS2_MACH_RETURN:kr=0
PM_NATIVE_FONTSERVER_RENDEZVOUS2_REPLY:... size=0x00000038 id=0x0000334b complex=YES
PM_NATIVE_FONTSERVER_RENDEZVOUS2_FIELDS:descriptorCount=1 ... protocolVersion=5 ...
PM_NATIVE_FONTSERVER_RENDEZVOUS2_RESULT:CAPTURED_COMPLEX_V5
native_probe_exit_status=0
```

The following marker must be absent:

```text
PM_NATIVE_FONTSERVER_RENDEZVOUS2_PROBE_UNEXPECTED_RETURN
```

A successful run intentionally exits from the one-shot tracer immediately after the first native FontServer reply. The public title call is therefore not expected to return.

Do not rerun after a successful capture.

## Phase E — return evidence and stop

Return:

```text
native-i386-process-manager-fontserver-rendezvous2-title-probe.info.txt
native-i386-process-manager-fontserver-rendezvous2-title-probe.sha256
native-i386-process-manager-fontserver-rendezvous2-trace.dylib.info.txt
native-i386-process-manager-fontserver-rendezvous2-trace.dylib.sha256
process-manager-fontserver-native-rendezvous2-lion.log
```

Do not upload or commit the built Mach-O binaries themselves.

## Decision gate

### Native Lion returns complex 0x334b / 0x38 with version 5

The native server contract is now dynamically confirmed. The next stage will be a no-Mach-IPC copied-buffer proof for only the rendezvous conversion, comparing the legacy Snow `0x32c8/0x332c/0x34` contract with the native Lion `0x32e7/0x334b/0x38` contract and explicitly accounting for the added protocol-version scalar. Do not integrate that conversion live yet.

### Native Lion returns a simple error

Preserve the exact status and stop. The native probe did not establish the expected server precondition, so an adapter is not justified.

### The first FontServer request is not 0x32e7 or has another envelope

Preserve the log and stop. Reconcile the static client decode with the live call path before changing any compatibility code.

### No FontServer request is captured

The benign title probe did not exercise the global registry rendezvous. Do not broaden tracing globally; review the native call path and choose a narrower trigger.

## Current boundary

```text
Snow legacy rendezvous client             -> _XTSendRendezvous
Snow legacy request                       -> 0x32c8, 0x18/0x3c
Snow legacy reply                         -> 0x332c, complex 0x34
Lion translated legacy result             -> simple 0x332c/0x24, -667
Lion native client                        -> _XTSendRendezvous2
Lion native request (static)              -> 0x32e7, 0x18/0x40
Lion native success reply (static)        -> 0x334b, complex 0x38
Lion required protocol version (static)   -> 5
Lion server dispatch (static)             -> unresolved
next step                                 -> one-shot native-i386 Lion Rendezvous2 transport trace
```

No additional XNU change is indicated.


## Observed first attempt — pre-`mach_msg` header-size validator was invalid

The first native Lion attempt reached the intended path and proved several prerequisites before the tracer stopped itself:

```text
CreateNewWindow                         -> 0, nonzero WindowRef
CFStringCreateWithCString               -> PASS
com.apple.FontServer bootstrap lookup   -> kr=0, nonzero port
first FontServer request ID             -> 0x32e7
request bits                            -> 0x1513
mach_msg send argument                  -> 0x18
mach_msg receive argument               -> 0x40
mach_msg option                         -> 0x3
```

The v1 tracer then reported `REQUEST_CONTRACT_MISMATCH` only because it also required `msg->msgh_size == 0x18` before calling the original `mach_msg`. The observed value was `0x6c707061` and the raw request contained the byte words `appl` at header offset `0x04` and `rver` at offset `0x10`. That is consistent with the shipped Lion i386 `_XTSendRendezvous2` stub already captured by the static audit: it initializes the header bits, remote port, reply port, and request ID, then passes `0x18` and `0x40` as the authoritative `mach_msg` send/receive arguments without first storing either `msgh_size` or the reserved word in the request buffer.

Therefore this result is a tracer-validation defect, not a FontServer protocol mismatch. The v1 run never called the original `mach_msg`, so it produced no server reply and does not satisfy the native-server decision gate.

Current runtime `main` contains corrected trace build:

```text
native-i386-fontserver-rendezvous2-trace-v2
```

The corrected tracer:

- treats the pre-wrapper `msgh_size` and reserved words as observational only;
- validates request ID `0x32e7`, bits `0x1513`, send `0x18`, receive `0x40`, option `0x3`, and reply-port consistency;
- still captures only the first exact FontServer-port transaction;
- still exits immediately after its first reply;
- fixes the result-marker newline so the exit-status line is separate.

Pull current `main`, rebuild the probe/tracer with Phase B, transfer the new artifacts, and repeat exactly one Phase-D native Lion trace. Return the same five evidence files with the newly built tracer provenance. Do not run the translated-PPC title path and do not advance to a copied-buffer rendezvous proof until the corrected native reply is captured.
