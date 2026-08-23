import 'package:evchargerapp/screens/login_register_screen.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _noop() {}

/// Every span of the consent line, flattened.
List<TextSpan> _termsSpans(WidgetTester tester) {
  final Iterable<RichText> texts = tester.widgetList<RichText>(
    find.byType(RichText),
  );

  for (final RichText rich in texts) {
    final InlineSpan root = rich.text;
    if (root is! TextSpan) continue;
    final List<TextSpan> spans = <TextSpan>[];
    root.visitChildren((InlineSpan span) {
      if (span is TextSpan) spans.add(span);
      return true;
    });
    final String joined = spans.map((TextSpan s) => s.text ?? '').join();
    if (joined.contains(AppStrings.get('auth_terms_privacy'))) return spans;
  }
  return const <TextSpan>[];
}

void main() {
  setUp(() => AppStrings.currentLanguage = AppLanguage.mn);
  tearDown(() => AppStrings.currentLanguage = AppLanguage.mn);

  Future<void> openRegister(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: LoginRegisterScreen(onLoginSuccess: _noop)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(AppStrings.get('register')));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the sign-up consent line offers both documents as links', (
    WidgetTester tester,
  ) async {
    await openRegister(tester);

    final List<TextSpan> spans = _termsSpans(tester);
    expect(
      spans,
      isNotEmpty,
      reason: 'the consent line should be rendered as rich text',
    );

    // Apple expects the terms and privacy policy a registration screen names to
    // be openable from that screen, so both must carry a tap recognizer.
    for (final String label in <String>[
      AppStrings.get('auth_terms_terms'),
      AppStrings.get('auth_terms_privacy'),
    ]) {
      final TextSpan link = spans.firstWhere(
        (TextSpan s) => s.text == label,
        orElse: () => const TextSpan(),
      );
      expect(link.text, label, reason: 'missing a span for "$label"');
      expect(
        link.recognizer,
        isA<TapGestureRecognizer>(),
        reason: '"$label" must be tappable, not decoration',
      );
      expect(link.style?.decoration, TextDecoration.underline);
    }
  });

  for (final AppLanguage language in AppLanguage.values) {
    testWidgets('the consent line reads as a sentence in ${language.name}', (
      WidgetTester tester,
    ) async {
      AppStrings.currentLanguage = language;
      await openRegister(tester);

      final String sentence = _termsSpans(
        tester,
      ).map((TextSpan s) => s.text ?? '').join();

      // The pieces must reassemble into the sentence, or a translation has
      // drifted and the line reads as fragments.
      expect(sentence, contains(AppStrings.get('auth_terms_prefix')));
      expect(sentence, contains(AppStrings.get('auth_terms_terms')));
      expect(sentence, contains(AppStrings.get('auth_terms_privacy')));
      expect(sentence.trim(), isNotEmpty);
    });
  }

  testWidgets('the consent line disposes its recognizers with the screen', (
    WidgetTester tester,
  ) async {
    await openRegister(tester);
    expect(_termsSpans(tester), isNotEmpty);

    // Tearing the screen down must not leave a recognizer behind; a leaked one
    // trips the framework's own debug check on the next frame.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
