# The board's link, and the alarm — 2026-08-18/19

Result doc for the pass that made an order placed on the borne appear in the
cuisine and make a noise. Written after the work, against what actually ran.

## What was wrong

Three things, and all three passed every test in the repo.

**1. The board never opened a socket.** `KdsPairingController` ran the
handshake, wrote the identity, the credential and the branch secret, and
dropped into service. Nothing constructed a `LanSocketTransport`. Every
sentence in the plan about the kitchen receiving orders described a connection
no code created, so a kitchen paired correctly by a manager who did everything
right sat in front of empty lanes for ever. The reverse direction was missing
too: `PosEngine.advance` queues an envelope addressed to the hub, and nothing
drained that queue, so a cook tapping *Prêt* moved a row in a database no other
device would ever read.

**2. Pairing remembered who, never where.** Identity, credential and branch
secret were persisted; the hub's address was not. A restarted board came back
fully provisioned with nowhere to connect.

**3. The alarm was rules attached to nothing.** `KdsAlarm` had two registers,
two seen-sets and its own test group. No code constructed one, and there was no
sound. `kdsMuteAlarm` and `kdsAlarmMuted` had been written and translated and
were unreachable.

And on the kiosk side, found on the devices during this pass:

**4. The sale was announced to nobody.** `kioskBoardPublisherProvider` was
overridden in a **child** `ProviderScope`. Riverpod 3 does not re-instantiate a
provider in a child scope merely because it reads an overridden one, so
`kioskSessionProvider` — which lives in the root container — read the default
no-op. The call site had a test; the test built one container and overrode at
its root, which is the shape that works.

## What now exists

- `lib/kds/link/kds_link.dart` — `KdsLinkController`: snapshots down through
  `BoardSnapshot.applyTo`, an `OutboxDrain` up over the same socket, mDNS
  rediscovery bounded to 8 s, and `KdsHubAddress` in store meta.
- `lib/kds/audio/kds_alarm_sink.dart` — `AudioAlarmSink` over `audioplayers`,
  iOS `AVAudioSessionCategory.playback` (the silent switch cannot mute a
  kitchen), Android `AndroidUsageType.alarm`. `RecordingAlarmSink` for tests.
  The provider defaults to the **real** sink: a default of silence is how a
  board ships mute.
- `tool/make_alarm_sounds.py` — generates the two tones. 880/1320 Hz alternating
  for *waiting*, a soft falling pair for *notice*.
- Board wiring: every read evaluates the alarm, including the reads an arriving
  snapshot causes. *Couper l'alarme* silences the run, never the next order.
- An offline badge in the header, because a board that has lost the kiosk looks
  exactly like a board with no orders.

## Proven on hardware — Pixel emulator (borne) + iPhone 16e simulator (cuisine)

The two run on one Mac, so the LAN hop is `adb forward tcp:8801 tcp:8801`: the
simulator shares the host's network stack and dials `127.0.0.1:8801`, which the
emulator answers on its own 8801.

| Step | Result |
|---|---|
| Manager PIN → *Apparier une cuisine* → six digits | ok |
| Cuisine: manual address, `/health` names the borne, code accepted | ok, `peer_count: 1`, `link: "lan"` |
| Order rung on the borne | reached the cuisine **live**, `À encaisser` 1 → 2, no reconnect in between |
| The alarm | *Couper l'alarme* appears on arrival |
| Cuisine app relaunched | reconnected with no re-pairing, and received the backlog |
| Screen off and back | socket still up |
| 15-minute unpaid sweep | fired on the board, reported as one summary line |

Not yet driven on the devices: a cook's transition travelling back to the borne
(proven in `test/kds_link_test.dart` over a real socket, on real frames), and
the offline phase with the wifi box.

## Defects found on the devices during the run, and fixed

- The attract screen overflowed by 77 px behind the manager keypad — it sizes
  itself off the height it is given, and the Scaffold was resizing for a
  keyboard the screen does not own. Fixed both ways (no resize for that stage,
  and the column can no longer overflow at any height).
- The PIN dialog then fitted, legally, with *Annuler* and *Ouvrir* below the
  fold of its own scroll view. Now compact when the room is short.
- A stale pairing code reported **"Borne injoignable. Vérifiez le wifi"** while
  the borne's own screen said **"Code expiré"**. The hub does distinguish the
  cases; the board collapsed them.

## Still open

1. **The branch-secret conflict has no ceremony.** Re-pair a kitchen to a kiosk
   whose branch secret changed — which is what happens when a kiosk is replaced
   or reinstalled — and `BranchCollectionSecretVault.writeOnce` throws
   `collection_secret_conflict`. The board reports *"Impossible d'enregistrer la
   clé de sécurité sur cette tablette"*, which blames the tablet for a conflict
   it did not cause, and there is **no way out from the UI**: on iOS the
   keychain survives an app uninstall. The vault's own doc says rotation
   "requires an explicit recovery ceremony" — that ceremony was never built. A
   supervised pairing (a human read six digits off that kiosk's screen) is the
   authorisation it needs. The fix belongs in `pos_link_flutter` in the app
   repo and therefore moves the pinned commit in **both** tablet repos.
   Hit during this run; worked around with `simctl keychain … reset`.
2. **`LanPairingClient` leaks its connect failure to the zone.** It completes
   its own future correctly, so the UI is right, but `WebSocketChannel.connect`
   also reports to the zone where nothing observes it — which fails a Dart test
   outright. `test/kds_pairing_handshake_test.dart` guards around it and says so.
3. Board content: line items, modifiers and notes are still not rendered, and a
   slip's collection code is not verified before completing.
4. `PosOrder` has no `fire_at`, so the *Programmées* lane cannot fill and the
   *notice* register cannot sound.
