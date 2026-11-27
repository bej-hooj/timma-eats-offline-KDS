import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timma_kds/display/display_chrome.dart';
import 'package:timma_kds/tv/domain/tv_rules.dart';

void main() {
  testWidgets('F2 opens the settings; the cursor hides after 3 s and returns on movement', (WidgetTester tester) async {
    int opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DisplayChrome(onOpenSettings: () => opened++, child: const SizedBox.expand()),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    expect(opened, 1);

    MouseRegion region() => tester.widget<MouseRegion>(
      find.descendant(of: find.byType(DisplayChrome), matching: find.byType(MouseRegion)).first,
    );
    expect(region().cursor, MouseCursor.defer);
    await tester.pump(TvRules.cursorHideAfter + const Duration(milliseconds: 10));
    expect(region().cursor, SystemMouseCursors.none);

    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(20, 20));
    await tester.pump();
    expect(region().cursor, MouseCursor.defer);
    await mouse.removePointer();
  });
}
