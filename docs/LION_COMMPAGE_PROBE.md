# Lion translated-commpage probe

The phase-2 XNU patch restores a Snow Leopard-compatible PPC-facing commpage inside Lion's native 32-bit commpage mapping. Before executing another PPC process, verify that mapping from a native i386 executable.

## Build on Snow Leopard

Using the Xcode 3.2.6 toolchain already used for the PPC smoke test:

```sh
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
./scripts/build-lion-commpage-probe-on-snowleopard.sh ./lion-commpage-probe
```

The output must contain an i386 slice. Copy the resulting executable to Lion.

## Run after booting the phase-2 Lion kernel

```sh
./scripts/run-lion-commpage-probe.sh ./lion-commpage-probe
```

The probe never jumps into Rosetta. It uses Mach VM APIs to read its own commpage safely and checks:

- the restored mapping covers the Snow Leopard-compatible range;
- native Lion commpage version remains 12;
- translated PPC-view version is 11;
- `0xffff8020` is readable and contains the synthetic PPC capability word;
- translated cache-line size is 32;
- the PPC-view floating constants are present;
- signature data is present at `0xffff3000`;
- representative low and high branch-assist entries match the Snow Leopard table.

The desired final line is:

```
RESULT: PASS - Lion native ABI and Rosetta translated commpage are present
```

Only after this probe passes should the known-good `ppc-smoketest` be executed again.
