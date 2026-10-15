# PPC Carbon GUI CoreUI window-frame slot-0 compatibility-boundary audit

## Status

NEXT CONTROLLED STATIC STEP after the frame-ID relocation audit proved the
complete five-ID semantic relocation and showed that every Lion target has a
11x11 slot 0 plus a 22x22 slot 1.

The compatibility problem is now narrower than resource discovery:

```text
legacy 0x4e8d..0x4e91 -> Lion 0x4e75..0x4e79
```

is proven, but the old Snow-PPC shared-art reader must still be prevented from
turning those Lion type-1/count-2 records into slot-1 images.

This audit identifies the smallest safe implementation boundary before any new
compatibility dylib is written.

## Objective

On Snow Leopard only, statically inspect the exact PPC CoreUI binary that is
also the accepted Rosetta-cache runtime contract on Lion.

The analyzer emits complete bodies and call inventories for:

```text
_CUICreateImage(long,CUIDescriptor const*,float)
CUISharedArtReader::CreateImage(long,float)
CUISharedArtReader::CreateImageFromBytes(long,long)
CUISharedArtReader::CreateImageSource(long)
CUISharedArtReader::CreateImageProvider(long)
CUISharedArtReader::GetImageHeader(long)
```

It also emits every direct reference to
`CUISharedArtReader::CreateImage(long,float)`.

The review must answer four questions:

1. Is the shared-reader call reached by a direct internal branch, or through a
   boundary that an inserted dylib can safely interpose?
2. Which external CoreGraphics/ImageIO API is the earliest practical boundary
   for the raw branch?
3. Which external API in the ImageIO branch still has enough caller context to
   recover the original legacy image ID before that ID is overwritten?
4. Can one exact-five adapter return Lion slot-0 images while leaving every
   non-target image and every accepted compatibility rule untouched?

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary.py
Git blob 7dc68e88b0dd5378a5fbe8632dc6e421f5c0ba5f
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-coreui-windowframe-slot0-compat-boundary-v1
```

Pinned Snow PPC CoreUI:

```text
10.6.8 / 10K549 / ppc7400
5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839
```

## Safety constraints

- Static only; do not launch the PPC subject.
- Do not run this analyzer on native Lion CoreUI; the compatibility target is
  the accepted Snow-PPC CoreUI runtime image.
- Do not build or load a new compatibility dylib.
- Do not add the five-ID mapping.
- Do not force slot 0 or alter scale.
- Do not modify SArtFile, ArtFile, ArtFile200, CoreUI, HIToolbox, or the
  Rosetta cache.
- Do not copy Snow image bytes.
- Retain the exact-six semantic-key translation and exact-six
  `bitmapInfo 0x2 -> 0x2002` adapter unchanged.
- Do not alter CGContext state, hit masks, part codes, mouse routing, CGS
  compatibility, or XNU.

## Phase A — update and pin

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary.py)" = \
  "7dc68e88b0dd5378a5fbe8632dc6e421f5c0ba5f" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-slot0-compat-boundary-v1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary.py","rb").read(),"audit-slot0-boundary.py","exec")' || exit 1
```

## Phase B — Snow static boundary report

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary.py \
  ./ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
coreui_slice_exact=YES
runtime_on_lion_contract=accepted_exact_snow_ppc_coreui_cache
id_only_remap_safe=NO
slot0_compat_boundary_audit_exact=YES
RESULT: PASS
```

## Review gate

### A direct internal reader call is not safely interposable, but external raw and ImageIO boundaries retain enough target context

Design the next guarded adapter around those external APIs only. It must map
exactly five IDs, construct only Lion slot-0 images, preserve all original
non-target calls, and have a Snow passthrough control before one Lion run.

### A stable interposable boundary exists before type/slot selection

Prefer that boundary if it can change only the exact five IDs and select slot
0 without patching CoreUI code or resource memory.

### The ImageIO path loses the legacy ID before every external boundary

Do not implement a guessed adapter. The next step becomes a trace-only
per-thread correlation experiment at the earliest external source/provider
boundary.

### Any required symbol/body differs from the pinned Snow contract

Stop and resolve the binary mismatch before compatibility work.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-slot0-compat-boundary-snow.txt
```

## Current boundary

```text
five-ID semantic relocation                     PROVEN
Lion slot0                                       11x11 / 484 for all five
Lion slot1                                       22x22 / 1936 for all five
old PPC type1 high-scale behavior                can select slot1
ID-only remap                                    insufficient
new adapter                                      NOT YET DESIGNED
next step                                        static implementation-boundary audit
PPC subject                                      DO NOT RUN
XNU                                              no source change indicated
```
