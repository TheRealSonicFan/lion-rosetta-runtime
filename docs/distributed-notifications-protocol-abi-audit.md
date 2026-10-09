# Distributed notifications v2/v3 protocol ABI audit

## Objective

Close the remaining static field-semantics gap before any process-local distributed-notifications bridge is implemented.

The preceding schema audit passed on both Snow Leopard and Lion and established the broad protocol families, but it also exposed two reasons not to build the bridge yet:

1. the earlier description of Snow's legacy Mach header was wrong — `0x1413` is `msgh_bits`, not the message ID; the actual client-to-server `msgh_id` is `4`;
2. analyzer v1 did not fully recover every stack-built Snow `CFDictionaryCreate` key/value vector or every PIC-relative Lion/Snow i386 protocol constant, so several option/token/callback semantics remain inferred rather than proven.

This audit is entirely static/read-only. Its purpose is to emit enough exact construction and dispatch context to finish a normalized v2-to-v3 mapping without guessing.

## Corrected Snow Mach envelope

The reviewed Snow PPC disassembly establishes the private envelope layout used by CoreFoundation:

```text
offset 0x00  mach_msg_header_t.msgh_bits
offset 0x04  mach_msg_header_t.msgh_size
offset 0x08  mach_msg_header_t.msgh_remote_port
offset 0x0c  mach_msg_header_t.msgh_local_port
offset 0x10  mach_msg_header_t.msgh_reserved
offset 0x14  mach_msg_header_t.msgh_id
offset 0x1c  private payload length
offset 0x20  private binary-plist payload
```

For client -> Snow `distnoted`:

```text
msgh_bits = 0x1413
msgh_id   = 4
```

For Snow `distnoted` -> client callback:

```text
msgh_bits = 0x13
msgh_id   = 4
```

Do not use the superseded statement that `0x1413` is a message ID.

## Reviewed Phase B analyzer-v1 failure

The returned Snow Leopard 10.6.8 Phase B report is a **validator defect, not a protocol contradiction**. The PPC slice, exact protocol constants, and every required target symbol were present, but the four Mach-header checks were reported as `NO` solely because analyzer v1 accidentally stored doubled backslashes in two raw regular expressions. Those expressions therefore searched for literal `\\b`, `\\s`, and `\\d` text instead of regular-expression word boundaries, whitespace, and digits.

The same report contains the exact instructions that the broken validator failed to recognize:

```text
client -> server:
0004d34c  li   r0,0x4
0004d358  stw  r0,0x14(r27)                  # msgh_id = 4
0004d378  li   r0,0x1413
0004d38c  stw  r0,__mh_dylib_header(r27)     # offset 0x00, msgh_bits = 0x1413

server -> client:
0004ee00  li   r0,0x4
0004ee0c  stw  r0,0x14(r30)                  # msgh_id = 4
0004ee1c  li   r0,0x13
0004ee24  stw  r0,__mh_dylib_header(r30)      # offset 0x00, msgh_bits = 0x13
```

Current analyzer **version 2** fixes the escaping error, accepts both `__mh_dylib_header(...)` and numeric zero spellings for the offset-`0x00` store, and emits the matched load/store instruction pair into the report so this gate is self-auditing. No protocol assumption or compatibility behavior changed.

After pulling current `main`, rerun **Snow Phase B only** and require `analyzer_version=2`, all six Mach-envelope observations to be `YES`, and `RESULT: PASS`. Do not proceed to Lion Phase C from the analyzer-v1 report.

## Prepared implementation

Current runtime `main` provides:

```text
scripts/audit-distributed-notifications-protocol-abi.py
docs/distributed-notifications-protocol-abi-audit.md
```

The analyzer is Python-2.6-compatible, reports `analyzer_version=2`, and performs no dynamic notification, bootstrap, Mach, MIG, or XPC operation.

### Snow Leopard coverage

The audit thins both:

- PPC CoreFoundation — the actual translated client implementation;
- i386 CoreFoundation — the implementation loaded into native Snow `distnoted`.

It emits exact protocol constant inventories and complete windows for:

```text
___CFXNotificationSendToServer
___CFXNotificationSendToClient
___CFXNotificationReceiveFromServer
___CFXNotificationReceiveFromClient
___CFXNotificationHandleMessage
__CFXNotificationPostNotification
__CFXNotificationPost
__CFXNotificationRegister
__CFXNotificationUnregister
__CFXNotificationSetSuspended
__CFXNotificationResetSessionForTask
```

For each function it additionally emits:

- resolved PPC/i386 PIC-relative constants;
- `CFDictionaryCreate` / `CFDictionarySetValue` construction contexts;
- any XPC call contexts, if present;
- the complete function body needed to reconstruct stack-built key/value arrays.

The PPC pass separately validates the corrected Mach-header observations for both directions.

The exact Snow vocabulary tracked by the audit includes:

```text
message_type
post
name
object
userinfo
counter
entry
ping
pong
client
sessionid
immediately
sux
behavior
entries
state
register
unregister
suspend
session_reset
```

### Lion coverage

The audit thins Lion i386 CoreFoundation and emits complete windows plus improved PIC-relative constant recovery for:

```text
__CFXNotificationRegisterObserver
__CFXNotificationPost
__CFXNotificationRemoveObservers
__CFXNotificationSetSuspended
__CFXNotificationResetSessionForTask
___CFXNotificationCenterCreate
___CFXNotificationCenterSetupConnection
_____CFXNotificationCenterSetupConnection_block_invoke_1
___CFXNotificationPostToken
_____CFXNotificationPostToken_block_invoke_1
```

Every XPC dictionary set/get, XPC array, and XPC send call found in those functions is emitted with a focused context window and any resolved nearby constant.

The Lion `distnoted` pass emits:

- all short cstrings with addresses;
- the exact protocol constant inventory;
- XPC/Mach/bootstrap/MIG imports;
- Objective-C metadata;
- all XPC protocol callsites with wider context and resolved constants.

The tracked Lion vocabulary includes:

```text
method
version
post
post_all
options
token
tokens
name
object
userinfo
register
unregister
suspend
unsuspend
post_token
ping
registrations
```

The analyzer also prints a normalized boundary section, but any line labeled as a candidate mapping remains a review aid rather than authorization to implement it.

## Safety constraints

For this stage:

- do not launch any PowerPC application;
- do not run a Rosetta subject;
- do not call `CFNotificationCenterGetDistributedCenter` or `NSDistributedNotificationCenter` dynamically;
- do not register, post, remove, suspend, or deliver any notification;
- do not issue a bootstrap lookup;
- do not send a Mach/MIG request;
- do not create or send an XPC request;
- do not create a synthetic legacy notification receive port;
- do not rerun the failed standalone `.2` lookup;
- do not rerun the retired native service-selection tracer;
- do not integrate a `.2 -> @Uv3` name rewrite;
- do not load a compatibility bridge into the normal Rosetta subject;
- do not call `CreateNewWindow`;
- do not restart, signal, unload, load, or modify `distnoted` or `launchd`;
- do not edit launchd plists;
- do not patch CoreFoundation, Foundation, HIToolbox, distnoted, libSystem, Rosetta, dyld, or any shared cache;
- do not broaden the existing Process Manager compatibility interposers;
- do not change XNU.

Temporary architecture slices are created only under the system temporary directory and removed on exit.

## Phase A — update runtime main

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm that both files exist:

```text
scripts/audit-distributed-notifications-protocol-abi.py
docs/distributed-notifications-protocol-abi-audit.md
```

## Phase B — Snow Leopard ABI audit

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-protocol-abi.py \
  ./distributed-notifications-protocol-abi-snowleopard.txt
```

Require:

```text
Created: ./distributed-notifications-protocol-abi-snowleopard.txt
No PowerPC application was launched and no system state was modified.
RESULT: PASS
```

The generated Snow report must begin with:

```text
analyzer_version=2
product_version=10.6.8
```

The report must also contain:

```text
client_to_server_msgh_bits_0x1413=YES
client_to_server_msgh_id_4_at_0x14=YES
client_to_server_payload_length_at_0x1c=YES
server_to_client_msgh_bits_0x13=YES
server_to_client_msgh_id_4_at_0x14=YES
server_to_client_payload_length_at_0x1c=YES
corrected_interpretation=0x1413_is_msgh_bits_not_msgh_id
```

If Phase B fails, stop and return only the Snow report.

## Phase C — Lion ABI audit

Only after Snow Phase B passes, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-protocol-abi.py \
  ./distributed-notifications-protocol-abi-lion.txt
```

Require the same completion messages and `RESULT: PASS`.

The Lion validation must retain:

```text
selected_lion_service=com.apple.distributed_notifications@Uv3
lion_distnoted_imports_mach_msg=NO
lion_distnoted_imports_bootstrap_lookup=NO
```

If either import changes to `YES`, do not infer compatibility; return the report for review.

## Phase D — return evidence and stop

Return only:

```text
distributed-notifications-protocol-abi-snowleopard.txt
distributed-notifications-protocol-abi-lion.txt
```

Stop after Phase D.

## Review questions

The next review must answer all of these before implementation:

1. What exact Snow dictionary keys and value types are constructed for `post`, `register`, `unregister`, `suspend`, and `session_reset`?
2. Which Snow fields are per-client identity, per-registration identity, delivery behavior, and immediate-delivery flags?
3. What exact Lion XPC keys and value types are emitted for `post`, `register`, `unregister`, `suspend`, and `unsuspend`?
4. How are Lion registration `token` values allocated, stored, removed through `tokens`, and returned in `post_token` callbacks?
5. Can Snow callback dictionaries be generated losslessly from Lion `post_token` callbacks using only state maintained inside one process-local bridge?
6. Can every Snow operation observed at the current CreateNewWindow boundary be mapped without fabricating server-global state or altering another process?

Only if all required request and callback semantics are statically closed should the following stage build a standalone proof-only bridge.

## Result interpretation

- **Complete request + callback mapping:** prepare a standalone process-local bridge proof with strict negative controls. Do not integrate it with CreateNewWindow yet.
- **Request mapping complete, callback/token semantics incomplete:** perform one more static discriminator or a narrowly scoped native payload-observation experiment for only the unresolved callback fields.
- **Any field meaning remains ambiguous:** do not guess. Refine the analyzer around the exact construction/dispatch branch.
- **Evidence of a native Lion legacy Mach path appears:** stop and review; do not continue with the assumed bridge architecture.

## Current boundary

```text
Snow service                                   -> com.apple.distributed_notifications.2
Lion selected service                          -> com.apple.distributed_notifications@Uv3
Snow request representation                    -> CF dictionary -> binary plist -> Mach envelope
Snow client->server msgh_bits / msgh_id        -> 0x1413 / 4
Snow server->client msgh_bits / msgh_id        -> 0x13 / 4
Lion representation                            -> XPC dictionaries / arrays
Lion callback                                  -> method=post_token, version=1
Lion distnoted Mach/bootstrap imports           -> none in schema-v1 report
name-only translation                          -> rejected
live bridge                                    -> not yet authorized
next step                                      -> static v2/v3 protocol ABI/field-semantics audit
```

No XNU change is indicated.
