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
