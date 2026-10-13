# ShowWindow titlebar ArtFile state transition/provenance audit

## Objective

Resolve the remaining semantic gap between Snow Leopard's translated-PPC titlebar state logic and Lion's native titlebar-state helper before any live ArtFile path translation is attempted.

The corrected semantic-state analyzer v3 now proves:

- Snow Leopard 10.6.8 / 10K549 passes exact CoreUI and ArtFile provenance;
- Lion 10.7.5 / 11G63 passes exact CoreUI and ArtFile provenance;
- Snow's titlebar path uses inline `AppendState` and emits `active`, `disabled`, `inactive`, `key`, `pressed`, and `rollover`, but does not emit `activenokey`;
- Lion's dedicated `AppendWindowTitlebarButtonState` can emit all of those plus `activenokey`;
- Snow obtains the primary state from arg5 or descriptor+`0x18`, defaulting to `0xa3`, and has no dedicated titlebar-secondary input;
- Lion obtains the primary state from arg5 or descriptor+`0x28`, defaulting to `0xad`, and additionally passes descriptor+`0x2c` as a dedicated titlebar-secondary input.

Therefore the state model is not a simple numeric reindex. The next discriminator must enumerate the exact release-specific state transitions.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-state-transitions.py
```

Analyzer:

```text
analyzer_version=1
audit_contract=titlebar-state-transition-v1
git_blob=d84109343e8d7673d384dab11542bf8906d34a38
```

The analyzer is read-only and Python-2-compatible. It verifies exact OS/CoreUI/ArtFile provenance and then:

1. rechecks the accepted `CreateQSIImagePath` state-input setup;
2. on Snow, models the exact titlebar branch plus `AppendState(mask=0xab,fallback=active)` for primary selectors `0xa3..0xaa` and the regular/`0x14c`/`0x14d` window-variant classes;
3. on Lion, reads the two position-independent jump tables embedded in `AppendWindowTitlebarButtonState` directly from the accepted i386 CoreUI slice;
4. resolves the Lion helper's primary-selector transitions for `0xad..0xb4`, dedicated secondary selectors `0xb7`/`0xb8`/`0xb9`, and regular/`0x175`/`0x176` variant classes;
5. maps every emitted component back to its local ArtFile semantic name;
6. emits the complete helper disassembly and the decoded transition rows so the two reports can be compared by semantic output rather than raw numeric values.

This stage does not run the translated subject and does not change any framework, ArtFile, compatibility adapter, Rosetta cache, service, or kernel state.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not attach a debugger to a live process.
- Do not patch CoreUI or `ArtFile.bin`.
- Do not install a new interposer yet.
- Do not globally remap CoreUI component IDs.
- Do not suppress the CoreUI diagnostic.
- Do not substitute Snow resources on Lion.
- Keep accepted Process Manager/CGS/notification adapters unchanged.
- Keep RawCamera and ShapeWindow held.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update and preflight on both systems

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

SCRIPT=./scripts/audit-pm-artfile-titlebar-state-transitions.py

test "$(git hash-object "$SCRIPT")" = "d84109343e8d7673d384dab11542bf8906d34a38" || {
  echo "ERROR: titlebar transition analyzer is stale or locally modified"
  exit 1
}

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' "$SCRIPT" || {
  echo "ERROR: expected analyzer version 1"
  exit 1
}

/usr/bin/grep -q '^AUDIT_CONTRACT = "titlebar-state-transition-v1"$' "$SCRIPT" || {
  echo "ERROR: unexpected analyzer contract"
  exit 1
}
```

Do not proceed if Phase A fails.

## Phase B — syntax-check

On both systems:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-titlebar-state-transitions.py","rb").read(),"audit-pm-artfile-titlebar-state-transitions.py","exec")' || exit 1
```

## Phase C — Snow Leopard transition audit

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-state-transitions.py   ./pm-art-titlebar-state-transition-snow.txt
```

Require at minimum:

```text
analyzer_version=1
audit_contract=titlebar-state-transition-v1
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
primary_source=arg5-or-descriptor+0x18
primary_default=0xa3
titlebar_secondary_used=NO
RESULT: PASS
```

The report must include transition rows for primary selectors `0xa3..0xaa` under `regularwin`, `variant1`, and `variant2`.

## Phase D — Lion transition audit

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-state-transitions.py   ./pm-art-titlebar-state-transition-lion.txt
```

Require at minimum:

```text
analyzer_version=1
audit_contract=titlebar-state-transition-v1
product_version=10.7.5
build_version=11G63
required_arch=i386
primary_source=arg5-or-descriptor+0x28
primary_default=0xad
titlebar_secondary_source=descriptor+0x2c
titlebar_secondary_used=YES
special_jump_table_address=0x41bb8
regular_jump_table_address=0x41bd8
RESULT: PASS
```

The report must include all decoded jump-table targets and transition rows for primary selectors `0xad..0xb4`, secondary classes `other`/`key`/`active`/`inactive`, and `regularwin`/`variant1`/`variant2`.

## Phase E — return evidence

Return exactly:

```text
pm-art-titlebar-state-transition-snow.txt
pm-art-titlebar-state-transition-lion.txt
```

Do not return CoreUI or ArtFile binaries.

## Review gates

### Snow transitions are a semantic subset of Lion transitions

If every Snow titlebar-state semantic produced for the relevant window variants has an exact Lion semantic counterpart and the Lion-only `activenokey` paths are additive rather than replacements for Snow semantics, the next stage may move to a **translated-path feasibility audit** against Lion's ArtFile. That stage should verify that the semantic Snow titlebar paths, rewritten to Lion component IDs, are actual Lion archive lookup candidates before any live interposer is introduced.

### Lion's secondary state changes the meaning of a Snow-equivalent primary state

If the same apparent primary-state family yields different semantics depending on Lion descriptor+`0x2c`, do not collapse that distinction. Record the transition table and determine whether Snow's final path already carries enough semantic information to translate safely at the path-consumer boundary.

### Jump-table decode fails or produces an unknown target

Return both reports unchanged and stop. Do not guess the missing transition and do not run the PPC subject.

### A Snow semantic has no Lion component counterpart

Stop before any translator. Resource substitution and component synthesis remain out of scope.

## Current boundary

```text
titlebar prefix namespace shift                  PROVEN
window-variant semantic reindex                 PROVEN
Snow emitted-state surface                      PROVEN
Lion emitted-state surface                      PROVEN
Snow dedicated titlebar-secondary input         NONE
Lion dedicated titlebar-secondary input         descriptor+0x2c
exact state transition correspondence           NOT YET PROVEN
translated Lion ArtFile path feasibility        NOT YET TESTED
live path translator                            NOT YET AUTHORIZED
PPC subject rerun                               NO
CoreUI/ArtFile patch                            NO
XNU                                             no change indicated
```
