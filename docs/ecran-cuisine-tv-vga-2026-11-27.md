# S6-B · « Écran cuisine » — the kitchen kanban on a second LG TV (VGA) — 2026-11-27

> **Status (2026-11-27 late): B0–B7 BUILT and pushed on `feat/ecran-cuisine-2026-11-27` (`3610c79`), 172 tests green. B8: macOS visual check DONE (the black window was the preview fixture's duplicate line_no, not app code — board shows Nouvelles/En préparation/Prêtes read-only, no action/switch/mute). Windows CI run 46025232361 pending.** The §8 stage table is the only status
> source. Companion of `docs/tv-salle-windows-hdmi-2026-11-27.md` (S6, the
> dining-room TV — BUILT, proven on the HDMI TV by the owner 2026-11-27).
> Canon: `timmaeat-webapp/ECOSYSTEM.md` §25.3-b.
>
> **Audience: any coding agent, including a less capable one.** Every decision
> is taken; follow the cards in order. "Mirror X" = open X and copy its shape.

Read first: `~/Downloads/vibecoding coding code Prompt instructions rules Suffix (1).md`,
this repo's `CLAUDE.md`, the S6 doc above (its §2–§4 explain the surface
mechanism this stage generalises), then this file.

---

## 1 · What the owner asked (2026-11-27)

> « Afficher le kanban cuisine sur la deuxième télé LG… une TV devant pour les
> commandes et une TV derrière pour le kanban cuisine en grand. L'idéal : le KDS
> sur Windows juste pour encaisser, et sur Android l'utilisateur garde la
> cuisine. » — Alarm « sur la télé aussi si possible ».

Hardware (owner answers): laptop Core i3-4005U (Intel HD 4400 — 3 display
pipes), 4 GB RAM, **one HDMI** (already → front TV), **one VGA**, 4 USB. Back
TV is **15 m** away; it has **VGA in** and **« PC Audio In »** (3.5 mm) next
to it.

## 2 · The solution (decided)

| Screen | Link | Shows | Sound |
|---|---|---|---|
| Laptop screen | — | `timma_kds.exe` (no flag), view « Caisse paiement » | laptop speakers (default output) |
| Front TV (salle) | HDMI | `--surface=tv` — Écran salle (BUILT) | voice → HDMI audio device |
| **Back TV (cuisine)** | **VGA 15 m** + **3.5 mm 15 m** from a **USB sound card** → PC Audio In | **`--surface=kitchen-tv` — Écran cuisine**: the kitchen kanban, read-only, full-screen | **kitchen alarm → the USB sound card** |
| Android tablet (cuisine) | wifi | view « Cuisine » — the ONLY place cooks act | its own alarm |

Why a USB sound card: on most laptops a plug in the headphone jack mutes the
internal speakers, so the cashier's « À encaisser » alarm would go to the
kitchen. A USB card is a separate Windows output; the app sends the kitchen
alarm there explicitly (same native channel as the TV voice).

Why read-only: a TV is not touch, and two places acting on one ticket is how
double-advances happen. The tablet acts; the back TV mirrors within ~2–3 s
(both are boards paired to the borne and receive its snapshots).

**Software principle: a third surface of the same exe**, exactly like S6:
own flag, own store file, own pairing, own mutex, own window title,
full-screen on its own monitor. It REUSES the kitchen board screen
(`KdsBoardScreen`) in a read-only mode — no second kanban implementation.

## 3 · Behaviour (exact rules)

- Lanes = the « Cuisine » view: `KdsView.kitchen` (Programmées/Nouvelles/En
  préparation/Prêtes/En livraison as the tablet shows them). Forced: the TV
  writes meta `kds.view = kitchen` at start; no picker, no « Changer de vue ».
- **Read-only:** no primary action on cards, no delete, no « Couper
  l'alarme », no view switch. Tap-to-expand of a card may stay (harmless).
- **Alarm:** the existing `KdsAlarm` rules run unchanged (they already decide
  per view: the kitchen view rings the *waiting* register for Nouvelles, the
  *notice* register for new arrivals). Only the SINK changes: sound goes to the
  output chosen in the TV settings. It stops when the cook accepts the ticket
  on the tablet (lane empties) — there is no mute on the TV.
- **Monitor:** the window goes full-screen on its own monitor. Default = the
  LAST non-primary monitor (left→right), the Écran salle's default being the
  FIRST — so with laptop + HDMI + VGA they never collide. Overridable in
  settings (F2 → « Écran ») and remembered in the store (`screen.monitor`).
  The same override is added to the Écran salle (its F2).
- **Settings (F2 / double-click on the header logo):** « Écran » (monitor
  list), « Sortie son » (output list), « Tester l'alarme », « Fermer »,
  « Quitter l'écran cuisine ».
- Cursor hides after 3 s (mirror `TvScreen`). Screen kept awake (native).
- Size: at 1080p with Windows scaling 150 % the board gets 1280×720 logical,
  the layout it was designed for. Guide tells the owner to keep 150 % (or 125 %
  for more columns' room).

## 4 · File contract

### 4.1 Dart — changed

| File | Change |
|---|---|
| `lib/launch/kds_surface.dart` | `enum KdsSurface { kitchen, tv, kitchenTv }`; `kitchenTvFlag = '--surface=kitchen-tv'`; `kitchenTvStoreFile = 'kds-cuisine-tv.db'`; `parse` returns kitchenTv for that exact flag; `storeFileName` covers it; `bool isDisplay(KdsSurface)` = tv \|\| kitchenTv. |
| `lib/main.dart` | `KdsSurface.kitchenTv` → before `runApp`: `store.writeMeta(KdsViewController.metaKey, KdsView.kitchen)`; overrides: `kdsReadOnlyProvider.overrideWithValue(true)`, `kdsAlarmSinkProvider.overrideWith(...)` → `OutputAlarmSink` (Windows) else default; child builds `KitchenTvRoot`. Kitchen and TV paths unchanged. |
| `lib/kds/state/kds_board.dart` | add `final Provider<bool> kdsReadOnlyProvider = Provider<bool>((_) => false);` (doc comment: true only on the Écran cuisine). Nothing else. |
| `lib/kds/presentation/board_screen.dart` | read `kdsReadOnlyProvider`; when true: pass `onPrimaryAction: null`, `onDelete: null` to every `KdsTicketCard`; `_Header` gets `onMute: null` and `onSwitchView: null` and hides those buttons when null (check the current null handling at lines ~395/413/450 — today `onSwitchView` may already be nullable). Wrap the screen in the same F2 `CallbackShortcuts` + cursor-hide as `TvScreen` **only when read-only** — put that wrapper in a new widget (below), not inline. |
| `lib/tv/state/tv_settings_controller.dart` | add meta key `monitorKey = 'screen.monitor'` + `chooseMonitor(String?)`; `TvSettings.monitorId`. Reused by both display surfaces (each has its own store, so no clash). |
| `lib/tv/ports/tv_speech.dart` | add to the port: `Future<List<TvMonitor>> monitors(); Future<void> placeOnMonitor(String? id); Future<void> playSound(String asset, {String? outputId}); Future<void> stopSound();` + value class `TvMonitor {id, name, isPrimary, width, height}`. (Rename of the port is NOT done — keep `TvSpeech`; add a doc line "also the display surfaces' native window/sound port".) |
| `lib/tv/data/windows_tv_speech.dart` / `silent_tv_speech.dart` | implement the 4 methods (channel names `listMonitors`, `placeOnMonitor`, `playSound`, `stopSound`; silent = record calls). |
| `lib/tv/presentation/tv_settings_dialog.dart` | add the « Écran » dropdown (monitors) → `chooseMonitor` + `placeOnMonitor`. |
| `lib/tv/presentation/tv_root.dart` / `tv_screen.dart` | on first build after pairing, apply the stored monitor: `ref.read(tvSpeechProvider).placeOnMonitor(settings.monitorId)` (null = keep native default). Put this in a small `DisplayPlacement` widget shared by both surfaces (below). |
| `lib/l10n/app_fr.arb` + `app_en.arb` | keys in §5. |

### 4.2 Dart — new

| File | Responsibility / API |
|---|---|
| `lib/display/display_placement.dart` | `class DisplayPlacement extends ConsumerStatefulWidget { child }` — in `initState` post-frame: read `tvSettingsProvider.monitorId`, call `tvSpeechProvider.placeOnMonitor(id)` once. Used by TvRoot's screen and KitchenTvRoot. |
| `lib/display/display_chrome.dart` | `class DisplayChrome extends StatefulWidget { child, onOpenSettings }` — F2 `CallbackShortcuts` + autofocus `Focus` + cursor hide after `TvRules.cursorHideAfter`. Extract from `TvScreen` (then make `TvScreen` use it — no duplicate). |
| `lib/kitchen_tv/kitchen_tv_root.dart` | Mirror `TvRoot`: identity null → `KdsPairingScreen`; else `KdsApp(home: DisplayPlacement(child: DisplayChrome(onOpenSettings: …KitchenTvSettingsDialog.show, child: KdsBoardScreen())))`. Title via l10n `kitchenTvTitle`. |
| `lib/kitchen_tv/kitchen_tv_settings_dialog.dart` | Mirror `TvSettingsDialog`: « Écran », « Sortie son », « Tester l'alarme » (calls `kdsAlarmSinkProvider.ring(KdsAlarmRegister.waiting)` then `silence()` after 3 s), « Fermer », « Quitter l'écran cuisine ». No voice section. Shared dropdown widgets → extract `lib/display/widgets/output_dropdown.dart` and `monitor_dropdown.dart` and use them in BOTH dialogs. |
| `lib/kitchen_tv/output_alarm_sink.dart` | `class OutputAlarmSink implements KdsAlarmSink` — `ring(r)` → `speech.playSound(AudioAlarmSink.assetFor(r), outputId: settings.outputId)`; `silence()` → `stopSound()`; never throws (mirror AudioAlarmSink's catch). Constructor takes `TvSpeech` + `String? Function() outputId`. Make `AudioAlarmSink.assetFor` reachable (it exists — check visibility; if private, add a `static String assetFor(KdsAlarmRegister)` public, no behaviour change). |

### 4.3 Windows runner (C++)

| File | Change |
|---|---|
| `tv_surface.h/.cpp` → keep file names, generalise | `enum class Surface { kKitchen, kTv, kKitchenTv }`; `Surface ParseSurface(const wchar_t* cmd)` (`--surface=kitchen-tv` checked BEFORE `--surface=tv`? No: `wcsstr("--surface=kitchen-tv", "--surface=tv")` is false, both literals are distinct — still test both orders); mutex `Local\\TIMMA-KDS-kitchen-tv`; title `L"TIMMA Écran cuisine"`; `bool IsDisplay(Surface)`. `TargetMonitorRect(Surface)`: tv → first non-primary sorted by `rcMonitor.left`; kitchen-tv → LAST non-primary; fallback primary. New: `std::vector<MonitorInfo> ListMonitors()` ({device name `szDevice` from `MONITORINFOEXW`, primary, rect}); `void SetPreferredMonitor(const std::wstring& device)` stored in a static; `FillTargetMonitor` uses the preferred device when it still exists, else the default for the surface. |
| `main.cpp` | use `ParseSurface`; title/mutex per surface; `FlutterWindow(project, surface)`; display surfaces → `FillTargetMonitor` + `KeepDisplayAwake`. |
| `flutter_window.h/.cpp` | ctor takes `tv_surface::Surface`; register the channel for any display surface; DISPLAYCHANGE/DPICHANGED re-fill for any display surface. |
| `tv_speech_channel.h/.cpp` | new methods: `listMonitors` → `[{id,name,isPrimary,width,height}]` (main thread, no worker — Win32 only); `placeOnMonitor {id?}` → `SetPreferredMonitor` + `FillTargetMonitor(window_)` (main thread); `playSound {asset, outputId?}` → worker: `MediaSource::CreateFromStorageFile(exeDir + data\flutter_assets\assets\audio\<asset>)` played on the output (reuse `Play`); validate `asset` = `[a-z_]+\.wav` only (no path separators — path traversal guard) ; `stopSound` → sets an atomic flag the `Play` wait loop checks (stop current clip), main thread. |

### 4.4 Installer — `windows/installer/timma-cuisine.iss`

`#define KitchenTvName "TIMMA Écran cuisine"`, `#define KitchenTvFlag "--surface=kitchen-tv"`; tasks `kitchentvicon` (unchecked) and `kitchentvstartup` (unchecked); three `[Icons]` lines mirroring the Écran salle ones. AppId unchanged.

## 5 · l10n keys (fr / en)

| Key | fr | en |
|---|---|---|
| `kitchenTvTitle` | TIMMA Écran cuisine | TIMMA kitchen screen |
| `kitchenTvSettingsTitle` | Réglages de l'écran cuisine | Kitchen screen settings |
| `kitchenTvTestAlarm` | Tester l'alarme | Test the alarm |
| `kitchenTvQuit` | Quitter l'écran cuisine | Quit the kitchen screen |
| `displaySettingsMonitor` | Écran (choisir la télé) | Screen (choose the TV) |
| `displaySettingsDefaultMonitor` | Automatique | Automatic |
| `displaySettingsMainMonitorSuffix` | (écran principal) | (main screen) |

## 6 · Security self-audit

- No new network surface: the Écran cuisine is a LAN client like any board.
- Read-only enforced in the UI (`kdsReadOnlyProvider` nulls every action
  callback). Residual risk identical to S6 (paired as `kds`, hub would accept
  an intent if one were sent) — S6.9 `display` role covers both later.
- `playSound` accepts only a bare `*.wav` file name from the app's own
  `assets/audio/` (regex-checked natively) — no path traversal.
- Monitor ids come from the OS list; unknown id → surface default.
- No PII on the kitchen TV beyond what the tablet already shows (dish lines,
  ticket codes; kiosk orders carry no customer names).

## 7 · Owner setup (goes into `WINDOWS-CUISINE.md` §6 and the Claude Doc guide)

1. **Test gratuit d'abord** : télé arrière branchée en VGA (même câble court),
   télé avant toujours en HDMI → Paramètres → Système → Affichage : **3 écrans**
   → écran 3 « Étendre ces affichages ». Télé arrière : entrée **PC / RGB**.
2. Acheter : câble **VGA 15 m** avec ferrites ; câble **jack 3,5 mm 15 m** ;
   **carte son USB**.
3. Carte son USB sur le portable ; jack 15 m de la carte son → **PC Audio In**
   de la télé arrière. Son Windows : sortie par défaut = haut-parleurs du
   portable.
4. Affichage : télé arrière 1920 × 1080 (ou la meilleure proposée en VGA),
   mise à l'échelle 150 %.
5. Réinstaller `TIMMA-Cuisine-Setup.exe` (nouvelle version) en cochant
   **« Icône TIMMA Écran cuisine »** + **« Lancer l'écran cuisine au
   démarrage »**.
6. Ouvrir **TIMMA Écran cuisine** → appairer sur la borne (une fois).
7. F2 → **Écran** : la télé arrière ; **Sortie son** : la carte son USB →
   **Tester l'alarme** → Fermer.
8. Sur le portable, TIMMA Cuisine : « Changer de vue » → **Caisse paiement**.
   La tablette Android reste sur **Cuisine**.
9. Si l'Écran salle s'est ouvert sur la mauvaise télé : F2 sur la télé avant →
   Écran → la bonne.

## 8 · Stage table (only status source)

| # | Stage | Files | Status |
|---|---|---|---|
| B0 | Branch `feat/ecran-cuisine-2026-11-27` from `feat/tv-salle-2026-11-27` | — | ✅ |
| B1 | Surface `kitchenTv` (Dart enum, flag, store) + tests | `lib/launch/kds_surface.dart`, `test/tv/kds_surface_test.dart` | ✅ `008c7cf` |
| B2 | `kdsReadOnlyProvider` + board screen read-only + tests (no action callbacks, no mute/switch buttons) | `kds_board.dart`, `board_screen.dart`, `test/kitchen_tv/*` | ✅ `008c7cf` |
| B3 | Port extension (monitors, placement, playSound/stopSound) + silent/windows impl + `OutputAlarmSink` + tests | `lib/tv/ports`, `lib/tv/data`, `lib/kitchen_tv/output_alarm_sink.dart` | ✅ `8920689` |
| B4 | `lib/display/*` (chrome, placement, dropdowns) extracted; `TvScreen` uses `DisplayChrome`; TV settings get « Écran » | `lib/display/*`, `lib/tv/presentation/*` | ✅ `79540e7` |
| B5 | `KitchenTvRoot` + settings dialog + `main.dart` wiring + l10n + widget tests (1280×720, read-only, F2, alarm test → sink) | `lib/kitchen_tv/*`, `lib/main.dart`, arb | ✅ `79540e7` |
| B6 | Native: Surface enum, monitor list/preference, kitchen-tv mutex/title, channel methods, path guard | `windows/runner/*` | ✅ `3610c79` (CI pending) |
| B7 | Installer tasks/icons | `windows/installer/timma-cuisine.iss` | ✅ `3610c79` |
| B8 | Full suite + analyze; macOS visual check (temporary preview entrypoint, never committed); Windows CI run green | — | ⬜ |
| B9 | Docs: WINDOWS-CUISINE §6, this table, ECOSYSTEM §25.3-b, memory, Claude Doc guide section | docs | ⬜ |
| B10 | Publish 1.0.4 (2015) Setup + APK on `cuisine-win-20261123` — **owner yes first** | release | ⬜ |
| B11 | Owner hardware proof (§9 checklist) | — | ⬜ |

## 9 · Test plan

Automated (`flutter test > log 2>&1; echo test=$?` — never pipe to tail):
- `kds_surface_test`: `--surface=kitchen-tv` → kitchenTv; `--surface=tv` still
  tv; unknown → kitchen; store names distinct for all three.
- `kitchen_tv/read_only_board_test`: with `kdsReadOnlyProvider=true` a placed
  ticket shows, tapping its primary area does NOT change the store status; no
  « Couper l'alarme » / « Changer de vue » widgets; with false (kitchen) the
  same ticket advances (regression guard for the tablet).
- `kitchen_tv/output_alarm_sink_test`: ring(waiting) → `playSound('kds_waiting.wav', outputId: chosen)`;
  silence → `stopSound`; a throwing port does not throw out of the sink.
- `kitchen_tv/kitchen_tv_root_test`: unpaired → pairing screen; paired → board
  with kitchen lanes only (no « À encaisser »), F2 opens settings, « Tester
  l'alarme » rings the sink.
- `display/display_chrome_test`: F2 calls back; cursor hides after 3 s.
- TV regression: all `test/tv/*` stay green (TvScreen now uses DisplayChrome).
- Whole suite green (161 before this stage) + `flutter analyze` clean.
- Windows CI (`gh workflow run windows-build.yml -f ref=<branch>`), confirm
  the checkout SHA in the log.

Owner hardware checklist (after B10):
- [ ] 3 screens: caisse on laptop, Écran salle on front TV, Écran cuisine on back TV, each opens by itself after reboot.
- [ ] Back TV shows Nouvelles / En préparation / Prêtes, same tickets as the Android tablet, within 3 s.
- [ ] Tapping on the back TV does nothing; the tablet advances tickets and the back TV follows.
- [ ] New borne order (after payment) → kitchen alarm on the back TV speakers, stops when accepted on the tablet.
- [ ] The cashier's « À encaisser » sound stays on the laptop; the front-TV voice stays on the front TV.
- [ ] F2 « Écran » swaps a window to the other TV and it stays there after restart.
