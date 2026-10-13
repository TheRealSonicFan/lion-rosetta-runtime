# ShowWindow titlebar ArtFile state-semantics audit

## Objective

Determine whether Snow Leopard's translated-PPC titlebar state construction and Lion's native titlebar state construction produce the same **semantic** CoreUI ArtFile components under their release-specific component namespaces.

The completed titlebar path-builder audit establishes:

- both Snow Leopard and Lion reports use analyzer v3 and exact accepted CoreUI/ArtFile provenance;
- both reports complete `RESULT: PASS`;
- Snow builds titlebar button state inline with `CUIPath::AppendState`;
- Lion factors the same stage into `CUIPath::AppendWindowTitlebarButtonState(long,long,long)`;
- both releases use semantic-equivalent titlebar prefix components under different IDs;
- both releases use `AppendWindowVariant`, but its raw selector constants differ between releases.

This means the remaining blocker before any live translation experiment is the **state/variant semantic transform**, not the already-proven prefix namespace shift.

## Accepted path-builder evidence

Snow 10.6.8 / 10K549:

```text
analyzer_version=3
audit_contract=release-specific-titlebar-state-v3
titlebar_state_strategy=INLINE_APPEND_STATE
titlebar_state_helper_expected=NO
titlebar_state_helper_present=NO
AppendWindowVariant calls=4
AppendState calls=7
RESULT: PASS
```

Lion 10.7.5 / 11G63:

```text
analyzer_version=3
audit_contract=release-specific-titlebar-state-v3
titlebar_state_strategy=HELPER
titlebar_state_helper_expected=YES
titlebar_state_helper_present=YES
AppendWindowVariant calls=3
AppendWindowTitlebarButtonState calls=3
RESULT: PASS
```

The variant helper is already semantically suggestive:

```text
Snow selector 0x14c -> utilwin.variant1
Snow selector 0x14d -> utilwin.variant2
Snow other          -> regularwin

Lion selector 0x175 -> utilwin.variant1
Lion selector 0x176 -> utilwin.variant2
Lion other          -> regularwin
```

The output semantics match by name, while the raw selector numbers do not. Therefore no compatibility design may compare or translate descriptor/state inputs by raw Snow-versus-Lion numeric equality.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-state-semantics.py
```

Analyzer version:

```text
2
```

Audit contract:

```text
titlebar-state-semantics-v2
```

The analyzer is Python-2-compatible and read-only. On each release it:

1. verifies the exact OS build, CoreUI thin-slice SHA-256, and local `ArtFile.bin` size/SHA;
2. decodes the local component dictionary by semantic name;
3. checks the titlebar prefix semantic surface, including `titlebarcontrols`, `close`, `closedirty`, `colorsryg`, `graphite`, `minimize`, and `zoom`;
4. validates the release-specific `AppendWindowVariant` selector structure and reports the semantic selector mapping above;
5. emits the complete `AppendWindowVariant` body;
6. emits the complete generic `AppendState` body;
7. on Snow, combines the inline titlebar-state branch/continuations with the generic `AppendState` body;
8. on Lion, emits the complete `AppendWindowTitlebarButtonState` body;
9. reports the presence of semantic state components `active`, `activenokey`, `disabled`, `inactive`, `key`, `pressed`, and `rollover`;
10. modifies nothing outside a temporary architecture slice.

The semantic-presence flags are evidence aids, not a substitute for reviewing the helper control flow. A matching immediate appearing somewhere in a helper does **not** by itself prove the same logical input produces that semantic output.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not attach GDB to a live process.
- Do not patch CoreUI or any ArtFile.
- Do not translate component bytes yet.
- Do not globally remap arbitrary CoreUI IDs.
- Do not suppress CoreUI diagnostics.
- Do not substitute Snow resources on Lion.
- Keep all accepted Process Manager/CGS/notification compatibility adapters unchanged.
- Keep RawCamera and ShapeWindow held.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update runtime on both systems

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

LOCAL_HEAD="$(git rev-parse HEAD)" || exit 1
REMOTE_HEAD="$(git rev-parse origin/main)" || exit 1

echo "local_head=$LOCAL_HEAD"
echo "origin_main=$REMOTE_HEAD"

test "$LOCAL_HEAD" = "$REMOTE_HEAD" || {
  echo "ERROR: local runtime main is not current origin/main"
  exit 1
}

SCRIPT=./scripts/audit-pm-artfile-titlebar-state-semantics.py

/usr/bin/grep -q '^ANALYZER_VERSION = "2"$' "$SCRIPT" || {
  echo "ERROR: expected analyzer version 2"
  exit 1
}

/usr/bin/grep -q '^AUDIT_CONTRACT = "titlebar-state-semantics-v2"$' "$SCRIPT" || {
  echo "ERROR: unexpected analyzer contract"
  exit 1
}
```

Do not proceed if Phase A fails.

## Phase B — syntax-check

On both systems:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-titlebar-state-semantics.py","rb").read(),"audit-pm-artfile-titlebar-state-semantics.py","exec")' || exit 1
```

## Phase C — Snow Leopard semantic-state audit

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-state-semantics.py   ./pm-art-titlebar-state-snow.txt
```

Require at minimum:

```text
analyzer_version=2
audit_contract=titlebar-state-semantics-v2
product_version=10.6.8
required_arch=ppc7400
titlebar_state_strategy=INLINE_APPEND_STATE
titlebar_state_helper_expected=NO
titlebar_state_helper_present=NO
variant_selector_0x14c=utilwin.variant1
variant_selector_0x14d=utilwin.variant2
variant_selector_other=regularwin
RESULT: PASS
```

## Phase D — Lion semantic-state audit

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-state-semantics.py   ./pm-art-titlebar-state-lion.txt
```

Require at minimum:

```text
analyzer_version=2
audit_contract=titlebar-state-semantics-v2
product_version=10.7.5
required_arch=i386
titlebar_state_strategy=HELPER
titlebar_state_helper_expected=YES
titlebar_state_helper_present=YES
variant_selector_0x175=utilwin.variant1
variant_selector_0x176=utilwin.variant2
variant_selector_other=regularwin
RESULT: PASS
```

## Phase E — return evidence

Return exactly:

```text
pm-art-titlebar-state-snow.txt
pm-art-titlebar-state-lion.txt
```

Do not return CoreUI or ArtFile binaries.

## Review gates

### Variant semantics agree, state semantics agree

If the two reports show that release-specific selector/state values lead to the same semantic component names for the titlebar paths of interest, the next stage may design a **narrow process-local semantic path translator** between Snow-PPC path construction and Lion ArtFile consumption.

That translator must be constrained to proven titlebar path shapes and the exact accepted Lion ArtFile provenance. It must not be a global numeric dictionary remap.

### Variant semantics agree, state semantics differ

Stop before a live shim. Model the exact state transformation first; do not manufacture Lion state components from Snow numeric values.

### A semantic present in one release is absent in the other

Stop before translation. Identify the native Lion replacement path shape rather than inventing a component.

### Static provenance or analyzer validation fails

Return the reports unchanged and stop. Do not rerun the PPC subject.

## Current boundary

```text
component namespace shift                       PROVEN
Snow/Lion titlebar prefix semantics             equivalent by name, IDs differ
Snow titlebar state implementation              inline AppendState
Lion titlebar state implementation              dedicated helper
Snow variant selectors                          0x14c / 0x14d
Lion variant selectors                          0x175 / 0x176
variant semantic outputs                        utilwin.variant1 / utilwin.variant2 / regularwin
state semantic mapping                          NOT YET PROVEN
live component translation                      NOT YET AUTHORIZED
PPC subject rerun                               NO
CoreUI/ArtFile patch                            NO
XNU                                             no change indicated
```
