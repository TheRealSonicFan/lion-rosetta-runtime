# ShowWindow titlebar ArtFile path-builder audit

## Status

Completed.

Both returned analyzer-v3 reports pass their provenance, component-dictionary, path-builder, and release-specific titlebar-state-structure gates.

Snow Leopard 10.6.8 / 10K549:

```text
analyzer_version=3
audit_contract=release-specific-titlebar-state-v3
coreui_slice_sha256=5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839
artfile_sha256=1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5
titlebar_state_strategy=INLINE_APPEND_STATE
titlebar_state_helper_expected=NO
titlebar_state_helper_present=NO
RESULT: PASS
```

Lion 10.7.5 / 11G63:

```text
analyzer_version=3
audit_contract=release-specific-titlebar-state-v3
coreui_slice_sha256=5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b
artfile_sha256=0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4
titlebar_state_strategy=HELPER
titlebar_state_helper_expected=YES
titlebar_state_helper_present=YES
RESULT: PASS
```

The supplied Snow report therefore does **not** contain a current Phase C failure. The earlier failures were analyzer-version/procedure issues and are superseded by these passing v3 reports.

## Established result

The titlebar prefix namespace shift is real and broader than the terminal `0xb6` token:

```text
Snow  Lion  semantic
a6    99    titlebarcontrols
13    14    close
14    15    closedirty
16    17    colorsryg
3b    3d    graphite
56    55    minimize
7a    72    regularwin
b6    a9    zoom
```

The close/minimize/zoom branches in both releases build the same high-level semantic families under release-specific numeric IDs, but the state implementation is structurally different: Snow performs titlebar state selection inline using `AppendState`, while Lion calls `AppendWindowTitlebarButtonState`.

`AppendWindowVariant` also shows a release-specific input-enum shift while retaining matching output semantics:

```text
Snow 0x14c -> utilwin.variant1
Snow 0x14d -> utilwin.variant2
Snow other -> regularwin

Lion 0x175 -> utilwin.variant1
Lion 0x176 -> utilwin.variant2
Lion other -> regularwin
```

This means a flat numeric component map or raw descriptor/state-value comparison is not justified.

## Next authoritative step

Proceed to:

```text
docs/pm-showwindow-artfile-titlebar-state-semantics-audit.md
scripts/audit-pm-artfile-titlebar-state-semantics.py
```

The next read-only audit compares the semantic state surface produced by Snow's inline titlebar logic plus `AppendState` against Lion's dedicated titlebar-state helper. It must complete before any live compatibility translator is designed.

Return exactly:

```text
pm-art-titlebar-state-snow.txt
pm-art-titlebar-state-lion.txt
```

## Safety boundary

- Do not rerun the PPC ShowWindow subject.
- Do not patch CoreUI or `ArtFile.bin`.
- Do not perform a global component-ID remap.
- Do not suppress the CoreUI diagnostic.
- Do not substitute Snow resources on Lion.
- Keep accepted Process Manager/CGS/notification adapters unchanged.
- Keep RawCamera and ShapeWindow held.
- Do not change XNU, rebuild the kernel, or reboot.

## Current boundary

```text
exact ArtFile crash mechanism                    PROVEN
full titlebar component namespace shift          PROVEN
Snow path-builder structure                      PROVEN
Lion path-builder structure                      PROVEN
variant output semantics                         equivalent by name
variant raw selector values                      release-specific
state semantic equivalence                       NOT YET PROVEN
live semantic translator                         NOT YET AUTHORIZED
XNU                                              no change indicated
```
