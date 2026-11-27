import 'package:flutter_test/flutter_test.dart';
import 'package:timma_kds/tv/domain/tv_rules.dart';
import 'package:timma_kds/tv/domain/tv_speech_text.dart';
import 'package:timma_kds/tv/domain/tv_ticket.dart';

import 'tv_fixtures.dart';

void main() {
  test('spells a label character by character', () {
    expect(TvSpeechText.spell('AD45'), 'A. D. 4. 5.');
    expect(TvSpeechText.spell('07'), '0. 7.');
    expect(TvSpeechText.spell('ad-4 5'), 'A. D. 4. 5.');
  });

  TvTicket ticket({List<TvSpokenLine> lines = const <TvSpokenLine>[]}) =>
      TvTicket(clientId: 'c', label: 'AD45', column: TvColumn.ready, since: t0, lines: lines);

  test('preparing sentence', () {
    expect(TvSpeechText.preparing(ticket(), frPhrases), 'Commande A. D. 4. 5. en préparation. Je répète : A. D. 4. 5.');
  });

  test('ready sentence lists every dish and drink', () {
    expect(
      TvSpeechText.ready(
        ticket(lines: const <TvSpokenLine>[
          TvSpokenLine(quantity: 2, name: 'Ndolé'),
          TvSpokenLine(quantity: 1, name: 'Foléré'),
        ]),
        frPhrases,
      ),
      'Commande A. D. 4. 5. est prête. 2 Ndolé, 1 Foléré. Je répète : A. D. 4. 5.',
    );
    expect(TvSpeechText.ready(ticket(), frPhrases), 'Commande A. D. 4. 5. est prête. Je répète : A. D. 4. 5.');
  });

  test('never longer than the channel accepts', () {
    final String text = TvSpeechText.ready(
      ticket(lines: <TvSpokenLine>[
        for (int i = 0; i < 100; i++) TvSpokenLine(quantity: 1, name: 'Plat numéro $i'),
      ]),
      frPhrases,
    );
    expect(text.length, TvRules.maxSpeechChars);
  });
}
