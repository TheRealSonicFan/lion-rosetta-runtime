# ShowWindow titlebar ArtFile path-builder audit

## Objective

Resolve whether the Snow-PPC and native Lion CoreUI titlebar path builders construct the same semantic ArtFile path using different numeric component IDs.

The completed component-dictionary audit proves that this is **not** a one-byte `0xb6` problem. All seven component IDs used by the three observed titlebar paths changed meaning between Snow Leopard and Lion.

Snow decodes the captured paths as:

```text
a6 13 16 1f 7a          titlebarcontrols.close.colorsryg.disabled.regularwin
a6 16 1f 56 7a          titlebarcontrols.colorsryg.disabled.minimize.regularwin
a6 16 1f 7a b6          titlebarcontrols.colorsryg.disabled.regularwin.zoom
```

The same semantics exist uniquely in Lion, but at different IDs:

```text
Snow  Lion  semantic
a6    99    titlebarcontrols
13    14    close
16    17    colorsryg
1f    22    disabled
56    55    minimize
7a    72    regularwin
b6    a9    zoom
```

This explains the misleading Lion diagnostics. Snow's numeric path `a6 16 1f 7a b6` is semantically a titlebar zoom path under Snow's dictionary, but Lion's old unchecked diagnostic decodes the first four numbers as `west.colorsrgb.determinate.scrollbars` and then falls off the end at `0xb6`.

The remaining discriminator is whether native Lion `CUIElement::CreateQSIImagePath` and its two titlebar helper routines emit the Lion-side semantic IDs above for the same titlebar descriptor/state. If they do, the compatibility defect is a release-specific **component-ID namespace mismatch** between Snow-PPC path construction and Lion ArtFile consumption, and any later experiment can be constrained to semantic path translation rather than archive replacement.

## Accepted evidence

Both component dictionary reports complete `RESULT: PASS`.

Snow:

```text
component_count=182 / 0xb6
component_table_end=0x5c8
titlebarcontrols=0xa6
close=0x13
colorsryg=0x16
disabled=0x1f
minimize=0x56
regularwin=0x7a
zoom=0xb6
```

Lion:

```text
component_count=169 / 0xa9
component_table_end=0x560
titlebarcontrols=0x99
close=0x14
colorsryg=0x17
disabled=0x22
minimize=0x55
regularwin=0x72
zoom=0xa9
```

The earlier preserved-core audit already tied Snow's `0xb6` lookup against Lion's shorter table to runtime pointer `0x787221c5`, adjacent to the exact fault address `0x787221c4`.

The existing static disassemblies show a shared high-level titlebar path-builder shape but an important implementation difference: both releases append titlebar tokens and call `CUIPath::AppendWindowVariant`, but Snow Leopard has **no** `CUIPath::AppendWindowTitlebarButtonState(long,long,long)` symbol. Snow performs the titlebar button-state selection inline in `CreateQSIImagePath` using direct `AppendState` calls and out-of-line continuation blocks. Lion introduces the dedicated `AppendWindowTitlebarButtonState` helper and calls it from the close/minimize/zoom branches. The corrected audit models those release-specific forms explicitly.


## Analyzer-v1 correction after the first Phase C run

The first Snow Leopard run failed only because analyzer v1 incorrectly required Lion's later `CUIPath::AppendWindowTitlebarButtonState(long,long,long)` helper to exist on Snow.

The returned report otherwise passes every provenance and semantic-ID check: Snow 10.6.8 / 10K549, the accepted PPC CoreUI slice SHA-256, the accepted Snow `ArtFile.bin`, and all seven expected Snow component IDs are exact. The extracted titlebar branches also show the intended Snow implementation directly: each branch calls `AppendWindowVariant` and then performs button-state handling with `AppendState`. The helper symbol is genuinely absent; this is a release implementation difference, not a corrupt binary or an audit failure.

Analyzer v2 therefore:

- keeps `AppendWindowVariant` required on both releases;
- treats Snow as `INLINE_APPEND_STATE` and requires the dedicated titlebar-state helper to be absent;
- validates Snow's direct `AppendState` calls and additionally captures the titlebar-state continuation range at `0x28e78..0x28ec0`;
- treats Lion as `HELPER` and still requires `AppendWindowTitlebarButtonState` plus its titlebar callsites;
- reports the strategy, helper presence expectation, and per-branch call counts explicitly.

Use the same static inputs. No PPC application rerun is needed.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-path-builder.py
```

Analyzer version:

```text
2
```

It is Python-2-compatible and read-only. On each release it:

1. verifies the exact OS build;
2. thins the local CoreUI framework to the accepted architecture;
3. verifies the previously accepted CoreUI slice SHA-256;
4. verifies the accepted local `ArtFile.bin` size/SHA;
5. decodes the local ArtFile dictionary and requires the seven titlebar semantics at the already-proven release-specific IDs;
6. extracts only the titlebar section of `CUIElement::CreateQSIImagePath`;
7. requires the known release-specific close/minimize/zoom/color/titlebar constants and helper calls to remain present;
8. models Snow's titlebar state logic as inline `AppendState` plus its continuation blocks, while requiring Lion's dedicated `AppendWindowTitlebarButtonState(long,long,long)` helper;
9. emits the complete `AppendWindowVariant(long)` body on both releases and the titlebar-state helper body only when that helper is expected to exist;
10. reports strategy/helper presence and call counts so an absent Snow helper is a validated structural finding rather than a failure;
11. modifies nothing outside its temporary architecture slice.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not attach GDB to a live process.
- Do not patch CoreUI or any ArtFile.
- Do not remap component bytes yet.
- Do not suppress `ShowArtFilePathToStdErr`, `fprintf`, or `vfprintf`.
- Do not substitute Snow resources on Lion.
- Keep all accepted Process Manager/CGS/notification compatibility adapters unchanged.
- Keep RawCamera and ShapeWindow held.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update runtime on both systems

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD

ls -l ./scripts/audit-pm-artfile-titlebar-path-builder.py
ls -l ./docs/pm-showwindow-artfile-titlebar-path-audit.md
```

## Phase B — syntax-check

On both systems:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-titlebar-path-builder.py","rb").read(),"audit-pm-artfile-titlebar-path-builder.py","exec")' || exit 1
```

## Phase C — Snow Leopard path-builder audit

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-path-builder.py \
  ./pm-art-titlebar-path-snow.txt
```

Require:

```text
analyzer_version=2
product_version=10.6.8
required_arch=ppc7400
semantic=titlebarcontrols id=0xa6
semantic=close id=0x13
semantic=colorsryg id=0x16
semantic=disabled id=0x1f
semantic=minimize id=0x56
semantic=regularwin id=0x7a
semantic=zoom id=0xb6
titlebar_state_strategy=INLINE_APPEND_STATE
titlebar_state_helper_expected=NO
titlebar_state_helper_present=NO
RESULT: PASS
```

Also require nonzero direct `AppendState` calls in the titlebar extraction and the emitted inline continuation range `0x28e78..0x28ec0`.

## Phase D — Lion path-builder audit

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-path-builder.py \
  ./pm-art-titlebar-path-lion.txt
```

Require:

```text
analyzer_version=2
product_version=10.7.5
required_arch=i386
semantic=titlebarcontrols id=0x99
semantic=close id=0x14
semantic=colorsryg id=0x17
semantic=disabled id=0x22
semantic=minimize id=0x55
semantic=regularwin id=0x72
semantic=zoom id=0xa9
titlebar_state_strategy=HELPER
titlebar_state_helper_expected=YES
titlebar_state_helper_present=YES
RESULT: PASS
```

The Lion titlebar branch must call `AppendWindowTitlebarButtonState`; unlike Snow, this helper is a required Lion structure.

## Phase E — return evidence

Return exactly:

```text
pm-art-titlebar-path-snow.txt
pm-art-titlebar-path-lion.txt
```

Do not return CoreUI or ArtFile binaries.

## Review gates

### Native Lion builder uses the semantic-equivalent Lion IDs

If the Lion close/minimize/zoom branches and the two helper routines resolve to the semantic-equivalent IDs listed above while Snow resolves to its own IDs, the namespace mismatch is proven at the path-construction boundary. The next experiment may then be a process-local path translation limited to the titlebar paths actually produced by Snow-PPC CoreUI and only when Lion's ArtFile dictionary is the proven mapped archive.

Do not globally translate arbitrary CoreUI IDs.

### Titlebar state implementation differs structurally

This difference is now already established: Snow inlines the titlebar button-state logic through `AppendState`, while Lion factors it into `AppendWindowTitlebarButtonState`. That difference alone is not an analyzer failure. The v2 reports must be compared semantically: if the Lion helper implements the same state choices under Lion's reindexed component namespace, a narrowly scoped semantic translator may still be justified; if the state choices differ, stop before a live shim and model the state transformation explicitly.

### Variant helper differs semantically

If `AppendWindowVariant` changes its state/variant meaning rather than merely its component constants, stop before a live shim. Do not apply a flat byte map.

### Lion no longer constructs one of the Snow semantics

If native Lion omits `disabled`, `regularwin`, or another captured semantic from the corresponding titlebar path, do not manufacture that component. The next discriminator must identify Lion's native replacement path shape.

### Static provenance fails

If either report returns `RESULT: FAIL`, return both reports unchanged and stop. Do not rerun the PPC subject.

## Current boundary

```text
Snow captured titlebar paths                       semantically decoded
Snow/Lion active component IDs                     all seven differ numerically
Snow 0xb6 semantic                                 zoom
Lion zoom semantic                                 0xa9
Snow a6 semantic                                   titlebarcontrols
Lion titlebarcontrols semantic                     0x99
Snow colorsryg / disabled / regularwin             0x16 / 0x1f / 0x7a
Lion colorsryg / disabled / regularwin             0x17 / 0x22 / 0x72
numeric-only Lion diagnostic names                 misleading by dictionary reindexing

Snow titlebar-state implementation                 inline AppendState; dedicated helper absent
Lion titlebar-state implementation                 dedicated helper expected
analyzer-v1 Phase C failure                        analyzer modeling error, not Snow binary failure
exact crash pointer                                already proven
next step                                          rerun analyzer v2 on Snow, then run Lion static path-builder/helper audit
PPC subject rerun                                  NO
resource substitution                              NO
component remap                                    NOT YET
XNU                                                no change indicated
```
