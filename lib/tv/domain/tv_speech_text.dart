import 'tv_phrases.dart';
import 'tv_rules.dart';
import 'tv_ticket.dart';

/// Turns a ticket into what the synthesizer says. Pure.
abstract final class TvSpeechText {
  /// `AD45` → `A, D, 4, 5`: the commas make every synthesizer say the
  /// characters one by one instead of « ad quarante-cinq ». Spaces and dashes
  /// in a label are dropped.
  static String spell(String label) => label
      .toUpperCase()
      .split('')
      .where((String c) => c.trim().isNotEmpty && c != '-')
      .join(', ');

  /// « Commande A, D, 4, 5, en préparation. »
  static String preparing(TvTicket ticket, TvPhrases phrases) =>
      _cap(phrases.preparing(spell(ticket.label)));

  /// « Commande A, D, 4, 5, est prête. 2 Ndolé, 1 Foléré. » — every line.
  static String ready(TvTicket ticket, TvPhrases phrases) {
    final String head = phrases.ready(spell(ticket.label));
    if (ticket.lines.isEmpty) {
      return _cap(head);
    }
    final String body = ticket.lines
        .map((TvSpokenLine l) => phrases.line(l.quantity, l.name))
        .join(', ');
    return _cap('$head $body.');
  }

  /// Never hand the native channel more than it accepts.
  static String _cap(String text) => text.length <= TvRules.maxSpeechChars
      ? text
      : text.substring(0, TvRules.maxSpeechChars);
}
