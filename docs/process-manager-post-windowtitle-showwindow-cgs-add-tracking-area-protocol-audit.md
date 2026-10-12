# Process Manager post-ShowWindow CGSAddTrackingArea protocol audit

## Objective

The passive ShowWindow CGS transport trace has localized one exact generated-MIG failure tightly enough to justify a static Snow-Leopard-versus-Lion protocol audit before any adapter is written.

The behavior-preserving Snow Leopard control passes through `S01_AFTER_ShowWindow` and records six previously unclassified application-CGS transactions inside the ShowWindow call window:

```text
0x7320 -> 0x7384
0x72e7 -> 0x734b
0x7388 -> 0x73ec
0x7268 -> 0x72cc
0x72f2 -> 0x7356
0x723c -> 0x72a0
```

All six complete with Mach success and successful legacy-facing replies.

The corresponding Lion run reaches `S00_BEFORE_ShowWindow` but not `S01_AFTER_ShowWindow`. Four previously unclassified application-CGS transactions are observed before the process exits:

```text
0x72e7 -> 0x734b   simple reply result -304
0x7388 -> 0x73ec   simple reply result -304
0x7268 -> 0x72cc   simple reply result 0
0x72f2 -> 0x7356   simple reply result -304
```

The decisive attribution is the second transaction. The unchanged Snow PPC client sends the same legacy `0x7388` request envelope on both systems:

```text
bits              0x1513
request ID        0x7388
expected reply    0x73ec
mach_msg option   0x3
send size         0x60
receive size      0x2c
simple reply size 0x24
```

Snow Leopard returns result 0. Lion returns result `-304 / MIG_BAD_ARGUMENTS`, and immediately afterward CoreGraphics emits:

```text
MIG: server type check failure: CGSAddTrackingArea
```

That sequence is sufficient to identify `0x7388` as the live legacy `CGSAddTrackingArea` boundary, but it does **not** establish the Lion-native request ID or layout. This stage recovers the exact Snow PPC and Lion i386 client contracts statically and read-only.

The adjacent `0x72e7` and `0x72f2` Lion failures and the color-profile/window-context diagnostics remain open but are out of scope here. Do not broaden this audit to them.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-showwindow-cgs-add-tracking-area-protocol.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and inspects only the system CoreGraphics binary. On Snow Leopard it thins the `ppc7400` slice; on Lion it thins the `i386` slice. It does not launch a PowerPC program or issue any Mach message.

It records:

- full-file and thin-slice SHA-256 provenance;
- focused symbols, imports, strings, and addressed cstrings for tracking-area families;
- all text symbols containing `CGSAddTrackingArea`, plus nearby tracking-area/region families;
- complete symbol windows through the next text symbol;
- direct calls and branches;
- MIG transport calls;
- immediate-bearing instructions;
- references to each selected symbol;
- disassembly context around the live legacy `0x7388 / 0x73ec` ID anchors when present.

## Questions this audit must answer

For Snow Leopard PPC and Lion i386, determine the exact `CGSAddTrackingArea` generated-MIG/client contract:

- request and expected reply IDs;
- request header bits;
- Mach options;
- send and receive sizes;
- accepted reply size(s);
- NDR placement and handling;
- scalar field order and widths;
- variable data or descriptor use, if any;
- reply/result decoding;
- any client-side reply validation.

Then compare the two contracts.

The live trace already proves that the legacy `0x7388 / 0x73ec`, `0x60 / 0x2c` form succeeds on Snow but is rejected by Lion's server-side MIG type check. The static audit must establish whether Lion changed only the routine number, changed the wire geometry, or changed both.

## Safety constraints

- Do not launch the ShowWindow subject.
- Do not rerun the exact-six notification integration.
- Do not build or load a new compatibility dylib.
- Do not modify the exact-six native broker.
- Do not add a `CGSAddTrackingArea` adapter in this stage.
- Do not adapt `0x72e7`, `0x72f2`, color-profile, window-context, CoreUI, or rendering paths.
- Do not add `SelectWindow` or any later Carbon operation.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, or XNU.
- Do not restart or signal WindowServer or related jobs.
- Keep the Lion crash report/core named by the preceding trace run locally; they are not required for this static phase.
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

Confirm that runtime contains:

```text
scripts/audit-process-manager-showwindow-cgs-add-tracking-area-protocol.py
docs/process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-protocol-audit.md
```

Before either audit, syntax-check the analyzer with the platform Python:

```sh
/usr/bin/python -c 'compile(open("./scripts/audit-process-manager-showwindow-cgs-add-tracking-area-protocol.py", "rb").read(), "./scripts/audit-process-manager-showwindow-cgs-add-tracking-area-protocol.py", "exec")'
```

The command must produce no output and exit 0.

## Phase B — Snow Leopard 10.6.8 static audit

Run:

```sh
/usr/bin/python ./scripts/audit-process-manager-showwindow-cgs-add-tracking-area-protocol.py \
  ./process-manager-showwindow-cgs-add-tracking-area-protocol-snowleopard.txt
```

Require:

```text
analyzer_version=1
product_version=10.6.8
required_arch=ppc7400
live_legacy_request_id=0x00007388
live_legacy_reply_id=0x000073ec
CGSAddTrackingArea count >= 1
RESULT: PASS
```

Do not launch the PPC ShowWindow subject afterward.

If the Snow audit fails, stop and return only the Snow report.

## Phase C — Lion 10.7.5 static audit

Only after the Snow audit passes, run on Lion:

```sh
/usr/bin/python ./scripts/audit-process-manager-showwindow-cgs-add-tracking-area-protocol.py \
  ./process-manager-showwindow-cgs-add-tracking-area-protocol-lion.txt
```

Require:

```text
analyzer_version=1
product_version=10.7.5
required_arch=i386
live_legacy_request_id=0x00007388
live_legacy_reply_id=0x000073ec
CGSAddTrackingArea count >= 1
RESULT: PASS
```

Do not launch translated PPC afterward.

## Phase D — return evidence and stop

Return exactly:

```text
process-manager-showwindow-cgs-add-tracking-area-protocol-snowleopard.txt
process-manager-showwindow-cgs-add-tracking-area-protocol-lion.txt
```

Keep the existing Lion crash report, crash plist, and core locally.

## Decision gate

### Narrow generated-MIG differential

If the reports show a specific Snow/Lion request/reply ID, message-size, descriptor, field-layout, or reply-layout difference, combine that static result with the already completed live passive trace. Only then prepare an exact `CGSAddTrackingArea` compatibility experiment constrained to the observed ShowWindow request. Do not adapt the neighboring `0x72e7` or `0x72f2` requests in the same change.

### Wire-compatible contracts

If Snow PPC and Lion i386 `CGSAddTrackingArea` contracts are wire-compatible, do not rewrite `0x7388`. The `-304` must then be treated as an argument/state-semantics failure, and the next review should use the wrapper inputs plus the preserved crash/core before changing transport behavior.

### Required family missing

Treat that as an analyzer/modeling issue. Preserve the report and stop. Do not substitute a broader live trace.

## Current boundary

```text
PPC execution / syscall 295                    -> PASS
accepted pre-ShowWindow compatibility stack    -> PASS
six reviewed notifications                     -> accepted, zero rejects
Snow ShowWindow passive trace                  -> PASS, six matched requests
Lion ShowWindow passive trace                  -> four matched requests, S01 absent
legacy 0x7388 / 0x73ec on Snow                -> result 0
legacy 0x7388 / 0x73ec on Lion                -> result -304
immediate Lion diagnostic                      -> CGSAddTrackingArea MIG server type-check failure
next step                                      -> static Snow-PPC vs Lion-i386 CGSAddTrackingArea audit
live CGS adaptation                            -> not authorized
XNU                                             -> no change indicated
```


## Observed result — exact inline generated-MIG ID shift

Both analyzer-v1 reports pass on their required architectures. The static contracts resolve the live ShowWindow boundary to the inline tracking-area helper, not the distinct non-inline helper.

The exact inline differential is:

```text
                               Snow PPC              Lion i386
helper                         __CGSAddTrackingAreaInline
request / reply                0x7388 / 0x73ec      0x738e / 0x73f2
header bits                    0x1513                0x1513
mach_msg option                0x3                   0x3
send size                      0x3c + 4*count        0x3c + 4*count
receive size                   0x2c                  0x2c
accepted reply size            0x24                  0x24
count limit                    0x1000                0x1000
NDR/result handling            equivalent             equivalent
```

The preceding passive trace captured `count=9`, which yields the observed `0x60` send size on both contracts. This is therefore a narrow generated-MIG routine-number shift with otherwise matching visible wire geometry.

Lion also exposes a separate non-inline `__CGSAddTrackingArea` client using `0x72d8 / 0x733c`, complex bits `0x80001513`, and fixed send size `0x4c`. That helper does not match the live `0x7388 / 0x60` ShowWindow transaction and is not part of the compatibility rule.

The static result and the already completed passive trace together now authorize one exact inline adapter for the observed request only:

```text
request ID   0x7388 -> 0x738e
reply ID     0x73f2 -> 0x73ec
count        9
send/recv    0x60 / 0x2c
body         unchanged
```

Current `main` prepares that guarded adapter and the authoritative next procedure:

```text
docs/process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-integration-experiment.md
```

Do not adapt the neighboring `0x72e7` or `0x72f2` transactions, the non-inline tracking-area helper, or the color-profile/window-context path in the same experiment. No XNU change is indicated.
