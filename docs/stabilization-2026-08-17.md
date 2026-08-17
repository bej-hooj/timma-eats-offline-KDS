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
