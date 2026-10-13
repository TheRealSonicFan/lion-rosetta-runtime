# ShowWindow titlebar ArtFile state-semantics audit

## Status

Completed.

Both corrected analyzer-v3 reports pass exact release provenance and the release-specific titlebar-state structure checks.

Snow Leopard 10.6.8 / 10K549:

```text
analyzer_version=3
audit_contract=titlebar-state-semantics-v3
titlebar_state_strategy=INLINE_APPEND_STATE
titlebar_state_helper_expected=NO
titlebar_state_helper_present=NO
state_input_primary_source=arg5-or-descriptor+0x18
state_input_primary_default=0xa3
state_input_dedicated_titlebar_secondary=NONE
state_semantic_active=YES
state_semantic_activenokey=NO
state_semantic_disabled=YES
state_semantic_inactive=YES
state_semantic_key=YES
state_semantic_pressed=YES
state_semantic_rollover=YES
RESULT: PASS
```

Lion 10.7.5 / 11G63:

```text
analyzer_version=3
audit_contract=titlebar-state-semantics-v3
titlebar_state_strategy=HELPER
titlebar_state_helper_expected=YES
titlebar_state_helper_present=YES
state_input_primary_source=arg5-or-descriptor+0x28
state_input_primary_default=0xad
state_input_dedicated_titlebar_secondary=descriptor+0x2c
state_semantic_active=YES
state_semantic_activenokey=YES
state_semantic_disabled=YES
state_semantic_inactive=YES
state_semantic_key=YES
state_semantic_pressed=YES
state_semantic_rollover=YES
RESULT: PASS
```

## Established result

The titlebar state models are related but not identical.

Snow's titlebar path builder has no dedicated secondary titlebar-state input and never emits the `activenokey` component from the audited titlebar state surface. Lion adds descriptor+`0x2c` as a dedicated titlebar-state input and its dedicated helper can emit `activenokey` in addition to the semantic states shared with Snow.

The shared emitted semantic set is:

```text
active
disabled
inactive
key
pressed
rollover
```

Their component IDs remain release-specific:

```text
semantic      Snow   Lion
active        0x01   0x01
disabled      0x1f   0x22
inactive      0x41   0x43
key           0x46   0x48
pressed       0x6f   0x67
rollover      0x82   0x77
activenokey   —      0x03
```

This closes the emitted-state surface audit but does **not** yet prove transition equivalence, because Lion's additional titlebar-secondary input can change which semantic component is emitted for the same primary-state family.

## Next authoritative step

Proceed to:

```text
docs/pm-showwindow-artfile-titlebar-state-transition-audit.md
scripts/audit-pm-artfile-titlebar-state-transitions.py
```

Run the new read-only transition/provenance audit once on Snow Leopard and once on Lion and return exactly:

```text
pm-art-titlebar-state-transition-snow.txt
pm-art-titlebar-state-transition-lion.txt
```

The transition audit enumerates Snow's titlebar-state outputs across primary/window-variant states and decodes Lion's native titlebar helper jump tables across primary, dedicated-secondary, and window-variant states. Only after those transition tables are compared should a translated-path feasibility audit be considered.

## Safety boundary

- Do not rerun the PPC ShowWindow subject.
- Do not patch CoreUI or any ArtFile.
- Do not install a new titlebar path interposer yet.
- Do not globally remap CoreUI component IDs.
- Do not suppress diagnostics.
- Do not substitute Snow resources on Lion.
- Keep accepted Process Manager/CGS/notification adapters unchanged.
- Keep RawCamera and ShapeWindow held.
- Do not change XNU, rebuild the kernel, or reboot.

## Current boundary

```text
titlebar prefix namespace shift                  PROVEN
window-variant semantic reindex                 PROVEN
Snow emitted-state surface                      PROVEN
Lion emitted-state surface                      PROVEN
Snow activenokey titlebar emission              absent
Lion activenokey titlebar emission              present
Snow dedicated titlebar-secondary input         NONE
Lion dedicated titlebar-secondary input         descriptor+0x2c
exact state transition correspondence           NOT YET PROVEN
translated Lion ArtFile path feasibility        NOT YET TESTED
live path translator                            NOT YET AUTHORIZED
XNU                                             no change indicated
```
