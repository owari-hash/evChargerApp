import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/widgets/swipe_to_slide_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> swipe(WidgetTester tester, bool Function() onDone) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: SwipeToSlideButton(onSwipeCompleted: onDone),
            ),
          ),
        ),
      ),
    );
    await tester.drag(
      find.byIcon(Icons.arrow_forward_rounded),
      const Offset(320, 0),
    );
    await tester.pump();
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a declined swipe springs back to the start', (
    WidgetTester tester,
  ) async {
    // Regression: with an empty wallet the knob stayed parked at the end.
    int calls = 0;
    await swipe(tester, () {
      calls++;
      return false;
    });

    expect(calls, 1);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('an accepted swipe stays confirmed', (WidgetTester tester) async {
    await swipe(tester, () => true);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
