# The kitchen board on a Windows 10 PC

Owner, 2026-11-23: *"we will put the kitchen app on a windows pc … i really
want two versions of the app windows flutter adaptation and android one"*, and
then: *"is there a easier way?"*

There is. **Nothing is installed on the PC except the app itself.** No Flutter
SDK, no Visual Studio, no Android tooling, no wireless debugging, no command
line. The PC downloads one zip, unzips it, and double-clicks.

That is possible because a GitHub runner does the Windows build:
`.github/workflows/windows-build.yml` compiles on `windows-latest` and attaches
the finished folder. Flutter cannot cross-compile desktop — a Windows build has
to happen **on** Windows — and the alternative was several gigabytes of
toolchain on a machine whose job is to show tickets to cooks.

Android is unaffected: the same `lib/` builds both, and the tablet keeps its
APK. There is no second codebase and no fork.

---

## 1 · What the owner does on the PC (every update)

1. Open **Edge** and go to the kitchen board's **Releases** page — always the
   same link, `cuisine-win-20261123`. New builds replace the file there; there
   is never a second place to look.
2. Sign in to GitHub **once** on this PC. Edge remembers it; later updates are
   a single click.
3. Download **`TIMMA-Cuisine-Setup.exe`**.
4. Double-click it. Keep **"Créer une icône sur le Bureau"** ticked.
5. Open **TIMMA Cuisine** from the desktop.

That is the whole procedure. There is nothing to unzip, no folder to remember
and no path to type — owner, 2026-11-23: *"i really want windows vertion to be
installing version with a shortcut on desktop so the user wont have to go find
it in timma/cuisine"*.

An update is the same five steps: run the new setup and it replaces the
installed copy in place, keeping the shortcuts and the pairing.

### The first run asks two things

- **"Windows protected your PC" (SmartScreen).** The installer is not
  code-signed — signing a Windows binary needs a certificate TIMMA does not
  have yet. Click **More info → Run anyway**. It appears once per downloaded
  copy.
- **Windows Defender Firewall**, the first time the board itself runs. Tick
  **Private networks** and allow it. The board finds the borne over the
  restaurant's wifi; blocked, it will show *"Cuisine non appairée"* forever
  and no ticket will ever arrive.

### Start it with the PC

Tick **"Lancer TIMMA Cuisine au démarrage de l'ordinateur"** during setup. If
it was missed, run the setup again and tick it. The PC can then be switched on
in the morning by anyone.

### Removing it

Settings → Apps → **TIMMA Cuisine** → Uninstall, like any other program.

⚠ **Setup installs for the current user only**, into that account's own
folder, so it never asks for an administrator password — nobody in a kitchen
has those at eight in the morning. The consequence: install it under the
account the kitchen actually signs into.

---

## 2 · Pairing it to the borne

Both machines on the same wifi, the borne's app open on its manager screen:

1. The board shows **"Appairer en un geste"** and lists the borne by name.
2. Tap it. The borne shows an approval card — *Autoriser* on the borne.
3. Done. No code typed anywhere.

The six-digit code is still there, behind **"Utiliser un code"**, as the second
procedure (owner, 2026-11-23). It is what to use if the one-tap list stays
empty.

⚠ **The one Windows caveat.** One-tap discovery uses the Windows DNS-SD API
(`nsd_windows`), which needs **Windows 10 version 1809 or newer**. On an older
Windows 10 the list stays empty and nothing else breaks — pair with the code
instead. Check with **Win + R** → `winver`.

Nothing on the wifi needs configuring: no port forwarding, no fixed IP, no
internet. The borne is the hub; the board connects out to it.

---

## 3 · Pushing a new build (the Mac side)

```bash
gh workflow run windows-build.yml -f ref=main
```

Then, when it is green, put the setup on the **existing** release — owner,
2026-11-23: *"it should be updated on this link no elsewhere i want things to
be in one place"*. `--clobber` replaces the file on the same tag, so the link
the kitchen PC has bookmarked never changes:

```bash
gh run download <run-id> -D /tmp/setup && gh release upload cuisine-win-20261123 /tmp/setup/*/TIMMA-Cuisine-Setup.exe --clobber
```

⚠ **Never `gh release create` a new tag for a new build.** A second release
page is a second answer to "where do I get it", and the kitchen will end up
running whichever one it finds first.

Pushing a tag matching `cuisine-win-*` builds automatically as well.

### What the installer is

`windows/installer/timma-cuisine.iss`, built by the runner with Inno Setup 6.
Its `AppId` GUID is fixed and must stay fixed: it is how Windows recognises
the existing installation and upgrades it in place rather than leaving two
TIMMA Cuisines on the PC.

The icon comes from `tool/make_windows_icon.py`, which builds
`windows/runner/resources/app_icon.ico` out of `assets/branding/app_icon.png`.
`flutter create` leaves Flutter's own icon there and nothing in a Flutter
build replaces it — which is why the first Windows build shipped with the
wrong logo on the taskbar. Change the brand PNG, run the script, commit the
`.ico`.

⚠ **The runner's Flutter version is pinned** (3.47.9) and must match the SDK
the Android board and the test suite were proven on. `channel: stable` drew
3.50.1 on the first run and failed `analyze` on 14 deprecations no developer
here can see — but the dangerous outcome was the green build it would have
been: a kitchen binary compiled against a different framework from the tablet
it has to pair with. Bump it deliberately, with the local SDK, never silently.

The `pos_*` packages are git dependencies on the **private** schema-owner
repository, which the runner's built-in token cannot read. It uses
`POS_PACKAGES_DEPLOY_KEY` — a **read-only deploy key on that one repository**,
not a personal access token: it carries read access to one repo, is revocable
on its own, and cannot write.

---

## 4 · If the download needs no GitHub sign-in

The repository is private, so both the workflow artefact and a release asset
ask for a login. One sign-in in Edge, kept, is the recommended answer: the
source stays private and the kitchen PC still downloads with one click.

The alternative the owner raised is a **separate public repository holding only
the built zip** — no source. It was checked rather than assumed: the board
bundle carries **no secrets** (the app declares no `--dart-define` and no
`String.fromEnvironment`; the pairing keys are generated on the devices and the
branch secret lives in the platform vault, never in the binary). What it would
expose is the binary itself, which anyone could run and point at a borne — and
pairing would still refuse them, because it needs someone to tap *Autoriser* on
the borne's own screen.

So it is safe enough, and it is still the owner's call, not a default. Nothing
public exists today.
