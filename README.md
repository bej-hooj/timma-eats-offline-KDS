# TIMMA — kitchen display (offline KDS)

The tablet in the kitchen. It keeps showing and advancing tickets **with the WAN unplugged**, driven
by the kiosk hub over the restaurant's LAN — and over a cloud relay when the two tablets are not on
one network.

The web KDS survives as the manager's remote view; it cannot be given an offline mode, because it is
a Blade page rendered on a VPS and polled. With the WAN down it shows a browser error, not a stale
board. That is why this app exists.

```bash
flutter run          # the board
flutter test         # 25 tests
```

## Where everything lives — four repos, one database

| Repo | Owns |
|---|---|
| `timmaeat-app-flutter` | The customer phone app. **SCHEMA OWNER**: every migration, every edge function, and the four `pos_*` packages this repo depends on. |
| `timmaeat-webapp` | Dashboard + landing. Home of **`ECOSYSTEM.md`** (canon for anything spanning repos) and **`design-tokens/tokens.json`** (the one colour/spacing source). |
| `timma-eats-offline-POS` | The self-order kiosk — a customer tablet at the door that is **also the store hub**. |
| `timma-eats-offline-KDS` | The kitchen board — a tablet that keeps working with the WAN unplugged. |

### Why the engine is not in here

`pos_core` (money, outbox, status guard), `pos_link` (LAN + relay transport), `pos_link_flutter`
and `pos_cloud` stay in `timmaeat-app-flutter` and are consumed here as **pinned git
dependencies**.

Both tablet apps need the same engine. Two copies of `pos_core` would mean a ticket behaving
differently depending on which tablet touched it — and `pos_cloud` calls the kiosk RPCs directly,
so an engine one git hop from the migrations it is written against is exactly how those two drift.
One engine, two apps, no fork.

**Bumping the pin is a deliberate edit to `pubspec.yaml`, and the POS and KDS repos should be
bumped together** — they speak the same wire, and a version skew between them is a tablet that
cannot pair.

### Why the design layer is copied, and why that is not a fork

`lib/design/` mirrors `timmaeat-webapp/design-tokens/tokens.json`, which is the single source
ECOSYSTEM §15.5 names. The phone app's `AppColors` is *already* a derived mirror of that file — so
this is a third consumer of one source, not a second source. **Sync from `tokens.json`, never
edit a hex here.**

## The one rule this app must never lose

**A lane is a presentation choice. A transition is a state-machine fact.**

The board draws `accepted` in the *Preparing* lane, so a lane-keyed advance map once offered those
cards `preparing → ready` — a move the state machine does not have. The RPC refused it
**permanently** (the status never changed, so a refresh could not help) and the whole kitchen board
was stuck. `KdsLane.advanceFor` is keyed on **status**, and a test walks every status × mode pair
asserting the board can never offer a move `StatusGuard` would refuse.

`pending_payment` has **no** advance at all — it is *settled*, not advanced. Offering a cook an
advance button on an unpaid ticket is how food leaves the building without being paid for.

## This app never writes order state to Supabase

Every action goes through the hub (§23.2). Over the relay it sends *the same envelope addressed to
the hub*, and the hub applies it and remains the only writer. A relay is a postal service, not a
second author.

## Plan and stage results

`docs/pos-kiosk-kds-offline-2026-08-15.md` is the plan of record (K0–K10); `docs/kiosk-k5-kds-2026-08-16.md`
carries this stage's results.
