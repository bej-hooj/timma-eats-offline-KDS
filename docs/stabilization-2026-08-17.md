# KDS coordination plan — 2026-08-17

Written before any source edit. Plan of record:
`timmaeat-app-flutter/docs/kiosk-stabilization-2026-08-17.md`.

This repository is a coordinated consumer during the kiosk print/secret pass:

- extend the KDS vault to persist an atomic paired bundle: the device credential, hub metadata and
  AES-256-GCM-wrapped branch collection secret opened only after hub-proof verification. The
  existing vault currently stores only `DeviceCredential`; it does not yet satisfy this contract;
- prove a collection code printed before a hub restart still verifies afterward, and that multiple
  KDS pairings receive the same branch secret while retaining distinct device credentials;
- keep lane/status semantics, `pending_payment`, alarm-register separation and French real-width
  regressions unchanged;
- update the exact `pos_*` git pin together with the POS repo if and only if the shared contract
  changes, then run analyze/tests/build in both tablet repositories.
- replace the fresh-database `readIdentity()!` crash with an explicit loading/unprovisioned/ready
  bootstrap. Compose snapshot ingress and outbox egress before claiming that board actions reach a
  hub; at plan time neither LAN nor relay is wired into production.
- render line items, quantities, variants/modifiers/notes and a stable order code. Gate completion
  on a collection HMAC that resolves to the exact local ready order; at plan time the direct
  `ready -> completed` tap is not safe for release.
- add release Android network/multicast and iOS local-network/Bonjour declarations and prove both
  build modes. The LAN credential and the server device key used for relay-token fetching are
  separate authorities and must be provisioned/stored separately.

No schema, migration, edge function, token hex or private design color belongs here. The known
`PosOrder.fire_at` omission remains a blocker for scheduled-order branches until its shared
pos_core/store migration is separately implemented. Check the branch before every commit, stage
explicit paths only, and never `git add -A`.

Proofs for this pass are initially unchecked: KDS baseline tests/analyze, pairing-secret restart
regression, coordinated pin parity, Android build, and any available device smoke. Hardware-only
K9, printer, two-network, device-owner and Guided Access proofs must be labelled blocked unless run.

## RESULT — 2026-08-17, session 2 (device-proven)

Pin bumped to `ea872ac` in lockstep with the kiosk (`cb10f4d` here, `6c82491` there). Both tablets
speak the same wire; a split pin is a protocol mismatch waiting to happen.

- [x] analyze clean, **28/28** (25 at the start, plus three bootstrap tests)
- [x] the unpaired-tablet bootstrap replaces `store.readIdentity()!`, which crashed a fresh install
      before `runApp` — proven on the Samsung, which renders "Tablette non appariée"
- [x] release APK builds and carries INTERNET / ACCESS_NETWORK_STATE / ACCESS_WIFI_STATE /
      CHANGE_WIFI_MULTICAST_STATE, verified with `aapt2 dump permissions` against the binary. Before
      this only the debug and profile manifests had INTERNET, injected by the Flutter tool — so the
      relay, the socket to the hub and mDNS discovery would all have failed in a release build while
      passing every debug smoke.
- [x] iOS `NSLocalNetworkUsageDescription` + `NSBonjourServices` for `_timma-pos._tcp`; without them
      Bonjour returns nothing forever and reads as "hub offline" rather than raising anything
- [x] French copy at three real tablet widths — the first version of the bootstrap screen overflowed
      by 14 px at 1280 × 800, caught by its own test before it ever reached a device
- [ ] two-tablet pairing/board drill — **hardware-blocked**, one device available
- [ ] collection-code verification at `ready → completed` — still not built (see below)

### Still open here

The board still does not render kitchen line items, does not drain its outbox, and does not verify a
slip's collection code before completing. Those are composition stages, not bug fixes, and the
isolated green suite is **not** operational evidence. `PosOrder` still has no `fire_at`, so the
scheduled lane cannot fill: do not point this board at a branch taking scheduled orders.
