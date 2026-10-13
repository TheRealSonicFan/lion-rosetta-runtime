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

The existing static disassemblies also show the same structural path-builder shape in both releases: titlebar branches call `CUIPath::AppendToken(s)`, then `AppendWindowVariant`, then `AppendWindowTitlebarButtonState`. Snow's titlebar branches visibly contain the Snow IDs; Lion's contain the corresponding Lion IDs. The new audit extracts only those exact regions plus both helper bodies so the remaining variant/state constants can be reviewed without another broad CoreUI dump.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-path-builder.py
```

Analyzer version:

```text
1
```

It is Python-2-compatible and read-only. On each release it:

1. verifies the exact OS build;
2. thins the local CoreUI framework to the accepted architecture;
3. verifies the previously accepted CoreUI slice SHA-256;
4. verifies the accepted local `ArtFile.bin` size/SHA;
5. decodes the local ArtFile dictionary and requires the seven titlebar semantics at the already-proven release-specific IDs;
6. extracts only the titlebar section of `CUIElement::CreateQSIImagePath`;
7. requires the known release-specific close/minimize/zoom/color/titlebar constants and helper calls to remain present;
8. emits the complete bodies of `CUIPath::AppendWindowVariant(long)` and `CUIPath::AppendWindowTitlebarButtonState(long,long,long)`;
9. marks which of the seven semantic IDs appear as immediates in each helper;
10. modifies nothing outside its temporary architecture slice.

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
product_version=10.6.8
required_arch=ppc7400
semantic=titlebarcontrols id=0xa6
semantic=close id=0x13
semantic=colorsryg id=0x16
semantic=disabled id=0x1f
semantic=minimize id=0x56
semantic=regularwin id=0x7a
semantic=zoom id=0xb6
RESULT: PASS
```

## Phase D — Lion path-builder audit

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-path-builder.py \
  ./pm-art-titlebar-path-lion.txt
```

Require:

```text
product_version=10.7.5
required_arch=i386
semantic=titlebarcontrols id=0x99
semantic=close id=0x14
semantic=colorsryg id=0x17
semantic=disabled id=0x22
semantic=minimize id=0x55
semantic=regularwin id=0x72
semantic=zoom id=0xa9
RESULT: PASS
```

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

### Variant/state helpers differ structurally

If `AppendWindowVariant` or `AppendWindowTitlebarButtonState` changed more than their component constants, stop before a live shim. The next step must model the semantic state/variant transformation rather than apply a flat byte map.

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
exact crash pointer                                already proven
next step                                          static titlebar path-builder/helper audit
PPC subject rerun                                  NO
resource substitution                              NO
component remap                                    NOT YET
XNU                                                no change indicated
```
