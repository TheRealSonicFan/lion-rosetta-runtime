# PPC Carbon GUI CoreUI window-frame frame-ID relocation audit

## Status

COMPLETED STATIC PASS.

The accepted Snow report and regenerated Lion analyzer-v2 report jointly prove the active frame-ID relocation contract:

```text
Snow 0x4e8d -> Lion 0x4e75
Snow 0x4e8e -> Lion 0x4e76
Snow 0x4e8f -> Lion 0x4e77
Snow 0x4e90 -> Lion 0x4e78
Snow 0x4e91 -> Lion 0x4e79
```

The renderer-role order is preserved exactly:

```text
Snow: 0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91
Lion: 0x4e76,0x4e78,0x4e75,0x4e77,0x4e79
```

and every Lion target is consumed by native Lion
`CUIRenderer::CreateInternalImageWithScale(long,CUIDescriptor const*,CGRect*)`.

The next controlled step is
`docs/ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary-audit.md`.

## Observed result

Snow remains the healthy PPC renderer reference:

```text
five active records
type=2
count=1
slot0=11x11
provider_length=484
RESULT: PASS
```

Lion's mapped records are all:

```text
type=1
count=2
slot0=11x11 / 484 bytes
slot1=22x22 / 1936 bytes
```

The regenerated Lion report resolves all five numeric `calll 0x00004944`
instructions through the exact CoreUI symbol table and reports
`callee_match=YES`.

Three slot-0 providers remain byte-identical across releases:

```text
0x4e8d -> 0x4e75
0x4e8e -> 0x4e76
0x4e90 -> 0x4e78
```

The `0x4e8f -> 0x4e77` and `0x4e91 -> 0x4e79` mappings are
semantic/renderer-role relocations; their Lion pixels changed.

## Why an ID-only mapping is still not authorized

Snow-PPC `CUISharedArtReader::CreateImage(long,float)` treats type-2 records
as slot-0 raw images, so the healthy Snow frame renderer always obtains the
11x11 representation.

The same Snow-PPC reader, when pointed at Lion type-1/count-2 records, can
select slot 1 on its high-scale branch. The completed Lion live trace already
demonstrated that behavior on the old IDs by producing larger raw images.

Therefore the proven ID relocation is necessary but not sufficient. Any
compatibility rule must also preserve the old renderer's 11x11 slot-0
semantics without rewriting Lion resources or copying Snow pixels.

## Safety constraints

- Do not launch the PPC subject for the next audit.
- Do not build or load a new compatibility dylib yet.
- Do not add the five-ID mapping yet.
- Do not force slot 0 yet.
- Do not alter scale values yet.
- Do not patch SArtFile metadata or copy Snow image bytes.
- Retain the exact-six titlebar semantic-key translation and exact-six
  bitmap-info adapter unchanged.
- Do not change CGContext state, hit masks, classic part codes, mouse routing,
  control actions, or CGS policy.
- Do not modify XNU, rebuild the kernel, or reboot.

## Current boundary

```text
Snow relocation audit                            PASS
Lion relocation audit v2                         PASS
renderer-role relocation                         PROVEN
mapping range                                    legacy 0x4e8d..0x4e91 -> Lion 0x4e75..0x4e79
Lion slot0                                       11x11 / 484 for all five
Lion slot1                                       22x22 / 1936 for all five
exact-byte anchors                               3
semantic-only changed-pixel mappings             2
ID-only mapping                                  NOT AUTHORIZED
slot0 forcing                                    NOT AUTHORIZED
next step                                        static slot0 compatibility-boundary audit
XNU                                              no source change indicated
```
