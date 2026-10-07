# Process Manager Security SessionGetInfo AuditInfo API adapter experiment

## Objective

Prove that a narrow process-local replacement for Snow Leopard PPC `SessionGetInfo(callerSecuritySession,...)` can reproduce Lion's native behavior directly from `getaudit_addr`, without invoking the retired SecurityServer `getSessionInfo=0x428` RPC.

The completed AuditInfo oracle established:

- native Lion i386 `SessionGetInfo(callerSecuritySession,...)` returns values that match `auditinfo_addr`;
- translated PPC on Lion can call `getaudit_addr(..., 0x30)` successfully;
- the PPC and i386 runs share the same audit session ID;
- the raw 32-bit word at offset `0x28` differs across i386 and PPC.

That last difference is expected to be an endianness/view issue, not a semantic mismatch: Darwin defines `ai_flags` as the 64-bit `au_asflgs_t`, aligned at offset `0x28`. On little-endian i386 the low 32 bits occupy offset `0x28`; on big-endian PPC the low 32 bits occupy offset `0x2c`. The adapter therefore uses the typed `auditinfo_addr_t.ai_flags` value and converts that logical 64-bit value to `SessionAttributeBits`; it does not read a hard-coded 32-bit word.

The new interposer also has compile-time checks that the Snow Leopard SDK supplies exactly the expected layout:

- `sizeof(auditinfo_addr_t) == 0x30`;
- `offsetof(ai_asid) == 0x24`;
- `offsetof(ai_flags) == 0x28`.

## Prepared files

```text
tests/ppc-process-manager-security-session-auditinfo-api-interposer.c
scripts/build-ppc-process-manager-security-session-auditinfo-api-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-security-session-auditinfo-api-control.sh
scripts/run-lion-ppc-process-manager-security-session-auditinfo-api.sh
docs/process-manager-security-session-auditinfo-api-adapter-experiment.md
```

The build produces:

```text
ppc-process-manager-security-session-auditinfo-api-private-dyld
ppc-process-manager-security-session-auditinfo-api-private-dyld.info.txt
ppc-process-manager-security-session-auditinfo-api-private-dyld.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

The interposer contains exactly one tuple: `SessionGetInfo`.

## Safety constraints

- build only on Snow Leopard 10.6.8;
- no SecurityServer/bootstrap/Mach-message adaptation in this stage;
- no CoreServices adapter in this stage;
- no Security/securityd/libSystem/Rosetta/dyld/cache/XNU modification;
- no daemon restart;
- no `SessionCreate`, `setaudit_addr`, or `auditon`;
- no debugger, DTrace, dtruss, or system-wide injection;
- Lion mode adapts only `callerSecuritySession`;
- perform exactly one Lion adapter run before review.

## Phase A — update repositories

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update `lion-rosetta-xnu` and record its head. No rebuild of XNU is required.

## Phase B — build on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-security-session-auditinfo-api-on-snowleopard.sh
```

Require:

- both outputs are PPC;
- executable uses `/usr/oah/dyld`;
- interposer has exactly one `__interpose` tuple;
- build ID is `security-session-auditinfo-api-v1`;
- interposer imports `SessionGetInfo` and `getaudit_addr`;
- interposer does not import `dlsym`.

If the compile-time `auditinfo_addr_t` layout checks fail, stop and return the build output.

## Phase C — Snow Leopard passthrough control

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-security-session-auditinfo-api-control.sh
```

The runner sets:

```text
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=passthrough
```

Require:

```text
PM_SECURITY_SESSION_API_COMPAT_CALL:... mode=passthrough ... targetCaller=YES
PM_SECURITY_SESSION_API_COMPAT_PASSTHROUGH_RETURN:status=0 ...
PM_SECURITY_SESSION_STATUS:SessionGetInfo=0
PM_SECURITY_SESSION_RESULT:PASS
RESULT: PASS
```

This proves the one-tuple interposer is transparent on the working Snow Leopard path.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer the executable, dylib, both info files, both SHA files, and the Snow control log. Put executable/dylib/sidecars under `payload/` or pass explicit paths to the runner.

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel and repeat the existing native commpage and syscall-295 probes. Preserve the syscall result as:

```text
syscall295-probe-process-manager-security-session-auditinfo-api.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — one Lion SessionGetInfo adapter run

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-security-session-auditinfo-api.sh
```

The runner enables only:

```text
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

The decisive markers are:

```text
PM_SECURITY_SESSION_API_COMPAT_CALL:... targetCaller=YES
PM_SECURITY_SESSION_API_COMPAT_LAYOUT:size=0x30 asidOffset=0x24 flagsOffset=0x28 flagsSize=0x08
PM_SECURITY_SESSION_API_COMPAT_AUDIT:rc=0 errno=0 rawWord28=... rawWord2c=... asid=... flagsHigh=... flagsLow=...
PM_SECURITY_SESSION_API_COMPAT_RESULT:ADAPTER_PASS id=... attrs=...
PM_SECURITY_SESSION_STATUS:SessionGetInfo=0
PM_SECURITY_SESSION_RESULT:PASS
RESULT: SECURITY_SESSION_AUDITINFO_API_ADAPTER_PASS
```

The runner also requires the adapter's returned ID/attributes to exactly equal the values observed by the public probe.

The `rawWord28` / `rawWord2c` values are diagnostic evidence for the 64-bit endian layout. The semantic value is `ai_flags`, represented in the log as `flagsHigh` / `flagsLow`.

Do not rerun before review.

## Phase G — return evidence

Return:

```text
ppc-process-manager-security-session-auditinfo-api-snowleopard-control.log
lion-ppc-process-manager-security-session-auditinfo-api.log
lion-ppc-process-manager-security-session-auditinfo-api.raw.log
syscall295-probe-process-manager-security-session-auditinfo-api.log
ppc-process-manager-security-session-auditinfo-api-private-dyld.info.txt
ppc-process-manager-security-session-auditinfo-api-private-dyld.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return any new crash/core diagnostic named by the runner.

## Result interpretation

### `SECURITY_SESSION_AUDITINFO_API_ADAPTER_PASS`

The obsolete SecurityServer session query is no longer needed for `callerSecuritySession`. The next stage should integrate this exact one-tuple SessionGetInfo adapter with the already-proven dual CoreServices compatibility layer and rerun the pre-dispatch/LaunchServices path.

Do not automatically add the SecurityServer bootstrap adapter to that combined layer: this API replacement should prevent the legacy SessionGetInfo path from activating SecurityServer at all. Retain the proven SecurityServer bootstrap adapter as a separate compatibility component for later Security APIs if a real call path requires it.

### audit read/layout failure

Stop. Preserve the raw log. Do not fall back to synthesizing attributes.

### public probe mismatch

Stop. The adapter is not faithfully returning its typed AuditInfo values.

### crash/diagnostic

Preserve diagnostics and stop.

## Current boundary

```text
SecurityServer bootstrap adaptation -> proven
verifyPrivileged2 -> proven
setup -> proven
legacy getSessionInfo 0x428 -> MIG_BAD_ID
Lion native SessionGetInfo -> AuditInfo-backed
translated PPC getaudit_addr -> PASS
typed PPC SessionGetInfo AuditInfo adapter -> next proof
```

No additional XNU change is indicated.
