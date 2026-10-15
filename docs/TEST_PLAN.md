# Test plan

Use a staged progression so a failure identifies the layer that is still incompatible.

1. **Payload validation on 10.6.8**
   - `translate` exists.
   - collector succeeds and emits a manifest/checksum.
   - `inspect-payload.sh` verifies every manifest entry.
   - compare the cache identity with `docs/VALIDATED_PAYLOAD.md` when reproducing the current test baseline.

2. **Lion runtime staging**
   - install the OAH directory and isolated `dyld_shared_cache_rosetta`.
   - verify Lion's i386/x86_64 dyld caches were not replaced.
   - run `diagnose-on-lion.sh`.

3. **Phase-2 XNU source validation/build**
   - apply `lion-rosetta-xnu/patches/xnu-1699.32.7-rosetta-commpage.patch` to a clean `xnu-1699.32.7` tree.
   - run `lion-rosetta-xnu/tools/validate_rosetta_source.py` before compiling.
   - compile the patched kernel with the historical Apple build environment.
   - install it using the existing backup/rollback discipline and rebuild the kernelcache.

4. **Reboot and architecture-handler check**
   - confirm `sysctl kern.exec.archhandler.powerpc` reports `/usr/libexec/oah/translate`.

5. **Native i386 commpage verification**
   - build `lion-commpage-probe` on Snow Leopard with `build-lion-commpage-probe-on-snowleopard.sh` if necessary.
   - run it on Lion with `run-lion-commpage-probe.sh`.
   - require `RESULT: PASS` before invoking a PPC executable.
   - this specifically verifies that `0xffff8020` and representative Rosetta branch/signature data are mapped and populated.
   - validated result on the current Lion 10.7.5 phase-2 kernel: PASS; native version 12, Rosetta version 11, PPC capabilities `0x00020145`, cache line 32, expected PPC-view constants, signature data, and low/high branch-assist representatives.

6. **Minimal 32-bit PPC Mach-O**
   - reuse the already validated `ppc-smoketest` binary when possible.
   - run it on Lion with `run-ppc-smoketest.sh`.
   - capture `collect-lion-test-report.sh ./lion-rosetta-test-report.txt ./ppc-smoketest` after the attempt.
   - if Rosetta fails while opening the guest `/usr/lib/dyld`, follow `docs/PPC_DYLD_GAP.md` before making another kernel change.
   - the current Lion direct-launch postmortem shows exactly this condition: Rosetta requests a PPC dyld, Lion provides only x86_64/i386, and the translator misparses the fallback x86_64 slice.
   - use a disposable PPC smoke binary with a private alternate `LC_LOAD_DYLINKER` for the controlled test; never replace Lion's native `/usr/lib/dyld`.
   - the first Lion private-dyld run has now passed the former parser boundary: guest dyld reaches library resolution, rejects the Snow Leopard Rosetta cache because Lion's on-disk libSystem does not match it, then reports that Lion's `/usr/lib/libgcc_s.1.dylib` has no PPC slice.
   - the corrected cache-bypass run has now completed: the stale-cache rejection disappeared, the PPC subject was reported as loaded, and `translate` then terminated with `EXC_CRASH (SIGSYS)`, status 140, `EIP=0xb815ac07`, and `EAX=0x4e`.
   - source comparison points to removed syscall 295 (`shared_region_map_np`) as the leading boundary: Snow Leopard dyld calls it directly, Snow Leopard XNU implements it, and Lion routes 295 to `nosys`.
   - the read-only postmortem collector has now confirmed the legacy shared-region call: runtime code executes `int $0x80`, returns `ENOSYS` with carry set, and the caller passes syscall 295 with `fd=4`, `mappingCount=3`, and mappings spanning exactly the validated Rosetta shared-cache file.
   - do not collect or install a private `libgcc_s.1.dylib` yet. The confirmed syscall-295 boundary precedes that unresolved library question under the active cache-validation bypass.
   - the syscall-295 compatibility experiment has now passed completely: both kernel architectures built, the installed kernel hash matched the candidate, the commpage regression probe passed, the native syscall-295 probe returned EBADF with no SIGSYS, and the guarded direct Rosetta private-dyld/cache-bypass control printed the PPC smoke-test message and exited 0.
   - the syscall-295 SIGSYS/ENOSYS boundary is therefore closed. Do not add guest libraries or make another XNU change before testing the next layer.
   - the normal PPC exec activation experiment has now passed: the validated private-dyld subject launched through the kernel architecture handler, loaded the Rosetta runtime libraries, printed the smoke-test marker, exited 0, and generated no diagnostic.
   - the kernel activation/subject-path layer is therefore closed for the minimal command-line subject.
   - the PPC CoreFoundation experiment has now passed on both Snow Leopard and Lion. The exact PPC subject loaded CoreFoundation plus libauto, libicucore, libobjc, libz, libstdc++, libSystem, and libmathCommon, validated CFString/CFArray behavior, exited 0, and generated no diagnostic.
   - command-line CoreFoundation compatibility is therefore closed for the controlled environment.
   - the first Carbon GUI experiment passed on Snow Leopard but failed on Lion before either program marker or window creation: the exact PPC subject loaded the Carbon/ApplicationServices dependency graph and then terminated with SIGABRT/status 134, producing `/cores/core.1311`.
   - the preserved-core postmortem has now confirmed that Rosetta executes syscall 37 `kill(pid, signum, posix)` with PID 1311, SIGABRT, and posix flag 1; the host syscall returns success. The abort is therefore guest-requested rather than another missing Lion syscall ABI.
   - the milestone experiment has now localized the guest abort precisely: Lion reaches `M00_MAIN_ENTER` and `M01_BEFORE_GetCurrentProcess`, then self-SIGABRTs before `M02_AFTER_GetCurrentProcess`. Snow Leopard reaches all milestones through `M27_SUCCESS` with the exact control binary.
   - this rules out pre-main framework initialization and makes `GetCurrentProcess`/Carbon Process Manager initialization the immediate observed boundary.
   - the LaunchServices bundle control passed on Snow Leopard, but Lion refuses the identical PPC app before execution with `LSOpenURLsWithRole` error `-10665` (`kLSNoRosettaEnvironmentErr`). No milestone file is expected because `main()` is never entered.
   - this is now an earlier LaunchServices Rosetta-availability gate, so the experiment cannot yet test whether registration changes `GetCurrentProcess`.
   - the Snow Leopard/Lion LaunchServices environment audit is complete. Runtime metadata matches, but Snow Leopard has Rosetta receipts and explicit Rosetta/OAH LaunchServices logic while Lion does not; Lion also records the same PPC app as `unsupported-format`.
   - the receipts difference is not yet proven causal. Do not install Snow Leopard receipts on Lion.
   - the first static audit confirms a real Snow Leopard `-10665` path through `_LSAppMeetsRosettaRequirement` and a structurally different Lion `-10665` path, but the analyzer's symbol spelling and broad text matcher prevented precise Lion callsite attribution.
   - the corrected callsite audit is complete: Snow Leopard's `_LSLaunch` uses `_LSAppMeetsRosettaRequirement`, while Lion's `_LSLaunch` calls `_LSBundleDataGetUnsupportedFormatFlag` and returns `-10665` from that persisted classification.
   - the unsupported-format provenance audit is complete. `_LSBundleDataGetUnsupportedFormatFlag` computes the flag from bundle architecture bits and current CPU policy; no dedicated unsupported-format setter was identified.
   - Snow Leopard contains an Intel-host fallback that accepts the PPC architecture bit for Rosetta, while Lion's x86_64-host path tests only native Intel bits and returns unsupported-format for the PPC-only bundle.
   - the private one-byte i386 LaunchServices hypothesis test has now cleared the `-10665` launch gate: the verified private framework was loaded, `open` returned 0, and the PPC app was spawned by LaunchServices. The app then reproduced the independent `GetCurrentProcess` self-SIGABRT boundary.
   - do not broaden or install the LaunchServices patch. Follow `docs/process-manager-alternate-path-experiment.md` to test documented alternate Process Manager identity routes while keeping the private LaunchServices proof setup unchanged.
   - the initial Phase B `NOT_PATCHABLE` result was a patcher-signature bug: the system and i386 hashes matched the validated baseline. The corrected patcher now maps the audited Mach-O virtual address through `LC_SEGMENT` and verifies the exact target instruction bytes before changing one byte in a private copy.

7. **Dynamic-library expansion**
   - only if the validated Rosetta cache still cannot satisfy the guest dependency should individual Snow Leopard PPC libraries be collected for a new private-path experiment.
   - if the smoke test works, test additional PPC binaries that exercise ordinary system libraries.
   - preserve any dyld or translator error verbatim before modifying framework/cache state.

8. **GUI application**
   - only after command-line translation is confirmed should Carbon/Cocoa applications be tested.

9. **Compatibility expansion**
   - add only the specific shim/framework/cache behavior demonstrated missing by the prior step.
   - do not copy Snow Leopard `/System/Library` wholesale into Lion.


## Current Process Manager boundary

The two CoreServices compatibility defects below LaunchServices are now closed in the real translated PPC CarbonCore path.

The process-local `dual-bootstrap-servercheckin-v3` layer succeeds through:

- Lion-format coreservicesd bootstrap lookup;
- Lion-format ServerCheckin;
- unmodified Snow Leopard PPC CarbonCore `FindService("LaunchApplicationServices")`.

The pre-dispatch compatibility experiment has now advanced beyond CarbonCore and exposed the next concrete boundary.

On Lion, after the above CoreServices sequence returns a nonzero `LaunchApplicationServices` port, the untouched Snow Leopard PPC Security call returns normally with:

```text
SessionGetInfo(callerSecuritySession, ...) = 1
session ID = 0
attributes = 0
RESULT: SESSIONGETINFO_ERROR
```

The exact Snow Leopard control returns status 0 with a nonzero session ID and nonzero attributes.

No crash/core diagnostic was produced, all protected identities remained unchanged, and the syscall-295 probe remains a clean EBADF/no-SIGSYS PASS.

The read-only Security session protocol audit has now passed on Snow Leopard and Lion. The shipped Snow Leopard PPC client proves that `ucsp_client_getSessionInfo` uses request ID `0x428` (1064), with a `0x24` send and `0x74` receive; this corrects the earlier source-only `0x429` arithmetic. The same first public call activates the legacy SecurityServer client first, with visible request IDs `setup=0x3e8`, `setupNew=0x3e9`, `setupThread=0x3ea`, and `verifyPrivileged2=0x441`. Lion's native Security client instead uses `CommonCriteria::AuditInfo`; Lion securityd retains visible setup/setupThread/verifyPrivileged2 handlers but no visible `getSessionInfo` or `setupNew` server body.

The Security-only RPC discriminator has now resolved the first-use ambiguity dynamically. The Snow Leopard control obtains a nonzero `com.apple.SecurityServer` port and then successfully executes `verifyPrivileged2 (0x441)`, `setup (0x3e8)`, and `getSessionInfo (0x428)`. On Lion, the same translated PPC client stops earlier: `bootstrap_look_up("com.apple.SecurityServer")` returns `-304` / `MIG_BAD_ARGUMENTS` with a zero service port, after which `SessionGetInfo` collapses the failure to status `1`. No Security ucsp request is sent on Lion in this run.

This supersedes the removed-`getSessionInfo` RPC as the immediate live boundary. That RPC may still become a later compatibility issue, but it has not yet been reached.

The standalone SecurityServer bootstrap adapter proof has now passed completely. Snow Leopard's ordinary `bootstrap_look_up("com.apple.SecurityServer")` returned a nonzero service port. On Lion, the prepared PPC subject sent the already-proven UUID-expanded `vproc_mig_look_up2` request with request ID `0x194`, send size `0xbc`, receive size `0x6c`, target PID 0, zero instance UUID, flags 0, and the SecurityServer service name. Lion returned Mach success and the expected complex `0x28` / reply-ID-`0x1f8` message with one descriptor and a nonzero SecurityServer port.

This closes the immediate Security first-use bootstrap defect as another instance of the Snow-Leopard-to-Lion launchd lookup layout change. No additional bootstrap protocol audit is needed before continuing.

The Security bootstrap compatibility integration has now reached the retired session RPC itself. With only the proven SecurityServer lookup adaptation enabled on Lion, `verifyPrivileged2 (0x441)` succeeds, `setup (0x3e8)` succeeds with RetCode 0, and untouched Snow Leopard PPC Security sends `getSessionInfo (0x428)`. Mach transport succeeds, but Lion returns a non-complex `0x24` MIG error reply. The raw PPC-visible error word is `0xd1feffff`; the shipped PPC generated stub's NDR conversion byte-swaps that to `0xfffffed1`, i.e. signed `-303` / `MIG_BAD_ID`. `SessionGetInfo` consequently returns status 1.

This directly proves that Lion no longer implements the legacy `getSessionInfo=0x428` routine. The next compatibility design must follow Lion's native semantics rather than revive the retired securityd RPC. Lion's native `SessionGetInfo(callerSecuritySession,...)` calls `getaudit_addr(..., 0x30)` and returns the words at offsets `0x24` and `0x28` as session ID and attributes.

The AuditInfo oracle has now passed completely. Native Lion i386 `SessionGetInfo(callerSecuritySession,...)` matches the typed audit-session data returned by `getaudit_addr(..., 0x30)`, and translated PPC can call `getaudit_addr` directly with the same audit session ID. The first raw 32-bit word of `ai_flags` differs across i386/PPC because `ai_flags` is a 64-bit field and the two architectures have opposite endianness.

The one-tuple Security `SessionGetInfo(callerSecuritySession,...)` AuditInfo adapter has now passed completely. On Lion, typed `getaudit_addr` returned `ai_asid=0x000186a3` and logical `ai_flags=0x00002030`; the adapter returned those values through the public API with status 0, and the runner confirmed exact ID/attribute equality. The translated PPC raw words also confirm the big-endian 64-bit `ai_flags` layout: offset `0x28` is the high half and offset `0x2c` is the low half.

That standalone Security adapter result has since been integrated successfully with the proven CoreServices layer; see the combined pre-dispatch result below.


The first Snow Leopard AuditInfo oracle control exposed a harness overconstraint rather than a platform failure. Both PPC and i386 subjects returned a successful legacy `SessionGetInfo`, and both raw `getaudit_addr` reads succeeded with the same session ID at word `0x24`; only the legacy public attribute bits (`0x8030`) differed from raw word `0x28` (PPC `0`, i386 `1`). The corrected oracle now uses a Snow-only `session-id-audit` mode that requires only the proven session-ID correspondence, while preserving strict ID+attribute equality for the native Lion `session-audit` oracle. Pull current main, rebuild Phase B, and rerun Phase C only; do not proceed to Lion until the corrected control reports `RESULT: PASS`.


The corrected Security AuditInfo oracle now passes completely. On Lion, native i386 `SessionGetInfo(callerSecuritySession,...)` returned status 0 and exactly matched the typed audit session ID/attribute values from `getaudit_addr(..., 0x30)`; translated PPC also called `getaudit_addr` successfully and returned the same audit session ID. The raw 32-bit word at offset `0x28` differs between i386 and PPC because `ai_flags` is a 64-bit field: the previous probe logged only the first word, which is the low half on little-endian i386 and the high half on big-endian PPC. The next controlled stage is `docs/process-manager-security-session-auditinfo-api-adapter-experiment.md`, a one-tuple process-local `SessionGetInfo` adapter for `callerSecuritySession` that uses typed `auditinfo_addr_t.ai_asid` / `ai_flags` and sends no SecurityServer RPC. No additional XNU change is indicated.


The combined pre-dispatch integration has now passed completely. In one translated PPC process on Lion, the proven CoreServices bootstrap/ServerCheckin adaptations and the proven AuditInfo-backed `SessionGetInfo` adapter coexist successfully; CarbonCore returns a nonzero `LaunchApplicationServices` port, `SessionGetInfo` returns status 0 with a nonzero session ID, and the original subject reaches `PREDISPATCH_PRIMITIVES_PASS`.

The InitializeProcessesServices wire experiment has now passed completely. Lion accepted the exact Snow Leopard PPC `0x4650` request unchanged and returned the expected complex `0x48` / reply-ID-`0x46b4` response with two descriptors, `outVersion=0x00a1be40`, `outError=0`, and `outCount=0`. The Snow Leopard control returned the same successful reply shape and scalar values.

The corrected LaunchServices process-dispatch experiment has now passed completely on both Snow Leopard and Lion. On Lion, the proven CoreServices and Security adapters allowed the real Snow Leopard PPC setup path to return a nonzero process-dispatch table and a nonzero process-services port, with no diagnostic or integrity change.

The post-dispatch `GetProcessForPID` experiment has now reached the identity call after successfully re-establishing a nonzero LaunchServices dispatch table and process-services port in the same translated PPC process. Lion reaches the marker immediately before `GetProcessForPID`, then terminates before the call returns with exit status `138`, producing a crash report and `/cores/core.17940`. The Snow Leopard control returns status 0 and a nonzero PSN.

The original runner's `POSTDISPATCH_GETPROCESSFORPID_ABORT_BEFORE_RETURN` label was too broad because it classified every non-returning call as an abort without reading the crash signal. The observed status also differs from the historical status-`134` SIGABRT cases.

The preserved post-dispatch core has now resolved the termination. The failure is `EXC_BAD_ACCESS (SIGBUS)` with `KERN_PROTECTION_FAILURE` at guest address `0x3c`, not the historical guest-requested SIGABRT/no-ASN branch. The PPC stack localizes the fault below `__LSApplicationCheckIn` in CarbonCore's filesystem/session-universe path, ending at `__SCSessionUniverseByUIDAcquireAndLock`. The crash state also contains a possible byte-swapped `-304/MIG_BAD_ARGUMENTS` clue, but its liveness is not yet established.

The CarbonCore session-universe differential audit has now passed on both Snow Leopard and Lion. It identifies a concrete InitConnection protocol evolution: Snow Leopard PPC and native clients pass an explicit PID to `__scclient_SCSessionUniverseInitConnection_rpc`, while Lion native clients no longer do. Snow PPC also continues after an RPC error without constructing a universe, which is consistent with the later protected-zero-page fault. The preserved `-304/MIG_BAD_ARGUMENTS` register value is now a strong correlation clue, but the generated MIG stubs must prove the exact request mismatch before compatibility code is justified.

The InitConnection protocol audit has now passed on both Snow Leopard and Lion and proves the exact wire mismatch. Snow Leopard PPC sends request ID `0x2712`, size `0x2c`, with payload `PID, UID, layout`. Lion uses the same request ID but requires size `0x28`, with only `UID, layout`; its generated dispatcher sends `MIG_BAD_ARGUMENTS (-304)` on the legacy size mismatch. The reply ID and success/error shapes remain compatible, so no reply translation is indicated.

The v5 SessionInit experiment has now passed completely. Snow Leopard observed the exact legacy InitConnection transaction transparently; Lion translated only request `0x2712` from `0x2c [PID,UID,layout]` to `0x28 [UID,layout]`, received the compatible success reply, and then returned successfully from `GetProcessForPID(getpid(), &psn)` with a nonzero PSN. No crash/core diagnostic appeared, protected hashes remained unchanged, and syscall 295 remained healthy.

The post-identity `GetProcessPID` round-trip experiment has now passed completely. Snow Leopard and Lion both re-proved the one-call SessionInit path, returned a nonzero PSN from `GetProcessForPID`, and then returned the exact original PID from `GetProcessPID`. Lion ended `RESULT: POSTIDENTITY_GETPROCESSPID_ROUNDTRIP_PASS` with no new crash/core diagnostic and unchanged protected hashes.

The post-identity `TransformProcessType` experiment has now passed completely. Snow Leopard and Lion both re-proved the identity path and returned `noErr` from `TransformProcessType(..., kProcessTransformToForegroundApplication)`. Lion ended `RESULT: POSTIDENTITY_TRANSFORMPROCESSTYPE_PASS` with no new crash/core diagnostic and unchanged protected hashes.

The SetFrontProcess experiment has now produced a clean cross-version differential. Snow Leopard completed the full prerequisite path and returned `SetFrontProcess=0`. Lion re-proved `GetProcessForPID`, exact `GetProcessPID` round-trip, and `TransformProcessType=0`, then returned normally from `SetFrontProcess` with status `-50`. There was no second exact SessionInit transaction, no new crash/core diagnostic, and protected hashes remained unchanged.

The authoritative next step is:

```text
docs/process-manager-setfrontprocess-callpath-audit.md
```

Run the new read-only audit once on Snow Leopard and once on Lion. It compares Snow PPC/i386 and Lion i386 HIServices `SetFrontProcess`/`SetFrontProcessWithOptions` code plus CoreGraphics/CGS/CPS/LaunchServices dependencies and must localize whether the returned status is generated by local validation or returned from a backend.

Do not rerun the PPC SetFrontProcess subject, call `GetFrontProcess`, add a WindowServer/CGS workaround, broaden the v5 adapter, create a window, or change XNU before this result is reviewed.

No additional XNU change is indicated.


The first Snow Leopard dispatch-setup Phase C failure was a harness address-resolution defect, not a LaunchServices compatibility failure. The corrected `loaded_header + offset` resolver and PPC prologue guards were subsequently rebuilt and passed on both Snow Leopard and Lion, so that earlier rerun gate is closed.


The first post-dispatch GetProcessForPID build failure was a harness linkage-gate defect. That corrected builder subsequently produced the accepted artifact, the Snow Leopard control passed, and the Lion run reached the post-dispatch identity boundary; the earlier rebuild gate is closed.


The first Snow Leopard passthrough control for this stage failed only because the v4 harness watched the wrong port and overconstrained an uninitialized header field. The subject itself completed with `GetProcessForPID=0` and a nonzero PSN. Existing CoreServices controls prove `scGetServerCheckinPort()` returns the original coreservicesd service/check-in port, not the different descriptor returned by ServerCheckin; the Snow PPC generated InitConnection client also uses the `mach_msg` send-size argument `0x2c` without initializing pre-send `msgh_size`. Current v5 corrects both assumptions. Rebuild the v5 interposer on Snow Leopard and repeat Phase C only. Do not transfer to Lion until that control reports `RESULT: PASS`.


The first SetFrontProcess call-path audit has now passed on both systems and localizes the returned Lion `-50` below the public HIServices argument checks. Snow PPC and Lion i386 both delegate valid `SetFrontProcessWithOptions` inputs to CoreGraphics `_CPSSetFrontProcess`. The v1 audit, however, did not emit the exact CoreGraphics CPS/CGS function windows needed to decide whether the error is pre-transport, a wire mismatch, or backend-returned.

The authoritative next step is:

```text
docs/process-manager-setfrontprocess-cps-transport-audit.md
```

Run the focused read-only analyzer once on Snow Leopard and once on Lion. It exact-targets the CPS/default-connection/CGS transport functions and requires the relevant Snow PPC and Lion i386 symbols to be present. Do not rerun the PPC application or design a CPS/CGS adapter until those two reports are reviewed.

No additional XNU change is indicated.


The focused SetFrontProcess CPS/CGS audit has now passed on both systems and proves that the current public `-50` has two possible lower-layer causes that must be ordered, not conflated. Snow PPC `__CPSSetFrontProcessWithOptions` returns raw `0x3eb` before transport when its current CoreGraphics connection record is null, and Snow PPC HIServices maps that status to `-50`; independently, Snow PPC `__CGSSetFrontProcess` uses request/reply IDs `0x729e/0x7302` while Lion native uses `0x72a1/0x7305` with otherwise matching `0x30/0x2c` transport sizes.

The authoritative next step is:

```text
docs/process-manager-setfrontprocess-cps-connection-discriminator-experiment.md
```

Build the new PPC discriminator on Snow Leopard and require its direct-execution control to pass with a nonzero audited CoreGraphics connection slot and raw `CPSSetFrontProcess=0`. Then run Lion exactly once. The leading Lion result is a zero audited connection slot plus raw CPS `0x3eb`, which will establish that the present failure occurs before the legacy `0x729e` Mach request. Only if the connection slot is nonzero should the already-proven request-ID mismatch become the next active boundary.

Do not add a CGS request adapter, call public `SetFrontProcess` again, call `GetFrontProcess`, create a window, broaden v5, or change XNU before this discriminator is reviewed.

No additional XNU change is indicated.


The CPS connection-state discriminator has now passed completely. Snow Leopard changes the decoded Snow PPC CoreGraphics connection slot from zero to nonzero during `GetProcessForPID` registration and returns raw `CPSSetFrontProcess=0`. Lion leaves that slot zero, logs `_RegisterApplication(), FAILED TO establish the default connection to the WindowServer, _CGSDefaultConnection() is NULL`, and returns raw CPS `0x3eb`; the runner ends `RESULT: CPS_CONNECTION_NULL_PRETRANSPORT_CONFIRMED`. No crash/core diagnostic appeared, protected hashes remained unchanged, and syscall 295 remains healthy.

The authoritative next step is:

```text
docs/process-manager-cgs-default-connection-audit.md
```

Run the new read-only analyzer once on Snow Leopard and once on Lion. It exact-targets the registration/default-connection creation path, including `_CGSDefaultConnection`, `_CGSNewConnection`, `__CGSNewConnectionPort`, `_CGSLookupServerPort`, bootstrap/vproc/XPC imports, and `_CPSRegisterWithServer` ordering. Snow Leopard `RESULT: PASS` is a hard tooling gate before Lion.

Do not rerun the PPC discriminator, adapt `0x729e -> 0x72a1`, force a CoreGraphics connection record, add a WindowServer/CPS interposer, call `GetFrontProcess`, create a window, broaden v5, or change XNU until the two default-connection audit reports are reviewed.

No additional XNU change is indicated.


The CGS default-connection differential audit has now passed on Snow Leopard and Lion. Both systems had a live WindowServer. Snow PPC and Lion native `__CGSDefaultConnection` both create through `_CGSNewConnection`, while their visible `__CGSNewConnectionPort` client contracts match at request/reply IDs `0x7469/0x74cd`, receive size `0x44`, Mach options `0x3`, complex request bits `0x80001513`, and aligned-name-plus-`0x44` send sizing. The active static differential is earlier: Snow PPC `_CGSLookupServerPort` calls `_lookupServerPort(0,1)`; Lion native x86_64 calls `_getSessionPort(1)` and then `_CGSLookupServerRootPort(1)` fallback, with additional per-session WindowServer/bootstrap/XPC helpers.

The authoritative next step is:

```text
docs/process-manager-cgs-server-port-acquisition-audit.md
```

Run the new read-only helper analyzer first on Snow Leopard as the hard gate, then Lion. It exact-targets `_CGSServerPort`, `_lookupServerPort`, `_getSessionPort`, `_CGSLookupServerRootPort`, `_CGSessionGetWindowServerPort`, root/active WindowServer helpers, bootstrap/XPC imports, and addressed service-name cstrings. Return only the two generated server-port acquisition reports.

Do not rerun the PPC discriminator or SetFrontProcess subject, dynamically call private CGS helpers, perform a bootstrap lookup, add a WindowServer/CoreGraphics interposer, fabricate a connection record, adapt `0x7469` or `0x729e`, broaden v5, or change XNU until those two reports are reviewed.

No additional XNU change is indicated.


The first returned CGS server-port acquisition reports both passed analyzer version 1, but they exposed a tooling ambiguity rather than an adapter-ready result. In the relevant Snow PPC and Lion i386 CoreGraphics slices, `_lookupServerPort` is a duplicated local static symbol; version 1 retained only the last address for same-name symbol-window emission. It also omitted a complete Snow PPC `_CGSLookupSessionPort` window even though that helper sits in the candidate session/root lookup cluster. The broad result still stands: the failure remains before `__CGSNewConnectionPort`, and no new XNU change is indicated, but the exact active session-port helper contract is not yet proven.

The authoritative next step remains:

```text
docs/process-manager-cgs-server-port-acquisition-audit.md
```

Pull current runtime `main` and rerun the read-only audit on Snow Leopard first and Lion second. The corrected script now reports `analyzer_version=2`, preserves every same-name symbol address, emits every `_lookupServerPort` window, exact-targets Snow `_CGSLookupSessionPort`, and requires Lion `__CGSGetSessionPort`. Return only the two regenerated version-2 reports. Do not rerun the PPC subject, perform a live bootstrap lookup, add a CoreGraphics/WindowServer interposer, or change XNU until the corrected reports are reviewed.

No additional XNU change is indicated.


The corrected CGS server-port acquisition audit has now passed on both Snow Leopard and Lion and resolves the exact active compatibility boundary. Snow PPC initially enters `_lookupServerPort(0,0)`, obtains task special port 4, and performs ordinary `bootstrap_look_up("com.apple.windowserver.session")`; failure falls through the legacy active/root lookup path and can produce the observed non-root on-demand-launch error. Lion native `_CGSLookupSessionPort` instead routes through `_getSessionPort(1)`: it obtains the active root WindowServer service through Lion's `bootstrap_look_up2` path with target PID 0 and flags 8, then issues `__CGSGetSessionPort` request/reply `0x7151/0x71b5` with `0x18/0x30` sizing and returns a one-descriptor `0x11` send right. The unchanged DeathWatch transaction remains `0x714c/0x71b0`, and `__CGSNewConnectionPort 0x7469/0x74cd` remains downstream.

The authoritative next step is:

```text
docs/process-manager-cgs-session-port-protocol-adapter-experiment.md
```

Build the prepared 32-bit PPC standalone probe on Snow Leopard and require the legacy session-lookup/DeathWatch positive control to pass. Then run Lion exactly once after the established native safety gates. The Lion probe performs only the native-format active-root lookup, one `GetSessionPort` transaction, send-right validation, one unchanged DeathWatch transaction, and port deallocation. Return the files listed by the experiment. Do not install a CGS interposer, rerun Process Manager registration, adapt `0x7469` or `0x729e`, or change XNU until this standalone protocol proof is reviewed.

No additional XNU change is indicated.


The first Snow Leopard control for the CGS session-port protocol proof stopped at the probe's own `PM_CGS_SESSION_PORT_LAYOUT:FAIL_LOOKUP` gate before any bootstrap or Mach transaction. The artifact itself was the expected PPC7400/private-dyld build. Review found an endian-sensitive validation defect in probe version 1: it stored the 64-bit launchd flags field as a native `uint64_t`, then compared its two 32-bit halves in little-endian word order. On big-endian PPC, the correct `flags=8` representation therefore failed the checker. Runtime `main` now uses `cgs-session-port-protocol-v2`, validates the flags field as one native 64-bit value, and rejects stale v1 artifacts in both runners. Rebuild on Snow Leopard and repeat Phase C only; do not transfer the v1 executable or run Lion until the v2 Snow control reports `RESULT: PASS`.


The rebuilt version-2 CGS session-port Snow control advanced past the lookup self-check and successfully exercised the real legacy path: `com.apple.windowserver.session` returned a nonzero send right, and DeathWatch returned Mach success with the expected complex `0x28` / reply-ID-`0x71b0` message and one nonzero descriptor. The remaining failure was another probe-only endian bug: v2 decoded the descriptor disposition by shifting a native 32-bit word, yielding `0x00` from the big-endian PPC word `0x00001100`, even though the ABI byte at descriptor offset `0x26` was `0x11`. Runtime `main` now uses `cgs-session-port-protocol-v3`, reads disposition/type directly from bytes `0x26/0x27`, requires `0x11/0x00`, and rejects stale v1/v2 artifacts. Rebuild on Snow Leopard and repeat Phase C only. Do not transfer the v2 executable or run Lion until the v3 control reaches `SNOW_CONTROL_PASS` and `RESULT: PASS`.


The corrected version-3 standalone CGS session-port protocol experiment has now passed completely. Snow Leopard resolved the legacy `com.apple.windowserver.session` service, validated the returned send right, and completed DeathWatch `0x714c -> 0x71b0`. On Lion 10.7.5, translated PPC successfully issued the native-format active WindowServer lookup `0x194` with target PID 0, zero UUID, and flags 8, received a root-owned service port, completed `GetSessionPort 0x7151 -> 0x71b5`, validated the returned `0x11/0x00` port descriptor and send right, and completed unchanged DeathWatch. The runner produced no new crash/core diagnostic, protected hashes were unchanged, and ended `RESULT: CGS_SESSION_PORT_PROTOCOL_ADAPTER_PASS`.

The authoritative next step is:

```text
docs/process-manager-cgs-session-bootstrap-compat-integration-experiment.md
```

Current runtime `main` now provides a one-tuple process-local `bootstrap_look_up` adapter that targets only `com.apple.windowserver.session`, plus a registration-only subject mode and Snow/Lion runners. First require the Snow passthrough integration control. Then, after the established Lion native safety gates, run exactly one Lion registration integration with the proven CoreServices v5 and Security v1 adapters plus the new CGS session-bootstrap adapter. The subject exits immediately after `GetProcessForPID` and the read-only CoreGraphics connection-slot check; it does not call `GetProcessPID`, `TransformProcessType`, SetFrontProcess/CPS, create a window, or enter an event loop. Do not adapt `0x729e` until that result is reviewed.

No additional XNU change is indicated.


The first Lion CGS session-bootstrap registration integration reached and passed the new compatibility bridge: the active-root lookup returned a root-owned send right, `GetSessionPort 0x7151/0x71b5` returned a live session send right, and the CGS adapter logged `ADAPTER_PASS`. `GetProcessForPID` nevertheless did not reach its post-call marker. The process exited with status 1, no new crash/core diagnostic was generated, and protected hashes were unchanged. The original runner's `GETPROCESSFORPID_ABORT_OR_CRASH` label was therefore overbroad; current `main` classifies that exact pattern as a clean early exit after the session adapter.

The authoritative next step is:

```text
docs/process-manager-cgs-connection-transport-trace-experiment.md
```

Build only the new `dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v1` CoreServices trace interposer on Snow Leopard and require the passive Snow control to observe successful `0x714c -> 0x71b0` DeathWatch and `0x7469 -> 0x74cd` NewConnection transactions while registration still succeeds. Then run exactly one guarded Lion trace with the already accepted registration subject, Security v1 adapter, and CGS session-bootstrap v1 adapter. The trace changes no message fields; it records request/reply headers and raw reply words only. Do not adapt `0x714c`, `0x7469`, or `0x729e` before review.

No additional XNU change is indicated.


The first Snow Leopard passive CGS connection trace control exposed a harness expectation error, not a transport failure. The trace build remained behavior-preserving: SessionInit and the legacy WindowServer session lookup passed through, `__CGSNewConnectionPort` sent `0x7469`, received Mach success with reply `0x74cd` and size `0x3c`, `GetProcessForPID` returned 0, and the postidentity CoreGraphics connection slot became nonzero. No `0x714c` DeathWatch appeared. Review of the already-collected Snow PPC static audit explains why: `_CGSNewConnection` uses `_CGSServerPort -> _lookupServerPort(0,0)`, while the separate `_CGSLookupServerPort` helper is the path that wraps `_lookupServerPort(0,1)` with `__CGSSessionDeathWatchPort`. Current `main` therefore makes DeathWatch optional trace evidence and gates this registration experiment on the actual downstream `0x7469 -> 0x74cd` transaction.

The trace interposer itself remains valid as `dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v1`; no rebuild is required when its SHA matches. Pull current `main` and repeat Phase C only from `docs/process-manager-cgs-connection-transport-trace-experiment.md`. Lion remains blocked until the corrected control reports `RESULT: PASS`.


The corrected passive CGS transport experiment has now localized the Lion registration failure one step earlier than `__CGSNewConnectionPort`. Snow Leopard passed with the expected `0x7469 -> 0x74cd` NewConnection transaction, `GetProcessForPID=0`, and a nonzero CoreGraphics connection record. Lion translated PPC instead completed the native active-root lookup, `GetSessionPort 0x7151/0x71b5`, send-right validation, and the exact session-bootstrap adapter, then exited with status 1 before any `0x7469` request was observed; no new crash/core diagnostic appeared and protected hashes remained unchanged. This proves the current boundary is inside the local Snow PPC `_CGSServerPort` path after the adapted lookup and before `__CGSNewConnectionPort`.

The authoritative next step is the read-only `docs/process-manager-cgs-connect-and-check-audit.md` using `scripts/audit-process-manager-cgs-connect-and-check.py`. Run it first on Snow Leopard and then on Lion, return only the two reports, and do not rerun the PPC subject. The analyzer exact-targets `_connectAndCheck`, its `_CGSServerPort` call sites, lookup helpers, and NewConnection boundaries to determine whether this internal ABI/wire step evolved. Do not adapt `0x7469`, broaden the passive trace, or change XNU before those reports are reviewed.


The first read-only `_connectAndCheck` differential passed on Snow Leopard and Lion, but review found one remaining analyzer-coverage gap: both implementations route their first remote validation through private `__CGSGetCoreGraphicsServerVersion`, while analyzer v1 emitted the surrounding `_connectAndCheck` body but not that MIG client's body. The returned reports therefore prove the failure interval and local call ordering but do not yet resolve the actual request/reply IDs, message sizes, payload, outputs, or NDR behavior that can make the translated PPC path stop before `__CGSNewConnectionPort`.

Current `main` advances the same audit to analyzer v2. It now exact-targets and requires both `_CGSGetCoreGraphicsVersion` and `__CGSGetCoreGraphicsServerVersion` on Snow PPC and Lion i386. Rerun only the read-only Snow/Lion audit described in `docs/process-manager-cgs-connect-and-check-audit.md`, require `analyzer_version=2` plus `RESULT: PASS`, and return the two reports. Do not rerun the PPC subject or introduce another interposer until the private server-version protocol is compared.


Analyzer v2 has now resolved the private pre-NewConnection helper statically. Snow PPC and Lion native `__CGSGetCoreGraphicsServerVersion` use the same visible MIG envelope: request `0x7148`, reply `0x71ac`, bits `0x1513`, options `0x3`, send `0x24`, receive `0x48`, with NDR+PID request payload and endian-aware reply handling. The remaining leading explanation is version skew: Snow CoreGraphics is 545.0.0 while Lion is 600.0.0; Snow PPC `_connectAndCheck` compares the returned server version to its local version and can return `0x3f0`, which `_CGSServerPort` turns into `exit(1)`.

Do not patch that branch yet. Current `main` extends the proven passive CGS trace to build ID `dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v2`, adding only `SERVER_VERSION 0x7148 -> 0x71ac` plus raw request-word logging. Follow `docs/process-manager-cgs-server-version-transport-trace-experiment.md`: rebuild trace-v2 on Snow, require the Snow positive control to observe successful `0x7148/0x71ac` and `0x7469/0x74cd`, then run exactly one Lion translated-PPC trace and return the requested evidence. No server-version rewrite, defaults override, NewConnection adaptation, or XNU change is authorized before that review.


The passive server-version trace has now confirmed the exact pre-NewConnection failure mechanism dynamically. Snow PPC and Lion translated PPC both send `0x7148` and receive the expected complex `0x71ac` / `0x40` reply with the same descriptor shape, NDR representation, auxiliary output, and flags output. The Snow raw version word `0x21020000` decodes to `545`; the Lion raw version word `0x58020000` decodes to `600`. Lion then exits cleanly with status 1 before `0x7469`, with no new diagnostic and unchanged protected hashes. This is the already-audited Snow PPC mismatch path: `_connectAndCheck` returns `0x3f0` and `_CGSServerPort` calls `exit(1)`.

Do not rewrite the integrated reply yet. Current `main` provides the standalone `docs/process-manager-cgs-server-version-compat-protocol-adapter-experiment.md`. Build the new PPC proof on Snow, require Snow `545/0` plus descriptor/right semantics, then run exactly one Lion proof with no interposers. The Lion proof must first reproduce original `600/0`, then normalize only a copied NDR-aware reply buffer to `545/0` and prove that no byte outside offsets `0x30..0x37` changes. Only after that result is reviewed may the existing CoreServices `mach_msg` interposer be considered for an exact integrated `0x71ac` reply normalizer.


The standalone CGS server-version compatibility policy proof has passed completely. Snow reproduced the expected `545/0` server-version reply and live descriptor right. Lion reproduced the original `600/0` reply, then the standalone NDR-aware copied-buffer normalizer changed raw major `0x58020000 -> 0x21020000`, left the minor word at zero, changed exactly one byte, changed no byte outside offsets `0x30..0x37`, preserved descriptor/auxiliary/flags outputs, and reparsed as `545/0`. No diagnostic was produced and protected hashes stayed unchanged.

Current `main` now advances to `docs/process-manager-cgs-server-version-compat-integration-experiment.md`. The existing CoreServices `mach_msg` interposer gains an integration-only exact `0x71ac` normalizer; no additional interpose tuple is added. Snow is passthrough and must still complete `0x7469/0x74cd` plus registration. Lion normalization requires the exact standalone-proven request/reply envelope, descriptor, NDR, original `600/0`, auxiliary, and flags values, rewrites only the version region to `545/0`, and restores the original reply if any post-check fails. Run exactly one registration-only Lion integration and return the requested evidence. Do not adapt `0x7469` or `0x729e` before review.


The server-version compatibility integration has now passed its narrow objective. Lion translated PPC accepted the exact live `600/0 -> 545/0` server-version normalization, reached `__CGSNewConnectionPort 0x7469`, received expected reply `0x74cd` with Mach success, returned successfully from `GetProcessForPID`, and published a nonzero CoreGraphics connection record. No new diagnostic appeared and protected hashes remained unchanged.

That success does **not** complete Process Manager registration. The same Lion run still emitted `_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304` after NewConnection succeeded. Earlier static evidence already shows that Snow PPC `__CPSRegisterWithServer` calls legacy `__CGSCheckInApplication`, while Lion native `__CPSRegisterWithServer` calls `__CGSCreateApplication`. The active boundary has therefore moved from default-connection creation to CPS application registration.

The authoritative next step is the read-only `docs/process-manager-cps-registration-protocol-audit.md` using `scripts/audit-process-manager-cps-registration-protocol.py`. Run Snow first as a hard gate, then Lion, and return only the two reports. Do not rerun the foreground/CPS subject, call `CPSSetFrontProcess`, or adapt the later `0x729e -> 0x72a1` SetFrontProcess transaction until the application-registration protocol is reviewed.


The CPS application-registration differential audit has now passed and proves a release-level wire change after default-connection creation. Snow Leopard i386/x86_64/PPC all expose `__CGSCheckInApplication` and no `__CGSCreateApplication`; Lion i386/x86_64 expose `__CGSCreateApplication` and no legacy helper. Snow PPC sends `0x7372 -> 0x73d6` with receive size `0x2c` and send size `align(string)+0x40`; Lion native sends `0x73c1 -> 0x7425` with the same reply-size family but send size `align(string)+0x4c`, adding a 12-byte tail. Current `main` advances to the passive `docs/process-manager-cps-registration-transport-trace-experiment.md`: trace the unchanged Snow request on Snow, then once on Lion with the already-proven server-version normalization active, and inspect the raw reply that corresponds to the surviving `err=-304`. Do not adapt the registration request or the later `0x729e -> 0x72a1` SetFrontProcess transaction yet.


The passive CPS registration trace now directly identifies the post-connection failure. Snow sends `0x7372` with `0x84/0x2c`, receives `0x73d6` / `0x24`, and its NDR result is zero. Lion translated PPC sends the same legacy request and receives the same expected reply envelope with Mach success, but raw result word `0xd0feffff`; under the reply's little-endian NDR relative to PPC this decodes to `-304`, exactly matching the immediate `_RegisterApplication ... err=-304` diagnostic. The connection remains nonzero and `GetProcessForPID` still passes, so this is a normal application-registration server rejection, not a transport failure. Current `main` advances to `docs/process-manager-cps-registration-compat-protocol-adapter-experiment.md`, a no-Mach-IPC copied-buffer proof of the narrow `0x7372 -> 0x73c1`, `+0x0c` request-tail, and `0x7425 -> 0x73d6` reply-ID policy. Do not integrate it or touch `0x729e` yet.


Phase B of the CPS registration copied-buffer policy proof initially false-failed after a successful PPC compile because its build script treated unsuccessful `lipo -verify_arch` checks as conclusive. Snow Leopard `file` identified the output as `Mach-O executable ppc`. Current `main` now uses a robust PPC32 predicate in both the Snow builder and Lion proof runner: try both `lipo` verification forms, then fall back to a required Mach-O + tokenized PPC `file` description while rejecting PPC64. Discard/overwrite the partial artifact from the failed run and rerun Phase B; the compatibility policy itself is unchanged.


The standalone CPS registration compatibility policy proof has now passed completely. Snow reproduced the exact legacy `0x7372 / 0x84 / 0x2c` geometry and the captured `-304` NDR model. Lion's copied-buffer proof changed only the request ID in the common region, preserved the source buffer, appended the exact 12-byte native Lion tail, expanded the explicit send size to `0x90`, and converted a synthetic successful `0x7425` reply to legacy-facing `0x73d6` by changing exactly two reply-ID bytes while preserving result zero and NDR semantics. No new diagnostic appeared and protected hashes remained unchanged.

Current `main` now advances to `docs/process-manager-cps-registration-compat-integration-experiment.md`. The existing two-tuple CoreServices interposer gains an integration-only private-buffer registration adapter: Snow is passthrough; Lion accepts only the first exact traced `0x7372` request for the registration-only subject, copies it, converts the private request to `0x73c1`, appends the proven tail, calls the original `mach_msg` with send size `0x90`, requires native reply `0x7425/0x24/result 0`, then changes only the private reply ID to `0x73d6` before copying the reply back. Run exactly one Lion registration integration after the Snow control. Do not proceed to GetProcessPID/TransformProcessType or the later `0x729e -> 0x72a1` SetFrontProcess path until this result is reviewed.


The CPS registration compatibility integration has now passed completely. Lion accepted the exact private-buffer 0x7372 -> 0x73c1 request conversion and returned native 0x7425 / result 0; the interposer converted that reply back to legacy 0x73d6 / result 0, the registration adapter reported PASS, the previous _RegisterApplication ... err=-304 diagnostic did not recur, GetProcessForPID remained successful, no new diagnostic appeared, and protected hashes were unchanged.

Current main now advances to docs/process-manager-cps-registration-postidentity-validation-experiment.md. Reuse the accepted registration/session/server-version compatibility dylibs unchanged. Build only the extended subject under the same exact executable basename required by the registration predicate, then revalidate GetProcessPID and TransformProcessType on Snow first and Lion exactly once. Do not call the foreground activation API until this gate is reviewed.


The CPS-registration postidentity validation now passes completely on Snow Leopard and Lion. Under the live accepted Lion registration stack, GetProcessPID returns the exact current PID, TransformProcessType returns 0, the registration adapter remains successful, no second registration call is observed, no new diagnostic appears, and protected hashes remain unchanged. The previously latent SetFrontProcess CGS wire difference is therefore active again.

Current main advances to docs/process-manager-setfront-transport-trace-experiment.md. Build the SetFrontProcess subject under the same exact executable basename required by the registration predicate and build the new passive trace variant of the existing two-tuple CoreServices interposer. Snow must prove the unchanged 0x729e/0x7302, 0x30/0x2c transaction first. Lion then runs public SetFrontProcess exactly once with the full accepted compatibility stack while passively logging the unchanged legacy request/reply. Do not adapt 0x729e to 0x72a1 or 0x7305 to 0x7302 until the returned live reply is reviewed.


The passive postregistration SetFrontProcess trace now proves the formerly latent wire mismatch dynamically. Snow sends legacy 0x729e and receives 0x7302/result 0; Lion reaches the same legacy 0x729e request, mach_msg returns 0, but WindowServer returns a normal 0x7302/0x24 reply carrying result -304, which propagates to public SetFrontProcess=-304. Registration, GetProcessPID, and TransformProcessType remain intact, with no new diagnostic and unchanged protected hashes.

Current main advances to docs/process-manager-setfront-compat-protocol-adapter-experiment.md. The new proof keeps the accepted compatibility stack unchanged, uses a private copy of the exact first SetFrontProcess request, changes only request ID 0x729e to Lion-native 0x72a1, requires native reply 0x7305/result 0, changes only that private reply ID back to 0x7302, and verifies public SetFrontProcess returns 0. Snow remains strict passthrough. Do not broaden the predicate or rewrite a nonzero native server result.


The SetFrontProcess copied-buffer policy proof has now passed completely. On Lion the exact first legacy 0x729e request after one accepted registration call was copied privately to native 0x72a1 with exactly one changed request byte and zero source-buffer changes; Lion returned native 0x7305/0x24/result 0; the private reply ID was changed back to legacy 0x7302 with exactly one changed reply byte; the untouched PPC client then returned SetFrontProcess=0 and reached M13_SUCCESS. Snow remained strict passthrough, and no new diagnostic or protected-state change occurred.

Current main advances to docs/process-manager-setfront-compat-integration-experiment.md. Build only the combined SetFront compatibility dylib under PM_CPS_SETFRONT_COMPAT_INTEGRATION, reuse the exact accepted subject and other interposers unchanged, require Snow passthrough, then perform exactly one Lion integration run. The integration must preserve the same narrow SetFront predicate and must not normalize any nonzero native result.


The normal combined SetFrontProcess compatibility integration now passes completely on Snow Leopard and Lion. Lion retains the accepted CPS registration path, exact PID round-trip, foreground conversion, and exact 0x729e -> 0x72a1 / 0x7305 -> 0x7302 SetFrontProcess translation; public SetFrontProcess returns 0, no new diagnostic appears, and protected hashes remain unchanged. Snow remains strict passthrough.

Current main advances to `docs/process-manager-getfrontprocess-validation-experiment.md`. Reuse the accepted compatibility dylibs unchanged and build only a new PPC subject under the same exact registration-sensitive basename. After the already-proven SetFrontProcess success, call exactly one GetFrontProcess and require its returned PSN to match the expected current-process PSN exactly. Do not call GetCurrentProcess or add a GetFrontProcess adapter until this result is reviewed.


The post-SetFront GetFrontProcess validation now passes completely on Snow Leopard and Lion. On Lion, the accepted registration and SetFront compatibility stack remains intact, GetFrontProcess returns 0, and the returned front PSN exactly matches the current translated PPC process PSN; no new diagnostic appears and protected hashes remain unchanged. This confirms that the foreground-selection repair is externally visible through the public Process Manager query.

Current main advances to `docs/process-manager-getcurrentprocess-validation-experiment.md`. Reuse every accepted compatibility dylib unchanged and build only the exact-basename PPC subject. After re-proving PID identity, TransformProcessType, SetFrontProcess, and GetFrontProcess, call GetCurrentProcess exactly once and require its returned PSN to match the same expected PSN. Keep LSDONOTABORTIFNOASN unset and do not suppress abort, synthesize a PSN, add a GetCurrentProcess adapter, create a window, or enter an event loop until this historic boundary is reviewed.


The restored-stack GetCurrentProcess validation now passes completely on Snow Leopard and Lion. On Lion, after the accepted registration, PID identity, foreground conversion, SetFrontProcess, and GetFrontProcess sequence, GetCurrentProcess returns 0 and the exact same PSN already established for the process; no new diagnostic appears and protected hashes remain unchanged. This closes the investigation's original self-SIGABRT GetCurrentProcess boundary without LSDONOTABORTIFNOASN, abort suppression, PSN synthesis, or a GetCurrentProcess adapter.

Current main advances to `docs/process-manager-createwindow-validation-experiment.md`. Reuse every accepted compatibility dylib unchanged and build only the exact-basename PPC subject. Re-prove the restored Process Manager sequence, then call CreateNewWindow exactly once with the historical small document-window attributes/bounds, require status 0 and a nonzero WindowRef, immediately DisposeWindow, and stop before title/show/select/visibility or event-loop APIs.


The restored-stack CreateNewWindow validation now reaches the first post-Process-Manager boundary on Lion. All registration, PID/PSN identity, TransformProcessType, SetFrontProcess, GetFrontProcess, and GetCurrentProcess checks still pass. Immediately after M20_BEFORE_CreateNewWindow, the unchanged Snow PPC client calls bootstrap_look_up2 for com.apple.distributed_notifications.2 with pid 0 and flags 8. Snow returns success and a live service port; Lion's non-target legacy passthrough returns -304 and a null port, after which HIToolbox reports resource-copy failure, damage code -4960 with TTheme instance 0, and aborts before CreateNewWindow returns. Protected hashes remain unchanged.

Current main advances to docs/distributed-notifications-bootstrap-compat-protocol-experiment.md. Do not rerun CreateNewWindow yet. Build the standalone PPC lookup probe and proof-only two-tuple interposer on Snow, require the exact Snow passthrough success, then run exactly one Lion lookup using the already-proven Lion launchd 0x194/0x1f8 formatter for only com.apple.distributed_notifications.2, pid 0, flags 8. Require a real nonzero send right; do not send a notification or broaden the normal integration predicate until the proof is reviewed.


Phase B of the standalone distributed-notifications bootstrap proof initially false-failed after compilation because the probe emitted its build ID from two separate string literals at runtime while the artifact validator deliberately required the full provenance marker to exist as one literal in the binary. Current `main` now defines `PM_DISTRIBUTED_NOTIFICATIONS_PROBE_BUILD_ID:distributed-notifications-bootstrap-probe-v1` as one compile-time concatenated marker and prints it directly. This changes no lookup predicate or protocol behavior. Discard/overwrite the partial failed Phase B outputs and rerun the documented Phase B build.


The standalone distributed-notifications Lion-format lookup proof has returned `DISTRIBUTED_NOTIFICATIONS_COMPAT_ADAPTER_FAILED` with stronger localization than the earlier legacy `-304` result. The exact `0x194` request reached launchd and `mach_msg` returned success; launchd replied with the expected `0x1f8` ID in the simple `0x24` error envelope. The raw PPC-visible scalar `0x4e040000` is NDR byte-swapped and decodes to `0x0000044e` / 1102 (`BOOTSTRAP_UNKNOWN_SERVICE`). Snow's exact tuple still succeeds with a live send right, and Lion protected hashes remain unchanged.

Current `main` therefore advances to `docs/distributed-notifications-service-namespace-audit.md`. Run the new read-only analyzer on Snow Leopard and Lion and return only the two generated reports. It compares distnoted process roles, current launchctl labels, matching LaunchDaemon/LaunchAgent definitions, and distributed-notification service strings in distnoted/Foundation/CoreFoundation. Do not rerun the live PPC lookup, call `CreateNewWindow`, synthesize a service port, restart distnoted/launchd, broaden the compatibility interposer, or change XNU until the namespace evidence is reviewed.


The Snow/Lion distributed-notifications service/namespace comparison has passed and establishes a release-level service split. Snow Leopard has one system `distnoted` launch daemon exposing `com.apple.distributed_notifications.2`, while Lion has a system `distnoted daemon` exposing `com.apple.distributed_notifications@0v3` and `@1v3` plus a per-user `distnoted agent` exposing `@Uv3`. Lion's current user namespace contains the agent job; Lion CoreFoundation contains `@Uv3` and `@1v3`, whereas Snow CoreFoundation contains the legacy `.2` string.

Current `main` advances to `docs/distributed-notifications-client-service-selection-audit.md`. Run the new read-only static analyzer on Snow Leopard first and Lion second, then return only the two generated client-selection reports. The goal is to prove which v3 service native Lion selects for the ordinary distributed notification center before comparing v2/v3 wire semantics. Do not infer the mapping from service suffixes, rerun the live PPC lookup, call `CreateNewWindow`, post/register a distributed notification, restart distnoted/launchd, broaden the compatibility interposer, or change XNU.


The first static distributed-notifications client-selection reports both returned PASS, but analyzer v1 is not decisive enough to select a Lion service. Lion contains both `com.apple.distributed_notifications@Uv3` and `@1v3`, and the v1 address-text scan reported zero direct references for each. The public Lion `CFNotificationCenterGetDistributedCenter` body only reaches a dispatch-once initializer; the private initializer itself calls XPC connection creation but v1 did not emit its full body. Foundation's `defaultCenter` and `notificationCenterForType:` were likewise listed without complete windows.

Current `main` upgrades `scripts/audit-distributed-notifications-client-service-selection.py` to analyzer version 2. The next action remains read-only: overwrite the two v1 reports by rerunning the same audit on Snow Leopard first and Lion second, confirm `analyzer_version=2` and `RESULT: PASS`, and return only the two regenerated reports. Do not infer `@Uv3` versus `@1v3`, issue another live lookup, integrate a name rewrite, call `CreateNewWindow`, or change XNU before review.


Analyzer v2's Snow Phase B failure is a validation/parser defect, not a platform result. The PPC Foundation `nm -nm` output contains both `+[NSDistributedNotificationCenter defaultCenter]` and `+[NSDistributedNotificationCenter notificationCenterForType:]`, but the analyzer previously stored only the final whitespace token of Objective-C symbol names and therefore counted both required targets as absent. Current `main` fixes that parser and advances the analyzer marker to version 3. Overwrite the failed Snow report, rerun Phase B, and continue to Lion only if the regenerated report says `analyzer_version=3` and `RESULT: PASS`. No live lookup, notification, compatibility rewrite, CreateNewWindow retry, or XNU change is authorized by this correction.


The corrected analyzer-v3 Snow/Lion client-selection reports both pass. Snow PPC and Lion Foundation ordinary distributed-center construction converge on the host-center path; Lion `CFNotificationCenterGetDistributedCenter` initializes through `___CFXNotificationCenterCreate`. Lion CoreFoundation still contains both `com.apple.distributed_notifications@Uv3` and `@1v3`, and the static reference pass reports zero direct references for each, so the service identity remains unresolved by static analysis.

Current `main` advances to `docs/distributed-notifications-native-service-selection-trace-experiment.md`. Build the native i386 Lion probe and trace dylib on Lion, then run the CF and Foundation modes in fresh processes. The interposer may only log and forward `xpc_connection_create`; it must not rewrite the service, post/register/remove a notification, run any PowerPC subject, retry `CreateNewWindow`, or change XNU. Return only `distributed-notifications-native-service-selection-lion.txt`.


The native Lion service-selection Phase C report is diagnostically useful despite `ERROR: native CF probe failed`. It records the selected service as `com.apple.distributed_notifications@Uv3` before the trace implementation recursively re-enters `xpc_connection_create` and terminates with status 139. Treat that recursion as a trace-tool defect, not a platform selection failure. Current `main` guards the retired interposer against repeating the log flood, but the native trace is not to be rerun for service identity.

Current `main` advances to `docs/distributed-notifications-protocol-differential-audit.md` with `scripts/audit-distributed-notifications-protocol-differential.py`. Run the static analyzer on Snow Leopard first and Lion second and return only `distributed-notifications-protocol-differential-snowleopard.txt` and `distributed-notifications-protocol-differential-lion.txt`. The audit must determine whether the Snow v2 Mach/MIG client contract is accepted unchanged by Lion's selected `@Uv3` v3 server path or whether a dedicated process-local protocol translation is required. Do not integrate a name rewrite, run another live lookup, call CreateNewWindow, post/register/remove a notification, or change XNU before review.


The completed distributed-notifications protocol differential establishes a representation/transport break, not merely a service-name change. Snow PPC CoreFoundation serializes request dictionaries as binary property lists inside legacy Mach messages and uses the private `SendToServer/ReceiveFromServer/SendToClient/ReceiveFromClient` transport family. Lion's selected `com.apple.distributed_notifications@Uv3` path constructs XPC dictionaries, while Lion `distnoted` imports XPC dictionary/array and connection-send primitives. A direct `.2 -> @Uv3` bootstrap rewrite is therefore insufficient and must not be integrated.

Current `main` advances to `docs/distributed-notifications-protocol-schema-audit.md` using `scripts/audit-distributed-notifications-protocol-schema.py`. Run the static audit on Snow Leopard first and Lion second, then return only `distributed-notifications-protocol-schema-snowleopard.txt` and `distributed-notifications-protocol-schema-lion.txt`. The gate is to recover exact request, remove, post, callback, token, PID, flag, data, and property-list field mappings before any proof-only process-local bridge is designed. No live lookup, notification registration/post, synthetic server port, CreateNewWindow retry, or XNU change is authorized.


The distributed-notifications protocol-schema reports both pass, but they do not yet authorize a bridge. Snow's Mach-header interpretation is now corrected: the client-to-server envelope stores `msgh_bits=0x1413` at header offset `0x00` and `msgh_id=4` at `0x14`; callbacks use `msgh_bits=0x13` and the same ID 4. The reports ground the legacy operation/key vocabulary and Lion's `method=post_token/version=1/token/name/object/userinfo` callback form, while Lion `distnoted` confirms an XPC-only transport surface with no `mach_msg` or bootstrap lookup import. The remaining gate is exact key/value and option/token semantics, because analyzer v1 still misses some stack-built Snow dictionaries and PIC-relative i386 constants.

Current `main` advances to `docs/distributed-notifications-protocol-abi-audit.md`. Run that static audit on Snow Leopard first and Lion second and return only its two reports. No live compatibility bridge, synthetic legacy receive port, notification operation, PPC subject, CreateNewWindow retry, or XNU change is authorized before review.


The analyzer-v2 distributed-notifications ABI reports now both pass. The reviewed mapping is stateful rather than a byte-for-byte rewrite: Snow `register` exposes `entry/counter` identities and Lion v3 uses a uint64 `token`; Snow `unregister` sends selected `entries[]`, Lion sends `tokens[]`; and Lion `post_token` callbacks can be converted back to Snow callbacks by restoring the stored `entry/counter`. Snow suspend state also maps structurally to Lion suspend/unsuspend. Legacy `session_reset` is excluded from the first ordinary-client proof because Lion's reset implementation is explicitly loginwindow-only and uses an `i_am_loginwindow` request/reply handshake.

Current `main` advances to `docs/distributed-notifications-bridge-preflight-audit.md` with `scripts/audit-distributed-notifications-bridge-preflight.py`. Run it on Snow Leopard first and Lion second, then return only the two preflight reports. The gate is to resolve `behavior -> options`, post immediate/all-session/`sux` semantics, and whether any PPC-callable XPC create/send surface exists on Lion. If none exists, the first standalone proof must be a native i386 broker/helper rather than an in-process PPC XPC bridge. No live notification operation, synthetic legacy server, PPC subject, CreateNewWindow retry, or XNU change is authorized before review.


The analyzer-v1 distributed-notifications bridge-preflight reports both pass and establish `ppc_callable_xpc_surface=NO`. Lion's native libxpc surface is i386/x86_64 only, so a translated PPC process cannot directly speak the selected `@Uv3` XPC protocol. The selected implementation boundary is consequently a native i386 broker that uses Lion's **public CoreFoundation distributed-notification API**, not private XPC dictionary synthesis. This keeps Lion's own CoreFoundation responsible for `___checkDelivImmed`, native XPC option encoding, token allocation, and connection lifecycle.

Current `main` advances the same preflight to analyzer version 2. Run `docs/distributed-notifications-bridge-preflight-audit.md` again on Snow Leopard first and Lion second and return only the regenerated two preflight reports. Snow must prove the public suspension-behavior inversion and that post bit 0 controls immediate delivery while bit 1 controls all-session scope; the first proof policy rejects all-session and `sux=true/unknown`. Lion must prove that public AddObserver/PostWithOptions route to the native private distributed-notification paths, that `___checkDelivImmed` is present, and that the architecture remains a native i386 broker using public CF APIs. No broker launch, synthetic legacy service, live notification operation, PPC subject, CreateNewWindow retry, or XNU change is authorized before review.


The distributed-notifications bridge-preflight analyzer-v2 reports now pass on Snow Leopard and Lion. Static architecture selection is closed: no PPC-callable Lion XPC provider exists, Lion native i386 public `CFNotificationCenterAddObserver` / `PostNotificationWithOptions` route into the audited native implementation, and Snow proves public option bit 0 = immediate plus bit 1 = all-session scope. Correct public suspension enum names are Drop=1, Coalesce=2, Hold=3, DeliverImmediately=4; invert the proven Snow numeric conversion as legacy 1->DeliverImmediately(4), 2->Drop(1), 4->Coalesce(2), 8->Hold(3).

Current `main` advances to `docs/distributed-notifications-native-broker-proof-experiment.md`. Build and run the provided i386 proof on Snow Leopard first as the native control, then on Lion. The proof performs exactly one isolated register -> current-session post -> callback -> unregister lifecycle using public CoreFoundation, while negative controls reject `sux=true`, all-session scope, suspend, session_reset, and an invalid legacy behavior before any notification API call. Return only the two native-broker proof reports. No PPC subject, synthetic legacy Mach service, launchd mutation, private XPC synthesis, CreateNewWindow retry, or XNU change is authorized before review.


The standalone native distributed-notification broker proof now passes on both 10.6.8 and 10.7.5. Each run confirms `register -> immediate current-session post -> callback -> unregister`, exact Snow entry/counter callback reconstruction, zero notification API calls in the negative controls, and unchanged protected binaries. This closes the native i386 public-CoreFoundation backend.

Current `main` advances to `docs/distributed-notifications-ppc-ingress-bridge-proof-experiment.md`. Build the PPC proof subject and one-tuple bootstrap interposer on Snow Leopard, require the native Snow `.2` passthrough lifecycle to pass, transfer those exact hashed PPC artifacts to Lion, build the native i386 ingress broker there, then run one Lion proof. The Lion adapter creates only a process-local Mach receive right for the exact `.2`, pid-0, flags-8 lookup, forwards the unchanged Snow binary-plist payload over an inherited socketpair, uses the proven public CoreFoundation broker backend, and reconstructs the Snow callback Mach envelope to the callback right supplied by unchanged PPC CoreFoundation. No launchd registration, global legacy service, raw XPC synthesis, real Process Manager subject, CreateNewWindow retry, or XNU change is authorized before review.


The first Phase B build for the PPC distributed-notifications ingress bridge failed at link time before any live notification test: the PPC dynamic interposer used a direct `extern char **environ` reference, producing an unresolved `_environ` symbol. This is a build-only defect. Current `main` replaces that reference with Darwin's dynamic-library-safe `_NSGetEnviron()` accessor from `crt_externs.h`, preserves the existing environment filtering and `posix_spawn` logic, bumps the interposer build ID to version 2, and strengthens the Snow builder to require `__NSGetEnviron` while forbidding `_environ`. Both runners require the v2 interposer. Pull current `main` and rerun Phase B from the beginning on Snow Leopard; Phase C remains blocked until the build succeeds.


The second Phase B PPC-ingress build failure is a validator false negative: the probe was successfully produced as `Mach-O executable ppc`, but the helper's `lipo -verify_arch` test rejected the thin artifact on this Snow Leopard toolchain. Current `main` replaces that check with `lipo -info` architecture parsing, requires the Snow artifacts to report thin `architecture: ppc`, corroborates with `file`, and applies the same parser to the Lion transfer checks. A malformed duplicated shell block discovered after the earlier `_NSGetEnviron` patch was also removed by reconstructing the builder. Pull current `main`, discard partial Phase B outputs, and rerun Phase B from the beginning; Phase C remains blocked until the build fully completes.


The third PPC-ingress Phase B failure is another architecture-validator false negative: Snow's `lipo -info` reported the `-arch ppc` probe as concrete subtype `ppc7400`, while `file` confirmed it is a PPC Mach-O. Current `main` now normalizes the documented 32-bit cctools PowerPC subtype names into the generic PPC32 family and explicitly excludes `ppc64`. The same family-aware matcher is used by the Snow control and Lion proof runners so transferred `ppc7400` artifacts are accepted consistently. Pull current `main`, discard partial outputs, and rerun Phase B from the beginning; Phase C remains blocked until the complete build succeeds.


The fourth PPC-ingress Phase B failure is a Darwin symbol-versioning validator defect: the interposer calls `socketpair()`, but Snow's UNIX03 headers can emit the undefined symbol `_socketpair$UNIX2003` rather than unversioned `_socketpair`. Current `main` requires exactly one supported socketpair import (`_socketpair` or `_socketpair$UNIX2003`), records it in the interposer info file, and leaves all other import, architecture, and interposer-v2 checks intact. Pull current `main`, discard partial artifacts, and rerun Phase B from the beginning; Phase C remains blocked until the complete build succeeds.


The first Lion PPC-ingress Phase F failure is a runner syntax defect in the required-marker loop, not yet evidence of a bridge/protocol failure. Because the malformed loop occurs after the live PPC proof launch and protected-hash recomputation, the failed invocation may already have consumed the intended one-shot live proof. Current `main` fixes the loop and adds `scripts/validate-lion-ppc-distributed-notifications-ingress-existing.sh`, which checks the preserved `.txt` and `.raw.log` without launching PPC or the broker again. Syntax-check both scripts with `/bin/bash -n` first, then use recovery validation on the existing Lion artifacts; do not rerun Phase F unless preserved evidence is missing/inconclusive and a later review explicitly authorizes it.


The standalone PPC distributed-notifications ingress/native-broker proof is now complete on both systems. Lion proved the full process-local `.2` request -> native broker -> public Lion CFNotificationCenter -> callback -> legacy Mach callback chain with one lookup, three legacy requests, one callback, zero rejects, broker exit 0, PPC exit 0, and unchanged protected hashes. The live receive side observed `msgh_bits=0x1111`; do not incorrectly gate the integration on the sender-side static `0x1413` value.

Current `main` advances to `docs/process-manager-createwindow-distributed-notifications-integration-experiment.md`. The new build embeds the proven ingress implementation into the accepted CoreServices `bootstrap_look_up2` interposer so there is no duplicate interpose tuple, explicitly excludes the obsolete name-only notification adapter, and keeps all existing Process Manager/CGS/CPS behavior unchanged. Build the combined PPC dylib on Snow Leopard, require the Snow CreateNewWindow passthrough control, then perform exactly one Lion CreateNewWindow integration run with the native i386 broker. No global `.2` service, launchd change, private XPC synthesis, broader notification semantics, or XNU change is authorized.


The first real CreateNewWindow distributed-notifications integration run established the process-local `.2` ingress but the proof broker rejected all three real legacy requests with `BROKER_REJECT_SCHEMA` (status 20); the old `INGRESS_NOT_ESTABLISHED` label was a runner false classification caused by an interleaved local-service-result log line. Current `main` fixes that classification and advances to `docs/process-manager-createwindow-distributed-notifications-real-schema-audit.md`. The next run uses a capture-only native broker to record the exact three real request dictionaries; it does not authorize any new notification name, operation, callback, or XNU change.

The CreateNewWindow real-schema audit now passes and closes the schema-capture gate. Lion captured exactly three legacy requests, all `register`: `com.apple.MCX._managementStatusChangedForDomains` / `com.apple.MCX` behavior 1, `com.apple.CFPreferences._domainsChangedExternally` / `com.apple.CFPreferences` behavior 1, and `AppleColorPreferencesChangedNotification` / `kCFNotificationAnyObject` behavior 4. All three share the reviewed eight-key shape, `counter=1`, one common session ID, and distinct run-time entries. The audit reported three captures, three legacy Mach requests, zero failures, unchanged protected hashes, and `CREATENEWWINDOW_DISTNOTIFY_REAL_SCHEMA_AUDIT_PASS`.

Current `main` advances to `docs/process-manager-createwindow-distributed-notifications-real-registration-experiment.md`. The dedicated native i386 broker supports exactly those three simultaneous registrations, maps the Snow `kCFNotificationAnyObject` serialization to a public any-object filter, preserves each `entry/counter` for callback reconstruction, and rejects every unreviewed operation. Reuse all accepted PPC artifacts unchanged, repeat the syscall-295 gate, and perform exactly one Lion CreateNewWindow run in `lion-createwindow-register-v1` mode. A successful window creation must reach M21, return status 0 with a nonzero WindowRef, dispose the window, reach M24, and report `CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_PASS`. If all three registrations are established but CreateNewWindow still does not return, stop and analyze that new boundary before broadening notification policy. No XNU change is authorized.

The exact CreateNewWindow real-registration gate is now complete with a no-return result: all three reviewed registrations are accepted by Lion's native public distributed-notification bridge, the broker reports zero rejects and zero callbacks, yet the same HIToolbox resource-URL failure and TTheme `-4960` abort occurs before `M21_AFTER_CreateNewWindow`. This moves the immediate unresolved boundary beyond notification registration.

Current `main` advances to `docs/process-manager-createwindow-hitoolbox-cfbundle-live-trace-experiment.md`. The new PPC trace interposes `CFBundleCopyResourceURLForLocalization` as a strict pass-through and records only the exact `com.apple.HIToolbox` / `Extras` / `rsrc` lookup. Require the Snow CreateNewWindow control to observe a non-NULL result and still reach M24 before one Lion run is authorized. On Lion, retain the proven three-registration broker and require the exact lookup to return NULL immediately before the known HIToolbox warning to classify `CREATENEWWINDOW_HITOOLBOX_EXTRAS_LOOKUP_CONFIRMED_NO_RETURN`. This remains diagnostic only: existing resource-map/payload audits show `Extras.rsrc` and `Extras2.rsrc` are not safe to treat as equivalent. No XNU change is authorized.

The live HIToolbox CFBundle differential is complete. The successful Snow control observed the exact `com.apple.HIToolbox` / `Extras` / `rsrc` lookup twice with non-NULL `Extras.rsrc` URLs and reached M24. The Lion run observed the same exact call once with a NULL result immediately before the known HIToolbox resource warning and TTheme `-4960` abort, while the exact three-registration broker still passed. This establishes the missing Snow `Extras.rsrc` as the current CreateNewWindow compatibility boundary.

The next gate is `docs/process-manager-createwindow-hitoolbox-extras-resource-compat-experiment.md`. Stage only the exact Snow Leopard 10.6.8 `Extras.rsrc` with SHA-256 `a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197`; validate a forced external-resource CreateNewWindow control on Snow first; then run exactly one Lion fallback test with the proven notification broker. Never install the resource into Lion's system framework, never substitute `Extras2.rsrc`, and never commit or upload the proprietary resource. No XNU rebuild or reboot is authorized.

The exact Snow `Extras.rsrc` compatibility stage has moved CreateNewWindow beyond the old HIToolbox/TTheme abort. The Snow forced-external control passed, and the Lion run produced two exact `original=NULL fallback=NONNULL` resource results before a fourth legacy distributed-notification request appeared. The current three-name broker rejected that newly reachable request with status 25 (`BROKER_REJECT_NAME`), after which execution still reached M21 and returned `CreateNewWindow=-304`; a later `com.apple.dock.server` bootstrap lookup also returned `-304`.

The next gate is `docs/process-manager-createwindow-post-extras-distributed-notification-schema-audit.md`. Build only the new native i386 post-Extras audit broker, retain the proven first three registrations and exact PPC resource fallback unchanged, capture exactly the fourth request's binary plist/XML, and deliberately keep returning status 25 for that unknown name. Do not broaden notification policy or modify the dock-server path in the same experiment. No PPC rebuild, XNU rebuild, or reboot is authorized.

## Exact fourth post-Extras notification registration gate

The post-Extras schema audit captured `AppleAquaColorVariantChanged` as the fourth request with the reviewed eight-key `register` schema, `kCFNotificationAnyObject`, legacy behavior 4, counter 1, and the same session discipline as the accepted first three registrations. The exact Snow HIToolbox resource fallback remained effective and the audit passed with four legacy requests, one intentional capture, zero unexpected rejects, and unchanged protected hashes.

Follow `docs/process-manager-createwindow-post-extras-distributed-notification-registration-experiment.md`. The next run may add only that exact fourth name to the native public-CoreFoundation registration broker. If all four registrations pass and `com.apple.dock.server` still returns `-304`, stop there and treat that bootstrap lookup as the next boundary. No fifth notification policy, dock-server compatibility change, or XNU change is part of this gate.



## Dock server bootstrap protocol proof after exact-four registration gate

The exact-four post-Extras notification run established all four reviewed registrations with zero rejects and left the already recorded `com.apple.dock.server` lookup as the next live boundary. On Lion the untouched Snow PPC ordinary `bootstrap_look_up` returned `-304/MIG_BAD_ARGUMENTS` with a zero port and `CreateNewWindow=-304`; the exact Snow resource fallback and protected-state checks remained clean.

Follow `docs/process-manager-createwindow-dockserver-bootstrap-protocol-adapter-experiment.md`. Build the standalone PPC Dock lookup subject only on Snow Leopard, require its ordinary `com.apple.dock.server` control to return `kr=0` and a nonzero port, transfer that exact hashed subject to Lion, repeat the native safety gates, and send exactly one known Lion-format lookup request: ID `0x194`, size `0xbc`, PID 0, zero UUID, flags 0, reply ID `0x1f8`. Stop after the lookup result. Do not run CreateNewWindow, modify the CGS interposer, broaden notification policy, alter HIToolbox resources, or change XNU before review.


## Dock-server bootstrap compatibility integration gate

The standalone Dock lookup discriminator passed on both systems. Snow Leopard's ordinary PPC lookup returned a nonzero `com.apple.dock.server` port. Lion accepted the exact `0xbc` UUID-expanded request with PID 0, zero UUID, and flags 0, returned reply ID `0x1f8`, descriptor count 1, and a valid send right; no diagnostic or protected-state change occurred.

Follow `docs/process-manager-createwindow-dockserver-bootstrap-compat-integration-experiment.md`. Build only the opt-in `cgs-session-bootstrap-dockserver-compat-v2` interposer on Snow Leopard, require the full Snow CreateNewWindow passthrough control, transfer that exact hashed dylib to Lion, repeat syscall 295, and perform exactly one CreateNewWindow run with `ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1`, the exact-four notification broker, and the accepted Snow `Extras.rsrc` fallback. If CreateNewWindow succeeds through `M24_SUCCESS`, stop and advance beyond window construction; if the Dock adapter passes but another error/no-return appears, preserve that new boundary without broadening compatibility.

## Dock bootstrap integration accepted; CGS NewWindow protocol differential next

The completed Dock-aware CreateNewWindow integration reproduces the standalone Dock lookup proof inside the restored stack: exact `com.apple.dock.server` adaptation returns a valid send right and `PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS`. The exact-four distributed-notification broker still passes with zero rejects, the Snow `Extras.rsrc` fallback still succeeds, syscall 295 remains EBADF/no-SIGSYS, and protected hashes remain unchanged.

The first remaining failure is now after the Dock lookup: CoreGraphics logs `MIG: server type check failure: CGSNewWindowWithOpaqueShape: Cannot create window`, public `CreateNewWindow` returns `-304`, and the WindowRef remains null. The next gate is `docs/process-manager-createwindow-cgs-newwindow-protocol-audit.md`. Run its read-only analyzer on Snow Leopard PPC first and Lion i386 second; do not rerun CreateNewWindow, broaden the live Mach trace, or implement a NewWindow adapter until the client contracts are compared.

## CGS NewWindow static protocol differential passed; exact passive trace is next

The static audit now shows that Snow PPC and Lion i386 `__CGSCreateWindowInline` are structurally aligned except for their MIG routine IDs: Snow uses `0x7394/0x73f8`, while Lion uses `0x739a/0x73fe`. Request bits remain `0x1513`, Mach option `0x3`, receive size `0x40`, send-size construction remains `0x38 + 4*countA + 4*countB`, and both generated clients accept `0x38` success or `0x24` error replies with NDR-aware handling.

The next gate is `docs/process-manager-createwindow-cgs-newwindow-transport-trace-experiment.md`. Build only the new passive trace variant of the accepted CoreServices interposer on Snow Leopard, require a full Snow CreateNewWindow trace/control, transfer that exact hashed dylib to Lion, repeat syscall-295, and perform one Lion trace with the accepted Dock adapter, exact-four notification broker, and HIToolbox Extras fallback unchanged. No NewWindow request/reply conversion is authorized yet.


## NewWindow transport trace passed; prove ID-only policy locally

The passive CreateNewWindow NewWindow trace now closes the current live failure mechanism. Snow and Lion translated PPC both issue the exact legacy inline 0x7394 request with bits 0x1513, explicit send/receive sizes 0x68/0x40, and matching visible request words. Snow receives 0x73f8 / 0x38 and succeeds; Lion receives Mach success plus 0x73f8 / 0x24 with raw result 0xd0feffff, decoded -304, and public CreateNewWindow returns -304 with a null WindowRef. The previously audited Lion-native pair is 0x739a/0x73fe.

Follow docs/process-manager-createwindow-cgs-newwindow-compat-protocol-adapter-experiment.md next. Build the standalone PPC proof on Snow, require its local control, transfer the exact hashed executable, repeat syscall 295 on Lion, and run one local Lion policy proof with no interposers and no Mach IPC. The proof changes only request/reply IDs in private copies, verifies the source and body bytes are untouched, and verifies that an error reply remains -304. Only after review may a live private-buffer NewWindow adapter be considered. No XNU rebuild or reboot is indicated.


## NewWindow copied-buffer policy proof passed; integrate once

The standalone NewWindow compatibility proof now passes with the exact policy predicted by the transport trace and static audit. The 0x68-byte legacy request is copied privately and only request ID 0x7394 becomes Lion native 0x739a; exactly one byte changes, the source buffer remains untouched, and zero body bytes change. Native reply ID 0x73fe is converted back to legacy 0x73f8 for both accepted 0x38 success and 0x24 error shapes with exactly one changed byte and zero body changes. The modeled 0x24 error remains decoded -304. Snow control, syscall 295, diagnostics, and protected hashes all pass.

Follow docs/process-manager-createwindow-cgs-newwindow-compat-integration-experiment.md. Build only the new combined NewWindow compatibility dylib on Snow, require the full Snow CreateNewWindow passthrough control, transfer the exact hashed dylib, repeat syscall 295, and run one Lion integration with the accepted Dock adapter, exact-four notification broker, and Snow Extras fallback unchanged. A native 0x73fe/0x24 nonzero result must be propagated unchanged; success may be reported only if native 0x73fe/0x38/result 0 maps back to legacy 0x73f8 and public CreateNewWindow reaches a nonzero WindowRef and M24_SUCCESS.


## NewWindow native success reached; post-NewWindow CGS audit next

The live CGS NewWindow compatibility integration has now proved the ID-only adapter through a real native Lion success reply. The exact legacy request was copied as `0x7394 -> 0x739a` with one changed byte and no body/source changes; Lion returned `0x73fe / 0x38 / result 0`; the reply copy changed only `0x73fe -> 0x73f8`; and the legacy-facing trace accepted the resulting `0x73f8 / 0x38` success reply. The Dock bootstrap adapter, exact-four distributed-notification broker, Snow `Extras.rsrc` fallback, syscall-295 safety gate, and protected hashes also remained intact.

The public `CreateNewWindow` call still did not return. Immediately after the successful NewWindow reply, Lion reported `CGSSetWindowToReleaseBackingOnOrderOut` MIG type-check failure, `CGSSetWindowOpacity` receive-too-large, `CGSGetDisplayBounds (display 0)` illegal argument, and `CGSShapeWindow` MIG type-check failure, then terminated with status 138 and produced a crash/core. The previous Dock-oriented no-return result label was too coarse; current runner classification recognizes successful NewWindow adaptation before reporting the post-RPC no-return state.

The next gate is `docs/process-manager-createwindow-cgs-post-newwindow-protocol-audit.md`. Run only its read-only Snow-PPC and Lion-i386 CoreGraphics analyzer and return the two reports. Do not rerun the PPC subject, rebuild the compatibility dylib or native notification broker, broaden the NewWindow predicate, or change XNU before that differential is reviewed.


## Post-NewWindow static audit passed; release-backing trace next

The Snow Leopard PPC and Lion i386 post-NewWindow CoreGraphics audit now passes. The first helper named by the live Lion failure sequence, `CGSSetWindowToReleaseBackingOnOrderOut`, is structurally aligned except for generated-MIG IDs: Snow uses `0x724b/0x72af`, Lion uses `0x724c/0x72b0`; both use bits `0x1513`, option `0x3`, send/receive sizes `0x28/0x2c`, and a `0x24` reply with NDR-aware result decoding. The later ShapeWindow clients also show ID movement, but they remain out of scope until the first release-backing transaction is validated live.

Current main therefore advances only to `docs/process-manager-createwindow-cgs-releasebacking-transport-trace-experiment.md`. Build the new combined passive-trace dylib on Snow, require a full Snow CreateNewWindow positive control, then run exactly one Lion trace with the already accepted NewWindow adapter unchanged. No `0x724b -> 0x724c` conversion is authorized yet, and no XNU rebuild or reboot is indicated.


## Release-backing trace gate passed; policy proof is next

The release-backing passive trace is now closed: the Snow control reaches `CreateNewWindow=0`, nonzero WindowRef, DisposeWindow, and M24 while `0x724b -> 0x72af / 0x24` returns result 0. On Lion, after the accepted NewWindow adapter returns native success, the same legacy release-backing envelope returns Mach success and `0x72af / 0x24` with raw `0xd0feffff` (decoded `-304`). The exact-four notification broker remains PASS, syscall 295 still reaches EBADF without SIGSYS, and protected hashes remain unchanged.

The next gate is `docs/process-manager-createwindow-cgs-releasebacking-compat-protocol-adapter-experiment.md`. It is standalone and performs no Mach IPC. Build the PPC proof on Snow, require its local control, transfer the exact hashed executable, rerun the syscall-295 safety gate, then run the Lion policy proof exactly once. The proof must demonstrate one-byte request-ID conversion `0x724b -> 0x724c`, one-byte reply-ID conversion `0x72b0 -> 0x72af`, zero body/source changes, success-result preservation, and nonzero-result preservation. No live release-backing adapter is authorized until that proof passes and is reviewed.


## Release-backing copied-buffer proof passed; live integration next

The standalone release-backing policy proof now passes on Lion with no new diagnostics and unchanged protected hashes. The exact `0x28/0x2c` legacy request is copied unchanged except for one byte of request-ID conversion `0x724b -> 0x724c`; the source request remains untouched. Native `0x72b0 / 0x24` success and error replies are copied unchanged except for one byte of reply-ID conversion to `0x72af`, preserving both result 0 and the modeled raw `0xd0feffff` / decoded `-304` error.

Current main therefore advances to `docs/process-manager-createwindow-cgs-releasebacking-compat-integration-experiment.md`. Build only the new combined release-backing compatibility dylib on Snow, require the full Snow passthrough CreateNewWindow/DisposeWindow control, repeat syscall 295 on Lion, then run exactly one Lion integration with the accepted NewWindow adapter unchanged. Do not broaden the release-backing predicate or adapt opacity, display-bounds, ShapeWindow, or XNU in this stage.


## Release-backing live adapter passed; opacity alpha-plane audit next

The first live `CGSSetWindowToReleaseBackingOnOrderOut` compatibility integration now succeeds natively on Lion: request ID `0x724b -> 0x724c` changes exactly one copied request byte with no body/source changes, Lion returns native `0x72b0 / 0x24 / result 0`, and reply ID `0x72b0 -> 0x72af` changes exactly one copied reply byte with no body changes. The legacy-facing reply is accepted and the release-backing adapter reports PASS.

`CreateNewWindow` still does not return. The first subsequent live diagnostic is now `(ipc/rcv) msg too large: CGSSetWindowOpacity`; display-bounds and ShapeWindow diagnostics follow later. The accepted static post-NewWindow reports show that the opacity wrapper routes through `__CGSCreateWindowAlphaPlane` and `__CGSTerminateWindowAlphaPlane`, so the next gate is the static/read-only `docs/process-manager-createwindow-cgs-opacity-alpha-plane-protocol-audit.md`. Run only its Snow-PPC and Lion-i386 analyzer and return the two reports. Do not rerun CreateNewWindow, change the accepted NewWindow/release-backing adapters, or trace/adapt display-bounds, ShapeWindow, or XNU before that differential is reviewed.


## Opacity alpha-plane static audit passed; passive branch trace next

The focused Snow-PPC/Lion-i386 opacity audit now passes and resolves the generated-MIG clients beneath `CGSSetWindowOpacity`. Create-alpha shifts from Snow `0x724f/0x72b3` to Lion `0x7250/0x72b4`; terminate-alpha shifts from Snow `0x7250/0x72b4` to Lion `0x7251/0x72b5`. Both retain bits `0x1513`, option `0x3`, send/receive `0x24/0x2c`, accepted reply `0x24`, and the same NDR-aware result layout.

Snow terminate is numerically identical to Lion create, so static evidence cannot safely choose an opacity conversion. Current main advances to `docs/process-manager-createwindow-cgs-opacity-alpha-plane-transport-trace-experiment.md`: identify exactly one legacy create/terminate branch on the Snow positive control and one Lion run while preserving the accepted NewWindow and release-backing adapters and rewriting no opacity traffic. Do not advance to display-bounds, ShapeWindow, or XNU before that trace is reviewed.


## Opacity create-alpha trace passed; copied-buffer policy proof next

The Snow positive control and Lion passive opacity trace both selected the create-alpha path beneath `CGSSetWindowOpacity`. Snow sent legacy `0x724f`, received `0x72b3 / 0x24 / result 0`, and completed CreateNewWindow/DisposeWindow/M24. Lion reached the same `0x724f` request only after the accepted NewWindow and release-backing adapters had returned native success, then `mach_msg` returned `0x10004004/MACH_RCV_TOO_LARGE`. Exactly one create-alpha request and zero terminate-alpha requests were observed; protected hashes remained unchanged.

Current `main` advances to `docs/process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-adapter-experiment.md`. That stage is standalone and sends no Mach IPC: it must prove one-byte request-ID conversion `0x724f -> 0x7250`, one-byte reply-ID conversion `0x72b4 -> 0x72b3`, zero request/reply body changes, zero source-buffer changes, and preservation of both zero and modeled nonzero results. Do not integrate a live opacity adapter, alter the `0x2c` receive size, or advance to display-bounds/ShapeWindow/XNU until that proof is reviewed.


## Opacity create-alpha copied-buffer proof passed; live integration next

The standalone opacity create-alpha policy proof now passes. The legacy `0x24/0x2c` request is copied privately and only request ID `0x724f -> 0x7250` changes; exactly one byte changes, zero body bytes change, and the source request remains untouched. Native `0x72b4 / 0x24` replies are copied back with only reply ID `0x72b4 -> 0x72b3` changed; zero reply-body bytes change, result 0 remains 0, and a modeled nonzero `-304` result remains unchanged. Snow control and syscall 295 pass, no new diagnostics were produced, and protected hashes remained unchanged.

Current `main` advances to `docs/process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-integration-experiment.md`. Build only the new combined opacity create-alpha compatibility dylib on Snow, require the full Snow passthrough CreateNewWindow/DisposeWindow/M24 control, repeat syscall 295 on Lion, then perform exactly one Lion CreateNewWindow run with the accepted NewWindow and release-backing adapters unchanged. Do not change receive size, adapt terminate-alpha, or advance to display-bounds/ShapeWindow/XNU before that live result is reviewed.


## CreateNewWindow chain closed; window-title validation next

The live opacity create-alpha integration has now closed the restored-stack CreateNewWindow construction gate. Lion converted only `0x724f -> 0x7250` in the private request copy and `0x72b4 -> 0x72b3` in the private reply copy, received native result 0, and the public `CreateNewWindow` call returned 0 with a nonzero WindowRef. Immediate `DisposeWindow` reached `M24_SUCCESS`, the process exited 0, the exact-four notification broker passed, no new crash/core diagnostic was created, and protected hashes remained unchanged.

Residual CoreGraphics diagnostics for display-bounds, ShapeWindow, backing lock/map, and display-color-space are still visible inside the successful CreateNewWindow call. They are not independently authorized targets because they no longer block the public API.

Current `main` advances to `docs/process-manager-post-createwindow-windowtitle-validation-experiment.md`. Build only the new exact-basename PPC subject, require the Snow full-stack passthrough control, repeat syscall 295, and perform one Lion run that adds only `CFStringCreateWithCString` plus `SetWindowTitleWithCFString` before release/disposal. Keep every accepted compatibility adapter unchanged; do not show/select the window, query visibility, enter the event loop, or modify XNU before this title result is reviewed.


## Window-title validation localized to FontServer bootstrap

The first post-CreateNewWindow window-title run did not reach `T03_AFTER_SetWindowTitleWithCFString`. Snow Leopard resolved ordinary `bootstrap_look_up("com.apple.FontServer")` with `kr=0` and a nonzero port and then completed `SetWindowTitleWithCFString=0`. Lion reached the same T02 boundary but the untouched Snow-PPC FontServer lookup returned `-304/MIG_BAD_ARGUMENTS` with a zero port before a later fifth distributed-notification request was rejected by the deliberately exact-four broker. Repeated FontServer retries then produced CoreText invalid-destination errors and the subject exited 138. The prior top-level notification-reject result was therefore too coarse; the runner now classifies the earlier title-specific FontServer boundary first.

Follow `docs/process-manager-post-createwindow-fontserver-bootstrap-protocol-adapter-experiment.md`. Build only the standalone PPC FontServer lookup probe on Snow, require the ordinary Snow lookup to return a nonzero port, transfer the exact hashed probe, repeat the native safety gates, and send exactly one Lion-format `0xbc` launchd lookup request for `com.apple.FontServer` with PID 0, zero UUID, and flags 0. Do not rerun SetWindowTitle, broaden the notification allowlist, accept the fifth request, or modify XNU before this standalone service/namespace result is reviewed.


## FontServer standalone lookup passed; live title integration next

The standalone `com.apple.FontServer` discriminator now passes. Snow Leopard ordinary PPC `bootstrap_look_up` returned `kr=0` with a nonzero service port. Lion accepted the exact UUID-expanded `0xbc` request with PID 0, zero UUID, and flags 0, returned complex reply ID `0x1f8`/size `0x28` with descriptor count 1 and a valid send right, produced no new diagnostic, and left protected identities unchanged. Syscall 295 remains EBADF/no-SIGSYS.

This proves the earlier title-path `com.apple.FontServer -> -304` result is another launchd request-layout mismatch. Current `main` advances to `docs/process-manager-post-createwindow-fontserver-bootstrap-compat-integration-experiment.md`. Build only the new one-tuple `cgs-session-bootstrap-dockserver-fontserver-compat-v3` interposer on Snow, require a complete Snow window-title passthrough control, then perform exactly one Lion title run with the exact FontServer service adaptation added. Keep the exact-four notification broker unchanged: if the already observed fifth notification becomes the next blocker, stop and audit that request rather than accepting it immediately. No XNU change is indicated.


## FontServer live integration passed; fifth notification audit next

The post-CreateNewWindow title run now proves the exact `com.apple.FontServer` bootstrap adaptation live: the Lion-format `0x194 / 0xbc` request returned the expected `0x1f8 / 0x28` complex reply with one descriptor and a valid send right, and the FontServer adapter reported PASS. Immediately afterward the PPC ingress received legacy notification request index 5 with `bits=0x1111`, `id=4`, `size=356`, and `payload=321`; the unchanged exact-four broker rejected it with status 25. The four reviewed registrations remained accepted, protected hashes stayed unchanged, and the title call did not return.

Follow `docs/process-manager-post-createwindow-windowtitle-fifth-distributed-notification-schema-audit.md`. Build only the new native i386 audit broker on Lion, reuse all accepted PPC/runtime artifacts unchanged, repeat syscall 295, and perform one Lion title run that accepts the same first four registrations, captures exactly the fifth request as binary plist plus XML, deliberately returns status 25, and stops. Do not add a fifth allowlist entry or change XNU before that captured schema is reviewed.


## Fifth title-path notification schema audited; exact registration next

The fifth legacy distributed-notification request exposed after live FontServer compatibility is now fully audited. It is an eight-key `register` dictionary for exact name `com_apple_CoreText_FontManagerChangedNotification`, object `kCFNotificationAnyObject`, legacy behavior `1`, counter `1`, the established client and session scope, and a positive per-process entry. The audit accepted the first four reviewed registrations, captured exactly one fifth request, intentionally returned status 25, reported zero audit failures/unexpected rejects, preserved protected hashes, and passed.

Current `main` advances to `docs/process-manager-post-createwindow-windowtitle-fifth-distributed-notification-registration-experiment.md`. Build only the new native exact-five broker on Lion, repeat syscall 295, and perform one unchanged window-title run with `lion-windowtitle-fontserver-register-v1`. Accept only the reviewed fifth name/object/behavior tuple. If a sixth request appears, reject it and stop for a new schema audit; if the title returns successfully, close the title gate and advance only to `ShowWindow`. No XNU change is indicated.


## Fifth notification accepted; FontServer RPC transport trace next

The reviewed fifth distributed-notification registration is no longer the blocker. The exact-five broker accepted `com_apple_CoreText_FontManagerChangedNotification` with `kCFNotificationAnyObject`, legacy behavior 1, counter 1, and the established session scope; it exited with `register=5 callback=0 rejects=0 exact=YES`. FontServer bootstrap compatibility also remained successful.

`SetWindowTitleWithCFString` still failed to reach T03. Repeated CoreText `CopyFontForName` and `CopyPropertiesForFontsMatchingRequest` operations reported `FFFFFED0` from FontServer. The next test is therefore not another notification change: use `docs/process-manager-post-createwindow-windowtitle-fontserver-rpc-transport-trace-experiment.md` to capture the exact first FontServer-port Mach request and reply on Snow and Lion with a passive two-tuple trace build. No FontServer RPC translation or XNU change is authorized until that differential is reviewed.


## FontServer first RPC static audit

The passive transport trace resolves the first FontServer divergence beneath the title call. Snow PPC sends `0x32c8` with authoritative `mach_msg` send/receive sizes `0x18/0x3c`, receives a complex `0x34` reply `0x332c`, and completes the title operation. Lion translated PPC sends the same first request but receives a simple `0x24` reply `0x332c` with raw status bytes `65 fd ff ff`, which correlate to `0xfffffd65` / signed `-667` under the same byte-order interpretation that turns later `d0 fe ff ff` into CoreText's reported `FFFFFED0`. Later `0x32d9` and `0x32db` requests return `-304`, but they are downstream.

The next stage is `docs/process-manager-post-createwindow-windowtitle-fontserver-first-rpc-protocol-audit.md`. Run the read-only analyzer on Snow Leopard and Lion and return the two reports. The audit must identify the Snow `0x32c8` routine, the Lion-native equivalent or setup precondition, and any binary evidence for `-667`. No live title rerun, FontServer RPC adaptation, broker widening, or XNU change is authorized before review.


## FontServer rendezvous v2 static audit

The v1 first-RPC audit passed and proved that Snow PPC's first title-path FontServer transaction is `_XTSendRendezvous` request `0x32c8` with `0x18/0x3c`, while Lion native FontRegistry has replaced that client with `_XTSendRendezvous2` and contains no raw `0x32c8` request constant in the required i386 slice. The Lion registry rendezvous path calls `_XTSendRendezvous2`; `fontd` itself links the service implementation from `libATSServer.dylib`.

The v1 tool was request-ID-seeded, so it did not emit the new Rendezvous2 body or analyze the server library. Run `docs/process-manager-post-createwindow-windowtitle-fontserver-rendezvous-protocol-v2-audit.md` next. The v2 analyzer exact-targets both rendezvous client families, the wrapper and server-port helper, all protocol-range immediates in `0x3200..0x3400`, `libATSServer` rendezvous/demux/dispatch code, and raw `-667/-304` constants. No live title run or FontServer translation is authorized until those two static reports are reviewed.


## Native Lion FontServer Rendezvous2 trace gate

The completed v2 static audit now decodes Lion i386 `_XTSendRendezvous2`: header-only request `0x32e7`, bits `0x1513`, send/receive `0x18/0x40`, reply `0x334b`, complex success size `0x38` (simple error `0x24`). The native global-registry caller requires returned protocol version `5` and nonzero rendezvous payload address/length. Snow PPC remains `_XTSendRendezvous` `0x32c8 -> 0x332c`, `0x18/0x3c`, complex `0x34`.

The corrected Lion server audit exposes zero true protocol-range immediates in `libATSServer.dylib`, so static evidence still cannot prove the server dispatch mapping or assign a semantic name to the translated legacy `-667` result. The next and only authorized stage is `docs/process-manager-post-createwindow-windowtitle-fontserver-native-rendezvous2-transport-trace-experiment.md`: one native-i386 Lion trace of the first FontServer transaction, terminated immediately after its reply. Do not rerun the translated-PPC title path or add a rendezvous adapter before review.


## Native Rendezvous2 trace correction

The first native-i386 Rendezvous2 attempt is not a protocol result. It reached the expected Lion request `0x32e7` with bits `0x1513`, `mach_msg` send/receive arguments `0x18/0x40`, and option `0x3`, but trace v1 rejected the call before IPC because it also required the pre-wrapper `msgh_size` field to equal `0x18`. Static disassembly shows the generated stub does not initialize that header word before calling `mach_msg`; the send-size argument is authoritative at this interposition layer.

Runtime `main` now carries trace v2 and revised instructions in `docs/process-manager-post-createwindow-windowtitle-fontserver-native-rendezvous2-transport-trace-experiment.md`. Rebuild and perform exactly one corrected native Lion capture. Do not advance to a rendezvous copied-buffer proof until an actual `0x334b` server reply has been observed.


## FontServer Rendezvous2 native success confirmed; local conversion proof next

The corrected native-i386 Lion capture passed: request `0x32e7`, bits `0x1513`, send/receive `0x18/0x40`, Mach success, reply `0x334b`, complex size `0x38`, descriptor count 1, protocol version `5`, and explicit payload size `0x1000`. The prior server-dispatch ambiguity is therefore closed dynamically.

Current runtime `main` advances only to `docs/process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-adapter-experiment.md`. That stage performs no Mach IPC and proves the request copy/envelope change plus the structural native-success-to-legacy-success reply conversion, including simple-error preservation. Do not integrate live FontServer translation, adapt later `0x32d9/0x32db` operations, or change XNU before the local policy proof is reviewed.


## FontServer rendezvous local policy closed; one live integration run next

The no-IPC PPC rendezvous policy proof is complete: Snow control passed, syscall 295 remained EBADF/no-SIGSYS, Lion request conversion changed only `0x32c8 -> 0x32e7` while widening only the receive argument `0x3c -> 0x40`, and the modeled native `0x334b/0x38` version-5 success was converted to legacy `0x332c/0x34` with descriptor/NDR preservation and explicit-size relocation. The modeled simple error preserved its nonzero result. No diagnostics appeared and protected hashes were unchanged.

The authoritative next gate is `docs/process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-integration-experiment.md`: one Snow passthrough title control followed by exactly one Lion title run with only the first FontServer rendezvous adapted. Keep RPC tracing active and leave all later FontServer operations unmodified for diagnosis.


## Window title gate closed; isolate ShowWindow

The live FontServer rendezvous integration is complete. Lion observed exactly one targeted FontServer RPC: legacy `0x32c8` was converted to native `0x32e7`, the native server returned complex `0x334b/0x38` with protocol version 5, and the adapter reconstructed legacy `0x332c/0x34` while preserving the descriptor, NDR, and `0x1000` explicit size. The title API then returned success, disposal completed, the exact-five notification broker remained at five accepted registrations with zero rejects, no diagnostics appeared, and protected hashes were unchanged. There was no second FontServer RPC.

Follow `docs/process-manager-post-windowtitle-showwindow-validation-experiment.md`. Reuse all accepted compatibility artifacts unchanged, build only the new ShowWindow subject, require a Snow positive control, repeat syscall 295, and run exactly one Lion discriminator containing `ShowWindow` but no `SelectWindow`, `IsWindowVisible`, timers, or event loop. A ShowWindow no-return result authorizes only a later passive trace, not an immediate compatibility rule.


## ShowWindow sixth-request boundary

The new `cps-showwindow-validation-v1` subject passes its Snow control completely. In the first Lion discriminator, the accepted chain remains intact through CreateNewWindow, FontServer bootstrap/rendezvous compatibility, the fifth reviewed notification registration, and `SetWindowTitleWithCFString=0`. After `S00_BEFORE_ShowWindow`, a sixth ingress request appears with `bits=0x1111`, `id=4`, size 320 and payload 287; the exact-five broker returns status 20, `S01_AFTER_ShowWindow` is not reached, the process exits 139, and the runner names crash/core diagnostics while protected hashes remain unchanged.

Follow `docs/process-manager-post-windowtitle-showwindow-sixth-distributed-notification-schema-audit.md`. Build only the new Lion-native audit broker, reuse the ShowWindow subject and all accepted compatibility unchanged, repeat syscall 295, capture exactly the sixth request as binary plist plus XML, preserve the observed status-20 rejection, and stop. Status 20 is only a current-schema rejection; it does not justify assuming that the sixth payload is another eight-key registration. Keep SelectWindow, visibility queries, timers, event-loop work, new CGS adapters, and XNU changes held.


## Exact sixth ShowWindow registration gate

The sixth-request audit passed with one capture, zero audit failures/unexpected rejects, unchanged protected hashes, and the expected status-20 intentional stop. The payload is an ordinary eight-key `register` for `AppleAquaColorVariantChanged`, `kCFNotificationAnyObject`, behavior 4, `counter=2`, the established client/session form, and a positive entry distinct from the earlier request-4 registration. The prior ABI audit already requires the bridge to preserve a separate `entry/counter` identity per registration record.

Follow `docs/process-manager-post-windowtitle-showwindow-sixth-distributed-notification-registration-experiment.md`. The new exact-six broker accepts only the observed sequence and allows the reviewed Aqua-variant tuple a second time only at request 6 with counter 2 and a unique entry. Repeat syscall 295 and perform one unchanged Lion ShowWindow run. If a seventh notification request is rejected, audit it before broadening policy; if the six registrations are established but `S01_AFTER_ShowWindow` is still absent, advance only then to a passive ShowWindow-side CGS/window-context trace. No XNU change is indicated.


## ShowWindow passive CGS transport discriminator

The exact-six registration gate passed: request 6 was accepted as the reviewed Aqua-variant registration with counter 2, the broker reported six exact registrations and zero rejects, no seventh notification request appeared, and protected hashes remained unchanged. Nevertheless `S01_AFTER_ShowWindow` is still absent, the PPC process exits 139 with crash/core diagnostics, and the ShowWindow interval repeats `CGSAddTrackingArea` MIG server type-check failure alongside the known color-profile/window-context errors.

Follow `docs/process-manager-post-windowtitle-showwindow-cgs-passive-transport-trace-experiment.md`. Build only the new PPC trace dylib on Snow Leopard, require the unchanged ShowWindow Snow control to pass while producing matched unknown-CGS request/return records inside S00-to-S01, then run exactly once on Lion with `lion-showwindow-sixth-register-v1` and `ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1`. Compare Snow and Lion transport evidence before authorizing any request/reply conversion. No seventh notification policy, direct CGS adaptation, or XNU change is part of this gate.


## ShowWindow CGSAddTrackingArea static protocol gate

The passive trace is behavior-preserving on Snow and localizes one exact Lion server-side generated-MIG rejection. Snow's ShowWindow window contains six matched unknown-CGS transactions and reaches S01; Lion contains four matched transactions and still stops before S01. The legacy `0x7388 / 0x73ec` request has the same `0x1513`, `0x60 / 0x2c` geometry in both traces, but Snow returns result 0 and Lion returns `-304`, immediately followed by `CGSAddTrackingArea` server type-check failure.

Follow `docs/process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-protocol-audit.md`. Syntax-check and run `scripts/audit-process-manager-showwindow-cgs-add-tracking-area-protocol.py` statically on Snow Leopard 10.6.8 PPC7400 and then Lion 10.7.5 i386. Return only the two generated reports. Do not launch translated PPC, add a live adapter, broaden to the neighboring `0x72e7` or `0x72f2` failures, modify the color-profile/window-context path, or change XNU during this gate.


## ShowWindow CGSAddTrackingArea exact compatibility gate

The static protocol gate passed on Snow Leopard PPC7400 and Lion i386. The live inline helper is a narrow generated-MIG ID shift: Snow `0x7388 / 0x73ec`, Lion `0x738e / 0x73f2`, with matching `0x1513` bits, option `0x3`, `0x2c` receive size, `0x24` reply size, and `0x3c + 4*count` send geometry. The observed ShowWindow request has count 9 and send size `0x60`. The separate Lion non-inline tracking-area routine is not authorized for adaptation.

Follow `docs/process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-integration-experiment.md`. Build only the new PPC compatibility dylib on Snow Leopard, run the behavior-preserving Snow passthrough control, repeat syscall 295 on Lion, then run exactly one Lion integration with `ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1` and the existing unknown-CGS passive trace still enabled. Require a one-byte request-ID change `0x7388 -> 0x738e`, exact native reply `0x73f2`, one-byte PPC-facing reply-ID change to `0x73ec`, and unchanged payload/result. If ShowWindow still does not return, review the remaining trace before authorizing any other CGS conversion. No XNU change is part of this gate.


## Tracking-area integration passed; post-tracking protocol attribution

The exact `CGSAddTrackingAreaInline` integration is proven: Snow passthrough completes ShowWindow and Lion's count-9 request is converted from `0x7388` to native `0x738e`, receives native `0x73f2 / result 0`, and is returned to PPC as `0x73ec / result 0` with no body changes. The tracking-area MIG type-check failure disappears.

Lion still stops inside ShowWindow with `S01` absent and exit 139. The remaining post-`S00` trace is `0x72e7 -> 0x734b = -304`, successful tracking conversion, `0x7268 -> 0x72cc = 0`, then `0x72f2 -> 0x7356 = -304`. Repeated color-profile/window-context initialization errors bracket these requests and begin before the first failing RPC. The next gate is therefore static attribution, not another adapter: run `scripts/audit-process-manager-showwindow-post-tracking-cgs-protocol.py` once on Snow Leopard 10.6.8 and once on Lion 10.7.5 according to `docs/process-manager-post-windowtitle-showwindow-post-tracking-cgs-protocol-audit.md`, then return only the two reports. Do not adapt either failing ID, the earlier `CGSShapeWindow` rejection, or the color-profile path until that differential is reviewed.


## ShowWindow OrderFrontConditionally exact compatibility gate

The post-tracking static audits passed and resolve the two remaining ShowWindow `-304` replies to generated-MIG release skews. The first is `__CGSOrderFrontConditionally`: Snow PPC uses `0x72e7 / 0x734b`, while Lion i386 uses `0x72ea / 0x734e`; request bits `0x1513`, option `0x3`, send `0x34`, receive `0x2c`, NDR plus five 32-bit scalars, and simple `0x24` reply geometry are equivalent. The later `__CGSSetFrontWindow` transaction is independently proven as Snow `0x72f2 / 0x7356` versus Lion `0x72f5 / 0x7359`, with matching `0x24 / 0x2c` request/receive geometry, but it is not authorized for adaptation yet.

The next live gate is `docs/process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat-integration-experiment.md`. Build only the new combined PPC dylib, run a behavior-preserving Snow passthrough control, repeat syscall 295, then make exactly one Lion run that rewrites only `0x72e7 -> 0x72ea` and native reply `0x734e -> 0x734b`. Require the existing tracking-area adapter and all upstream compatibility layers to remain unchanged. If ShowWindow still does not return, review the continuing trace before deciding whether the separately proven SetFrontWindow shift is now the next boundary.


## ShowWindow SetFrontWindow exact compatibility gate

The OrderFrontConditionally integration passed on Lion, then AddTrackingArea passed unchanged, `0x7268 / 0x72cc` succeeded natively, and the next nonzero-window `0x72f2 / 0x7356` request returned `-304` before ShowWindow could return. The prior static audit identifies that exact request as `__CGSSetFrontWindow`: Snow PPC uses `0x72f2 / 0x7356`, Lion i386 uses `0x72f5 / 0x7359`, and both use bits `0x1513`, option `0x3`, send `0x24`, receive `0x2c`, NDR plus one 32-bit window ID, and a simple `0x24` result reply.

The next live gate is `docs/process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat-integration-experiment.md`. Build only the new combined PPC dylib on Snow Leopard, require a strict passthrough control, repeat syscall 295 on Lion, then make exactly one Lion run adapting only the first nonzero-window SetFrontWindow request `0x72f2 -> 0x72f5` and native reply `0x7359 -> 0x7356`. Preserve the later zero-window disposal request, ShapeWindow, color-profile/window-context, and all other CGS behavior unchanged.


## Experiment-document command completeness

Every authoritative experiment document must contain the actual commands needed for the current stage. Do not tell the reader to “run the existing runner,” “repeat the probe,” or refer to an older experiment for the invocation details.

Keep those commands portable and proportional:

- use a small number of path variables such as `RUNTIME`, `ROSETTA_XNU`, and `XNU_SRC` rather than hard-coding one user's absolute checkout paths; after `cd "$RUNTIME"`, prefer repo-relative `./...` paths for runtime-local payloads and resources so an unset or differently defined path variable cannot turn them into unintended root-level paths;
- use shell builtins such as `[ ... ]` when a guard is useful; do not depend on a separate `/usr/bin/test` binary;
- include the complete build command and complete runner command with every positional argument required by the current stage;
- include all stage-specific `unset` and `export` settings that materially affect behavior;
- include the syscall-295 command and kernel-hash gate when that preflight is part of the stage;
- name every expected output/report and every artifact that must be returned;
- state exact stop conditions and result markers;
- avoid redundant file-existence checks, repeated diagnostics, and long machine-specific transfer commands that do not improve the experiment's correctness;
- where transport between machines is inherently site-specific, list the exact files and required destination rather than pretending one transfer command is universal.

The current authoritative document must be self-contained for build and execution logic, but it should not become a machine-specific transcript.


## ShowWindow color-profile/window-context static gate

The SetFrontWindow compatibility conversion passed exactly on Lion: `0x72f2 -> 0x72f5`, native `0x7359 / result 0`, PPC-facing `0x7356 / result 0`, with no body changes. OrderFrontConditionally, AddTrackingArea, and the unchanged `0x7268 / 0x72cc` transaction also passed. ShowWindow still does not return, and no later application-CGS transport mismatch is observed.

The remaining first-order evidence is the repeated CoreGraphics color-profile/window-context failure, which predates OrderFrontConditionally and persists after SetFrontWindow succeeds. Run only `docs/process-manager-post-windowtitle-showwindow-color-profile-window-context-audit.md` next. Generate one static report on Snow Leopard PPC7400 and one on Lion i386 using the prepared analyzer; do not launch the PPC subject or add a color-profile, CoreUI, RawCamera, ShapeWindow, or XNU compatibility rule until those reports are reviewed.


## ShowWindow ColorProfileClient live discriminator

The static Snow/Lion CoreGraphics audit passed and proves an exact generated-MIG ColorProfileClient protocol differential: Snow PPC `0x74d4 / 0x7538`, Lion i386 `0x74d6 / 0x753a`, with otherwise matching `0x80001513` request bits, `0x34 / 0x30` send/receive geometry, one port descriptor, NDR/PID layout, and `0x28 / 0x24` success/error replies. Caller control flow proves that failure of this helper is the source of the observed color-profile-client initialization error.

Follow `docs/process-manager-post-windowtitle-showwindow-color-profile-client-live-trace-experiment.md`. Build the target-only passive tracer on Snow, require the legacy `0x74d4` call to return `0x7538 / result 0` with a nonzero client ID while ShowWindow still passes, repeat syscall 295, then run Lion exactly once. The leading expected discriminator is a legacy `0x74d4` transaction returning a simple `0x7538 / -304` error without any `0x74d6` request. Do not implement the statically indicated `+2` adapter until that live result is confirmed.


## ShowWindow ColorProfileClient live boundary confirmed; exact adapter next

The target-only live trace confirms the static generated-MIG differential. Snow PPC sends the exact `0x74d4` ColorProfileClient request before its NewWindow RPC and receives `0x7538 / 0x28` with result 0 and a nonzero client ID, after which the full control completes. Lion sends the same exact legacy request four times on the separate CGS server-port path; Mach transport succeeds each time, but each reply is `0x7538 / 0x24` with raw `0xd0feffff` (legacy-visible `-304`) and no client ID. The first two Lion failures occur immediately after `S00_BEFORE_ShowWindow`, before OrderFrontConditionally/AddTrackingArea/SetFrontWindow, and two retries follow those accepted adapters. No `0x74d6` request is emitted. The failures align directly with the recurring color-profile-client and window-context diagnostics, while every accepted upstream adapter, the exact-six broker, and protected hashes remain intact.

Current `main` advances to `docs/process-manager-post-windowtitle-showwindow-color-profile-client-compat-integration-experiment.md`. Build the compatibility-capable PPC dylib on Snow Leopard, require the new mode to remain strict passthrough there, repeat syscall 295 on Lion, and perform exactly one Lion run with `ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=lion-id-v1`. The rule is gated to the first exact Lion S00 ColorProfileClient call (NewWindow/release/create-alpha counts 1; OrderFront/AddTrackingArea/SetFrontWindow counts 0), changes only request ID `0x74d4 -> 0x74d6` in a private copy and native reply ID `0x753a -> 0x7538`, and preserves descriptor, PID, request body, result, and returned client-ID bytes. Do not synthesize a client ID, broaden to later rendering failures, alter ShapeWindow, or change XNU.


## ColorProfileClient Snow control v1 harness defect; rebuild v2

The first compatibility-capable Snow control did not expose a Snow behavior regression. The real legacy ColorProfileClient transaction remained successful (`0x74d4 -> 0x7538/0x28`, result 0, nonzero client ID), ShowWindow returned, disposal reached M24, and the subject exited 0. The final `RESULT: FAIL` came from the v1 compatibility recognizer reporting `exact=NO` while the passive trace reported the same request `exact=YES`. V1 had incorrectly required the application-CGS port to have already been learned from CreateNewWindow even though Snow performs its successful ColorProfileClient initialization before that CreateNewWindow call.

Current `main` uses ColorProfileClient compatibility build v2. Structural `exact` now matches the proven passive-trace geometry; Lion-only non-application-port provenance is a separate `lionPortExact` gate and is still mandatory before adaptation. Snow must report `exact=YES lionPortExact=NO applicationPort=0x00000000`; Lion must report `exact=YES lionPortExact=YES` with a nonzero learned application port. Pull current runtime `main`, rebuild Phase B, and repeat Phase C. Do not reuse a v1 dylib or proceed to Lion until the rebuilt Snow control passes.


## ColorProfileClient adapter passed; ResolveColorProfile audit next

The rebuilt v2 Snow control passed, syscall 295 remained on the accepted EBADF/no-SIGSYS path, and the single Lion ColorProfileClient compatibility run passed its exact adapter. The first legacy `0x74d4` request was converted only to native `0x74d6`; Lion returned `0x753a / 0x28`, result 0, with a nonzero client ID; the PPC-facing reply was changed only back to `0x7538`. There was exactly one ColorProfileClient call and no retry.

The failure has advanced from client initialization to profile resolution. Immediately after the successful ColorProfileClient reply, Lion now reports `CGSColorProfileCreateWithColorProfileID: Cannot resolve color profile id(1)`, followed by the invalid-profile/window-context cascade. OrderFrontConditionally, AddTrackingArea, the unchanged `0x7268 / 0x72cc` call, SetFrontWindow, the exact-six broker, and protected hashes remain intact, but `S01_AFTER_ShowWindow` is still absent and the process exits 139.

Current `main` advances to `docs/process-manager-post-windowtitle-showwindow-color-profile-resolve-protocol-audit.md`. Run only the new read-only Snow-PPC/Lion-i386 CoreGraphics resolver audit and return its two reports. Do not broaden the ColorProfileClient adapter, add a ResolveColorProfile rewrite, force profile ID 1, work around CGWindowContext/CoreUI/RawCamera, revisit ShapeWindow, or change XNU before reviewing that differential.


## ResolveColorProfile static differential complete; passive live trace next

The Snow PPC and Lion i386 resolver audits both pass. `__CGSResolveColorProfile` is the same generated-MIG shape on both systems except for a +2 routine-ID shift: Snow uses `0x74d7 / 0x753b`, Lion uses `0x74d9 / 0x753d`; both use `0x80001513`, option `0x3`, `0x38 / 0x3c` send/receive sizes, one port descriptor, and `0x34 / 0x24` success/error replies. The server stubs and resolve routines preserve the same live-relevant client/task/profile lookup path, so the static evidence isolates a plausible generated-MIG boundary but does not by itself prove the live PPC request is rejected before server semantics.

Current `main` advances to `docs/process-manager-post-windowtitle-showwindow-color-profile-resolve-live-trace-experiment.md`. Phase B now uses the abbreviated artifact name `pm-cpc-compat-cpr-trace.dylib` (CPC = ColorProfileClient, CPR = ColorProfile Resolve) so the dylib and its `.info.txt` / `.sha256` sidecars remain safely below legacy filename limits. Build the prepared passive resolver tracer on Snow Leopard, require the successful Snow `0x74d7 -> 0x753b` control and full ShowWindow PASS, repeat syscall 295, then make exactly one Lion run with the accepted ColorProfileClient adapter unchanged. Do not add a ResolveColorProfile adapter, force profile ID 1, broaden into CGWindowContext/CoreUI/RawCamera, revisit ShapeWindow, or change XNU until the live resolver request/reply is reviewed.


## ResolveColorProfile live skew proven; ID-only compatibility next

The passive resolver experiment completes the live discriminator. Snow's legacy resolver uses `0x74d7 / 0x753b`; its earlier profile-ID-2 request and later target profile-ID-1 request both return `0x34` success replies with result zero, and the full Snow control reaches M24 and PASS. The profile-ID-2 request appears as `exact=NO` only because the target passive predicate intentionally requires profile ID 1; its wire geometry is otherwise the same and it succeeds.

The Lion syscall-295 probe remains healthy. In the single Lion run, the accepted ColorProfileClient adapter succeeds once; the native client ID decodes to semantic value 55, which is exactly the client ID carried by the following profile-ID-1 resolver request. Each of four exact legacy `0x74d7` resolver calls completes Mach transport but receives `0x753b / 0x24` with raw `0xd0feffff` (-304). This live-proves the generated-MIG resolver ID skew predicted by the static audit; it does not support forcing profile state.

Current `main` advances to `docs/process-manager-post-windowtitle-showwindow-color-profile-resolve-compat-experiment.md`. The prepared test adapter is ID-only: private-copy request `0x74d7 -> 0x74d9`, native reply `0x753d -> 0x753b`, with request/reply bodies preserved. It additionally requires provenance from the successful ColorProfileClient transaction and is capped at the four target calls observed in the passive baseline. Run the documented Snow passthrough control, syscall-295 preflight, and exactly one Lion compatibility run. Keep `CGSReleaseColorProfile`, profile synthesis, CGWindowContext/CoreUI/RawCamera workarounds, ShapeWindow, and XNU changes held.


## ResolveColorProfile compatibility passed; backing-lock audit next

The Snow resolver-compatibility passthrough control passes, the Lion syscall-295 probe remains healthy, and the single Lion ResolveColorProfile compatibility run satisfies its exact provenance gate. ColorProfileClient succeeds once and yields semantic client ID 57; the following profile-ID-1 resolver request carries the same client ID and captured ports. The adapter changes only `0x74d7 -> 0x74d9`; Lion returns native `0x753d / 0x34 / result 0`; the PPC-facing reply changes only `0x753d -> 0x753b`, with zero request/reply body changes. The prior color-profile resolution and window-context-creation diagnostic cascade disappears.

ShowWindow still does not return. The next repeated live failure is the existing `0x7263 / 0x72c7` transaction: Mach transport succeeds and its `0x34` reply reports result zero, but CoreGraphics immediately reports `_CGSBindWindowBacking: cannot map backing data shmem` and `_CGSLockWindow: Unable to lock window`. Snow uses the same observed IDs and geometry without that failure and reaches S01/M24/PASS. The later seventh notification registration rejection occurs only after several backing-map failures and remains held.

Current `main` advances to `docs/process-manager-post-windowtitle-showwindow-window-backing-lock-protocol-audit.md` using `scripts/audit-process-manager-showwindow-window-backing-lock-protocol.py`. Run only the new read-only Snow-PPC/Lion-i386 CoreGraphics audit and return its two reports. Do not adapt `0x7263`, broaden the resolver adapter, add `CGSReleaseColorProfile`, expand the exact-six broker, force backing mapping, revisit ShapeWindow, or change XNU before that differential is reviewed.


## WindowBackingInfo routine collision proven; one-call ID compatibility next

The read-only Snow-PPC/Lion-i386 backing-lock audits both pass and isolate a one-slot generated-MIG collision. Snow uses `__CGSGetWindowInfo 0x7262/0x72c6` and `__CGSGetWindowBackingInfo 0x7263/0x72c7`; Lion shifts those same helpers to `0x7263/0x72c7` and `0x7264/0x72c8`, respectively. The backing-info helper keeps the same bits `0x1513`, option `0x3`, `0x24/0x3c` send/receive geometry, one window-ID scalar, and `0x34/0x24` reply shape with result plus two output pairs. Lion therefore accepts the legacy PPC `0x7263` as the wrong routine, `GetWindowInfo`, which explains the live result-zero reply followed by invalid backing-shmem mapping.

Current `main` advances to `docs/process-manager-post-windowtitle-showwindow-window-backing-info-compat-experiment.md`. The prepared adapter is limited to the first exact application-port backing-info call and changes only `0x7263 -> 0x7264` and native `0x72c8 -> 0x72c7`; the window ID, NDR, result, and both output pairs remain byte-for-byte unchanged. Run the documented Snow passthrough control, syscall-295 preflight, and exactly one Lion compatibility run. Do not raise the one-call cap, rewrite shared-memory outputs, expand the exact-six broker, revisit ShapeWindow, or change XNU before reviewing that run.


## WindowBackingInfo compatibility passed; seventh notification audit next

The Snow WindowBackingInfo passthrough control passes through ShowWindow, disposal, and M24; the syscall-295 preflight remains accepted; and the single Lion compatibility run meets the exact one-call gate. The request changes only `0x7263 -> 0x7264`; native Lion returns `0x72c8 / 0x34 / result 0`; the PPC-facing reply changes only `0x72c8 -> 0x72c7`. No request/reply body bytes are changed, and the prior backing-data-shmem/`_CGSLockWindow` failure pair no longer occurs. ColorProfileClient and ResolveColorProfile remain successful later in the same run.

The next live boundary is notification request 7 with bits `0x1111`, ID 4, message size 356, and binary-plist payload 322. The exact-six broker rejects it with status 25 / name reject. This is insufficient evidence to authorize a seventh allowlist entry.

Proceed only with `docs/process-manager-showwindow-seventh-notification-schema-audit.md`: build the native `dn-showwindow-7-schema-audit-broker`, rerun syscall 295, then make exactly one Lion capture with exact-six policy and all accepted adapters unchanged. Require exactly one seventh capture and the deliberate status-25 reject, return the binary/XML report, and stop. Do not broaden the broker, modify WindowBackingInfo outputs, revisit ShapeWindow, work around RawCamera/CoreUI, or change XNU in that stage.


## Seventh notification audited; exact-seven registration next

The seventh-request schema audit passes exactly once with the accepted ShowWindow compatibility stack intact. The captured request is an ordinary eight-key `register` dictionary for exact name `com.apple.ColorSync.DisplayProfileNotification`, object `kCFNotificationAnyObject`, legacy behavior `4` (the already reviewed Coalesce mapping), counter `1`, a positive per-run entry, and the established client/session scope. The audit preserves status 25 rather than accepting the unreviewed tuple, reports one capture with zero failures/unexpected rejects, and keeps the first six registrations exact. WindowBackingInfo, ColorProfileClient, ResolveColorProfile, and FontServer rendezvous remain PASS; the backing-map/`_CGSLockWindow` failures remain absent; protected hashes remain unchanged.

Current `main` advances to `docs/process-manager-showwindow-seventh-notification-registration.md`. Build only the short native `dn-showwindow-7-registration-broker`, repeat syscall 295, and perform exactly one Lion run with all accepted ShowWindow compatibility modes unchanged. Accept only the reviewed seventh ColorSync tuple. Any eighth request remains rejected and becomes a new schema-audit boundary; if no eighth request appears but ShowWindow still does not return, preserve the first later diagnostic and crash/core evidence before choosing another compatibility boundary. Do not revisit ShapeWindow, modify backing/color-profile adapters, work around RawCamera/CoreUI, or change XNU in the same stage.


## Exact-seven notification passes; preserved ShowWindow crash postmortem next

The exact-seven distributed-notification run accepts `com.apple.ColorSync.DisplayProfileNotification` as reviewed request 7 and finishes `register=7 callback=0 rejects=0 exact=YES` with broker PASS. No eighth request appears. WindowBackingInfo, ColorProfileClient, ResolveColorProfile, and the existing upstream stack remain healthy; the former backing-map/`_CGSLockWindow` failure is still absent. `ShowWindow` nevertheless terminates before `S01_AFTER_ShowWindow`, with exit status 139 and three immediate CoreUI `Invalid ArtFile Path!` diagnostics after request 7. The returned SetFrontWindow-predicate result is a runner-ordering artifact: AddTrackingArea, OrderFrontConditionally, and SetFrontWindow are not reached before this termination, so their prior accepted proofs remain unchanged.

Current `main` advances to `docs/process-manager-showwindow-post-dn7-postmortem.md`. Do not rerun the PPC subject or rebuild the broker. Use the new read-only `scripts/collect-lion-dn7-showwindow-core.sh` against the preserved `/cores/core.89664` and matching 23:59:58 crash report, then return `lion-dn7-postmortem.txt`, `lion-dn7-crash.bin`, and its SHA sidecar. The postmortem must decide whether CoreUI/theme rendering, RawCamera/ImageIO, another PPC framework path, or the Rosetta host is actually faulting before any new compatibility rule is prepared. XNU remains unchanged.


## Exact-seven crash localizes to CoreUI theme-art path

The preserved exact-seven ShowWindow crash has now been postmortemed without another PPC run. The collector passed all GDB stages and the 512-byte crash window hashes to `17010dbf591b2c3b6dbdbd5d9912ce75b27ce69e09b7f5c12b5079ff0a6fefe1`. The failure is `EXC_BAD_ACCESS (SIGSEGV)` at `0x787221c4`. The PPC stack localizes the fault to `vfprintf <- fprintf <- CoreUI::ShowArtFilePathToStdErr <- CUIElement::LoadFromArtFile <- CUIElement::Load <- CUIRenderer`, entered from HIToolbox titlebar-button drawing during `ShowWindow`. The translated host instruction at `EIP=0x8bea0843` loads through `ECX=0x787221c4`, matching the fault address. RawCamera is absent from the preserved postmortem and remains held.

Current `main` advances to the read-only `docs/pm-showwindow-coreui-theme-audit.md` using `scripts/audit-pm-showwindow-coreui-theme.py`. Run the analyzer once on Snow Leopard and once on Lion, returning `pm-coreui-snow.txt` and `pm-coreui-lion.txt`. Do not rerun the PPC subject, suppress the CoreUI diagnostic, copy Snow theme resources, modify RawCamera, revisit ShapeWindow, or change XNU until the CoreUI/HIToolbox code/resource differential is reviewed.


## Rosetta CoreUI code/resource mismatch proven; ArtFile contract audit next

The Snow/Lion static differential now proves that the Rosetta shared cache and cache map are identical on both systems while Snow's on-disk CoreUI/HIToolbox still contain PPC slices and Lion's do not. The preserved Lion crash addresses map exactly to Snow PPC CoreUI/HIToolbox symbol offsets at fixed bases, so the failing Rosetta process is executing Snow-era PPC framework code from the unchanged cache while consuming Lion-era CoreUI resources. The resource generation changed sharply: Snow has legacy `ArtFile.bin`/`SArtFile.bin` plus the UI recipe tree, whereas Lion adds a large `ArtFile200.bin`, changes both legacy archive sizes/hashes, and removes that recipe tree. The CoreUI helper contract also changed from `ShowArtFilePathToStdErr(unsigned char const*)` plus one `ArtFileSetupOnce()` to an `ArtFileInfo*`-aware helper with separate ArtFile10/ArtFile20 setup.

Current `main` advances to the read-only `docs/pm-showwindow-coreui-artfile-audit.md` using `scripts/audit-pm-coreui-artfile.py`. Run it once on Snow Leopard and once on Lion and return `pm-art-snow.txt` and `pm-art-lion.txt`. Do not rerun the PPC subject or substitute Snow CoreUI resources until the targeted report identifies the exact archive/key/path contract that fails.


## ArtFile static audit closes literal-key search; preserved core decode next

The targeted Snow/Lion ArtFile audit now shows that the visible `west...scrollbars` diagnostics are synthesized from component IDs rather than stored as literal archive strings. The exact dotted strings occur zero times in the audited ArtFile/SArtFile resources, while component names such as `colorsrgb`, `scrollbars`, and `titlebarcontrols` are present. The old Snow-PPC diagnostic helper decodes path bytes through global archive tables; Lion's native helper instead takes an `ArtFileInfo*`, supports separate ArtFile10/ArtFile20 setup, and applies per-archive validation. The static reports do not yet prove that `ArtFile200.bin` participates in the crashing call.

Current `main` advances to `docs/pm-showwindow-art-core.md` using `scripts/collect-pm-art-core.py`. It analyzes only the preserved exact-seven core and Lion's current `ArtFile.bin`, recovers the old PPC CoreUI global archive pointers and the active `CUIElement::Load` path buffer, and emulates the old component lookup to identify the exact crash-time path/table result. Do not rerun the PPC subject or substitute Snow resources.


## Preserved ArtFile decode proves the exact titlebar component-table overrun

The preserved exact-seven core decode proves that Snow-PPC CoreUI consumed Lion's legacy `ArtFile.bin` and that the active Snow titlebar path `a6 16 1f 7a b6 00 00 00` drives the old unchecked component lookup beyond Lion's shorter component table. Snow component `0xb6` is valid `zoom`; Lion's table ends at `0xa9`, so the old helper reads string-pool bytes as an offset and computes the exact bad pointer preserved in the crash.

The component dictionary audit then proves a full semantic namespace shift rather than an isolated terminal-token mismatch. The titlebar prefix/state/variant components are all reindexed between Snow and Lion, so a one-byte `b6->a9` patch is rejected.

## Titlebar path-builder and emitted-state surfaces proven

The corrected path-builder audit proves Snow's titlebar branch uses inline `AppendState` while Lion uses `AppendWindowTitlebarButtonState`. The semantic prefix components and `AppendWindowVariant` outputs correspond by name, but raw IDs and raw window-variant selectors differ by release.

The corrected semantic-state analyzer v3 then proves the emitted-state surfaces and input provenance. Snow uses primary state from arg5/descriptor+`0x18`, has no dedicated titlebar-secondary input, and emits `active`, `disabled`, `inactive`, `key`, `pressed`, and `rollover` but not `activenokey`. Lion uses primary state from arg5/descriptor+`0x28`, additionally passes descriptor+`0x2c` to the dedicated titlebar-state helper, and can emit the shared Snow states plus `activenokey`.

## Titlebar state transition correspondence proven

The completed transition audit passes on Snow Leopard 10.6.8 and Lion 10.7.5. Under Lion's neutral/other dedicated titlebar-secondary class, the complete Snow primary range maps exactly by `Lion primary = Snow primary + 0x0a`:

```text
a3->ad  a4->ae  a5->af  a6->b0
a7->b1  a8->b2  a9->b3  aa->b4
```

For each pair, `regularwin`, `variant1`, and `variant2` produce the same semantic output. Lion's additional secondary classes remain additive state distinctions; they do not invalidate the neutral mapping. Because Snow resolves the titlebar state into the final eight-byte path before the old `LoadFromArtFile` consumer sees it, descriptor-state reconstruction is not required for an exact path-key compatibility policy.

## Translated Lion ArtFile path feasibility proven

The Snow positive control passes with all three source keys as direct index hits. Lion also passes the feasibility gate: each untranslated Snow key has zero Lion index hits, while each semantic-equivalent Lion key has exactly one direct hit with a valid payload reference.

```text
clear  a613161f7a000000 -> 9914172272000000
minus  a6161f567a000000 -> 9917225572000000
zoom   a6161f7ab6000000 -> 99172272a9000000
```

This closes the question of whether the three exact crash-time semantics exist in Lion's legacy ArtFile. It does not yet authorize live CoreUI interception.

## Exact-three-key policy proof passed

Both returned reports satisfy the complete static policy contract. Snow records `guard_enabled=NO`, one source-index hit for each Snow key, 6,120 near-miss cases with zero failures, zero changed local index records, and passing idempotence. Lion records `guard_enabled=YES`, zero untranslated-source hits, exactly one valid semantic target for each of clear/minus/zoom, the same 6,120/0 near-miss result, zero changed local index records, and passing idempotence.

## Bsearch integration boundary proven

Both returned reports pass. Snow proves the old PPC `CUIElement::Load -> LoadFromArtFile` edge is a direct internal branch and the ArtFile search reaches libSystem `bsearch` through exactly one undefined lazy-bound external stub with the expected argument setup and comparator. Lion proves the identical Rosetta-cache contract and the accepted 10.7.5 / 11G63 ArtFile environment. The narrow process-local boundary is therefore libSystem `bsearch`, not `LoadFromArtFile` or the diagnostic/stdio path.

## Current step — audit all eight remaining Lion registrations in one run

The first request-14-only Phase E stopped before PPC subject launch with `ERROR: broker build marker missing`; the raw log was empty. The broker itself was valid i386 with a matching SHA sidecar. The failure was a runner control-flow bug: the request-14 validation block split the broker-selection chain, allowing the exact-seven base branch to overwrite the request-14 audit build ID. The runner is fixed.

The prior exact-thirteen run already established eight remaining registration-path requests, indexes 14–21, with stable transport geometries. Rather than repeat eight audit/accept pairs, follow `docs/process-manager-post-runapplicationeventloop-remaining-notifications-schema-audit.md`. The new broker preserves exact registrations 1–13, captures all eight requests 14–21 into one audit report, and deliberately rejects every captured request. After all eight plists are reviewed, a combined exact requests-14–21 policy may be prepared if their schemas and session/counter semantics permit it. No bulk acceptance is authorized before that review; XNU, timer removal, UPP disposal, compatibility broadening, and titlebar broadening remain held.


## Current step — rerun the original Carbon GUI smoke under the completed restored stack

The exact remaining notification tail, `RemoveEventLoopTimer()`, and `DisposeEventLoopTimerUPP()` are now live-proven on Lion. The final UPP-disposal integration preserved the exact-21 broker, all accepted compatibility/titlebar gates, no-new-diagnostic requirement, and protected hashes through full cleanup.

The next controlled step is `docs/ppc-carbon-gui-restored-stack-retest.md`. It uses the exact historical Snow-positive Carbon GUI smoke executable SHA-256 `fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067`—the same binary that originally aborted on Lion before its first application marker—and runs it exactly once with the complete accepted restored stack. This is an end-to-end regression closure, not another isolated API experiment. Do not rebuild or instrument the historical subject, broaden notification/titlebar/CGS compatibility, test LaunchServices/Finder/Cocoa/another PPC application, or change XNU before this result is reviewed.


## Current step — exact historical Carbon smoke CPS registration

The original Snow-positive Carbon GUI smoke subject now reaches both application markers and exits 0 on Lion, but no window was visually observed. The restored-stack trace localizes the immediate discrepancy to application registration: the historical subject sends legacy CPS CheckInApplication with `send=0x68` and NUL-inclusive process-name length `0x26`; the accepted Process Manager registration predicate is pinned to the longer validation basename/request, so it reports `exact=NO`, passes through, and Lion returns `-304/MIG_BAD_ARGUMENTS`. The process appears in the Dock but is not successfully registered with CPS/CoreGraphics.

Follow `docs/ppc-carbon-gui-cps-registration-integration.md`. Build the dedicated full-stack PPC compatibility artifact on Snow Leopard and perform exactly one Lion run using the exact historical smoke binary. This stage adds only the exact `ppc-carbon-gui-smoketest-private-dyld` CPS-registration predicate (`0x68 -> 0x74`, legacy ID `0x7372 -> 0x73c1`) and requires a native success reply translated back to `0x73d6`. Keep the Process Manager-bound exact-21 notification broker unchanged and deliberately expect its 21 schema-status-20 rejects; notification acceptance, titlebar broadening, LaunchServices/Finder/Cocoa, and XNU remain held.


## Current step — exact historical Carbon GUI notification client

The dedicated historical-client CPS registration integration now passes completely: the original `0x68` CheckInApplication request matches exactly, native Lion CreateApplication returns result zero, the reply is translated back to the legacy ID, the prior `-304` registration failure is absent, and every other accepted CGS/titlebar gate remains stable. The application still exits 0 after both historical markers, but no Carbon GUI window is visually observed.

The remaining deliberately held difference is the distributed-notification broker's client identity. Follow `docs/ppc-carbon-gui-notification-registration-integration.md`. It builds one dedicated i386 broker whose only intended policy change is `EXPECTED_CLIENT="ppc-carbon-gui-smoketest-private-dyld"`; the exact 21 reviewed names, objects, behaviors, counters, sequence, and callback policy remain unchanged. If the original client matches that reviewed sequence, require `register=21 callback=0 rejects=0 exact=YES` / broker `PASS`; otherwise stop without broadening. Titlebar/CGS policy, LaunchServices/Finder/Cocoa, and XNU remain held.


## CGSShapeWindow static protocol audit complete; current step — one exact inline ID compatibility integration

Both read-only reports pass. Snow PPC uses __CGSSetWindowShapeInline request/reply 0x724d/0x72b1 with bits 0x1513, option 0x3, send size 0x2c+4*count, receive size 0x2c, count limit 0x1000, and a 0x24 reply. Lion's same inline generated client is wire-equivalent but uses 0x724e/0x72b2. Lion simultaneously reuses 0x724d/0x72b1 for a different non-inline client with complex bits 0x80001513 and fixed send size 0x3c, explaining the live count-9/send-0x50 -304 type-check failure.

Follow docs/ppc-carbon-gui-cgsshapewindow-inline-compat-integration.md. Build the new combined PPC artifact on Snow, require one exact passthrough control, run a fresh syscall-295 probe, then perform exactly one Lion integration that changes only request ID 0x724d->0x724e and native reply ID 0x72b2->0x72b1 for the pinned count-9 historical shape payload. Require native result zero, no remaining CGSShapeWindow type-check diagnostic, all accepted full-stack gates unchanged, and the exact observer to reach onscreen 400x222 geometry before any later shape/backing/display compatibility is considered.


## All-CoreUI image-constructor trace complete; current step — static image caller resolution

The trace+compat artifact passes on both systems without regressing any accepted gate. Snow records 13 CoreUI-originating `CGImageCreate` calls and Lion 10. The generated gray-gradient stream at `0x0001bdb0` is equivalent on both systems (two 1x22, 8-bpp images), and the six `0x000299e0` titlebar calls are the already accepted exact-six path. The only new non-button differential is return site `0x0002ad34`: Snow makes five 11x11 / bpr44 / raw-`0x2` calls, while Lion makes only one 256x256 / bpr1024 and one 2x62 / bpr8 call, also raw-`0x2`; every provider and result is non-NULL. That is a call-count/geometry/source difference, not evidence for another bitmap-info rewrite.

Follow `docs/ppc-carbon-gui-coreui-windowframe-image-caller-resolution-audit.md` next. Run the new static analyzer on Snow to resolve `0x0002ad34`, the gray-gradient control `0x0001bdb0`, and the exact-six control `0x000299e0` to their containing CoreUI functions, then use the Snow report for a Lion-native same-symbol reference. The new manual observation that Lion's now-sharp traffic-light controls are cosmetic only (clicks do nothing) and that titlebar dragging remains non-functional is recorded, but no mouse/hit evidence was collected in this run; keep hit/part adaptation held unless the divergent image caller proves a direct region/mask connection. Do not rerun the PPC subject, broaden bitmap-info policy, replace resources, or modify XNU.

## CoreUI image caller resolved; current step — shared-art source

The caller-resolution reports pass on both systems. Snow's divergent `0x0002ad34` site resolves to `CUISharedArtReader::CreateImageFromBytes(long,long)`, whose body calls `GetImageHeader(long)` and then obtains width, height, provider length, and provider data offset from byte-swapped serialized header fields before creating the image. The five Snow 11x11 calls versus Lion's 256x256 and 2x62 calls therefore diverge at the shared-art header/source boundary, not in CoreGraphics construction. The gray-gradient and exact-six titlebar control sites resolve independently as expected, and native Lion's absence of the same shared-reader symbol is treated only as release-refactor evidence.

Follow `docs/ppc-carbon-gui-coreui-windowframe-shared-art-source-audit.md` next. Run `scripts/audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py` once on Snow Leopard and once on Lion, with no PPC subject launch, and return the two generated text reports. Do not alter shared-art indices, geometry, resources, hit masks, CGS compatibility, or XNU before the exact reader/resource/header source is identified.

## Shared-art source resolved; current step — SArtFile frame records

The shared-art source reports pass on both systems. Snow's unique raw-bytes caller is `CUISharedArtReader::CreateImage(long,float)`, and `GetImageHeader(long)` translates image IDs through `image_id - 0x4e20` before indexing a byte-swapped shared-art offset table. The seven legacy frame IDs map to indices 105, 106, 109, 110, 111, 112, and 113. The release-local `SArtFile.bin` resources both identify as version 2 but differ materially: Snow count 237 / 811436 bytes, Lion count 348 / 9370228 bytes.

Follow `docs/ppc-carbon-gui-coreui-windowframe-sartfile-record-audit.md` next. Run `scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py` statically on Snow and Lion and return the two text reports. Do not launch the PPC subject, alter records/resources/geometry, broaden bitmap-info or CGS rules, change hit handling, or modify XNU before the exact seven record geometries and raw-byte slots are compared.

## Slot-0 integration partial; current step — mapped-payload pixel-format audit

The Snow slot-0 passthrough control passes. Lion executes all five guarded replacements with `ADAPTER_PASS`, binds all three ImageIO targets, preserves the exact-six titlebar bitmap adapter, and visibly restores the titlebar background, but the two top corners remain missing. The runner's FAIL is isolated to the exact-21 notification broker: the previously accepted ColorSync registration 7 is absent, and the old requests 8..21 shift to 7..20, producing fourteen state rejects. No adapter fallback/null occurred.

Follow `docs/ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format-audit.md` next. Run the Lion-only static analyzer and return its report. It compares alpha-byte-0 and alpha-byte-3 interpretations of all five mapped slot-0 payloads, with the three exact Snow-byte relocations as controls, before any per-ID bitmap-info or notification-policy change is authorized.
