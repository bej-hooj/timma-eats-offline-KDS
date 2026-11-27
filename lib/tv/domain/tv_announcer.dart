import 'tv_board.dart';
import 'tv_phrases.dart';
import 'tv_rules.dart';
import 'tv_speech_text.dart';
import 'tv_ticket.dart';
import 'tv_utterance.dart';

/// Decides what the TV says, from one board to the next. Pure: the caller
/// passes the clock.
///
/// * The **first** board after launch is *primed* silently — a PC rebooted at
///   noon must not read the whole board out loud.
/// * A ticket is announced once per column it enters (keyed on
///   [TvTicket.announceKey]), so a re-sent snapshot or a 2-s re-read is silent.
/// * While tickets are ready, one of them is re-announced every
///   [TvRules.rotationEvery], round-robin. A fresh « prête » restarts the wait.
class TvAnnouncer {
  TvAnnouncer({required this.phrases});

  final TvPhrases phrases;

  final Set<String> _heard = <String>{};
  bool _primed = false;
  DateTime? _lastReadyAnnouncement;
  int _cursor = 0;

  /// Utterances to queue now, in speaking order.
  ///
  /// Call with every board the controller reads; an unchanged board returns an
  /// empty list (except when a rotation is due).
  List<TvUtterance> next(TvBoard board, DateTime now) {
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
      _lastReadyAnnouncement = now;
      return const <TvUtterance>[];
    }

    final List<TvUtterance> out = <TvUtterance>[];
    for (final TvTicket t in board.preparing) {
      if (_heard.add(t.announceKey)) {
        out.add(
          TvUtterance(
            text: TvSpeechText.preparing(t, phrases),
            priority: TvUtterancePriority.preparing,
          ),
        );
      }
    }
    bool announcedReady = false;
    // Oldest ready first, so two simultaneous ones are said in order.
    for (final TvTicket t in board.ready.reversed) {
      if (_heard.add(t.announceKey)) {
        announcedReady = true;
        out.add(_ready(t));
      }
    }

    if (announcedReady || board.ready.isEmpty) {
      _lastReadyAnnouncement = now;
    } else if (now.difference(_lastReadyAnnouncement ?? now) >=
        TvRules.rotationEvery) {
      final TvTicket t = board.ready[_cursor % board.ready.length];
      _cursor++;
      _lastReadyAnnouncement = now;
      out.add(_ready(t));
    }
    return out;
  }

  TvUtterance _ready(TvTicket t) => TvUtterance(
    text: TvSpeechText.ready(t, phrases),
    priority: TvUtterancePriority.ready,
    chime: true,
  );
}
