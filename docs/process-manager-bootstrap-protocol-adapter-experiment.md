# Process Manager bootstrap protocol adapter discriminator

## Objective

Test one process-local compatibility transaction for the exact launchd/bootstrap request-layout mismatch now confirmed by the Snow Leopard PPC and Lion native client binaries.

The prior live discriminator proved that the restored Snow Leopard PPC `bootstrap_look_up2` reaches Lion launchd but receives:

```text
MIG_BAD_ARGUMENTS (-304)
```

for the coreservicesd lookup.

The corrected binary audit now confirms why.

Snow Leopard PPC and Lion use the same `look_up2` MIG routine number and reply contract, but Lion inserts a 16-byte instance UUID into the request between `target_pid` and the 64-bit flags field. The Lion request is therefore 16 bytes larger.

This stage sends exactly one Lion-format `look_up2` request from a translated PPC process. It does not patch libSystem, liblaunch, launchd, CarbonCore, Rosetta, or XNU.

It also does not call CoreServices `ServerCheckin`.

## Binary evidence now established

### Snow Leopard 10.6.8 PPC client

The explicit PPC `_vproc_mig_look_up2` body shows:

- request message ID `0x194`;
- service-name field at request offset `0x20`;
- target PID immediately after the 128-byte service name;
- 64-bit flags immediately after target PID;
- Mach send size `0xac`;
- Mach receive size `0x6c`;
- expected reply ID `0x1f8`.

The request therefore has no UUID field.

### Lion 10.7.5 i386 client

Lion strips the private generated symbol name, but analyzer version 2 resolves the unique repeated non-stub callee used by `bootstrap_look_up3`.

On the validated Lion i386 `liblaunch.dylib`, that body begins at:

```text
0x7967
```

and shows:

- the same request message ID `0x194`;
- the same service-name field at request offset `0x20`;
- target PID at request offset `0xa0`;
- a copied 16-byte value at request offset `0xa4`;
- 64-bit flags at request offset `0xb4`;
- Mach send size `0xbc`;
- Mach receive size `0x6c`;
- expected reply ID `0x1f8`.

The difference between `0xac` and `0xbc` is exactly 16 bytes.

The copied 16-byte field matches the `instanceid : uuid_t` parameter in Apple launchd-392.39 `protocol_vproc.defs`.

This closes the static protocol question.

## Adapter scope

Current runtime `main` provides:

```text
tests/ppc-process-manager-bootstrap-protocol-adapter.c
scripts/build-ppc-process-manager-bootstrap-protocol-adapter-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-bootstrap-protocol-adapter-control.sh
scripts/run-lion-ppc-process-manager-bootstrap-protocol-adapter.sh
docs/process-manager-bootstrap-protocol-adapter-experiment.md
```

The executable has two explicit modes.

### Snow Leopard control mode

`snow-control`:

1. verifies the Lion-format request layout in memory without sending it;
2. calls the normal Snow Leopard PPC `bootstrap_look_up2`;
3. requires the ordinary legacy lookup to succeed and return a nonzero coreservicesd port.

The Lion-format custom Mach request is not sent on Snow Leopard.

### Lion adapter mode

`lion-adapter`:

1. verifies the same request layout in memory;
2. obtains the normal MIG reply port;
3. constructs one Lion-format `look_up2` request;
4. uses the process's existing `bootstrap_port`;
5. requests `com.apple.CoreServices.coreservicesd`;
6. uses target PID 0;
7. supplies a zero instance UUID;
8. uses flags `0x8`;
9. sends exactly one Mach request with:
   - request ID `0x194`;
   - send size `0xbc`;
   - receive size `0x6c`;
10. validates reply ID `0x1f8`;
11. accepts only the expected one-port complex success reply;
12. deallocates the returned coreservicesd send right before exit.

A zero UUID is intentional. The normal Lion public `bootstrap_look_up2` does not expose an instance UUID to its caller; this experiment does not request lookup of a specific service instance. The UUID field is present to satisfy the Lion MIG request schema, not to change service-selection semantics.

## Safety constraints

For this experiment:

- build the PPC subject only on Snow Leopard;
- run one Snow Leopard positive control;
- transfer the exact hashed subject to Lion;
- repeat the established Lion native commpage and syscall-295 safety gates;
- run the Lion adapter mode exactly once;
- do not rerun the legacy PPC bootstrap discriminator;
- do not send more than the single prepared Lion-format lookup request;
- do not call `ServerCheckin`;
- do not call `FindService`;
- do not call CarbonCore service acquisition;
- do not call Security, LaunchServices process services, or Process Manager;
- do not set `CORESERVICESD_SERVICE_NAME` or `SCDontUseServer`;
- do not restart or signal launchd, coreservicesd, pbs, securityd, or WindowServer;
- do not patch or replace libSystem, liblaunch, launchd, CarbonCore, or any framework;
- do not modify the Rosetta cache, private dyld, system dyld, or XNU;
- do not use GDB, DTrace, dtruss, DYLD interposition, or live injection.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm the five files listed above.

On Lion also update XNU:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — build the PPC adapter subject on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-bootstrap-protocol-adapter-on-snowleopard.sh \
  ./ppc-process-manager-bootstrap-protocol-adapter-private-dyld
```

Expected outputs:

```text
ppc-process-manager-bootstrap-protocol-adapter-private-dyld
ppc-process-manager-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-bootstrap-protocol-adapter-private-dyld.sha256
```

Require:

- 32-bit PowerPC;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- imports for `bootstrap_look_up2`, `bootstrap_port`, `mig_get_reply_port`, and `mach_msg`.

If compilation or link validation fails, stop and return the complete build output.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-bootstrap-protocol-adapter-control.sh \
  ./ppc-process-manager-bootstrap-protocol-adapter-private-dyld \
  ./ppc-process-manager-bootstrap-protocol-adapter-private-dyld.sha256 \
  ./ppc-process-manager-bootstrap-protocol-adapter-snowleopard-control.log
```

Require:

```text
PM_BOOTSTRAP_ADAPTER_LAYOUT:PASS
request_id=0x00000194
send_size=0x000000bc
recv_size=0x0000006c
PM_BOOTSTRAP_ADAPTER_SNOW_RETURN:kr=0 ...
PM_BOOTSTRAP_ADAPTER_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

The Snow Leopard control must return a nonzero service port.

This phase validates the exact subject and its baseline environment. It does not send the Lion-format request.

If this control fails, stop.

## Phase D — transfer the exact subject to Lion

Transfer privately:

```text
ppc-process-manager-bootstrap-protocol-adapter-private-dyld
ppc-process-manager-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-bootstrap-protocol-adapter-snowleopard-control.log
```

Place the executable and SHA sidecar in the runtime `payload/` directory or pass their paths explicitly.

Do not rebuild the PPC subject on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

The validated kernel SHA-256 remains:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Run the established native commpage safety probe and require its existing `RESULT: PASS`.

Then:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-process-manager-bootstrap-protocol-adapter.log"
```

Require the established syscall-295 PASS result.

Do not continue if either native safety gate fails.

## Phase F — run the single Lion PPC adapter transaction

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-bootstrap-protocol-adapter.sh
```

The runner verifies:

- Lion 10.7.5;
- clean bootstrap/CoreServices environment variables;
- validated kernel;
- PowerPC architecture handler;
- translator identity;
- exact PPC executable hash;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- private/system dyld identities;
- Rosetta cache/map identities;
- restored PPC libSystem membership in the cache map.

It then runs exactly one `lion-adapter` invocation.

Do not rerun before review.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-bootstrap-protocol-adapter-private-dyld.info.txt
ppc-process-manager-bootstrap-protocol-adapter-private-dyld.sha256
ppc-process-manager-bootstrap-protocol-adapter-snowleopard-control.log
syscall295-probe-process-manager-bootstrap-protocol-adapter.log
lion-ppc-process-manager-bootstrap-protocol-adapter.log
lion-ppc-process-manager-bootstrap-protocol-adapter.raw.log
```

Also return every new crash report or core listed by the Lion runner.

## Result interpretation

### `BOOTSTRAP_PROTOCOL_ADAPTER_PASS`

Lion accepted the UUID-expanded PPC request and returned a nonzero coreservicesd service port.

This would directly validate the identified `0xac -> 0xbc` request-layout mismatch as the cause of the earlier `MIG_BAD_ARGUMENTS`.

Stop there.

The next stage would be a separate process-local integration design that adapts only the restored PPC `bootstrap_look_up2` call used by CarbonCore before allowing the existing Snow Leopard PPC `ServerCheckin` path to execute.

Do not call `ServerCheckin` in this experiment.

### `ADAPTER_MIG_BAD_ARGUMENTS`

Lion still rejects the prepared request at MIG type checking.

Do not broaden the adapter or guess additional fields. Preserve the raw reply and re-audit the generated request layout.

### `ADAPTER_SERVER_ERROR`

The Lion-format request passed Mach transport but launchd returned another explicit server error.

Preserve the exact error code. That becomes the next boundary.

### `ADAPTER_MACH_MSG_ERROR`

The custom transaction failed at Mach transport.

Do not retry.

### `ADAPTER_ZERO_PORT`

The reply has the expected complex success shape but no service port.

Treat this as invalid success output and stop.

### `ADAPTER_REPLY_SHAPE_ERROR`

The reply ID, size, descriptor count, or simple/complex form does not match the binary-confirmed contract.

Do not reinterpret the buffer manually during the same run.

### abort/crash or pre-main failure

Preserve all diagnostics and stop.

## Current interpretation to preserve

The current evidence is stronger than a generic "launchd changed" hypothesis.

The exact binary delta is:

```text
Snow Leopard PPC:
target_pid -> flags
send size 0xac

Lion:
target_pid -> 16-byte instance UUID -> flags
send size 0xbc
```

The request ID and reply contract remain aligned.

The prior `MIG_BAD_ARGUMENTS` is therefore explained by a concrete request type/size mismatch at the launchd MIG boundary.

The adapter experiment tests only whether supplying that missing field restores the exact bootstrap lookup.

No additional XNU change is indicated.

## Non-goals

This experiment does not:

- install a permanent compatibility layer;
- modify the restored PPC libSystem image;
- patch launchd;
- interpose bootstrap calls globally;
- initialize CarbonCore;
- perform CoreServices `ServerCheckin`;
- request `LaunchApplicationServices`;
- call Security;
- call LaunchServices process services;
- call Process Manager;
- modify Rosetta or XNU.

It is a one-transaction proof of the binary-confirmed bootstrap protocol adapter.
