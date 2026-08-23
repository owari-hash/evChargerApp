import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/screens/quick_controls_screen.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';
import 'package:evchargerapp/theme/app_theme.dart';

Future<void> _pumpFrames(WidgetTester tester, [int frames = 5]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() => OcppMockService.enablePeriodicTimer = false);

  testWidgets('map opens as a page whose back button clears the status bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    // Simulate a notched device: 59pt of top inset.
    tester.view.padding = const FakeViewPadding(top: 177);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const QuickControlsScreen(),
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await _pumpFrames(tester, 8);

    // The map page is up.
    expect(find.text('Цэнэглэх станцын зураг'), findsOneWidget);

    final Finder back = find.byTooltip('Буцах');
    expect(back, findsOneWidget);

    // Regression: as a modal sheet the header sat under the notch, so the back
    // button was unreachable. It must now sit fully below the status bar.
    final double topInset =
        tester.view.padding.top / tester.view.devicePixelRatio;
    expect(tester.getTopLeft(back).dy, greaterThanOrEqualTo(topInset));

    // And it actually dismisses the page.
    await tester.tap(back);
    await _pumpFrames(tester, 8);
    expect(find.text('Цэнэглэх станцын зураг'), findsNothing);
  });
}
