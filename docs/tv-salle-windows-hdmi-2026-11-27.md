# S6 · Dining-room TV on the kitchen's Windows PC + LG TV over HDMI — 2026-11-27

> **Status (2026-11-27): BUILT on branch `feat/tv-salle-2026-11-27` (S6.1–S6.8); Windows proof on the owner's PC + LG TV pending (S6.10–S6.11).** This file is the plan, the file
> contract and the task cards. The stage table in §9 is the only status source;
> tick it as you go. Canon: `timmaeat-webapp/ECOSYSTEM.md` §25.3.
>
> **Audience: any coding agent, including one less capable than the one that
> wrote this.** Every decision is taken. Do not redesign; follow the cards in
> order. When a card says "mirror X", open X and copy its structure.

Read first, in order:
1. `~/Downloads/vibecoding coding code Prompt instructions rules Suffix (1).md` (owner's global rules).
2. This repo's `CLAUDE.md` (§0 prime directives, §11 security).
3. This file, top to bottom.
4. `timma-eats-offline-POS/docs/roles-tv-logo-sync-2026-11-25.md` §G and "Session 3" (the TV behaviour the owner decided).
5. `docs/WINDOWS-CUISINE.md` (how the Windows build and installer ship today).

---

## 1 · What the owner asked (2026-11-27)

> « On veut vraiment implémenter l'affichage des commandes prêtes sur la TV LG.
> Je n'ai pas de box android et voici le matériel que j'ai : l'ordinateur
> Windows sur lequel le KDS exe est installé, la télé LG, un câble HDMI.
> Faisons que cela puisse fonctionner. Même s'il faut modifier le code. La
> solution idéale. »

Behaviour already decided by the owner (2026-11-25, Session 3 — do not re-ask):
1. Voice announces BOTH « en préparation » and « prête ».
2. A « Prêt » number stays **3 minutes** on screen.
3. While several are ready, the TV **rotates** announcements: « Commande XXXX
   est prête » + the ticket code spelled + **the dishes and drinks on it**.
4. Voice always on (no chime-only mode).
5. Several TVs possible (each one paired independently, like several KDS).
6. **Kiosk orders only** (`source = kiosk`). App/web customers follow their
   order in the app.

## 2 · The solution (decided)

**The LG TV becomes the Windows PC's second screen over HDMI ("Étendre" /
Extend mode). The same `timma_kds.exe` is started a second time with the
argument `--surface=tv`; that second process opens full-screen on the TV and
shows the customer display (« Écran salle »).** The kitchen board keeps
running untouched on the PC's own screen.

```
            Restaurant wifi / LAN (unchanged)
   ┌──────────────┐   signed LAN frames   ┌────────────────────────────────────┐
   │ Borne (hub)  │ ───────────────────▶  │ Windows PC                         │
   │ only Supabase│ ◀── KDS intents ───── │  process 1: timma_kds.exe          │
   │ writer       │                       │   → PC monitor, « Cuisine » board  │
   └──────────────┘ ───────────────────▶  │   store kds.db, alarm → PC speakers│
                     read-only feed       │  process 2: timma_kds.exe          │
                                          │     --surface=tv                   │
                                          │   → LG TV (HDMI, extended desktop) │
                                          │   store kds-tv.db, voice → TV (HDMI│
                                          │   audio device, chosen explicitly) │
                                          └────────────────────────────────────┘
```

### Why this and not something else

| Option | Verdict |
|---|---|
| **Second process of the same exe, `--surface=tv`, full-screen on monitor 2** | ✅ **Chosen.** Reuses pairing, LAN link, offline store, lanes, l10n and the installer. No new server, works with the WAN down (§23). One codebase, one installer, one update. |
| One process, two windows (Flutter multi-window) | ❌ Flutter's multi-window API is still experimental on 3.47; each window is a separate engine anyway, so it costs IPC for nothing. |
| LG webOS built-in browser opening a page served on the LAN | ❌ No reliable auto-start, screen-saver/auto-off fights, uncertain speech support, and it needs an HTTP server on the LAN exposing orders (new attack surface). The owner also has no box, but has the HDMI cable — HDMI is the direct path. |
| Mirror ("Dupliquer") the PC screen | ❌ The cooks' board and the customers' screen are different things; customers must not see the kitchen board. |

### Three problems this design must solve (and how)

1. **Two processes on one PC must not share a store.** Process 1 uses
   `kds.db`; the TV process uses `kds-tv.db`. Each has its own pairing
   identity (`PosIds.newDeviceId()` is random, so no clash) and pairs to the
   borne once, exactly like a second KDS. A named-mutex **single-instance
   guard per surface** stops two kitchen boards (or two TVs) writing the same
   file — today nothing stops a cook double-clicking the icon twice.
2. **The TV must open on the TV, not on the PC screen.** The Windows runner
   picks the monitor: with `--surface=tv` it chooses the first **non-primary**
   monitor (falls back to the primary one if only one is connected, so the
   owner can still see it) and makes a borderless full-screen window over that
   monitor's rectangle. Screen-sleep is blocked for that process.
3. **The voice must come out of the TV, the kitchen alarm out of the PC.**
   Windows sends all sound to one default device, and its per-app routing is
   keyed by the exe path — both processes are the same exe, so it cannot tell
   them apart. So the TV process does **not** use `audioplayers`/default
   output: it speaks through a small **native Windows channel**
   (`timma/tv_speech`, C++/WinRT `SpeechSynthesizer` + `MediaPlayer` with
   `AudioDevice` set to the device the manager picked, e.g. « LG TV (Intel
   Display Audio) »). The choice is stored in the TV store meta and survives
   restarts. Kitchen process: unchanged (`AudioAlarmSink`, default device).

## 3 · What the TV shows and says (exact rules)

Constants live in `lib/tv/domain/tv_rules.dart` (no literal elsewhere).

- **Source filter:** `order.source == PosOrderSource.kiosk` only.
- **Column « En préparation » (amber):** status in
  `{placed, accepted, preparing}`. ⚠ Recommendation applied (owner rule
  "go with my recommendation"): `placed` is included — a customer who just
  paid must see their number at once, not only after a cook taps it. ECOSYSTEM
  §25.3 is updated to say so.
- **Column « Prêt — à récupérer » (green):** status `ready` and
  `now − statusChangedAt < readyVisibleFor` (**3 min**). It also leaves at
  once when the order goes terminal (`completed`, `cancelled`, …) — the store's
  `openOrders()` already excludes those.
- **Order inside a column:** oldest first in *En préparation*
  (`placedAtDevice`), newest first in *Prêt* (`statusChangedAt` desc).
- **Overflow:** at most `maxPerColumn` (constant, 12 at 1080p) tiles; extra
  tiles are not shown (a TV that scrolls is unreadable) — the oldest *Prêt*
  ones drop first.
- **Highlight:** a ticket that became ready less than `highlightFor`
  (**10 s**) ago is drawn enlarged/pulsing.
- **Tile:** ticket label only (`order.ticketLabelOrNull ?? order.dailyCode ??
  order.orderCode`) in very large type — **no dishes, no prices, no names on
  screen** (privacy; the dishes are only spoken).
- **Header:** TIMMA wordmark (`assets/branding/logo_inline.png`), clock
  (Africa/Douala via `TimeUtil`), and an *offline* dot when the LAN link is
  down (mirror the KDS board's badge).

Voice (French — the restaurant's language, like the KDS):
- **Entering « En préparation »** (first time a `clientId` is seen in that
  column): « Commande A, D, 4, 5, en préparation. »
- **Becoming ready:** chime, then « Commande A, D, 4, 5, est prête. 2 Ndolé,
  1 Foléré. » — every line: quantity + `nameFr` (+ `variantNameFr` when set).
  Removals/options are **not** spoken.
- **Rotation:** while ≥ 1 ticket is in *Prêt*, every `rotationEvery`
  (**30 s**) re-announce the next ready ticket in turn (round-robin, the same
  ready sentence). A ticket leaves the rotation when it leaves the column.
- **Spelling:** the label's characters separated by « , » so the synthesizer
  says them one by one (`AD45` → `A, D, 4, 5`). Pure function, tested.
- **No repeats:** a re-sent snapshot or a 2-s re-read must never re-announce.
  Keyed on `clientId + column`.
- **Start-up is silent:** the first read after launch/pairing *primes* the
  seen-set without speaking (otherwise a PC reboot at noon reads out the
  whole board). Rotation may start after priming.
- **Queue:** utterances are serialised (FIFO, never two at once), bounded to
  `maxQueue` (10; oldest preparation utterances dropped first, never a ready
  one).

## 4 · File contract — what each new/changed file does

Feature module `lib/tv/` (Clean Architecture: `domain/` is pure Dart — imports
only `pos_core` models; never Flutter, never `data/`/`presentation/`).

### 4.1 New Dart files

| File | Responsibility | Public API (exact) |
|---|---|---|
| `lib/launch/kds_surface.dart` | Which surface this process is. Parses argv. | `enum KdsSurface { kitchen, tv }`; `abstract final class KdsSurfaceArgs { static const String tvFlag = '--surface=tv'; static KdsSurface parse(List<String> args); static String storeFileName(KdsSurface s); }` → `'kds.db'` / `'kds-tv.db'` |
| `lib/tv/domain/tv_rules.dart` | Every TV constant. | `abstract final class TvRules { static const Duration readyVisibleFor = Duration(minutes: 3); static const Duration highlightFor = Duration(seconds: 10); static const Duration rotationEvery = Duration(seconds: 30); static const Duration refreshEvery = Duration(seconds: 2); static const int maxPerColumn = 12; static const int maxQueue = 10; static const Set<String> preparingStatuses = {placed, accepted, preparing}; }` |
| `lib/tv/domain/tv_ticket.dart` | One tile + what to say. Immutable. | `class TvTicket { final String clientId; final String label; final TvColumn column; final DateTime since; final List<TvSpokenLine> lines; }`; `enum TvColumn { preparing, ready }`; `class TvSpokenLine { final int quantity; final String name; }` |
| `lib/tv/domain/tv_board.dart` | Pure projection: open orders + lines + now → two columns. | `class TvBoard { final List<TvTicket> preparing; final List<TvTicket> ready; static TvBoard project({required List<PosOrder> orders, required List<PosOrderLine> Function(String clientId) linesOf, required DateTime now}); bool isHighlighted(TvTicket t, DateTime now); }` |
| `lib/tv/domain/tv_speech_text.dart` | French sentences. Pure. | `abstract final class TvSpeechText { static String spell(String label); static String preparing(TvTicket t); static String ready(TvTicket t); }` ⚠ The sentences are user-facing text: build them from `AppLocalizations` strings passed in (`tvSayPreparing(code)`, `tvSayReady(code)`, `tvSayLine(qty, name)`), not literals — so take an `AppLocalizations` parameter or a small `TvPhrases` value object filled from it. |
| `lib/tv/domain/tv_announcer.dart` | Diff engine: board(t−1) → board(t) → utterances; seen-set; priming; rotation cursor. Pure, clock injected. | `class TvAnnouncer { List<TvUtterance> next(TvBoard board, DateTime now); }`; `class TvUtterance { final String text; final bool chime; final TvUtterancePriority priority; }` |
| `lib/tv/ports/tv_speech.dart` | Port (interface) for speaking. | `abstract interface class TvSpeech { Future<List<TvAudioOutput>> outputs(); Future<List<TvVoice>> voices(); Future<void> say(TvUtterance u, {String? outputId, String? voiceId}); }`; value classes `TvAudioOutput {id, name, isDefault}`, `TvVoice {id, name, language}` |
| `lib/tv/data/windows_tv_speech.dart` | `TvSpeech` over `MethodChannel('timma/tv_speech')`. Maps `PlatformException` to a logged, swallowed failure (a TV that cannot speak must keep showing numbers). | `class WindowsTvSpeech implements TvSpeech` |
| `lib/tv/data/silent_tv_speech.dart` | Fallback on non-Windows + tests; records utterances. | `class SilentTvSpeech implements TvSpeech { final List<TvUtterance> said; }` |
| `lib/tv/state/tv_settings_controller.dart` | Meta keys + Notifier for the chosen output/voice. | keys `'tv.audio_output'`, `'tv.voice'` (static const); `class TvSettings { String? outputId; String? voiceId; }`; `NotifierProvider tvSettingsProvider` (mirror `kds_view_controller.dart`) |
| `lib/tv/state/tv_speech_queue.dart` | Serialised FIFO in front of the port; bounded; drops per §3. | `class TvSpeechQueue { void enqueue(List<TvUtterance>); Future<void> dispose(); }` + `Provider<TvSpeech> tvSpeechProvider` (Windows → `WindowsTvSpeech`, else `SilentTvSpeech`) |
| `lib/tv/state/tv_board_controller.dart` | Notifier: every `TvRules.refreshEvery` read `kdsEngineProvider.store.openOrders()` + lines, `TvBoard.project`, feed `TvAnnouncer` → queue. Also a 1-s tick for highlight/expiry so a ticket leaves at exactly 3 min. | `NotifierProvider<TvBoardController, TvBoardState> tvBoardProvider`; `TvBoardState { TvBoard board; DateTime now; }` |
| `lib/tv/presentation/tv_app.dart` | `MaterialApp` for the TV (mirror `kds_app.dart`: fr locale, `KdsTheme`, delegates). | `class TvApp extends StatelessWidget` |
| `lib/tv/presentation/tv_root.dart` | Pairing → TV screen (mirror `kds_root.dart`, **no view picker**). | `class TvRoot extends ConsumerWidget` |
| `lib/tv/presentation/tv_screen.dart` | Layout only: header + two columns. Hides the mouse cursor after 3 s idle (`MouseRegion(cursor: SystemMouseCursors.none)`). Opens settings on **F2**, or a double-click/long-press on the clock. | `class TvScreen extends ConsumerWidget` |
| `lib/tv/presentation/widgets/tv_header.dart` | Wordmark, clock, offline dot. | |
| `lib/tv/presentation/widgets/tv_column.dart` | Title + tiles grid (Wrap/Grid sized from `MediaQuery`, never fixed px). | |
| `lib/tv/presentation/widgets/tv_ticket_tile.dart` | One code, very large; highlight animation (one animation only — ecosystem design rule 1–2 per view). | |
| `lib/tv/presentation/tv_settings_dialog.dart` | Audio output dropdown, voice dropdown (French voices first), « Tester la voix », « Fermer », « Quitter l'écran salle ». No other actions. | |

### 4.2 Changed Dart files (minimal, behaviour of the kitchen unchanged)

| File | Change |
|---|---|
| `lib/main.dart` | `main(List<String> args)`. `final surface = KdsSurfaceArgs.parse(args)`. Store path uses `KdsSurfaceArgs.storeFileName(surface)`. `surface == tv` → `runApp(ProviderScope(overrides: [same store + publisher overrides, kdsAlarmSinkProvider.overrideWithValue(RecordingAlarmSink())  /* the TV never rings the kitchen alarm */], child: _TvWithLink()))` where `_TvWithLink` mirrors `_BoardWithLink` but builds `TvRoot`. Kitchen path byte-for-byte as today. ⚠ Keep `SystemChrome` calls (no-ops on Windows). |
| `lib/kds/state/kds_board.dart` | **No change.** The TV does not use `kdsBoardProvider` (it has its own controller), so the kitchen alarm logic cannot fire in the TV process. Verify by test. |
| `lib/l10n/app_fr.arb` + `app_en.arb` | New keys (see §6). Then `flutter gen-l10n`. |

### 4.3 Windows runner (C++) — `windows/runner/`

| File | Change |
|---|---|
| `main.cpp` | 1) Read the raw command line; `bool tv = wcsstr(command_line, L"--surface=tv") != nullptr;` (the Dart side parses the same args itself). 2) **Single-instance guard**: `CreateMutexW(nullptr, TRUE, tv ? L"Local\\TIMMA-KDS-tv" : L"Local\\TIMMA-KDS-kitchen")`; if `GetLastError() == ERROR_ALREADY_EXISTS` → `FindWindowW(kWindowClass, title)` → `ShowWindow(SW_RESTORE)` + `SetForegroundWindow` → `return EXIT_SUCCESS`. 3) Title `L"TIMMA Écran salle"` for tv, `L"TIMMA Cuisine"` otherwise. 4) For tv: `RECT r = TvMonitor::TargetRect();` create the window at `r`, then `TvMonitor::MakeBorderlessFullscreen(window.GetHandle(), r)`; `SetThreadExecutionState(ES_CONTINUOUS \| ES_DISPLAY_REQUIRED \| ES_SYSTEM_REQUIRED)`. Kitchen path unchanged. |
| `tv_monitor.h/.cpp` (new) | `EnumDisplayMonitors` → first monitor without `MONITORINFOF_PRIMARY`, else the primary. `MakeBorderlessFullscreen`: `SetWindowLongPtr(GWL_STYLE, WS_POPUP \| WS_VISIBLE)`, `SetWindowPos(HWND_TOP, r…, SWP_FRAMECHANGED)`. Also handle `WM_DISPLAYCHANGE` (TV switched on after the PC): re-run `TargetRect` and move the window — wire it in `FlutterWindow::MessageHandler`, tv only. ⚠ Win32 window coordinates are physical pixels; `Win32Window::Create` scales by DPI — create with the monitor rect via `SetWindowPos` after creation instead of trusting `Create`'s scaling. |
| `tv_speech_channel.h/.cpp` (new) | `flutter::MethodChannel<flutter::EncodableValue>` named `timma/tv_speech`, registered in `FlutterWindow::OnCreate` **only when tv** (pass the flag to `FlutterWindow`). Methods: `listOutputs` → `[{id,name,isDefault}]` via `DeviceInformation::FindAllAsync(MediaDevice::GetAudioRenderSelector())` + `MediaDevice::GetDefaultAudioRenderId(AudioDeviceRole::Default)`; `listVoices` → `SpeechSynthesizer::AllVoices()` `[{id,name,language}]`; `say {text, chime(bool), outputId?, voiceId?}` → on a **worker thread** (WinRT MTA, `winrt::init_apartment(multi_threaded)`): if chime, play `data\flutter_assets\assets\audio\kds_notice.wav` (path from `GetModuleFileName`), then `SynthesizeTextToStreamAsync(text).get()` → `MediaPlayer` with `AudioDevice = DeviceInformation::CreateFromIdAsync(outputId).get()` (skip when null/unknown → default device), `Source = MediaSource::CreateFromStream(stream, stream.ContentType())`, wait for `MediaEnded`/`MediaFailed` (an event + `WaitForSingleObject` with a 30-s timeout). **The method result must be delivered on the platform thread**: keep the `std::unique_ptr<MethodResult>` in a map keyed by an id, `PostMessage(hwnd, WM_APP + 0x54, id, ok)` and complete it in `FlutterWindow::MessageHandler`. Errors → `result->Error("speech_failed", <short message, no user data>)`. Never log the text (it can contain dish names only, but keep logs minimal anyway). |
| `flutter_window.h/.cpp` | Constructor takes `bool tv_surface`; registers the channel when true; handles the two messages above (`WM_DISPLAYCHANGE`, `WM_APP + 0x54`). |
| `CMakeLists.txt` (runner) | Add `tv_monitor.cpp`, `tv_speech_channel.cpp` to `add_executable`; `target_link_libraries(... "windowsapp.lib")`; `target_compile_options(${BINARY_NAME} PRIVATE /await:strict /bigobj)` only if the compiler asks for it (try without first). C++/WinRT headers come with the Windows SDK on `windows-latest` (`#include <winrt/Windows.Media.SpeechSynthesis.h>`, `…Media.Playback.h`, `…Media.Core.h`, `…Media.Devices.h`, `…Devices.Enumeration.h`, `…Foundation.h`). |

### 4.4 Installer — `windows/installer/timma-cuisine.iss`

- **Do not change `AppId`.** Same installer installs both surfaces.
- `[Tasks]` add: `Name: "tvicon"; Description: "Icône « TIMMA Écran salle » (télé de la salle)"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked` and `Name: "tvstartup"; Description: "Lancer l'écran salle au démarrage de l'ordinateur"; GroupDescription: "Démarrage"; Flags: unchecked`.
- `[Icons]` add: `Name: "{group}\TIMMA Écran salle"; Filename: "{app}\{#AppExe}"; Parameters: "--surface=tv"`, the same on `{autodesktop}` with `Tasks: tvicon`, and on `{userstartup}` with `Tasks: tvstartup`.
- ⚠ Inno Setup source file must stay UTF-8 with BOM for « É » (check how the existing « démarrage » is encoded and keep it identical).

### 4.5 Docs to update in the same pass

- `docs/WINDOWS-CUISINE.md` → new section « 4 · L'écran salle sur la télé LG » = the owner setup in §7 below.
- `README.md` / `docs/INDEX` (if present) → link this file.
- `timmaeat-webapp/ECOSYSTEM.md` §25.3 → mark BUILT with the commit, once built.
- `timma-eats-offline-POS/docs/roles-tv-logo-sync-2026-11-25.md` stage table S6 row.

## 5 · Data flow (one order, end to end)

1. Borne: customer orders + pays (or the cashier settles) → hub holds the
   order, status `placed`, pushes a board snapshot over the LAN to **every**
   paired board — the kitchen process and the TV process alike.
2. TV process `LanSocketTransport` merges it into `kds-tv.db` (existing
   `kds_link.dart` code, unchanged).
3. `TvBoardController` re-reads (≤ 2 s), `TvBoard.project` puts it in *En
   préparation*, `TvAnnouncer` sees a new `clientId` → « … en préparation »
   → queue → native channel → TV speakers.
4. Kitchen taps *Prêt* on the PC board → intent → hub → hub re-broadcasts →
   TV store says `ready` → tile moves, chime + « … est prête. 2 Ndolé … ».
5. Rotation every 30 s while it is ready; after 3 min (or `completed`) it
   leaves. The TV **never sends an intent** (it has no buttons that do).

Offline: the hub and both PC processes keep working on the LAN with the WAN
down (§23). If the borne is off, the TV shows its offline dot and the last
known board; tickets older than 3 min ready still leave on the TV's own clock.

## 6 · l10n keys (fr template / en)

| Key | fr | en |
|---|---|---|
| `tvTitle` | TIMMA Écran salle | TIMMA dining-room screen |
| `tvColumnPreparing` | En préparation | Preparing |
| `tvColumnReady` | Prêt — à récupérer | Ready — please collect |
| `tvEmptyReady` | Votre numéro s'affichera ici | Your number will appear here |
| `tvOffline` | Hors ligne | Offline |
| `tvSayPreparing` | Commande {code}, en préparation. | Order {code}, being prepared. |
| `tvSayReady` | Commande {code}, est prête. | Order {code} is ready. |
| `tvSayLine` | {quantity} {name} | {quantity} {name} |
| `tvSettingsTitle` | Réglages de l'écran salle | Dining-room screen settings |
| `tvSettingsOutput` | Sortie son (choisir la télé) | Sound output (choose the TV) |
| `tvSettingsVoice` | Voix | Voice |
| `tvSettingsTest` | Tester la voix | Test the voice |
| `tvSettingsTestPhrase` | Commande A, D, 4, 5, est prête. | Order A, D, 4, 5 is ready. |
| `tvSettingsDefaultOutput` | Sortie par défaut de Windows | Windows default output |
| `tvSettingsNoFrenchVoice` | Aucune voix française installée — voir le guide. | No French voice installed — see the guide. |
| `tvSettingsClose` | Fermer | Close |
| `tvSettingsQuit` | Quitter l'écran salle | Quit the dining-room screen |

The TV speaks French (locale fixed to `fr`, like the KDS).

## 7 · Owner setup on the PC + LG TV (goes into `WINDOWS-CUISINE.md` §4)

1. **Brancher** le câble HDMI du PC à une entrée HDMI de la télé LG. Télé :
   bouton *Input* → choisir cette entrée HDMI. (Astuce LG : renommer l'entrée
   « PC » dans *Tableau de bord d'accueil* pour une image nette.)
2. Sur le PC : **Windows + P → « Étendre »**. Paramètres → Système → Affichage :
   l'écran du PC reste **écran principal**; la télé en 1920 × 1080, mise à
   l'échelle 150 %.
3. Paramètres → Système → Son : la **sortie par défaut = haut-parleurs du PC**
   (c'est là que sonne l'alarme cuisine). La télé apparaît comme « LG TV … » :
   ne pas la mettre par défaut.
4. **Voix française** : Paramètres → Heure et langue → Voix (Speech) → Ajouter
   des voix → *Français (France)*. (Déjà présente sur un Windows en français.)
5. Réinstaller `TIMMA-Cuisine-Setup.exe` (nouvelle version) et cocher
   « Icône TIMMA Écran salle » et « Lancer l'écran salle au démarrage ».
6. Double-clic sur **TIMMA Écran salle** → la fenêtre s'ouvre sur la télé →
   écran d'appairage → sur la borne : *Autoriser* (une seule fois).
7. Sur la télé, appuyer **F2** (ou double-clic sur l'horloge) → *Sortie son* :
   choisir la télé LG → *Tester la voix* → *Fermer*.
8. Télé LG : Réglages → Général → **Économie d'énergie → Arrêt automatique :
   désactivé**, et désactiver l'*économiseur d'écran*; PC : Paramètres →
   Alimentation → écran **Jamais** (l'app empêche déjà la veille, ceci est la
   ceinture de sécurité).
9. **Distance** : un câble HDMI passif est fiable jusqu'à ~10 m. Au-delà : câble
   HDMI *actif* ou un *extendeur HDMI sur câble Ethernet* (RJ45). Aucun
   changement de code dans ces cas.

## 8 · Security self-audit (§11 / global rules §14–15)

- **No new network surface.** The TV is a LAN *client* of the hub, exactly
  like a KDS: signed frames, pairing approved on the borne. No HTTP server,
  no port opened, nothing exposed to the LG TV (it only receives HDMI video).
- **Least data on screen:** only ticket codes are drawn; dish names are only
  spoken; no prices, no names, no phone numbers (kiosk orders carry none).
- **No intents from the TV:** the TV UI has no action that calls
  `kdsBoardProvider`/the engine transitions. ⚠ Residual risk (accepted, noted
  for later): the TV is paired with role `kds`, so the hub would accept an
  intent from it if code ever sent one. Later hardening (optional stage
  S6.9): a `display` pairing role in `pos_link` that the hub refuses intents
  from — needs package + borne change and both tablets re-pinned.
- **Native channel input:** `say` text is built only by the app; the channel
  still validates types, caps text length at 500 chars, and rejects unknown
  methods (`NotImplemented`). Output/voice ids are looked up from the system
  lists — an unknown id falls back to default, never throws into Dart.
- **No secrets** in the TV path; logs never contain the spoken text.
- **Single-instance guard** prevents two processes corrupting one SQLite file.
- **Kitchen unaffected:** the kitchen process path in `main.dart`/`main.cpp`
  is unchanged except the mutex (a second double-click now focuses the open
  board instead of starting a second writer — a safety fix).

## 9 · Stage table (the only status source — update it as you go)

| # | Stage | Files | Status |
|---|---|---|---|
| S6.0 | Branch `feat/tv-salle-2026-11-27` from `feat/roles-tv-logo-2026-11-25` (= `main` `1569782`). Leave the uncommitted `macos/` + `.metadata` + `analysis_options.yaml` alone (never commit them). | — | ✅ `909b34e` (pushed) |
| S6.1 | Surface parsing + separate store + `main(args)` split (kitchen path unchanged) | `lib/launch/kds_surface.dart`, `lib/main.dart` | ✅ `3f63410` |
| S6.2 | Domain: rules, ticket, board projection, speech text, announcer — **with tests first** | `lib/tv/domain/*`, `test/tv/*` | ✅ `3f63410` |
| S6.3 | Port + silent impl + queue + settings controller + board controller | `lib/tv/ports`, `lib/tv/data/silent_tv_speech.dart`, `lib/tv/state/*` | ✅ `3f63410` |
| S6.4 | Presentation: TvApp, TvRoot, TvScreen, widgets, settings dialog; l10n fr/en; widget tests at 1920×1080 and 1280×720 | `lib/tv/presentation/*`, arb | ✅ `3f63410` (+ `few numbers bigger`) |
| S6.5 | `WindowsTvSpeech` (Dart side of the channel) | `lib/tv/data/windows_tv_speech.dart` | ✅ `3f63410` |
| S6.6 | Windows runner: mutex, monitor placement, full-screen, no-sleep, `WM_DISPLAYCHANGE`, speech channel, CMake | `windows/runner/*` | ✅ `8444599` |
| S6.7 | Installer tasks/icons + workflow untouched (it already builds the Release folder) | `windows/installer/timma-cuisine.iss` | ✅ `8444599` |
| S6.8 | Docs: WINDOWS-CUISINE §4, ECOSYSTEM §25.3, POS plan S6 row, memory | docs | ✅ this commit |
| S6.9 | (optional, later) `display` pairing role refused by the hub for intents | pos_link + borne + both pins | ⬜ later |
| S6.10 | Build on the GitHub runner (`workflow_dispatch`, `-f ref=feat/tv-salle-2026-11-27`) — it runs analyze + test + build + Inno. ⚠ Publishing the setup on the release link = **owner yes first** | CI | ✅ run 45986516842 (edc0c51); Setup + APK 1.0.3(2014) published on `cuisine-win-20261123` at the owner's request |
| S6.11 | Hardware proof on the owner's PC + LG TV (owner does the clicks; agent gives the checklist §10) | — | ⬜ |

## 10 · Test plan

Automated (all on the Mac, `flutter test` — every test must fail if the code it
protects is removed):
- `test/tv/kds_surface_test.dart`: `[]` → kitchen; `['--surface=tv']` → tv;
  unknown args → kitchen; store names.
- `test/tv/tv_board_test.dart`: app/web orders excluded; `placed/accepted/
  preparing` → preparing; `ready` 2:59 shown, 3:00 gone; completed gone;
  ordering; `maxPerColumn` drops the oldest ready; highlight 9 s yes / 11 s no.
- `test/tv/tv_speech_text_test.dart`: `AD45` → `A, D, 4, 5`; `07` → `0, 7`;
  ready sentence lists every line with quantity + variant.
- `test/tv/tv_announcer_test.dart`: priming is silent; new placed → one
  preparing utterance; same board again → nothing; → ready → chime + ready
  utterance; rotation after 30 s with 2 ready alternates A, B, A; a ticket that
  leaves stops rotating; preparing → ready skipped-in-between still announces
  ready once.
- `test/tv/tv_speech_queue_test.dart`: serial (second waits for first);
  bounded at 10 dropping preparation first; a failing port does not stop the
  queue.
- `test/tv/tv_screen_test.dart`: 1920×1080 and 1280×720 render with no
  overflow; only codes on screen (no dish names found by `find.text`); F2
  opens settings; settings lists outputs from a fake `TvSpeech`.
- Existing suite untouched and green (KDS had 126 tests on 2026-11-25).
- `flutter analyze` clean. Gate pattern (workspace gotcha):
  `flutter test > log 2>&1; echo test=$?` — never pipe into `tail` for the
  exit code.

Visual check on the Mac: run the TV surface on macOS desktop
(`flutter run -d macos --dart-entrypoint-args=--surface=tv`) with a fixture
store if the local `macos/` folder builds; otherwise widget-test golden-free
screenshots. Say plainly which one was done.

Windows (only possible on the runner + the owner's PC): runner build green;
then the owner checklist: TV opens on the LG; pairing; a borne test order →
« en préparation » spoken on the TV within 5 s; KDS *Prêt* → chime + « est
prête » + dishes on the TV, kitchen alarm still on the PC speakers; 3 min →
gone; unplug HDMI and replug → the window comes back on the TV; reboot PC →
both start; double-click the icon again → no second window.

## 11 · Results — 2026-11-27 (build session)

- Dart: `lib/launch/kds_surface.dart`, `lib/tv/**` (domain/ports/data/state/
  presentation), `lib/main.dart` split; 17 fr/en strings. Kitchen path
  unchanged.
- Native: `windows/runner/tv_surface.*` (monitor, borderless full-screen,
  keep-awake), `tv_speech_channel.*` (WinRT speech → chosen output, worker
  thread, results posted back to the platform thread), mutex per surface in
  `main.cpp`, `WM_DISPLAYCHANGE`/`WM_DPICHANGED` re-fill, `windowsapp.lib`.
- Installer: tasks `tvicon` / `tvstartup`, shortcuts with `--surface=tv`.
- Version 1.0.3+2014.
- Tests: KDS full suite 158 passed (126 existing + 32 TV), `flutter analyze`
  clean. Visual check on macOS (temporary preview entrypoint, deleted): two
  columns, codes only, fresh ready number enlarged, offline badge, clock.
- **Deviation from §3:** tiles are 2 per row while a column holds ≤ 4 numbers
  (bigger codes), 3 per row beyond.
- **Not verifiable here:** the C++ (compiled only on the GitHub runner), the
  voice, the TV monitor placement and the HDMI audio routing — owner checklist
  §10 on the real PC + LG TV.

## 12 · Owner changes, 2026-11-27 (after hearing it)

- **Columns = the KDS lanes.** The TV no longer has its own status list: it
  calls `KdsLane.laneFor` — TV « En préparation » = KDS « En préparation »
  (`accepted`/`preparing`), TV « Prêt » = KDS « Prêtes » (3 min on the TV).
  « Nouvelles » (`placed`) is NOT on the TV (reverses §3's `placed` addition).
- **Voice clarity:** code spelled with full stops (`A. K. 3.`), repeated at the
  end of every announcement (« Je répète : A. K. 3. »), rate
  `TvRules.speakingRate` = 0.85, a French **female** voice by default
  (WinRT `VoiceGender::Female`).
- **Re-read cycle replaces the 30-s rotation:** once every fresh move is said
  and the voice has been silent `TvRules.cyclePause` (20 s), the whole board is
  read again — « Prêt » newest first, then « En préparation » oldest first, no
  chime. Fresh announcements are queued AHEAD of re-reads; re-reads drop first
  when the queue (`maxQueue` = 30) is full.
