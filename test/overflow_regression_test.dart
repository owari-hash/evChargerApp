import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evchargerapp/screens/quick_controls_screen.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/charge_limit_selector.dart';
import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/widgets/swipe_to_slide_button.dart';

/// Screen widths worth caring about: iPhone SE through Pro Max.
const List<Size> _phones = <Size>[
  Size(320, 568),
  Size(390, 844),
  Size(430, 932),
];

Future<void> _pumpFrames(WidgetTester tester, [int frames = 4]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _host(Widget child, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUp(() => OcppMockService.enablePeriodicTimer = false);

  for (final ThemeData theme in <ThemeData>[
    AppTheme.lightTheme,
    AppTheme.darkTheme,
  ]) {
    final String mode = theme.brightness == Brightness.dark ? 'dark' : 'light';

    for (final Size size in _phones) {
      testWidgets(
        'charge limit selector fits ${size.width.toInt()}pt ($mode)',
        (WidgetTester tester) async {
          tester.view.physicalSize = size * 2;
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            _host(
              ChargeLimitSelector(targetLimitPct: 75, onLimitChanged: (_) {}),
              theme,
            ),
          );
          await _pumpFrames(tester);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('slide-to-start fits ${size.width.toInt()}pt ($mode)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _host(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: const SwipeToSlideButton(
                onSwipeCompleted: _noop,
                text: 'Цэнэглэж эхлэхийн тулд гулсуулна уу',
              ),
            ),
            theme,
          ),
        );
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('quick controls fits ${size.width.toInt()}pt ($mode)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(theme: theme, home: const QuickControlsScreen()),
        );
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('login fits ${size.width.toInt()}pt with no scroll ($mode)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: LoginRegisterScreen(onLoginSuccess: _noop),
          ),
        );
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);

        // The submit button must be fully on screen without scrolling: the
        // sheet used to be a fixed 30% with its own scroll view, which left
        // dead space on tall phones and hid the button on short ones.
        final Finder submit = find.byType(ElevatedButton);
        expect(submit, findsOneWidget);
        final Rect box = tester.getRect(submit);
        expect(box.bottom, lessThanOrEqualTo(size.height + 0.5));
        expect(box.top, greaterThanOrEqualTo(0));

        // Signing in must fit outright, so every field is visible without the
        // driver scrolling for it.
        for (final Rect field
            in tester
                .widgetList<TextField>(find.byType(TextField))
                .map((TextField f) => tester.getRect(find.byWidget(f)))) {
          expect(field.top, greaterThanOrEqualTo(0));
          expect(field.bottom, lessThanOrEqualTo(size.height + 0.5));
        }
      });

      testWidgets('sign-up fits ${size.width.toInt()}pt ($mode)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: LoginRegisterScreen(onLoginSuccess: _noop),
          ),
        );
        await _pumpFrames(tester);

        // Switch to the taller stack: five fields plus the terms line.
        await tester.tap(find.text(AppStrings.get('register')));
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsNWidgets(5));

        // The button stays pinned below the scrolling fields.
        final Finder submit = find.byType(ElevatedButton);
        expect(submit, findsOneWidget);
        final Rect box = tester.getRect(submit);
        expect(box.bottom, lessThanOrEqualTo(size.height + 0.5));
        expect(box.top, greaterThanOrEqualTo(0));
      });
    }
  }
}

void _noop() {}
