import 'tv_board.dart';
import 'tv_phrases.dart';
import 'tv_rules.dart';
import 'tv_speech_text.dart';
import 'tv_ticket.dart';
import 'tv_utterance.dart';

/// Decides what the TV says, from one board to the next. Pure: the caller
/// passes the clock and how long the voice has been silent.
///
/// * The **first** board after launch is *primed* silently — a PC rebooted at
///   noon must not blurt the whole board at once; the re-read cycle covers it
///   calmly afterwards.
/// * A ticket is announced once per column it enters (keyed on
///   [TvTicket.announceKey]), so a re-sent snapshot or a 2-s re-read is silent.
/// * **Re-read cycle (owner, 2026-11-27):** when nothing new is to be said and
///   the voice has been silent for [TvRules.cyclePause], the whole board is
///   read again — every « Prêt » (newest first), then every « En préparation »
///   (oldest first) — as [TvUtterance.reread] utterances.
class TvAnnouncer {
  TvAnnouncer({required this.phrases});

  final TvPhrases phrases;

  final Set<String> _heard = <String>{};
  bool _primed = false;

  /// Utterances to queue now, in speaking order.
  ///
  /// [silentFor] is how long the speech queue has been idle; null while it is
  /// speaking (no re-read is started over a voice that is still talking).
  List<TvUtterance> next(TvBoard board, DateTime now, {Duration? silentFor}) {
    final List<TvTicket> onBoard = <TvTicket>[...board.preparing, ...board.ready];
    // Forget tickets that left, so the set stays bounded over a long service
    // and a ticket sent back to the kitchen is announced again when it returns.
    final Set<String> present = <String>{
      for (final TvTicket t in onBoard) t.announceKey,
    };
    _heard.retainWhere(present.contains);

    if (!_primed) {
      _primed = true;
      _heard.addAll(present);
      return const <TvUtterance>[];
    }

    final List<TvUtterance> out = <TvUtterance>[];
    for (final TvTicket t in board.preparing) {
      if (_heard.add(t.announceKey)) {
        out.add(_preparing(t));
      }
    }
    // Oldest ready first, so two simultaneous ones are said in order.
    for (final TvTicket t in board.ready.reversed) {
      if (_heard.add(t.announceKey)) {
        out.add(_ready(t));
      }
    }
    if (out.isNotEmpty) {
      return out;
    }

    if (onBoard.isEmpty || silentFor == null || silentFor < TvRules.cyclePause) {
      return const <TvUtterance>[];
    }
    return <TvUtterance>[
      for (final TvTicket t in board.ready) _ready(t, reread: true),
      for (final TvTicket t in board.preparing) _preparing(t, reread: true),
    ];
  }

  TvUtterance _preparing(TvTicket t, {bool reread = false}) => TvUtterance(
    text: TvSpeechText.preparing(t, phrases),
    priority: TvUtterancePriority.preparing,
    reread: reread,
  );

  /// The chime marks a fresh « prête » only; re-reads are voice alone.
  TvUtterance _ready(TvTicket t, {bool reread = false}) => TvUtterance(
    text: TvSpeechText.ready(t, phrases),
    priority: TvUtterancePriority.ready,
    chime: !reread,
    reread: reread,
  );
}
