# Distributed notifications bridge preflight audit

## Objective

Choose the executable architecture for the first standalone distributed-notifications bridge proof and close the last option/token semantics before any compatibility code is run.

The completed analyzer-v2 ABI reports now provide enough structure to define the bridge state model, but they expose one implementation question that must be answered before writing the live proof: the translated Snow Leopard client is PowerPC, while Lion's selected `com.apple.distributed_notifications@Uv3` endpoint is reached through XPC. An in-process bridge is only viable if the translated PPC address space has a callable PPC XPC provider. If Lion's XPC implementation is i386/x86_64-only, the proof must instead use a deliberately narrow native i386 broker/helper and a separate local IPC contract to the translated PPC side.

This audit is static/read-only. It also emits the exact public/private CoreFoundation windows needed to finish the remaining option mappings.

## Reviewed ABI result

Both analyzer-v2 reports pass.

### Snow legacy envelope

The Snow PPC client uses:

```text
client -> server:
  msgh_bits = 0x1413
  msgh_id   = 4
  payload length at +0x1c
  binary-plist payload at +0x20

server -> client:
  msgh_bits = 0x13
  msgh_id   = 4
  payload length at +0x1c
  binary-plist payload at +0x20
```

### Snow request state that is now grounded

Static construction and server-side parsing together establish the following legacy dictionaries.

```text
post:
  message_type = post
  client       = process name
  sessionid    = current-session identifier, or all-session sentinel
  immediately  = boolean derived from post option bit 0
  sux          = legacy compatibility boolean
  name         = notification name
  object       = optional object string
  userinfo     = optional property-list dictionary

register:
  message_type = register
  client       = process name
  sessionid    = session identifier
  counter      = 32-bit registration counter
  entry        = 64-bit representation of the client registration entry identity
  behavior     = 32-bit internal suspension-behavior flags
  name         = notification name / any-name sentinel
  object       = optional object string / any-object sentinel

unregister:
  message_type = unregister
  client       = process name
  sessionid    = session identifier
  entries      = array of the legacy registration-entry identities selected locally
  behavior     = selection behavior flags
  name         = selection name
  object       = selection object

suspend:
  message_type = suspend
  client       = process name
  sessionid    = session identifier
  state        = boolean suspended state

session_reset:
  message_type = session_reset
  client       = process name
  sessionid    = replacement session identifier
```

The Snow callback consumer `___CFXNotificationHandleMessage` accepts a `message_type=post` dictionary containing `name`, `object`, optional `userinfo`, plus `counter` and `entry`. Those two registration identifiers are therefore the information a bridge must restore when translating a Lion callback back to the unchanged Snow PPC client.

### Lion v3 request/callback state that is now grounded

The Lion i386 implementation sends XPC dictionaries with `version=1`.

```text
register:
  method  = register
  version = 1
  name    = string
  object  = string
  options = uint64
  token   = uint64

post:
  method   = post
  version  = 1
  name     = string
  object   = string
  userinfo = optional XPC data containing serialized property-list data
  options  = uint64

unregister:
  method  = unregister
  version = 1
  tokens  = XPC array of uint64 registration tokens

suspend / unsuspend:
  method  = suspend or unsuspend
  version = 1

callback:
  method   = post_token
  version  = 1
  token    = uint64
  name     = string
  object   = optional string
  userinfo = optional XPC data
```

Lion's `__CFXNotificationResetSessionForTask` is not a general v3 equivalent of Snow's `session_reset`: it verifies the executable is `loginwindow`, sends `method=i_am_loginwindow`, waits for a reply, and may consume a `registrations` array. The first ordinary-client bridge proof must therefore reject `session_reset` rather than invent an unproven translation.

### Candidate bridge state model

The ABI evidence supports this stateful translation model, subject to the remaining option checks:

```text
Snow register
  (entry, counter, behavior, name, object)
        |
        | allocate one bridge-owned uint64 token
        v
Lion register
  (token, options, name, object)

Snow unregister entries[]
        |
        | look up stored tokens
        v
Lion unregister tokens[]

Lion post_token callback
  (token, name, object, userinfo)
        |
        | look up stored Snow entry + counter
        v
Snow callback post
  (entry, counter, name, object, userinfo)
```

This means no server-global registration identity needs to be fabricated. The bridge only needs state for registrations originating inside the translated client it serves.

Three points remain to be closed before implementation:

- whether Snow's internal `behavior` bit mask can be passed directly as Lion `options`, or requires a small deterministic conversion;
- how Snow `immediately` plus all-session `sessionid` semantics map to Lion post `options` bits, and whether the legacy `sux` field has any semantic effect that must survive translation;
- whether PPC code on Lion has any callable XPC provider at all. If not, the proof architecture must use a native i386 broker/helper.

## Prepared implementation

Current runtime `main` provides:

```text
scripts/audit-distributed-notifications-bridge-preflight.py
docs/distributed-notifications-bridge-preflight-audit.md
```

The analyzer is Python-2.6-compatible and static/read-only.

It inspects:

- the relevant Snow PPC or Lion i386 CoreFoundation slice;
- public `CFNotificationCenterAddObserver` and `CFNotificationCenterPostNotificationWithOptions` paths;
- the private request, suspension, reset, callback, and registration functions that feed the v2/v3 protocols;
- `/usr/lib/libSystem.B.dylib`, `/usr/lib/libSystem.dylib`, and known `libxpc` locations;
- architecture slices for PPC, i386, and x86_64;
- whether a PPC slice, if present, exports a usable `xpc_connection_create` plus XPC send surface.

The report does not create an XPC connection. Symbol presence and architecture compatibility are the only XPC tests in this stage.

## Safety constraints

For this stage:

- do not launch any PowerPC application;
- do not run the Rosetta subject;
- do not call a notification-center API dynamically;
- do not create or send an XPC message;
- do not issue a bootstrap lookup or Mach request;
- do not register, post, remove, suspend, or deliver a notification;
- do not create the synthetic legacy notification port yet;
- do not build or launch a native broker/helper yet;
- do not rerun the failed legacy `.2` lookup;
- do not rerun the retired native service-selection tracer;
- do not load a compatibility dylib into the real PPC subject;
- do not retry `CreateNewWindow`;
- do not restart, signal, unload, load, or modify `distnoted` or `launchd`;
- do not patch CoreFoundation, Foundation, HIToolbox, libSystem, Rosetta, dyld, a shared cache, or XNU.

Temporary architecture slices are created only under the system temporary directory and removed on exit.

## Phase A — update runtime main

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-distributed-notifications-bridge-preflight.py
docs/distributed-notifications-bridge-preflight-audit.md
```

## Phase B — Snow Leopard preflight

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-bridge-preflight.py \
  ./distributed-notifications-bridge-preflight-snowleopard.txt
```

Require:

```text
Created: ./distributed-notifications-bridge-preflight-snowleopard.txt
No PowerPC application was launched and no system state was modified.
RESULT: PASS
```

The report must begin with:

```text
analyzer_version=1
product_version=10.6.8
```

If Phase B fails, stop and return only the Snow report.

## Phase C — Lion preflight

Only after Snow passes, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/python ./scripts/audit-distributed-notifications-bridge-preflight.py \
  ./distributed-notifications-bridge-preflight-lion.txt
```

Require:

```text
Created: ./distributed-notifications-bridge-preflight-lion.txt
No PowerPC application was launched and no system state was modified.
RESULT: PASS
```

The Lion report will include:

```text
== Bridge architecture discriminator ==
ppc_callable_xpc_surface=YES|NO
candidate_bridge_architecture=...
remaining_semantic_checks=...
mapping_status=PREFLIGHT_ONLY_DO_NOT_BUILD_BRIDGE_YET
```

Do not interpret `ppc_callable_xpc_surface=NO` as a failure. It is the main architecture discriminator.

## Phase D — return evidence and stop

Return only:

```text
distributed-notifications-bridge-preflight-snowleopard.txt
distributed-notifications-bridge-preflight-lion.txt
```

Stop after Phase D.

## Decision gate

After the two reports are reviewed:

- If Lion exposes a real PPC-callable XPC create/send surface and the option mapping is exact, prepare an **in-process standalone bridge proof**.
- If Lion has no PPC-callable XPC provider, prepare a **native i386 broker proof** with one minimal local IPC channel to the PPC side. The broker may translate only the proven register/post/unregister/suspend/callback schema and must reject `session_reset`.
- If `behavior/options`, post option bits, or `sux` remain ambiguous, refine only those exact static callsites before any bridge is executed.
- Do not integrate either bridge architecture with `CreateNewWindow` until a standalone register -> post -> callback -> unregister proof passes with strict negative controls.

## Current boundary

```text
Snow v2 wire                                  -> binary plist in Mach envelope
Lion v3 wire                                  -> XPC dictionaries/arrays
register identity bridge candidate            -> Snow (entry,counter) <-> bridge token
unregister bridge candidate                   -> Snow entries[] -> Lion tokens[]
callback bridge candidate                     -> Lion post_token -> Snow post + stored entry/counter
Snow session_reset                            -> no ordinary Lion v3 equivalent; reject in first proof
Lion native reset path                        -> loginwindow-only i_am_loginwindow handshake
remaining semantic gate                       -> behavior/options + post options + sux
remaining implementation gate                 -> PPC-callable XPC surface vs native i386 broker
next step                                     -> static bridge preflight audit
```

No XNU change is indicated.
