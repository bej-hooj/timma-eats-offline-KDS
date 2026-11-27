/// Which screen this process drives.
///
/// The same `timma_kds.exe` runs twice on the kitchen's Windows PC (S6,
/// `docs/tv-salle-windows-hdmi-2026-11-27.md`): once as the kitchen board on
/// the PC's own monitor, once with [KdsSurfaceArgs.tvFlag] as the dining-room
/// screen on the LG TV plugged in by HDMI.
enum KdsSurface {
  /// The kitchen board — « Cuisine » / « Caisse paiement ». The default.
  kitchen,

  /// « Écran salle » — the customer order display on the TV.
  tv,

  /// « Écran cuisine » — the kitchen kanban, read-only, on the back TV (S6-B,
  /// `docs/ecran-cuisine-tv-vga-2026-11-27.md`). Cooks act on the tablet.
  kitchenTv,
}

/// Parses the process arguments into a [KdsSurface] and names its store.
abstract final class KdsSurfaceArgs {
  /// The one argument that turns a process into the TV. The Windows runner
  /// looks for the same literal to pick the monitor and the window title —
  /// keep `windows/runner/tv_surface.h` (`kTvSurfaceFlag`) in step.
  static const String tvFlag = '--surface=tv';

  /// The back-TV kitchen kanban. Keep in step with `kKitchenTvSurfaceFlag` in
  /// `windows/runner/tv_surface.h`.
  static const String kitchenTvFlag = '--surface=kitchen-tv';

  /// The kitchen board's store. ⚠ Never rename: an installed board keeps its
  /// pairing in this file.
  static const String kitchenStoreFile = 'kds.db';

  /// The TV's own store. A separate file so the two processes never write one
  /// SQLite database, and so the TV has its own pairing identity.
  static const String tvStoreFile = 'kds-tv.db';

  /// The Écran cuisine's own store and pairing.
  static const String kitchenTvStoreFile = 'kds-cuisine-tv.db';

  /// Returns [KdsSurface.tv] only for the exact [tvFlag]; anything else —
  /// no argument, a typo, an unknown flag — is the kitchen board, so a broken
  /// shortcut can never turn the cooks' screen into a customer display.
  static KdsSurface parse(List<String> args) {
    if (args.contains(tvFlag)) {
      return KdsSurface.tv;
    }
    if (args.contains(kitchenTvFlag)) {
      return KdsSurface.kitchenTv;
    }
    return KdsSurface.kitchen;
  }

  /// The store file name for [surface].
  static String storeFileName(KdsSurface surface) => switch (surface) {
    KdsSurface.kitchen => kitchenStoreFile,
    KdsSurface.tv => tvStoreFile,
    KdsSurface.kitchenTv => kitchenTvStoreFile,
  };

  /// A screen nobody touches (a TV): full-screen, read-only, F2 settings.
  static bool isDisplay(KdsSurface surface) => surface != KdsSurface.kitchen;
}
