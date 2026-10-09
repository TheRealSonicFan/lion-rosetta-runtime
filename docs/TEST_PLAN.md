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
