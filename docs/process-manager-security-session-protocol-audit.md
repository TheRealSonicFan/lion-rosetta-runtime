# Process Manager Security session protocol audit

## Objective

Resolve the newly exposed Security-session compatibility boundary before any Security patch or process-local adapter is attempted.

The corrected pre-dispatch compatibility experiment now proves that the two CoreServices transport repairs remain healthy in the real prerequisite sequence on Lion:

- the UUID-expanded coreservicesd bootstrap lookup succeeds;
- the native-form ServerCheckin adaptation succeeds;
- unmodified Snow Leopard PPC CarbonCore returns a nonzero `LaunchApplicationServices` service port.

The next call, untouched `SessionGetInfo(callerSecuritySession,...)`, then returns normally but reports:

```text
SessionGetInfo = 1
session ID = 0
attributes = 0
```

The exact Snow Leopard control returns `0`, a nonzero session ID, and nonzero session attributes.

This stage is a read-only binary audit of that Security boundary. It does not call `SessionGetInfo` again.

## Current interpretation

The dynamic result is narrower than an abort or crash: the restored Snow Leopard PPC Security implementation reaches its public API return path and deliberately returns status `1`.

Historical Apple OSS source provides a strong explanation that must now be checked against the shipped binaries:

1. The legacy Security implementation routes `SessionGetInfo` through `SecurityServer::ClientSession::getSessionInfo`.
2. That client path sends the generated `ucsp_client_getSessionInfo` RPC.
3. The historical `ucsp` subsystem begins at message ID 1000; `getSessionInfo` is routine ordinal 65, therefore request ID 1065 (`0x429`).
4. In the later SecurityServer protocol source, the same ordinal is retained only as:
   `skip; // was getSessionInfo -- now kept by the kernel`.
5. Native later `SessionGetInfo` no longer talks to securityd and instead uses the local/kernel-backed `CommonCriteria::AuditInfo` path.
6. The historical Security error bridge maps an otherwise unhandled `MachPlusPlus::Error` to the bare common error code `CSSM_ERRCODE_INTERNAL_ERROR`, whose value is `1`.

That makes a removed legacy SecurityServer session RPC the leading explanation for the live Lion status `1`.

There is one important alternative inside the same legacy Security boundary: the first `SessionGetInfo` call also forces `ClientSession` first-use activation. That path locates `com.apple.SecurityServer`, performs privileged-server verification, and executes the legacy client setup handshake before `ucsp_client_getSessionInfo` itself. Status `1` therefore proves a Security Mach-transport failure, but does not yet prove which first-use RPC failed.

The live experiment did **not** expose the underlying Mach/MIG return code. In particular, `MIG_BAD_ID` is plausible for the skipped `getSessionInfo` slot but is **not yet proven**. Do not record `MIG_BAD_ID` as the observed failure unless later binary or live evidence establishes it.

## Why a binary audit comes before an adapter

The source correlation is strong but spans historical open-source releases rather than the exact installed proprietary binaries.

Before constructing any compatibility path, establish from the shipped Snow Leopard and Lion images:

- the exact Snow Leopard PPC `SessionGetInfo` call chain;
- the legacy first-use `ClientSession` chain, including SecurityServer lookup, `verifyPrivileged2`, setup/setupThread, and `getSessionInfo` where visible;
- whether the generated legacy `getSessionInfo` client body is visible and what request/reply shape it emits;
- the exact Lion i386 native `SessionGetInfo` path;
- whether Lion securityd retains any visible server body for the legacy session RPC;
- relevant Security/securityd identities and architectures;
- installed Security/MIG error definitions where available.

If Lion securityd is stripped, lack of a visible server symbol is not by itself a failure. The audit must preserve the client-side binary evidence and the source-level slot correlation without pretending that symbol absence proves protocol absence.

## Prepared files

Current runtime `main` provides:

```text
scripts/audit-process-manager-security-session-protocol.py
docs/process-manager-security-session-protocol-audit.md
```

The analyzer is Python-2-compatible and read-only.

It records:

- OS/build and PowerPC architecture-handler state;
- validated Rosetta cache/map identity and Security membership;
- securityd launchd state;
- full Security framework and securityd identities;
- i386, x86_64, and PPC slices where present;
- symbols/imports and disassembly windows around:
  - `SessionGetInfo`;
  - legacy `ClientSession::getSessionInfo`;
  - generated `ucsp_client_getSessionInfo` when visible;
  - generated `verifyPrivileged2`, setup, and setupThread client/server bodies when visible;
  - `ClientSession::activate` / first-use connection setup;
  - native `CommonCriteria::AuditInfo`;
  - relevant securityd `ucsp`/session server symbols when visible;
- Mach/MIG/bootstrap/audit imports;
- relevant SecurityServer/session cstrings;
- installed AuthSession, CSSM-error, and MIG-error header evidence where available;
- the source-correlation constants for legacy request ID `0x429`.

## Safety constraints

For this audit:

- do not launch any PPC executable;
- do not rerun the pre-dispatch compatibility experiment;
- do not call `SessionGetInfo`, `SessionCreate`, or another SecuritySession API from custom code;
- do not perform a bootstrap lookup or send a Mach message from custom code;
- do not set `SECURITYSERVER` or alter any SecurityServer environment variable;
- do not create, replace, or modify a security session;
- do not restart, signal, suspend, or replace securityd;
- do not patch or interpose Security;
- do not broaden or alter the proven CoreServices v3 interposer;
- do not call LaunchServices process-services initialization;
- do not call Process Manager;
- do not use GDB, DTrace, dtruss, or live code injection;
- do not modify Rosetta, private dyld, system dyld, the shared cache, LaunchServices state, or XNU.

Temporary architecture slices are created only under the system temporary directory and removed on exit.

## Phase A — update runtime checkouts

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-process-manager-security-session-protocol.py
docs/process-manager-security-session-protocol-audit.md
```

No PPC artifact rebuild, kernel rebuild, or reboot is part of this stage.

## Phase B — Snow Leopard Security session protocol audit

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-security-session-protocol.py \
  ./process-manager-security-session-protocol-snowleopard.txt
```

Require:

```text
Created: ./process-manager-security-session-protocol-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return the report unchanged.

## Phase C — Lion Security session protocol audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-security-session-protocol.py \
  ./payload/process-manager-security-session-protocol-lion.txt
```

Require:

```text
Created: ./payload/process-manager-security-session-protocol-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return the report unchanged. Do not compensate with another live Security or Process Manager test.

## Phase D — stop and return evidence

Return only:

```text
process-manager-security-session-protocol-snowleopard.txt
process-manager-security-session-protocol-lion.txt
```

No Apple framework, daemon, Rosetta cache, or other proprietary binary should be uploaded.

## Decision gate

### A. Shipped binaries support the removed-legacy-session-RPC explanation

If the Snow Leopard PPC Security image confirms the legacy SecurityServer first-use/client path and Lion's native Security image confirms the AuditInfo path, review the shipped evidence to distinguish connection/setup compatibility from the later `getSessionInfo` slot. If connection/setup remains compatible while the old session RPC is no longer serviced, the removed-session-RPC defect is localized.

Only then prepare a separate, narrowly scoped proof of the correct Lion-side session-information mechanism for a translated PPC process.

Do not fold such a proof directly into the CoreServices v3 interposer and do not proceed to LaunchServices process-services initialization yet.

### B. Shipped binaries contradict the source correlation

Treat the binaries as authoritative.

Stop and localize the discrepancy before designing any adapter.

### C. Lion securityd is too stripped to prove the server slot from symbols

A stripped server is not a failed audit if the required native Security client evidence is present.

Review the Snow PPC client request body, Lion native client path, securityd identity, installed headers, and historical source correlation together. If the actual server response remains ambiguous, the next step will be one narrow live discriminator that exposes only the legacy Security RPC's Mach result. Do not infer `MIG_BAD_ID` solely from a missing symbol.

## Current boundary

The active sequence is now:

```text
PPC execution / Rosetta -> PASS
syscall 295 -> PASS
LaunchServices PPC admission proof -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
CarbonCore FindService -> PASS
SessionGetInfo -> returns 1, no session
```

The immediate failure is therefore the Snow Leopard PPC Security session-information path, not CarbonCore, LaunchServices Process Manager initialization, or XNU.

No additional XNU change is indicated.
