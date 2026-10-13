# ShowWindow titlebar exact-three-key policy proof

## Objective

Prove the exact process-local byte policy that would be required to translate only the three preserved Snow-PPC titlebar keys into their already-proven Lion semantic-equivalent ArtFile keys, without running the PPC ShowWindow subject and before any live interposer is built.

The completed translated-path feasibility audit is now decisive:

```text
Snow source archive positive control             PASS
Lion translated-path feasibility                PASS
clear                                            DIRECT_INDEX_HIT
minus                                            DIRECT_INDEX_HIT
zoom                                             DIRECT_INDEX_HIT
Lion target payload references                   valid
```

The exact mappings are:

```text
clear
a613161f7a000000 -> 9914172272000000

minus
a6161f567a000000 -> 9917225572000000

zoom
a6161f7ab6000000 -> 99172272a9000000
```

No other path is authorized for translation.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-three-key-policy.py
```

Identity:

```text
analyzer_version=1
audit_contract=titlebar-three-key-policy-v1
git_blob=313d2a6cb5b39586fc9068169f98e3e5583b9637
```

The analyzer is Python-2-compatible and read-only. It proves:

1. activation is guarded by exact Lion 10.7.5 / 11G63 identity plus the accepted Lion `ArtFile.bin` size, SHA-256, header geometry, and index padding;
2. Snow Leopard never enables the policy;
3. the policy has exactly three distinct eight-byte source predicates and three distinct outputs;
4. each predicate is full eight-byte equality, not a component-wise/global remap;
5. the three forced source mappings produce exactly the already-proven Lion keys;
6. the three outputs are not themselves policy sources, so repeated application is idempotent;
7. every single-byte mutation of every source key is identity (6,120 near-miss cases);
8. every record in the local ArtFile index is unchanged under the actual host guard;
9. on Snow, each exact source key remains a real source-index entry while the guard is disabled;
10. on Lion, each Snow source key is absent, each translated target is a single valid direct index entry, and each target decodes to the expected semantics with a valid payload reference.

This stage does not prove that a particular CoreUI symbol-interposition mechanism is safe. It proves only the byte policy and release/resource gating that any later process-local integration would have to preserve exactly.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not attach a debugger to a live process.
- Do not build or install a CoreUI/titlebar interposer yet.
- Do not patch CoreUI or `ArtFile.bin`.
- Do not globally remap CoreUI component IDs.
- Do not broaden beyond the three exact source keys above.
- Do not translate already-native Lion keys.
- Do not suppress diagnostics.
- Do not substitute Snow resources on Lion.
- Keep all accepted Process Manager, CGS, notification, Security, HIToolbox, and other compatibility artifacts unchanged.
- Keep RawCamera and ShapeWindow held.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update and preflight

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

LOCAL_HEAD="$(git rev-parse HEAD)" || exit 1
REMOTE_HEAD="$(git rev-parse origin/main)" || exit 1

echo "local_head=$LOCAL_HEAD"
echo "origin_main=$REMOTE_HEAD"

test "$LOCAL_HEAD" = "$REMOTE_HEAD" || {
  echo "ERROR: local runtime main is not current origin/main"
  exit 1
}

SCRIPT=./scripts/audit-pm-artfile-titlebar-three-key-policy.py

test "$(git hash-object "$SCRIPT")" = "313d2a6cb5b39586fc9068169f98e3e5583b9637" || {
  echo "ERROR: three-key policy analyzer is stale or locally modified"
  exit 1
}

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' "$SCRIPT" || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "titlebar-three-key-policy-v1"$' "$SCRIPT" || exit 1
```

Do not proceed if Phase A fails.

## Phase B — syntax-check

On both systems:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-titlebar-three-key-policy.py","rb").read(),"audit-pm-artfile-titlebar-three-key-policy.py","exec")' || exit 1
```

## Phase C — Snow guard-disabled control

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-three-key-policy.py   ./pm-art-titlebar-three-key-policy-snow.txt
```

Require:

```text
product_version=10.6.8
build_version=10K549
guard_enabled=NO
guard_selftest=PASS
policy_entry_count=3
single_byte_near_miss_cases=6120
single_byte_near_miss_failures=0
local_index_records_checked=3324
local_index_records_changed=0
policy_idempotence=PASS
RESULT: PASS
```

For `clear`, `minus`, and `zoom`, require `local_source_index_hits=1`. The Snow run must remain entirely identity because the Lion release/resource guard is disabled.

## Phase D — Lion exact-three-key policy proof

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-three-key-policy.py   ./pm-art-titlebar-three-key-policy-lion.txt
```

Require:

```text
product_version=10.7.5
build_version=11G63
guard_enabled=YES
guard_selftest=PASS
policy_entry_count=3
single_byte_near_miss_cases=6120
single_byte_near_miss_failures=0
local_index_records_checked=2674
local_index_records_changed=0
target_outputs_are_policy_sources=NO
policy_idempotence=PASS
RESULT: PASS
```

For each of `clear`, `minus`, and `zoom`, require:

```text
local_source_index_hits=0
local_target_index_hits=1
local_target_payload_0x68_valid=YES
```

and verify `local_target_decoded` equals the documented semantic path.

## Phase E — return evidence

Return exactly:

```text
pm-art-titlebar-three-key-policy-snow.txt
pm-art-titlebar-three-key-policy-lion.txt
```

Do not return CoreUI or ArtFile binaries.

## Review gates

### Both policy reports pass

If the Snow guard-disabled control and Lion guarded policy proof both pass, the next stage may investigate the narrowest process-local integration point for applying this exact three-key policy at the old Snow-PPC ArtFile consumer boundary.

That later integration stage must first establish the callable/interposable symbol boundary and preserve these invariants unchanged:

```text
activation scope          Lion 10.7.5 / 11G63 only
resource scope            accepted Lion ArtFile.bin only
predicate                 exact full 8-byte equality
authorized inputs         exactly three Snow keys
authorized outputs        exactly three proven Lion keys
all other inputs          identity
already-native Lion keys  identity
CoreUI/ArtFile files      unmodified
XNU                       unchanged
```

Do not perform a live ShowWindow run merely because the static policy proof passes; prepare and review the integration mechanism separately first.

### Any policy report fails

Stop. Do not build a live interposer. Return the failing report and preserve the existing compatibility environment unchanged.

## Current boundary

```text
titlebar prefix namespace shift                  PROVEN
window-variant semantic reindex                 PROVEN
state transition neutral correspondence         PROVEN
exact crash-time Snow paths                     PROVEN
Lion semantic-equivalent index keys             PROVEN
exact three-key translation table               DEFINED
release/resource guard                           TO BE STATICALLY PROVEN
non-target identity behavior                     TO BE STATICALLY PROVEN
live path translator                            NOT AUTHORIZED
PPC subject rerun                               NO
CoreUI/ArtFile patch                            NO
XNU                                             no change indicated
```
