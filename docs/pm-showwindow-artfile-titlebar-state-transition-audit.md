# ShowWindow titlebar ArtFile state transition/provenance audit

## Status

Completed.

Both analyzer-v1 reports pass exact release/CoreUI/ArtFile provenance and the transition-model validation.

Snow Leopard 10.6.8 / 10K549:

```text
analyzer_version=1
audit_contract=titlebar-state-transition-v1
primary_source=arg5-or-descriptor+0x18
primary_default=0xa3
titlebar_secondary_used=NO
RESULT: PASS
```

Lion 10.7.5 / 11G63:

```text
analyzer_version=1
audit_contract=titlebar-state-transition-v1
primary_source=arg5-or-descriptor+0x28
primary_default=0xad
titlebar_secondary_source=descriptor+0x2c
titlebar_secondary_used=YES
special_jump_table_address=0x41bb8
regular_jump_table_address=0x41bd8
RESULT: PASS
```

## Established neutral-state correspondence

For Lion's neutral/other titlebar-secondary class, the complete Snow primary-state table maps exactly to Lion by a constant primary-selector shift:

```text
Snow primary  Lion primary  regularwin  variant1/variant2
0xa3          0xad          active      key
0xa4          0xae          disabled    disabled
0xa5          0xaf          active      active
0xa6          0xb0          inactive    active
0xa7          0xb1          active      active
0xa8          0xb2          pressed     pressed
0xa9          0xb3          active      active
0xaa          0xb4          rollover    rollover
```

Therefore:

```text
Lion primary = Snow primary + 0x0a
```

for the complete audited Snow titlebar primary range `0xa3..0xaa`, and every emitted semantic state matches under `regularwin`, `variant1`, and `variant2` when Lion's dedicated secondary input is neutral.

Lion's additional secondary classes remain real extra distinctions:

- `0xb7` can force `key` for special utility variants and changes some regular-window outputs;
- `0xb8` can produce Lion-only `activenokey` for regular windows and `active` for utility variants;
- `0xb9` can force `inactive`;
- the dedicated helper still preserves its hard overrides for `disabled`, `pressed`, and `rollover`.

These are additive Lion-native state distinctions, not a failure of the neutral Snow-to-Lion correspondence.

## Consumer-boundary consequence

The Snow titlebar builder resolves its state before `CUIElement::LoadFromArtFile(const unsigned char*)` receives the final eight-byte component path. At that consumer boundary, the descriptor-state inputs—including Lion's extra secondary state—are no longer required to identify the exact semantic state represented by the Snow path itself.

That is sufficient to proceed to a **narrow translated-path feasibility audit** for only the three exact crash-time titlebar paths. It is not sufficient to authorize a global component map or a live interposer.

## Next authoritative step

Proceed to:

```text
docs/pm-showwindow-artfile-titlebar-translated-path-feasibility.md
scripts/audit-pm-artfile-titlebar-translated-paths.py
```

Run that read-only audit once on Snow Leopard and once on Lion and return exactly:

```text
pm-art-titlebar-translated-paths-snow.txt
pm-art-titlebar-translated-paths-lion.txt
```

The new audit parses the actual legacy `ArtFile.bin` lookup-record array used by Snow-PPC `LoadFromArtFile`, uses Snow as a positive control for the three captured paths, and asks whether their semantic-equivalent Lion keys are real Lion lookup records with valid payload references.

## Safety boundary

- Do not rerun the PPC ShowWindow subject.
- Do not patch CoreUI or any ArtFile.
- Do not install a titlebar interposer yet.
- Do not globally remap CoreUI IDs.
- Do not suppress diagnostics.
- Do not substitute Snow resources on Lion.
- Keep accepted Process Manager/CGS/notification adapters unchanged.
- Keep RawCamera and ShapeWindow held.
- Do not change XNU, rebuild the kernel, or reboot.

## Current boundary

```text
titlebar prefix namespace shift                  PROVEN
window-variant semantic reindex                 PROVEN
Snow/Lion neutral state correspondence           PROVEN
Snow primary -> Lion primary                    +0x0a for 0xa3..0xaa
Lion extra secondary state distinctions         additive and preserved
final Snow path carries emitted state semantic  YES
Lion semantic-equivalent index keys             NOT YET TESTED
live path translator                            NOT YET AUTHORIZED
XNU                                             no change indicated
```
