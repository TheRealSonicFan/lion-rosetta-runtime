# PPC Carbon GUI all-ArtFile live bsearch-key trace

## Status

NEXT CONTROLLED LIVE DISCRIMINATOR after the completed titlebar rendering/scale contract audit.

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
Git blob 2a1d5b2cca97c597fee2cb6f70942339551e9d6b

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
  "2a1d5b2cca97c597fee2cb6f70942339551e9d6b" || exit 1

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
titlebarcontrols live set                        exact six on both releases
outside-six titlebarcontrols live lookups        0
Snow ArtFile10 exact-six headers                 6 distinct
Lion ArtFile10 exact-six headers                 1 shared
Lion ArtFile20 exact-six headers                 1 shared / scale-dependent
Snow titlebarcontrols recipe                     present
Lion recipe tree                                 absent
DrawWindowTitleBar -> DrawWindowFrameDark        static-proven on both
non-titlebarcontrols ArtFile live set             UNKNOWN
next step                                        one Snow + one Lion all-ArtFile key trace
new mappings                                     NOT AUTHORIZED
payload/header substitution                      NOT AUTHORIZED
ArtFile200 forcing                               NOT AUTHORIZED
XNU                                              no source change indicated
```
