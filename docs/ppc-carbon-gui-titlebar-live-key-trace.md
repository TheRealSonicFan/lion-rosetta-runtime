# PPC Carbon GUI titlebar live bsearch-key trace

## Status

COMPLETED LIVE-PROVEN PASS. Snow and Lion both execute exactly the known six titlebar-control bsearch keys, with zero outside-six lookups. The next controlled step is `docs/ppc-carbon-gui-titlebar-rendering-contract-audit.md`.

## Reviewed result that advances this step

The returned static inventories both pass.

Snow Leopard 10.6.8 / 10K549:

```text
inventory_entry_count=223
known_exact_six_source_count=6
duplicate_semantic_path_count=0
RESULT=PASS
RESULT: PASS
```

Lion 10.7.5 / 11G63 cross-release classification:

```text
snow_inventory_entry_count=223
identity_same_semantic_count=0
silent_collision_count=0
translation_required_count=197
missing_equivalent_count=26
unresolved_component_count=0
ambiguous_count=0
known_exact_six_translation_count=6
outside_six_silent_collision_count=0
outside_six_translation_required_count=191
RESULT=PASS
RESULT: PASS
```

This closes the same-byte/different-semantic collision hypothesis for the audited legacy ArtFile index: none of the 223 Snow `titlebarcontrols` raw keys is a direct Lion index key. The six live mappings remain valid positive controls, and another 191 Snow titlebar paths have unique semantic-equivalent Lion entries, but static archive presence does not prove that the historical Carbon subject executes any of those 191 paths.

The prior accepted Lion backing-sync run emitted exactly the six existing titlebar translation markers and no `Invalid ArtFile Path!` diagnostic. That strongly narrows the likely live set, but the exact-six interposer did not log non-target bsearch keys. One passive live-key trace is therefore required before the titlebar-key boundary can be closed.

No seventh translation is authorized by the static inventory.

## Objective

Observe every current historical-client CoreUI ArtFile bsearch whose raw Snow path begins with the Snow `titlebarcontrols` component `0xa6`, while preserving the already-live exact-six behavior.

The trace artifact has two modes:

```text
Snow  snow-passive-trace-v1
      log validated titlebar bsearch keys; modify nothing

Lion  lion-exact-six-trace-v1
      log validated raw titlebar keys;
      translate only the existing six exact keys;
      pass every outside-six key through unchanged
```

The Lion run is therefore a discriminator, not a policy expansion.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-titlebar-bsearch-trace-interposer.c
Git blob 9a816f913317b88a45a8402438f56d476e292a08
source SHA-256 f6b08e07d681bf9c04270a372642037e30384a269c86d2b16c3c144678a14fd6

scripts/build-ppc-coreui-titlebar-bsearch-trace-on-snowleopard.sh
Git blob e1e65cc6af30733d84c511060a116fea1404ddbe

scripts/run-snowleopard-ppc-carbon-gui-titlebar-bsearch-trace-control.sh
Git blob 388106609200a71b69bc3bb28a13724c38d73efa

scripts/run-lion-ppc-carbon-gui-titlebar-bsearch-trace.sh
Git blob 4beb3abf01b306d15625ef129049b23fd9b34ea3
```

Trace build ID:

```text
coreui-titlebar-bsearch-exact-six-trace-v1
```

The trace predicate is the already-proven CoreUI ArtFile bsearch boundary:

```text
record size              12
search prefix            four zero bytes
path length              8
caller/comparator delta  0x38f0
Snow ArtFile index       3324 records, index 0x0c4a
Lion ArtFile index       2674 records, index 0x0b9d
raw titlebar component   0xa6
```

A validated titlebar lookup is logged as:

```text
PM_COREUI_TITLEBAR_BSEARCH_TRACE:index=N mode=... raw_key=................ known_exact_six=YES|NO action=...
```

The trace limit is 512 validated titlebar lookups. Hitting the limit invalidates the run.

## Safety constraints

- Do not add or change a titlebar translation.
- Do not copy or rewrite ArtFile payloads.
- Do not interpose `LoadFromArtFile`, `memcpy`, image providers, CoreGraphics drawing, or bitmap conversion.
- Do not change the existing six source/target keys.
- Do not change ShapeWindow, backing synchronization, WindowBackingInfo, color-profile, notification, CPS, or any later CGS rule.
- Do not test another PPC application.
- Do not modify CoreUI, ArtFile resources, the Rosetta cache, WindowServer, or system frameworks.
- Do not change XNU, rebuild the kernel, or reboot.
- Run one Snow trace control first. Run Lion exactly once only after Snow passes.

## Phase A — pull and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-titlebar-bsearch-trace-interposer.c)" = \
  "9a816f913317b88a45a8402438f56d476e292a08" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-titlebar-bsearch-trace-on-snowleopard.sh)" = \
  "e1e65cc6af30733d84c511060a116fea1404ddbe" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-titlebar-bsearch-trace-control.sh)" = \
  "388106609200a71b69bc3bb28a13724c38d73efa" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-titlebar-bsearch-trace.sh)" = \
  "4beb3abf01b306d15625ef129049b23fd9b34ea3" || exit 1
```

On each machine, syntax-check the runner that will be used:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-titlebar-bsearch-trace-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-titlebar-bsearch-trace.sh || exit 1
```

Only the Snow machine needs to compile the PPC trace dylib.

## Phase B — build the trace artifact on Snow Leopard

Reuse the already accepted historical subject, backing-sync v6 core compatibility dylib, and observer from the completed phase. Build only the new titlebar trace dylib:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-coreui-titlebar-bsearch-trace-on-snowleopard.sh \
  ./payload/pm-titlebar-bsearch-exact-six-trace.dylib || exit 1
```

The builder must create:

```text
payload/pm-titlebar-bsearch-exact-six-trace.dylib
payload/pm-titlebar-bsearch-exact-six-trace.dylib.info.txt
payload/pm-titlebar-bsearch-exact-six-trace.dylib.sha256
```

Require the info file to contain:

```text
interposer_source_sha256=f6b08e07d681bf9c04270a372642037e30384a269c86d2b16c3c144678a14fd6
compat_build_id=coreui-titlebar-bsearch-exact-six-trace-v1
```

and a 32-bit PowerPC Mach-O with one `__DATA,__interpose` tuple.

## Phase C — one Snow passive control

Place/reuse these accepted files in `payload/`:

```text
ppc-carbon-gui-smoketest-private-dyld
ppc-carbon-gui-smoketest-private-dyld.sha256
pm-carbon-gui-backing-sync-compat.dylib
pm-carbon-gui-backing-sync-compat.dylib.sha256
cgwindowlist-pid-observer
cgwindowlist-pid-observer.sha256
```

Then:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

../scripts/run-snowleopard-ppc-carbon-gui-titlebar-bsearch-trace-control.sh || exit 1
```

Require:

```text
RESULT: PPC_CARBON_GUI_TITLEBAR_BSEARCH_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
titlebar_trace_limit_count=0
titlebar_trace_disabled_clear_count >= 1
titlebar_trace_disabled_minus_count >= 1
titlebar_trace_disabled_zoom_count >= 1
titlebar_trace_active_clear_count >= 1
titlebar_trace_active_minus_count >= 1
titlebar_trace_active_zoom_count >= 1
```

Record, without treating either value as pass/fail evidence by itself:

```text
titlebar_trace_count
titlebar_trace_outside_six_count
```

The Snow trace mode must only report `action=PASSTHROUGH`.

Stop before Lion if Snow fails, the trace limit is reached, or the normal Snow titlebar is visibly perturbed.

## Phase D — transfer the trace artifact to Lion

Transfer exactly these three newly built files into Lion's runtime `payload/` directory:

```text
pm-titlebar-bsearch-exact-six-trace.dylib
pm-titlebar-bsearch-exact-six-trace.dylib.info.txt
pm-titlebar-bsearch-exact-six-trace.dylib.sha256
```

Do not replace the previously accepted exact-six dylib. Keep both artifacts distinct.

## Phase E — one Lion passive-key trace

Reuse the complete accepted backing-sync stack already staged in Lion `payload/`.

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

./scripts/run-lion-ppc-carbon-gui-titlebar-bsearch-trace.sh || exit 1
```

The runner preserves every previously accepted adapter and changes only the titlebar interposer artifact from the exact-six v2 build to the exact-six-plus-passive-trace v1 build.

Require the established stack gates, plus:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
titlebar_trace_known_six_count=6
titlebar_trace_limit_count=0
RESULT: PPC_CARBON_GUI_TITLEBAR_BSEARCH_TRACE_PASS
RESULT: PASS
```

Record:

```text
titlebar_trace_count
titlebar_trace_outside_six_count
```

and every `PM_COREUI_TITLEBAR_BSEARCH_TRACE:` line from the raw log.

## Decision gate

### Lion outside-six trace count = 0

If Snow also reports zero outside-six lookups, the current exact historical subject uses only the already translated six titlebar keys during this run. Close the additional-key hypothesis. Do not add mappings. The next discriminator moves to release-specific titlebar rendering/recipe/scale behavior.

If Snow reports an outside-six key that Lion does not, preserve the two sequences and review the release-state divergence before changing policy.

### Lion outside-six trace count > 0

Correlate each raw key against the completed static collision inventory.

A key classified `TRANSLATION_REQUIRED` with a unique Lion semantic equivalent is only a **live candidate**. Do not translate it in this run. First require the same semantic state to be observed/expected on Snow and isolate the smallest exercised set.

A key classified `MISSING_EQUIVALENT`, or a Lion-only key not present in the Snow trace, is not eligible for automatic translation.

### Trace limit, guard reject, regression, or new crash

Stop and preserve the raw log. Do not broaden the trace or translation table in the same run.

## Observed result — exact six is the complete live titlebarcontrols set

The returned trace artifact matches the pinned source and build identity:

```text
interposer_source_sha256=f6b08e07d681bf9c04270a372642037e30384a269c86d2b16c3c144678a14fd6
compat_build_id=coreui-titlebar-bsearch-exact-six-trace-v1
artifact_sha256=23f98478a9c0b5076415a83a064f2e3d775c5eee42d17c6b219e9dfc0fbea1ac
```

Snow passes with exactly six validated `titlebarcontrols` lookups, all known exact-six keys and all passthrough:

```text
titlebar_trace_count=6
titlebar_trace_outside_six_count=0
titlebar_trace_limit_count=0
RESULT: PPC_CARBON_GUI_TITLEBAR_BSEARCH_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Lion passes with the identical six raw source keys, exactly six translations, zero guard rejects, and zero outside-six lookups:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
titlebar_trace_count=6
titlebar_trace_known_six_count=6
titlebar_trace_outside_six_count=0
titlebar_trace_limit_count=0
RESULT: PPC_CARBON_GUI_TITLEBAR_BSEARCH_TRACE_PASS
RESULT: PASS
```

The live order is the same on both releases: disabled close, disabled minimize, disabled zoom, active close, active minimize, active zoom. The WindowServer observers pass and preserve the exact 400x222 title. Manual review reports Snow visually normal and Lion still only partially correct with the same titlebar defect.

This closes additional `titlebarcontrols` key translation for the current historical subject. Do not add any of the 191 static outside-six semantic-equivalent candidates. Proceed only through `docs/ppc-carbon-gui-titlebar-rendering-contract-audit.md`.

## Return evidence

Return:

```text
pm-titlebar-bsearch-exact-six-trace.dylib.info.txt
pm-titlebar-bsearch-exact-six-trace.dylib.sha256
ppc-carbon-gui-titlebar-bsearch-trace-snow.log
ppc-carbon-gui-titlebar-bsearch-trace-snow-observer.log
lion-ppc-carbon-gui-titlebar-bsearch-trace.log
lion-ppc-carbon-gui-titlebar-bsearch-trace.raw.log
lion-ppc-carbon-gui-titlebar-bsearch-trace-observer.log
```

Also state:

```text
Snow titlebar visually normal: YES/NO
Lion titlebar visually normal: YES/NO/PARTIAL
```

Do not return the trace dylib binary unless specifically requested.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
Lion exact titled frame                          400x222 at (120,98), onscreen
six titlebar mappings                            LIVE-PROVEN
six payload record structure                     STATIC-PROVEN COMPATIBLE
Snow titlebar live lookup count                  6
Lion titlebar live lookup count                  6
outside-six titlebarcontrols live lookups        0 on both releases
additional titlebar key hypothesis               CLOSED for current subject
Lion titlebar                                    PARTIAL / unchanged
next step                                        docs/ppc-carbon-gui-titlebar-rendering-contract-audit.md
new titlebar mappings                            NOT AUTHORIZED
payload substitution                             NOT AUTHORIZED
XNU                                              no source change indicated
```
