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

---

## 5 · L'écran salle sur la télé LG (S6, 1.0.3+2014)

Le même PC fait tourner **deux fenêtres** du même programme : la cuisine sur
l'écran du PC, et l'**écran salle** (numéros « En préparation » / « Prêt — à
récupérer », annonce vocale) en plein écran sur la télé LG branchée en HDMI.
Détails techniques : `docs/tv-salle-windows-hdmi-2026-11-27.md`.

1. **Brancher** le câble HDMI du PC à la télé LG. Télé : bouton *Input* → cette
   entrée HDMI.
2. PC : **Windows + P → « Étendre »**. Paramètres → Système → Affichage :
   l'écran du PC reste **écran principal** ; la télé en 1920 × 1080.
3. Paramètres → Système → Son : **sortie par défaut = haut-parleurs du PC**
   (l'alarme cuisine sonne là). Ne pas mettre la télé par défaut.
4. **Voix française** : Paramètres → Heure et langue → Voix → Ajouter des voix
   → *Français (France)* (déjà présente sur un Windows en français).
5. Installer la nouvelle `TIMMA-Cuisine-Setup.exe` et cocher **« Icône TIMMA
   Écran salle »** et **« Lancer l'écran salle au démarrage »**.
6. Double-clic sur **TIMMA Écran salle** → la fenêtre s'ouvre sur la télé →
   écran d'appairage → sur la borne : **Autoriser** (une seule fois — la télé
   est un tableau appairé de plus, comme une deuxième cuisine).
7. Sur la télé : touche **F2** (ou double-clic sur l'heure) → *Sortie son* :
   choisir la télé LG → **Tester la voix** → *Fermer*.
8. Télé LG : Réglages → Général → Économie d'énergie → **Arrêt automatique :
   désactivé**. PC : Alimentation → écran **Jamais**.
9. Plus de ~10 m entre le PC et la télé : câble HDMI **actif** ou extendeur
   HDMI sur câble Ethernet. Rien d'autre ne change.

Bon à savoir : double-cliquer une deuxième fois sur une icône ne lance pas une
deuxième copie, ça remet la fenêtre déjà ouverte devant. Si la télé est
allumée après le PC, la fenêtre revient d'elle-même sur la télé.

---

## 6 · L'écran cuisine sur la deuxième télé LG (S6-B, 1.0.4+2015)

Le portable pilote **3 écrans** : son écran = la **caisse** (« Caisse
paiement »), la télé avant en HDMI = l'**écran salle**, la télé arrière en
**VGA** = l'**écran cuisine** (le kanban Nouvelles → En préparation → Prêtes,
en grand, **lecture seule**). Les cuisiniers agissent sur la **tablette
Android** (« Cuisine ») ; la télé arrière suit en 2–3 secondes.
Détails : `docs/ecran-cuisine-tv-vga-2026-11-27.md`.

1. **Test gratuit d'abord** : télé arrière en VGA (même câble court), télé
   avant toujours en HDMI → Paramètres → Système → Affichage : **3 écrans** →
   écran 3 « **Étendre ces affichages** ». Télé arrière : entrée **PC / RGB**.
2. Acheter : câble **VGA 15 m** avec ferrites, câble **jack 3,5 mm 15 m**,
   **carte son USB**.
3. Carte son USB sur le portable ; jack 15 m de la carte son → **PC Audio In**
   de la télé arrière. Son Windows : sortie par défaut = **haut-parleurs du
   portable** (la caisse).
4. Télé arrière en 1920 × 1080 (ou la meilleure proposée en VGA), mise à
   l'échelle **150 %**.
5. Installer la nouvelle `TIMMA-Cuisine-Setup.exe` en cochant **« Icône TIMMA
   Écran cuisine »** + **« Lancer l'écran cuisine au démarrage »**.
6. Ouvrir **TIMMA Écran cuisine** → appairer sur la borne (une fois).
7. Sur la télé arrière, **F2** → **Écran** : la télé arrière ; **Sortie son** :
   la carte son USB → **Tester l'alarme** → Fermer.
8. Sur le portable, TIMMA Cuisine → « Changer de vue » → **Caisse paiement**.
   La tablette Android reste sur **Cuisine**.
9. Si un écran s'est ouvert sur la mauvaise télé : **F2** sur cette fenêtre →
   **Écran** → la bonne télé (le choix est gardé).
