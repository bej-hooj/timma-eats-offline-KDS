/// The sentences the TV speaks, as functions filled from the app's
/// localizations (`AppLocalizations.tvSay*`). Keeps the domain free of Flutter
/// while no user-facing text is ever written in Dart.
class TvPhrases {
  const TvPhrases({
    required this.preparing,
    required this.ready,
    required this.line,
    required this.repeat,
  });

  /// « Commande {code}, en préparation. »
  final String Function(String code) preparing;

  /// « Commande {code}, est prête. »
  final String Function(String code) ready;

  /// « {quantity} {name} »
  final String Function(int quantity, String name) line;

  /// « Je répète : {code} »
  final String Function(String code) repeat;
}
