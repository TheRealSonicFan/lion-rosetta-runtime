# Process Manager ShowWindow window-backing lock protocol audit

## Objective

The ResolveColorProfile ID-only compatibility experiment succeeded at its exact target boundary, but ShowWindow still does not return. This stage is a static, read-only Snow-Leopard-versus-Lion CoreGraphics audit of the next causally ordered failure: the window-backing lock/bind path associated with the observed `0x7263 / 0x72c7` transaction.

The completed resolver compatibility run proves:

```text
ColorProfileClient adapter                       PASS
ResolveColorProfile predicate                    exact=YES, provenanceExact=YES
legacy resolver request                          0x74d7
native Lion resolver request                     0x74d9
request changed bytes                            1
request body changed bytes                       0
native Lion resolver reply                       0x753d / 0x34 / result 0
legacy-facing resolver reply                     0x753b / 0x34 / result 0
reply changed bytes                              1
reply body changed bytes                         0
resolver adapter                                 PASS
```

The former first-order color-profile/window-context failure disappears in that run: there is no `Cannot resolve color profile id(1)`, no invalid-profile diagnostic, and no `CGWindowContextCreate: failed to create context delegate` cascade.

The next repeated failure is already visible in the preserved passive CGS trace. Lion issues:

```text
request ID                 0x7263
expected reply ID          0x72c7
bits                       0x1513
option                     0x3
send / receive             0x24 / 0x3c
request body               one 32-bit window ID
Mach transport             success
reply bits                 0x1200
reply size                 0x34
reply ID                   0x72c7
result                     0
```

Immediately after that apparently successful reply, CoreGraphics reports:

```text
_CGSBindWindowBacking: cannot map backing data shmem
_CGSLockWindow: Unable to lock window
```

The same pair repeats seven times in the Lion compatibility run. The first such failure after the successful resolver transaction occurs before the later seventh distributed-notifications registration rejection, so the notification-broker expansion remains held.

Snow Leopard provides the positive control. It uses the same observed `0x7263 / 0x72c7` pair with the same `0x24 / 0x3c` request/receive geometry and a `0x34`, result-zero reply, but does not emit the backing-map/lock failure and the full control reaches `S01_AFTER_ShowWindow`, M24, and final PASS.

The live evidence therefore does **not** justify an ID rewrite for `0x7263`. The immediate question is the ABI and semantic meaning of the reply outputs and how `_CGSBindWindowBacking` consumes them on Snow PPC versus Lion i386.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-showwindow-window-backing-lock-protocol.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and reads only the shipped CoreGraphics binary plus Rosetta shared-cache provenance. It selects the Snow Leopard `ppc7400` slice or Lion `i386` slice and emits:

- CoreGraphics and selected-slice SHA-256 provenance;
- focused backing/lock/shmem cstrings;
- symbols matching `CGSBindWindowBacking`, `CGSLockWindow`, visible-region/backing families, and related CGX/X server families;
- exact instruction anchors for request `0x7263` and reply `0x72c7`;
- neighboring generated-MIG candidates in a deliberately narrow request/reply range;
- complete disassembly windows for the anchor and focused backing/lock candidates;
- Mach/MIG transport lines inside those functions;
- candidate routine-ID immediates.

## Questions this audit must answer

Determine, separately on Snow PPC and Lion i386:

- the generated-MIG/helper symbol that owns `0x7263 / 0x72c7`;
- whether Lion's native helper uses the same IDs or a release-shifted pair;
- request bits, options, send/receive sizes, NDR layout, and scalar field semantics;
- the exact meaning, order, and widths of the four success-reply words after the result field;
- whether those outputs are byte-swapped scalar values, addresses, offsets, lengths, flags, ports, or another backing descriptor;
- the server-side stub/implementation semantics that produce those outputs;
- how `_CGSBindWindowBacking` and `_CGSLockWindow` consume them;
- which VM/shared-memory mapping primitive is called and what arguments are derived from the reply;
- whether Snow PPC and Lion i386 differ in pointer width assumptions, output representation, mapping API usage, or backing-state preconditions;
- whether the live Lion result-zero reply is semantically valid for an i386 client but misinterpreted by translated PPC, or whether it already encodes a server-side state mismatch.

Do not infer field semantics from raw word values alone. The static call path must establish them.

## Safety constraints

- Do not launch the PPC subject during this audit.
- Do not rerun the resolver compatibility integration.
- Do not alter the now-live-proven ResolveColorProfile or ColorProfileClient adapters.
- Do not adapt `0x7263` or any neighboring CGS request in this stage.
- Do not expand the exact-six notification broker to accept the seventh registration yet.
- Do not revisit `CGSShapeWindow` in this stage.
- Do not force `_CGSBindWindowBacking`, `_CGSLockWindow`, `CGSLockWindowVisibleRegion`, CoreUI, or RawCamera to succeed.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, or XNU.
- Preserve the new Lion crash report/plist/core locally; they are not required unless the static differential leaves the backing-map failure unresolved.
- No XNU rebuild or reboot.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the accepted XNU checkout used only for provenance:

```sh
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
cd "$ROSETTA_XNU" || exit 1
git pull --ff-only
git rev-parse HEAD
```

Confirm current runtime `main` contains:

```text
scripts/audit-process-manager-showwindow-window-backing-lock-protocol.py
docs/process-manager-post-windowtitle-showwindow-window-backing-lock-protocol-audit.md
```

Syntax-check the analyzer on each platform before use:

```sh
/usr/bin/python -c 'compile(open("./scripts/audit-process-manager-showwindow-window-backing-lock-protocol.py", "rb").read(), "./scripts/audit-process-manager-showwindow-window-backing-lock-protocol.py", "exec")'
```

The command must exit 0 with no output.

## Phase B — Snow Leopard 10.6.8 static audit

Run on Snow Leopard:

```sh
/usr/bin/python ./scripts/audit-process-manager-showwindow-window-backing-lock-protocol.py \
  ./process-manager-showwindow-window-backing-lock-protocol-snowleopard.txt
```

Require:

```text
analyzer_version=1
product_version=10.6.8
required_arch=ppc7400
window_backing_lock_request_id=0x00007263
window_backing_lock_reply_id=0x000072c7
candidate_symbol_count >= 1
RESULT: PASS
```

Snow additionally requires exact static anchors for both legacy IDs. Stop and return only the Snow report if it fails.

## Phase C — Lion 10.7.5 static audit

Only after Snow passes, run on Lion:

```sh
/usr/bin/python ./scripts/audit-process-manager-showwindow-window-backing-lock-protocol.py \
  ./process-manager-showwindow-window-backing-lock-protocol-lion.txt
```

Require:

```text
analyzer_version=1
product_version=10.7.5
required_arch=i386
candidate_symbol_count >= 1
RESULT: PASS
```

Do not launch translated PPC afterward.

## Phase D — return evidence and stop

Return exactly:

```text
process-manager-showwindow-window-backing-lock-protocol-snowleopard.txt
process-manager-showwindow-window-backing-lock-protocol-lion.txt
```

Keep the resolver-compatibility dylib, its six returned integration artifacts, and the named Lion crash/plist/core locally. Do not upload proprietary system binaries.

## Decision gate

### Same IDs and same generated-MIG contract, different local binding semantics

If both releases use `0x7263 / 0x72c7` with the same wire geometry but `_CGSBindWindowBacking` interprets or maps the outputs differently, do **not** add an ID adapter. The next stage must isolate the smallest local ABI/mapping compatibility boundary proved by the static differential.

### Native Lion routine ID differs

If the audit proves the Snow and Lion helpers have equivalent request/reply bodies but different routine IDs, do not immediately adapt them. Reconcile that result with the live Lion `0x7263 / 0x72c7 / result 0` response first; a successful legacy-facing response may indicate a different server stub or compatibility path than a simple generated-MIG dispatch miss.

### Server-side backing-state difference

If the wire/helper contract is already identical and the Lion server returns a semantically different backing descriptor because of state established earlier, audit the creator/state transition that feeds the backing object. Do not rewrite successful reply values.

### Static result remains ambiguous

If the reports do not establish the reply-field semantics and local mapping call, review the preserved crash/core and, if needed, prepare a **passive** local `_CGSBindWindowBacking` mapping-argument trace. Do not patch behavior.

## Current boundary

```text
ColorProfileClient adapter                         accepted PASS
ResolveColorProfile adapter                        live-proven PASS
native resolver result                             0
old profile/window-context diagnostics             eliminated
ShowWindow                                         S00 reached, S01 absent
0x7263 / 0x72c7                                   Mach success, result 0
immediate Lion failure                             backing shmem map / lock
backing failure repetitions                        7
sixth notification registration                    accepted
seventh notification registration                  later reject, held
CoreUI/RawCamera                                   downstream/held
CGSShapeWindow                                     earlier/held
next step                                          static backing-lock protocol/ABI audit
XNU                                                no change indicated
```
