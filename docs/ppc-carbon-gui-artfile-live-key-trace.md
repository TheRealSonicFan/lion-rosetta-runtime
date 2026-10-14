# PPC Carbon GUI all-ArtFile live bsearch-key trace

## Status

COMPLETED LIVE-PROVEN PASS. Both Snow and Lion execute only the existing exact-six ArtFile lookups, with zero outside-six keys and zero misses. The next controlled step is the static field-level audit in `docs/ppc-carbon-gui-artfile-snow-loader-field-audit.md`.

## Reviewed result that advances this step

Both rendering-contract reports pass their provenance and static validation gates.

Snow Leopard 10.6.8 / 10K549 proves:

```text
ArtFile10 state=PRESENT
exact_six_header_unique_count=6
exact_six_body_offset_0x68_count=6
ArtFile20 state=MISSING
CoreUI recipe tree state=PRESENT
title_or_window_recipe_count=1
focused_recipe=titlebarcontrols.xml
CoreUI required_arch=ppc7400
archive_and_renderer_contract_exact=YES
RESULT: PASS
```

Lion 10.7.5 / 11G63 proves:

```text
ArtFile10 state=PRESENT
exact_six_header_unique_count=1
exact_six_body_offset_0x68_count=6
ArtFile20 state=PRESENT
ArtFile20 exact_six_header_unique_count=1
CoreUI recipe tree state=MISSING
CoreUI required_arch=i386
archive_and_renderer_contract_exact=YES
RESULT: PASS
```

The exact-six resource contract is therefore release-specific even though the fixed payload offset remains `0x68`. Snow's six ArtFile10 records carry six distinct complete `0x68` headers; Lion ArtFile10 uses one common header for those six records, and Lion ArtFile20 uses a different common header with doubled scale-dependent geometry. Snow also retains `titlebarcontrols.xml`; Lion does not.

The code differential narrows the scale question. Lion native CoreUI has separate ArtFile10/ArtFile20 setup and `ArtFileInfo::GetArtFileInfoForScaleFactor(float)`. The historical Rosetta process, however, is already proven to execute the Snow-era PPC CoreUI path from the unchanged Rosetta cache. That old path owns one legacy `ArtFileSetupOnce()` and its own `_CUIUseArtFile` gating. Nothing in these static reports authorizes forcing ArtFile200 or substituting a resource.

The renderer differential also makes the transparent titlebar background important: on both releases `CUIRenderer::DrawWindowTitleBar` delegates the relevant path to `CUIRenderer::DrawWindowFrameDark`. The prior live tracer observed only the `titlebarcontrols` component. It therefore did not establish which other ArtFile semantic families the frame/titlebar-background renderer requests.

Before adapting any `0x68` header field, trace the complete validated ArtFile bsearch key set. This can distinguish a missing or silently colliding non-`titlebarcontrols` frame/background key from a genuine old-loader record interpretation problem.

## Objective

Observe every **unique** validated legacy ArtFile bsearch key used by the exact historical PPC Carbon subject on Snow and Lion, while preserving the accepted exact-six titlebar translations and every other accepted compatibility path.

The new tracer has two modes:

```text
Snow  snow-passive-allkeys-v1
      log every unique validated ArtFile raw key;
      modify nothing

Lion  lion-exact-six-allkeys-v1
      log every unique validated ArtFile raw key;
      translate only the existing exact six titlebar keys;
      pass every other key through unchanged
```

For each first-seen raw key it records:

```text
raw_key
raw_semantic              decoded with the release-local ArtFile dictionary
known_exact_six
action
effective_key
effective_semantic        decoded with the release-local ArtFile dictionary
result=HIT|MISS
result_index
```

This lets the same raw key be compared directly across Snow and Lion. A Snow semantic path is the intended old-PPC meaning. The Lion `raw_semantic` shows what the same bytes mean under Lion's component dictionary (or `UNRESOLVED`), while `result` shows whether those bytes actually hit Lion's index.

The tracer deduplicates by raw eight-byte path and stops logging after 512 unique ArtFile keys. Hitting that bound invalidates the run.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-artfile-bsearch-allkeys-trace-interposer.c
Git blob 32e6413d78ba3da7d327c35e199c46af1cc00b78

scripts/build-ppc-coreui-artfile-bsearch-allkeys-trace-on-snowleopard.sh
Git blob 8c0ee95fa9c2bcd323f71b88b716bda569607b1a

scripts/run-snowleopard-ppc-carbon-gui-artfile-bsearch-allkeys-trace-control.sh
Git blob 48106be730fb6cb3eecb9a51fb95486671a7dd95

scripts/run-lion-ppc-carbon-gui-artfile-bsearch-allkeys-trace.sh
Git blob ff446b7572bc418c95887b23a3cdc16f9d145b51
```

Build ID:

```text
coreui-artfile-bsearch-exact-six-allkeys-trace-v1
```

The guard remains the already-live-proven ArtFile bsearch boundary:

```text
record size              12
search prefix            four zero bytes
path length              8
caller/comparator delta  0x38f0
Snow ArtFile index       3324 records, index 0x0c4a
Lion ArtFile index       2674 records, index 0x0b9d
```

No `LoadFromArtFile`, renderer, payload, image-provider, CoreGraphics, or framework routine is interposed.

## Safety constraints

- Do not add or change a titlebar or frame/background translation.
- Do not copy or rewrite any ArtFile payload or `0x68` record header.
- Do not force ArtFile200 or a scale factor.
- Do not copy Snow `titlebarcontrols.xml` or any UI recipe to Lion.
- Do not interpose `LoadFromArtFile`, `memcpy`, renderer routines, image providers, CoreGraphics drawing, or bitmap conversion.
- Do not change ShapeWindow, backing synchronization, WindowBackingInfo, color-profile, notification, CPS, or any later CGS rule.
- Do not test another PPC application.
- Do not modify CoreUI, any ArtFile resource, the Rosetta cache, WindowServer, or system frameworks.
- Do not change XNU, rebuild the kernel, or reboot.
- Run one Snow control first. Run Lion exactly once only after Snow passes and the Snow titlebar remains visually normal.

## Phase A — pull and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-artfile-bsearch-allkeys-trace-interposer.c)" = \
  "32e6413d78ba3da7d327c35e199c46af1cc00b78" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-artfile-bsearch-allkeys-trace-on-snowleopard.sh)" = \
  "8c0ee95fa9c2bcd323f71b88b716bda569607b1a" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-artfile-bsearch-allkeys-trace-control.sh)" = \
  "48106be730fb6cb3eecb9a51fb95486671a7dd95" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-artfile-bsearch-allkeys-trace.sh)" = \
  "ff446b7572bc418c95887b23a3cdc16f9d145b51" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-artfile-bsearch-allkeys-trace-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-artfile-bsearch-allkeys-trace-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-artfile-bsearch-allkeys-trace.sh || exit 1
```

No XNU build action is required.

## Phase B — build only the new trace artifact on Snow

Reuse the accepted historical subject, backing-sync v6 core compatibility dylib, and observer. Build only:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-coreui-artfile-bsearch-allkeys-trace-on-snowleopard.sh \
  ./payload/pm-artfile-bsearch-exact-six-allkeys-trace.dylib || exit 1
```

Require:

```text
compat_build_id=coreui-artfile-bsearch-exact-six-allkeys-trace-v1
interposer_source_git_blob=32e6413d78ba3da7d327c35e199c46af1cc00b78
```

and a 32-bit PowerPC Mach-O containing exactly one `__DATA,__interpose` tuple.

### Phase B correction for blank source-blob errors

The original v1 builder incorrectly invoked `/usr/bin/git` directly when verifying the source blob. On Snow Leopard, Phase A can succeed with a `git` executable elsewhere on `PATH` while `/usr/bin/git` is absent; in that case the builder produced the misleading error:

```text
error: all-ArtFile bsearch interposer source blob mismatch:
```

with an empty value. This is a builder-path bug, not evidence that the source file differs.

Current `main` resolves the same usable `git` executable from `PATH` first, with Snow-era fallback locations, and uses it for both `hash-object` and `rev-parse`. After pulling current `main`, repeat Phase A's pin checks and rerun Phase B. Do not rebuild any previously accepted compatibility artifact, and do not proceed to Phase C unless the corrected Phase B completes normally.

## Phase C — one Snow passive all-key control

Place/reuse these accepted files in Snow's `payload/`:

```text
ppc-carbon-gui-smoketest-private-dyld
ppc-carbon-gui-smoketest-private-dyld.sha256
pm-carbon-gui-backing-sync-compat.dylib
pm-carbon-gui-backing-sync-compat.dylib.sha256
cgwindowlist-pid-observer
cgwindowlist-pid-observer.sha256
pm-artfile-bsearch-exact-six-allkeys-trace.dylib
pm-artfile-bsearch-exact-six-allkeys-trace.dylib.sha256
```

Then:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

../scripts/run-snowleopard-ppc-carbon-gui-artfile-bsearch-allkeys-trace-control.sh || exit 1
```

Require:

```text
artfile_trace_unique_count >= 6
artfile_trace_limit_count=0
artfile_trace_disabled_clear_count >= 1
artfile_trace_disabled_minus_count >= 1
artfile_trace_disabled_zoom_count >= 1
artfile_trace_active_clear_count >= 1
artfile_trace_active_minus_count >= 1
artfile_trace_active_zoom_count >= 1
RESULT: PPC_CARBON_GUI_ARTFILE_BSEARCH_ALLKEYS_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Record, without treating them as failure by themselves:

```text
artfile_trace_outside_six_unique_count
artfile_trace_miss_unique_count
```

Every Snow trace line must have `action=PASSTHROUGH`.

Stop before Lion if the control fails, the unique-key limit is reached, or the normal Snow titlebar/window appearance is perturbed.

## Phase D — transfer only the new trace artifact

Transfer exactly:

```text
pm-artfile-bsearch-exact-six-allkeys-trace.dylib
pm-artfile-bsearch-exact-six-allkeys-trace.dylib.info.txt
pm-artfile-bsearch-exact-six-allkeys-trace.dylib.sha256
```

into Lion's runtime `payload/` directory.

Keep the previously accepted exact-six and titlebar-only trace artifacts distinct.

## Phase E — one Lion exact-six plus all-key trace

Reuse the complete accepted backing-sync stack already staged on Lion.

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

./scripts/run-lion-ppc-carbon-gui-artfile-bsearch-allkeys-trace.sh || exit 1
```

Require all established full-stack gates plus:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
artfile_trace_unique_count >= 6
artfile_trace_known_six_count=6
artfile_trace_limit_count=0
RESULT: PPC_CARBON_GUI_ARTFILE_BSEARCH_ALLKEYS_TRACE_PASS
RESULT: PASS
```

Record:

```text
artfile_trace_outside_six_unique_count
artfile_trace_miss_unique_count
```

and preserve every `PM_COREUI_ARTFILE_BSEARCH_TRACE:` line from both releases.

## Decision gate

### Outside-six keys are observed

Correlate by `raw_key` between Snow and Lion.

For each outside-six Snow line:

- Snow `raw_semantic` is the intended legacy semantic path.
- If Lion reports `result=MISS`, the raw Snow key does not exist in Lion's index.
- If Lion reports `result=HIT` but Lion `raw_semantic` differs from Snow `raw_semantic`, that is a live same-byte/different-semantic collision.
- If Lion `raw_semantic=UNRESOLVED`, at least one Snow component ID is outside Lion's local component dictionary.

Any such key is only a **live compatibility candidate**. Do not translate it in this run. First isolate the smallest frame/titlebar-background-related set and prove a unique Lion semantic equivalent.

### Outside-six keys are observed and all remain semantically identical

If every outside-six key hits the same semantic path on both releases, close broad key translation as the explanation for the visual defect. The next step becomes the field-level Snow-PPC decode of the Lion ArtFile10 record metadata identified by the rendering-contract audit.

### No outside-six key is observed

If the exact six are the entire ArtFile lookup set, the transparent titlebar background is not caused by a separate bsearch key. Proceed to the same field-level old-loader metadata decode; do not add mappings.

### Trace limit, guard reject, regression, or new crash

Stop and preserve the raw log. Do not broaden the trace or translation table in the same run.

## Observed result — complete validated ArtFile bsearch set is exact six

The trace artifact matches the pinned source/build identity and both control runs pass.

Snow Leopard:

```text
artfile_trace_unique_count=6
artfile_trace_outside_six_unique_count=0
artfile_trace_miss_unique_count=0
artfile_trace_limit_count=0
RESULT: PPC_CARBON_GUI_ARTFILE_BSEARCH_ALLKEYS_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Lion:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
artfile_trace_unique_count=6
artfile_trace_known_six_count=6
artfile_trace_outside_six_unique_count=0
artfile_trace_miss_unique_count=0
artfile_trace_limit_count=0
RESULT: PPC_CARBON_GUI_ARTFILE_BSEARCH_ALLKEYS_TRACE_PASS
RESULT: PASS
```

The raw-key sequence is the same six Snow titlebar-control keys on both systems. Snow passes all six through and hits its local records. On Lion the same raw bytes decode to unrelated Lion-local component names, but the exact-six translation rewrites each to the intended semantic-equivalent Lion key and all six effective lookups hit. No additional validated ArtFile bsearch key is observed on either release.

The accepted full stack remains intact, the observer reaches the exact 400x222 titled window, protected hashes remain unchanged, and manual review still reports Snow normal versus Lion partial/unchanged.

This closes the non-`titlebarcontrols` bsearch-key hypothesis for the exact historical subject at this loader boundary. Do not add a seventh mapping. Follow `docs/ppc-carbon-gui-artfile-snow-loader-field-audit.md` next to prove which Lion record fields the Snow-PPC loader actually consumes before considering any field-level compatibility experiment.

## Return evidence

Return:

```text
pm-artfile-bsearch-exact-six-allkeys-trace.dylib.info.txt
pm-artfile-bsearch-exact-six-allkeys-trace.dylib.sha256
ppc-carbon-gui-artfile-bsearch-allkeys-trace-snow.log
ppc-carbon-gui-artfile-bsearch-allkeys-trace-snow-observer.log
lion-ppc-carbon-gui-artfile-bsearch-allkeys-trace.log
lion-ppc-carbon-gui-artfile-bsearch-allkeys-trace.raw.log
lion-ppc-carbon-gui-artfile-bsearch-allkeys-trace-observer.log
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
validated ArtFile live set                       exact six on both releases
outside-six ArtFile live lookups                 0
ArtFile live misses                              0
titlebar exact-six translations                  6 / guard rejects 0
non-titlebarcontrols bsearch-key hypothesis      CLOSED for current subject
Snow ArtFile10 exact-six headers                 6 distinct
Lion ArtFile10 exact-six headers                 1 shared
Lion ArtFile20 exact-six headers                 1 shared / scale-dependent
Lion titlebar                                    PARTIAL / unchanged
next step                                        docs/ppc-carbon-gui-artfile-snow-loader-field-audit.md
new mappings                                     NOT AUTHORIZED
payload/header substitution                      NOT AUTHORIZED
ArtFile200 forcing                               NOT AUTHORIZED
XNU                                              no source change indicated
```
