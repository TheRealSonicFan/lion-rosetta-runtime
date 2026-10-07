# Process Manager Security Session AuditInfo oracle experiment

## Objective

Prove the exact Lion-native semantics that should replace Snow Leopard's retired SecurityServer `getSessionInfo` RPC for `SessionGetInfo(callerSecuritySession,...)`, and verify that the same kernel-backed audit information is directly obtainable from translated PPC code before any compatibility interposer is designed.

The preceding Security bootstrap-integration run has now reached the legacy `getSessionInfo` request itself:

```text
verifyPrivileged2 (0x441) -> Mach success / valid reply
setup (0x3e8) -> Mach success / RetCode 0
getSessionInfo (0x428) -> Mach success / simple 0x24 MIG error reply
SessionGetInfo -> status 1
```

The raw error word at reply offset `0x20` was observed by the PPC tracer as:

```text
0xd1feffff
```

The shipped Snow Leopard PPC MIG stub checks the reply NDR integer representation and byte-swaps that word when the server representation differs. Byte-swapping `0xd1feffff` yields:

```text
0xfffffed1 = -303 = MIG_BAD_ID
```

Therefore Lion directly rejects the legacy `getSessionInfo=0x428` routine as an unknown request ID. The immediate transport question is closed.

The correct compatibility direction is not to revive the retired securityd RPC. Lion's own native Security implementation for `callerSecuritySession` calls `getaudit_addr(..., 0x30)` and returns the 32-bit words at offsets `0x24` and `0x28` as the public session ID and attribute bits.

This experiment validates the Lion mapping dynamically and tests whether translated PPC can call `getaudit_addr` successfully with the same 0x30-byte layout. Snow Leopard is used only as a build/runtime control: its legacy `SessionGetInfo` attributes come from the SecurityServer-era semantics and are not required to equal the raw `auditinfo_addr` flags word.

## Prepared files

Current runtime `main` provides:

```text
tests/process-manager-security-session-auditinfo-oracle.c
scripts/build-process-manager-security-session-auditinfo-oracle-on-snowleopard.sh
scripts/run-snowleopard-process-manager-security-session-auditinfo-oracle-control.sh
scripts/run-lion-process-manager-security-session-auditinfo-oracle.sh
docs/process-manager-security-session-auditinfo-oracle-experiment.md
```

The Snow Leopard builder produces two exact executables from one source:

```text
ppc-process-manager-security-session-auditinfo-private-dyld
i386-process-manager-security-session-auditinfo-oracle
```

The PPC executable is patched to `LC_LOAD_DYLINKER=/usr/oah/dyld`. The i386 executable is left native.

Both expose three modes:

- `session-id-audit`: call `SessionGetInfo(callerSecuritySession,...)`, then `getaudit_addr`, require only the public session ID to equal raw word `0x24`, and report the attribute/word-`0x28` comparison as diagnostic;
- `session-audit`: call `SessionGetInfo(callerSecuritySession,...)`, then `getaudit_addr`, and strictly require both the public session ID and attributes to equal raw words `0x24` and `0x28`; this mode is reserved for the native Lion oracle;
- `audit-only`: call only `getaudit_addr`, without calling `SessionGetInfo`.

## Safety constraints

For this experiment:

- build both artifacts only on Snow Leopard 10.6.8;
- do not use any Security/bootstrap/CoreServices interposer;
- keep `SECURITYSERVER` unset;
- keep `DYLD_INSERT_LIBRARIES` unset;
- run `session-id-audit` for both PPC and i386 only on Snow Leopard;
- do not require Snow Leopard's legacy `SessionGetInfo` attributes to equal `auditinfo_addr` word `0x28`;
- on Lion, run strict `session-audit` only in native i386;
- on Lion, run translated PPC only in `audit-only` mode;
- do not send any custom Mach message;
- do not call the legacy SecurityServer `getSessionInfo` RPC on Lion;
- do not call `SessionCreate`, `setaudit_addr`, or `auditon`;
- do not patch Security, securityd, libSystem, Rosetta, dyld, the cache, or XNU;
- do not use GDB, DTrace, dtruss, or live injection;
- perform exactly one Lion oracle run before review.

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

No kernel rebuild or reboot is part of this stage.

## Phase B — build PPC and i386 oracle subjects on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-process-manager-security-session-auditinfo-oracle-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-security-session-auditinfo-private-dyld
ppc-process-manager-security-session-auditinfo-private-dyld.info.txt
ppc-process-manager-security-session-auditinfo-private-dyld.sha256
i386-process-manager-security-session-auditinfo-oracle
i386-process-manager-security-session-auditinfo-oracle.info.txt
i386-process-manager-security-session-auditinfo-oracle.sha256
```

Require:

- PPC output is 32-bit PowerPC;
- i386 output is 32-bit Intel;
- PPC `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- both import `SessionGetInfo`;
- both import `getaudit_addr`;
- both link Security.

If the build fails, stop and return the complete build output.

## Phase C — Snow Leopard session-ID control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-process-manager-security-session-auditinfo-oracle-control.sh
```

The runner executes both architectures in `session-id-audit` mode.

Require both to report:

```text
PM_SECURITY_AUDITINFO_SESSION:status=0 ...
PM_SECURITY_AUDITINFO_GET:... rc=0 errno=0 size=0x30 ...
PM_SECURITY_AUDITINFO_COMPARE:sessionIdMatch=YES ...
PM_SECURITY_AUDITINFO_RESULT:SESSION_ID_AUDIT_MATCH
```

and the runner to end:

```text
RESULT: PASS
```

The `attrsMatch` field is diagnostic on Snow Leopard and is not a pass criterion. Snow Leopard's public `SessionGetInfo` still uses the legacy SecurityServer path, so its attribute bits are not evidence for Lion's direct AuditInfo mapping. The only Snow control invariant used here is that the successful public session ID matches `auditinfo_addr` word `0x24` in both PPC and i386 subjects.

If Phase C fails under this corrected criterion, stop. Do not run Lion.

## Observed Phase C harness failure and correction

The first Phase C run failed because the control incorrectly imposed Lion's attribute mapping on Snow Leopard.

The returned evidence was internally consistent:

- PPC `SessionGetInfo` returned session ID `0x0020ca74` and attributes `0x00008030`; `getaudit_addr` returned word `0x24 = 0x0020ca74` and word `0x28 = 0x00000000`;
- i386 `SessionGetInfo` returned the same session ID and attributes; `getaudit_addr` returned word `0x24 = 0x0020ca74` and word `0x28 = 0x00000001`;
- both architectures therefore proved `sessionIdMatch=YES` while correctly showing `attrsMatch=NO`.

This was a test-harness assumption defect, not a PPC translation failure or a `getaudit_addr` failure. The source and Snow runner now separate a Snow-only `session-id-audit` control from the strict Lion-native `session-audit` oracle.

Because the probe source changed, Phase B must be rebuilt before Phase C is repeated. Do not reuse the previous executable hashes. After pulling current `main`, repeat Phase B and Phase C only; do not proceed to Lion until the corrected control reports `RESULT: PASS`.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
ppc-process-manager-security-session-auditinfo-private-dyld
ppc-process-manager-security-session-auditinfo-private-dyld.info.txt
ppc-process-manager-security-session-auditinfo-private-dyld.sha256
i386-process-manager-security-session-auditinfo-oracle
i386-process-manager-security-session-auditinfo-oracle.info.txt
i386-process-manager-security-session-auditinfo-oracle.sha256
process-manager-security-session-auditinfo-snowleopard-control.log
```

Place the executables and SHA sidecars under runtime `payload/`, or pass explicit paths to the Lion runner.

Do not rebuild either executable on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require its existing `RESULT: PASS`.

Then run the syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-security-session-auditinfo-oracle.log
```

Require the existing EBADF/no-SIGSYS PASS.

Do not continue if either native gate fails.

## Phase F — one Lion AuditInfo oracle run

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-process-manager-security-session-auditinfo-oracle.sh
```

The runner performs exactly two launches:

1. native i386 `session-audit`;
2. translated PPC `audit-only`.

The native i386 launch must prove Lion's current public API mapping:

```text
PM_SECURITY_AUDITINFO_SESSION:status=0 ...
PM_SECURITY_AUDITINFO_GET:arch=i386 rc=0 ...
PM_SECURITY_AUDITINFO_COMPARE:sessionIdMatch=YES attrsMatch=YES
PM_SECURITY_AUDITINFO_RESULT:SESSION_AUDIT_MATCH
```

The translated PPC launch must prove direct kernel-backed availability without invoking the retired Security RPC:

```text
PM_SECURITY_AUDITINFO_GET:arch=ppc rc=0 ...
PM_SECURITY_AUDITINFO_RESULT:AUDIT_ONLY_PASS
```

The runner also records whether the i386 and PPC `word24` / `word28` values match. Those cross-process comparisons are diagnostic rather than the primary pass criterion because the authoritative requirements are the native mapping and successful translated-PPC audit read.

Expected successful runner result:

```text
RESULT: SECURITY_AUDITINFO_ORACLE_PASS
```

Do not rerun before review.

## Phase G — stop and return evidence

Return:

```text
process-manager-security-session-auditinfo-snowleopard-control.log
lion-process-manager-security-session-auditinfo-oracle.log
lion-process-manager-security-session-auditinfo-oracle.raw.log
syscall295-probe-process-manager-security-session-auditinfo-oracle.log
ppc-process-manager-security-session-auditinfo-private-dyld.info.txt
ppc-process-manager-security-session-auditinfo-private-dyld.sha256
i386-process-manager-security-session-auditinfo-oracle.info.txt
i386-process-manager-security-session-auditinfo-oracle.sha256
```

Also return every new diagnostic listed by the Lion runner, if any.

Do not upload the executables, Apple Security framework, private dyld, or Rosetta cache unless later analysis identifies one exact binary artifact as necessary.

## Result interpretation

### `SECURITY_AUDITINFO_ORACLE_PASS`

Lion's native `SessionGetInfo(callerSecuritySession,...)` semantics are dynamically confirmed to be the `getaudit_addr` 0x30-byte structure's words at offsets `0x24` and `0x28`, and translated PPC can obtain that kernel-backed structure directly.

The next compatibility experiment should therefore be a narrow process-local `SessionGetInfo` API adapter for `callerSecuritySession` that reproduces Lion's native behavior from `getaudit_addr`, rather than synthesizing or reviving the obsolete securityd RPC.

### native i386 mapping mismatch

Stop. Reconcile the static offset interpretation before designing an API adapter.

### translated PPC `getaudit_addr` failure

Stop. The kernel-backed native semantics are not directly reachable through the restored PPC libSystem path as assumed; preserve errno and do not implement the API adapter.

### crash or diagnostic

Preserve the diagnostic and stop.

## Current boundary

The proven sequence is now:

```text
SecurityServer Lion-format bootstrap -> PASS
verifyPrivileged2 -> PASS
setup -> PASS
legacy getSessionInfo 0x428 -> MIG_BAD_ID (-303)
Lion native SessionGetInfo -> getaudit_addr-backed
translated PPC direct getaudit_addr semantics -> next proof
```

No additional XNU change is indicated.
