; TIMMA Cuisine — Windows installer
;
; Owner, 2026-11-23: *"i really want windows vertion to be installing version
; with a shortcut on desktop so the user wont have to go find it in
; timma/cuisine"*.
;
; A zip to unpack was the wrong shape for a kitchen PC. Everything that could
; go wrong with it did: run the .exe from inside the zip and it starts without
; its `data\` folder; unpack it somewhere and nobody can find it again. This
; produces one `TIMMA-Cuisine-Setup.exe` that installs, puts an icon on the
; desktop and in the Start menu, and can be uninstalled from Settings like any
; other program.
;
; Built by the GitHub runner (.github/workflows/windows-build.yml) with
; Inno Setup 6, which is already on the `windows-latest` image.

#define AppName "TIMMA Cuisine"
#define AppExe "timma_kds.exe"
#define AppPublisher "TIMMA Restaurant"
; The dining-room TV shortcut (S6). TvFlag must match kTvSurfaceFlag in
; windows/runner/tv_surface.h and KdsSurfaceArgs.tvFlag in Dart.
#define TvName "TIMMA Écran salle"
#define TvFlag "--surface=tv"
; The kitchen TV « Écran cuisine » (S6-B): the kitchen kanban, read-only, on
; the back TV (VGA). Must match kKitchenTvSurfaceFlag / KdsSurfaceArgs.
#define KitchenTvName "TIMMA Écran cuisine"
#define KitchenTvFlag "--surface=kitchen-tv"

; Passed in by the workflow: /DAppVersion=... and /DSourceDir=...
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
; ⚠ **This GUID must never change.** It is how Windows recognises an existing
; installation: keep it and the next setup UPGRADES in place, keeping the
; shortcuts and the pairing the kitchen already has. Change it and the PC ends
; up with two TIMMA Cuisines, one of them stale, and a cook opening whichever
; shortcut they happen to find.
AppId={{155A6567-6F00-464E-AD60-C34F68F76193}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\TIMMA Cuisine
DefaultGroupName=TIMMA
DisableProgramGroupPage=yes
; ⚠ `lowest` — a per-user install into the user's own AppData, so setup does
; NOT ask for an administrator password. Nobody in a kitchen has the admin
; credentials of the restaurant's PC at eight in the morning, and an installer
; that stops on a UAC prompt is an installer that does not get run.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputBaseFilename=TIMMA-Cuisine-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The board is a landscape application for a screen on a wall; there is no
; 32-bit kitchen PC to support.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
; The kitchen runs in French (§3: default locale fr). English is kept for
; whoever sets the machine up.
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; ⚠ Ticked by default, and this is the whole request: the desktop icon is the
; only route a cook will ever use.
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "startup"; Description: "Lancer TIMMA Cuisine au démarrage de l'ordinateur"; GroupDescription: "Démarrage"; Flags: unchecked
; S6 — the dining-room TV. The same exe with --surface=tv opens full-screen on
; the LG TV plugged into this PC by HDMI (Windows + P → « Étendre »). Unticked
; by default: only the PC that drives the TV needs it.
Name: "tvicon"; Description: "Icône « TIMMA Écran salle » (télé de la salle)"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "tvstartup"; Description: "Lancer l'écran salle au démarrage de l'ordinateur"; GroupDescription: "Démarrage"; Flags: unchecked
Name: "kitchentvicon"; Description: "Icône « TIMMA Écran cuisine » (télé de la cuisine)"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "kitchentvstartup"; Description: "Lancer l'écran cuisine au démarrage de l'ordinateur"; GroupDescription: "Démarrage"; Flags: unchecked

[Files]
; ⚠ The WHOLE Release folder, not just the .exe. A Flutter Windows build needs
; its DLLs and its `data\` directory beside the binary; an .exe on its own is
; the classic "it does not start" support call, and it is exactly what the zip
; invited people to do.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: startup
Name: "{group}\{#TvName}"; Filename: "{app}\{#AppExe}"; Parameters: "{#TvFlag}"; Tasks: tvicon
Name: "{autodesktop}\{#TvName}"; Filename: "{app}\{#AppExe}"; Parameters: "{#TvFlag}"; Tasks: tvicon
Name: "{userstartup}\{#TvName}"; Filename: "{app}\{#AppExe}"; Parameters: "{#TvFlag}"; Tasks: tvstartup
Name: "{group}\{#KitchenTvName}"; Filename: "{app}\{#AppExe}"; Parameters: "{#KitchenTvFlag}"; Tasks: kitchentvicon
Name: "{autodesktop}\{#KitchenTvName}"; Filename: "{app}\{#AppExe}"; Parameters: "{#KitchenTvFlag}"; Tasks: kitchentvicon
Name: "{userstartup}\{#KitchenTvName}"; Filename: "{app}\{#AppExe}"; Parameters: "{#KitchenTvFlag}"; Tasks: kitchentvstartup

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
