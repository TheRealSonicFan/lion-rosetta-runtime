# Process Manager CreateNewWindow CGS opacity alpha-plane protocol audit

## Scope

The release-backing ID-only compatibility integration has now succeeded through a real Lion native transaction.

The accepted Lion run proves:

- NewWindow remains a native Lion success and the legacy-facing reply remains accepted;
- the first exact legacy release-backing request is recognized once;
- only request ID `0x724b -> 0x724c` changes in the private request copy;
- Lion returns native `0x72b0 / 0x24 / result 0`;
- only reply ID `0x72b0 -> 0x72af` changes in the legacy-facing reply copy;
- the release-backing adapter reports `ADAPTER_PASS`;
- the legacy-facing release-backing trace sees `0x72af / 0x24 / result 0`.

The public `CreateNewWindow` call still does not return. The first subsequent CoreGraphics diagnostic is now:

```text
(ipc/rcv) msg too large: CGSSetWindowOpacity
```

Only after that are these diagnostics emitted:

```text
kCGErrorFailure
kCGErrorIllegalArgument: CGSGetDisplayBounds (display 0)
MIG: server type check failure: CGSShapeWindow
```

The next stage therefore isolates only `CGSSetWindowOpacity`. Do not trace or adapt display-bounds or ShapeWindow yet.

## Why a focused alpha-plane audit is required

The earlier broad post-NewWindow audit established the public `CGSSetWindowOpacity` symbol on Snow PPC and Lion i386 but did not emit a same-named direct generated-`mach_msg` stub.

Review of those accepted static reports now shows the wrapper structure more precisely:

```text
_CGSSetWindowOpacity
    -> __CGSCreateWindowAlphaPlane
    -> __CGSTerminateWindowAlphaPlane
```

Both Snow PPC and Lion i386 resolve `__CGSCreateWindowAlphaPlane` as a direct generated-MIG client containing `mig_get_reply_port` and `mach_msg`. Both architectures also expose `__CGSTerminateWindowAlphaPlane` as the alternate opacity branch.

The live run did not capture which alpha-plane branch was selected, so this static gate must recover the complete generated-MIG contract of both helpers before any additional live transport recognition is added.

## Question

For Snow Leopard PPC and Lion i386, recover and compare the exact generated-MIG client contracts for:

- `__CGSCreateWindowAlphaPlane`
- `__CGSTerminateWindowAlphaPlane`

Also retain the public `_CGSSetWindowOpacity` wrapper window so the branch relationship and argument forwarding remain explicit.

For each generated helper compare:

- request and reply IDs;
- Mach header bits;
- `mach_msg` option;
- send size;
- receive size;
- accepted reply size;
- NDR handling;
- scalar argument positions;
- result scalar decoding;
- any descriptor use;
- any obvious wire-layout difference.

The specific live diagnostic is receive-side `msg too large`, so receive size and accepted reply size are first-class evidence. Do not infer an ID-only policy unless the complete Snow/Lion helper contracts justify it.

## Prepared analyzer

```text
scripts/audit-process-manager-cgs-opacity-alpha-plane-protocol.py
```

Analyzer version: `2`.

It is static and read-only. It thins only the required CoreGraphics slice for the current OS, locates exactly these symbols, emits their complete symbol windows plus direct calls, MIG transport calls, and immediate-bearing instructions, and validates that the opacity wrapper reaches both alpha-plane helpers and that both helpers are direct generated-MIG clients.

## Safety constraints

- do not launch the translated PPC subject;
- do not rerun CreateNewWindow;
- do not rebuild any compatibility dylib or broker;
- do not modify the accepted NewWindow or release-backing adapters;
- do not trace or adapt `CGSGetDisplayBounds` or `CGSShapeWindow`;
- do not patch CoreGraphics, WindowServer, Rosetta, dyld, the Rosetta cache, launchd, libSystem, or XNU;
- do not restart or signal WindowServer or launchd jobs;
- no XNU rebuild or reboot.

Preserve the new Lion diagnostics from the accepted integration run locally:

```text
/Users/Andy/Library/Logs/DiagnosticReports/.ppc-process-manager-cgs-session-bootstrap-integration-private-dy_2026-10-11-172341_Andys-Mac.crash.plist
/Users/Andy/Library/Logs/DiagnosticReports/ppc-process-manager-cgs-session-bootstrap-integration-private-dy_2026-10-11-172341_Andys-Mac.crash
/cores/core.37178
```

They are not required for this static phase.

## Phase A — update repositories

On Snow Leopard and Lion, pull current runtime `main`.

On Lion, also pull current XNU `main` for documentation consistency.

Confirm that runtime contains this document and:

```text
scripts/audit-process-manager-cgs-opacity-alpha-plane-protocol.py
```

Before running either audit, perform a no-write parser preflight with the platform `/usr/bin/python`:

```sh
/usr/bin/python -c 'compile(open("./scripts/audit-process-manager-cgs-opacity-alpha-plane-protocol.py", "rb").read(), "./scripts/audit-process-manager-cgs-opacity-alpha-plane-protocol.py", "exec")'
```

The command must return with no output and exit status 0. Stop if it reports any syntax error.

## Phase B — Snow Leopard 10.6.8 static audit

The first Phase B attempt using analyzer v1 stopped before the audit executed because of an extra closing parenthesis in the target-inventory formatting expression. The Snow `/usr/bin/python` parser reported the error at the closing parenthesis on the `if hits else ""` line. No CoreGraphics analysis, PowerPC launch, Mach IPC, or system-state change occurred in that failed attempt.

Analyzer v2 replaces that expression with an explicit Python-2.6-compatible address-string branch and retains the same audit semantics. After pulling current `main`, run the parser preflight from Phase A and then rerun Phase B from the beginning. Do not reuse or return any partial report from the syntax-failed attempt.

Run:

```sh
/usr/bin/python ./scripts/audit-process-manager-cgs-opacity-alpha-plane-protocol.py \
  ./process-manager-cgs-opacity-alpha-plane-protocol-snowleopard.txt
```

Hard gate:

```text
analyzer_version=2
product_version=10.6.8
required_arch=ppc7400

_CGSSetWindowOpacity count=1
__CGSCreateWindowAlphaPlane count=1
__CGSTerminateWindowAlphaPlane count=1

wrapper_calls_create_alpha_plane=YES
wrapper_calls_terminate_alpha_plane=YES
create_alpha_plane_calls_mach_msg=YES
create_alpha_plane_gets_reply_port=YES
terminate_alpha_plane_calls_mach_msg=YES
terminate_alpha_plane_gets_reply_port=YES

RESULT: PASS
```

Stop if the analyzer reports `FAIL`.

Do not launch the PPC subject afterward.

## Phase C — Lion 10.7.5 static audit

Run:

```sh
/usr/bin/python ./scripts/audit-process-manager-cgs-opacity-alpha-plane-protocol.py \
  ./process-manager-cgs-opacity-alpha-plane-protocol-lion.txt
```

Hard gate:

```text
analyzer_version=2
product_version=10.7.5
required_arch=i386

_CGSSetWindowOpacity count=1
__CGSCreateWindowAlphaPlane count=1
__CGSTerminateWindowAlphaPlane count=1

wrapper_calls_create_alpha_plane=YES
wrapper_calls_terminate_alpha_plane=YES
create_alpha_plane_calls_mach_msg=YES
create_alpha_plane_gets_reply_port=YES
terminate_alpha_plane_calls_mach_msg=YES
terminate_alpha_plane_gets_reply_port=YES

RESULT: PASS
```

Do not launch the translated PPC subject after the audit.

## Phase D — return for review and stop

Return exactly:

```text
process-manager-cgs-opacity-alpha-plane-protocol-snowleopard.txt
process-manager-cgs-opacity-alpha-plane-protocol-lion.txt
```

Keep the current crash report, plist, and core locally.

## Decision gate

### Narrow generated-MIG differential

If either alpha-plane helper has a Snow/Lion request/reply ID, receive-size, accepted-reply-size, or other narrow wire-contract differential, the next stage will be a passive exact transport trace for the relevant Snow/Lion helper pair. Because the live opacity boolean was not captured, the trace may recognize both create-alpha-plane and terminate-alpha-plane request IDs while adapting neither.

Do not implement an opacity compatibility rule from static evidence alone.

### Wire-compatible alpha-plane helpers

If both helpers are wire-compatible across Snow PPC and Lion i386, stop. The receive-too-large diagnostic is then not explained by a generated-MIG numbering/geometry differential, and the next review will use the preserved crash/core plus the live window/connection state rather than introducing an ID translation.

### Analyzer cannot recover a required helper

Stop and treat that as an analyzer/modeling problem. Do not broaden to later helpers.

## Current boundary

```text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
accepted pre-window compatibility stack         -> PASS
Dock bootstrap compatibility                    -> PASS
NewWindow ID-only integration                   -> native Lion success
release-backing ID-only integration             -> native Lion success / result 0
first subsequent live diagnostic                -> CGSSetWindowOpacity receive-too-large
next step                                       -> static create/terminate alpha-plane MIG audit
```

This remains a user-space CoreGraphics/generated-MIG compatibility investigation. No additional XNU change is indicated.


## Correction record — analyzer v2

The initial Snow Phase B invocation of analyzer v1 failed at parse time with:

```text
SyntaxError: invalid syntax
line 262: if hits else "")))
```

Root cause: the target-inventory `write_line` expression had one excess closing parenthesis. Because parsing failed before `main()` executed, the failed attempt did not thin CoreGraphics, launch a PPC process, issue Mach IPC, or modify system state.

Analyzer v2 removes the ambiguous nested conditional formatting entirely: it builds the optional address suffix explicitly and then writes the inventory line. The audit scope, target symbols, static-only safety model, structural checks, and decision gate are otherwise unchanged.

Required recovery sequence:

```text
git pull --ff-only
confirm analyzer_version=2
run the Phase A parser preflight with /usr/bin/python
rerun Snow Phase B once
continue to Lion Phase C only if Snow returns RESULT: PASS
```


## Observed completed result — both alpha-plane contracts are narrow shifted MIG pairs

Analyzer v2 completed successfully on both Snow Leopard 10.6.8 PPC7400 and Lion 10.7.5 i386. The wrapper and both generated-MIG helpers were recovered on each platform, all structural validation gates passed, and both reports ended with `RESULT: PASS`.

The complete static differential is:

```text
                              Snow PPC             Lion i386
create request/reply          0x724f / 0x72b3      0x7250 / 0x72b4
terminate request/reply       0x7250 / 0x72b4      0x7251 / 0x72b5
header bits                   0x1513               0x1513
mach_msg option               0x3                  0x3
send size                     0x24                 0x24
receive size                  0x2c                 0x2c
accepted reply size           0x24                 0x24
NDR/result handling           equivalent            equivalent
```

Both helper families therefore show a narrow generated-MIG routine-number shift with otherwise matching visible wire geometry. The terminate pair has an additional semantic hazard: Snow terminate `0x7250/0x72b4` is numerically identical to Lion create `0x7250/0x72b4`. A legacy terminate request sent unchanged to Lion can therefore collide with Lion's create-alpha routine.

The prior live diagnostic does not identify whether the PPC opacity wrapper selected the create or terminate branch. Static evidence therefore does **not** authorize either ID conversion yet.

The authoritative next procedure is:

```text
docs/process-manager-createwindow-cgs-opacity-alpha-plane-transport-trace-experiment.md
```

That stage keeps the accepted NewWindow and release-backing adapters unchanged, identifies exactly one legacy opacity alpha-plane branch on the Snow positive control and one Lion run, and performs no opacity rewrite. Display-bounds and ShapeWindow remain out of scope.
