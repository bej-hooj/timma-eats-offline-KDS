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

1. Open **Edge** and go to the kitchen board's **Releases** page.
2. Sign in to GitHub **once** on this PC. Edge remembers it; later updates are
   a single click.
3. Download `timma-cuisine-windows-<date>.zip`.
4. Right-click the zip → **Extract All…** → extract to `C:\TIMMA\Cuisine`
   (replacing what is there, on an update).
5. Double-click **`timma_kds.exe`**.

⚠ **Unzip it before running.** Windows will happily open an `.exe` from inside
a zip preview, and it starts without the `data\` folder beside it and fails
with no useful message. Everything in that folder is required — the `.exe`, the
DLLs and `data\`.

### The first run asks two things

- **"Windows protected your PC" (SmartScreen).** The build is not
  code-signed — signing a Windows binary needs a certificate TIMMA does not
  have yet. Click **More info → Run anyway**. It appears once per downloaded
  copy.
- **Windows Defender Firewall.** Tick **Private networks** and allow it. The
  board finds the borne over the restaurant's wifi; blocked, it will show
  *"Cuisine non appairée"* forever and no ticket will ever arrive.

### Make it start with the PC

Press **Win + R**, type `shell:startup`, Enter, and drop a **shortcut** to
`C:\TIMMA\Cuisine\timma_kds.exe` in the folder that opens. The PC can then be
switched on in the morning by anyone.

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

Then, when it is green, attach the zip to a release so the PC has a stable
page to download from:

```bash
gh run download <run-id> -D /tmp/cuisine && \
  cd /tmp/cuisine/timma-cuisine-windows-* && zip -qr /tmp/cuisine.zip . && \
  gh release create cuisine-win-$(date +%Y%m%d-%H%M) /tmp/cuisine.zip \
    --title "Cuisine Windows $(date +%Y-%m-%d)" --notes "…"
```

Pushing a tag matching `cuisine-win-*` builds automatically as well.

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
