import 'tv_phrases.dart';
import 'tv_rules.dart';
import 'tv_ticket.dart';

/// Turns a ticket into what the synthesizer says. Pure.
abstract final class TvSpeechText {
  /// `AD45` → `A. D. 4. 5.`: a full stop after every character makes every
  /// synthesizer say them one by one, with a clear pause, instead of « ad
  /// quarante-cinq » (commas were too short — owner, 2026-11-27). Spaces and
  /// dashes in a label are dropped.
  static String spell(String label) => label
      .toUpperCase()
      .split('')
      .where((String c) => c.trim().isNotEmpty && c != '-')
      .map((String c) => '$c.')
      .join(' ');

  /// « Commande A. D. 4. 5. en préparation. »
  static String preparing(TvTicket ticket, TvPhrases phrases) =>
      _cap(phrases.preparing(spell(ticket.label)));

  /// « Commande A. D. 4. 5. est prête. 2 Ndolé, 1 Foléré. Je répète : A. D.
  /// 4. 5. » — every line, then the code once more: the customer who missed
  /// the start still hears their number.
  static String ready(TvTicket ticket, TvPhrases phrases) {
    final String code = spell(ticket.label);
    final String head = phrases.ready(code);
    final String repeat = phrases.repeat(code);
    if (ticket.lines.isEmpty) {
      return _cap('$head $repeat');
    }
    final String body = ticket.lines
        .map((TvSpokenLine l) => phrases.line(l.quantity, l.name))
        .join(', ');
    return _cap('$head $body. $repeat');
  }

  /// Never hand the native channel more than it accepts.
  static String _cap(String text) => text.length <= TvRules.maxSpeechChars
      ? text
      : text.substring(0, TvRules.maxSpeechChars);
}
