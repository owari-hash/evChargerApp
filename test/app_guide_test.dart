import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/models/auth_user.dart';
import 'package:evchargerapp/screens/home_dashboard_screen.dart';
import 'package:evchargerapp/services/auth_service.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/guided_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_auth.dart';

/// The first-run walkthrough: shown once to new accounts after they sign in,
/// never to guests, and replayable from the account page.

final Finder _firstStep = find.text(AppStrings.get('guide_hero_title'));

bool _isGuideDone(http.Request r) =>
    r.method == 'POST' && r.url.path.endsWith('/account/guides/app/done');

/// The real update and announcement checks go to the network, so they are
/// stood in for; the ordering test passes its own.
Future<void> _noPrompts(BuildContext context) async {}

Future<void> _launch(
  WidgetTester tester,
  AuthService auth, {
  Future<void> Function(BuildContext context) startupPrompts = _noPrompts,
}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    EvChargerApp(authService: auth, startupPrompts: startupPrompts),
  );
}

/// Past the startup prompts, the dashboard's first load and the pause.
///
/// The app frame does not inject the dashboard's session and wallet services,
/// so in a test their first load never answers and the guide starts on the
/// dashboard's load cap (6 s) plus the pause — hence the long wait.
Future<void> _waitForGuide(WidgetTester tester) async {
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (_firstStep.evaluate().isNotEmpty) {
      // Let the card's entrance animation finish.
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }
  }
}

int _activeTab(WidgetTester tester) {
  return tester.widget<IndexedStack>(find.byType(IndexedStack).first).index!;
}

void main() {
  setUp(() {
    AppStrings.currentLanguage = AppLanguage.mn;
  });

  group('AuthUser.pendingGuides', () {
    test('parses the list the server sends', () {
      final AuthUser user = AuthUser.fromJson(<String, dynamic>{
        'id': 'u1',
        'name': 'Бат',
        'pendingGuides': <dynamic>['app', 'web'],
      });
      expect(user.pendingGuides, <String>['app', 'web']);
    });

    test('is empty when missing or malformed', () {
      expect(
        AuthUser.fromJson(<String, dynamic>{'id': 'u1', 'name': 'Бат'})
            .pendingGuides,
        isEmpty,
      );
      expect(
        AuthUser.fromJson(<String, dynamic>{
          'id': 'u1',
          'name': 'Бат',
          'pendingGuides': 'app',
        }).pendingGuides,
        isEmpty,
      );
    });
  });

  testWidgets('a guest never sees the guide', (WidgetTester tester) async {
    await _launch(tester, fakeAuthService(pendingGuides: <String>['app']));
    await _waitForGuide(tester);

    expect(_firstStep, findsNothing);
    expect(_activeTab(tester), 1, reason: 'stays on the map');
  });

  testWidgets('a returning driver with nothing pending does not see it', (
    WidgetTester tester,
  ) async {
    await _launch(tester, fakeAuthService(startSignedIn: true));
    await _waitForGuide(tester);

    expect(_firstStep, findsNothing);
    expect(_activeTab(tester), 1);
  });

  testWidgets('a new account sees it on the home tab after launch', (
    WidgetTester tester,
  ) async {
    await _launch(
      tester,
      fakeAuthService(startSignedIn: true, pendingGuides: <String>['app', 'web']),
    );
    await _waitForGuide(tester);

    expect(_activeTab(tester), 0, reason: 'switched to the dashboard');
    expect(_firstStep, findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text(AppStrings.get('guide_dont_show')), findsOneWidget);
  });

  testWidgets('it waits for the startup prompts and any modal on top', (
    WidgetTester tester,
  ) async {
    await _launch(
      tester,
      fakeAuthService(startSignedIn: true, pendingGuides: <String>['app']),
      // Stands in for the update dialog and the announcement.
      startupPrompts: (BuildContext context) => showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          content: const Text('announcement'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('close-prompt'),
            ),
          ],
        ),
      ),
    );
    await _waitForGuide(tester);
    expect(find.text('announcement'), findsOneWidget);
    expect(_firstStep, findsNothing);

    await tester.tap(find.text('close-prompt'));
    await tester.pump();

    // Something else opens on top before the guide gets going.
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => const SizedBox(
        height: 200,
        child: Text('sheet'),
      ),
    );
    await _waitForGuide(tester);
    expect(_firstStep, findsNothing);

    Navigator.of(tester.element(find.text('sheet'))).pop();
    await _waitForGuide(tester);
    expect(_firstStep, findsOneWidget);
  });

  testWidgets('it also starts right after signing in', (
    WidgetTester tester,
  ) async {
    await _launch(tester, fakeAuthService(pendingGuides: <String>['app']));
    await tester.pump();
    await tester.pump();
    expect(_firstStep, findsNothing);

    await signInThroughUi(tester);
    await _waitForGuide(tester);

    expect(_activeTab(tester), 0);
    expect(_firstStep, findsOneWidget);
  });

  testWidgets('a plain skip closes it without telling the server', (
    WidgetTester tester,
  ) async {
    final List<http.Request> log = <http.Request>[];
    final AuthService auth = fakeAuthService(
      startSignedIn: true,
      pendingGuides: <String>['app'],
      log: log,
    );
    await _launch(tester, auth);
    await _waitForGuide(tester);

    await tester.tap(find.text(AppStrings.get('guide_skip')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(_firstStep, findsNothing);
    expect(log.where(_isGuideDone), isEmpty);
    // Still pending on the server, but not again in this session.
    expect(auth.currentUser.value!.pendingGuides, contains('app'));
    expect(auth.shouldShowGuide('app'), isFalse);
  });

  testWidgets('skip with «Дахиж харахгүй» ticked marks it done', (
    WidgetTester tester,
  ) async {
    final List<http.Request> log = <http.Request>[];
    final AuthService auth = fakeAuthService(
      startSignedIn: true,
      pendingGuides: <String>['app', 'web'],
      log: log,
    );
    await _launch(tester, auth);
    await _waitForGuide(tester);

    await tester.tap(find.byKey(const ValueKey<String>('guide-dont-show')));
    await tester.pump();
    await tester.tap(find.text(AppStrings.get('guide_skip')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(_firstStep, findsNothing);
    expect(log.where(_isGuideDone), hasLength(1));
    expect(auth.currentUser.value!.pendingGuides, <String>['web']);
  });

  testWidgets('going through every step marks it done, ticked or not', (
    WidgetTester tester,
  ) async {
    final List<http.Request> log = <http.Request>[];
    final AuthService auth = fakeAuthService(
      startSignedIn: true,
      pendingGuides: <String>['app'],
      log: log,
    );
    await _launch(tester, auth);
    await _waitForGuide(tester);

    for (int step = 1; step <= 5; step++) {
      expect(find.text('$step / 5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('guide-next')));
      // The next section scrolls into view; let it get there.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    expect(find.text('5 / 5'), findsNothing);
    expect(log.where(_isGuideDone), hasLength(1));
    expect(auth.currentUser.value!.pendingGuides, isEmpty);
  });

  testWidgets('a failed done does not block and is retried later', (
    WidgetTester tester,
  ) async {
    final List<http.Request> log = <http.Request>[];
    final AuthService auth = fakeAuthService(
      startSignedIn: true,
      pendingGuides: <String>['app'],
      guidesDoneFails: true,
      log: log,
    );
    await _launch(tester, auth);
    await _waitForGuide(tester);

    await tester.tap(find.byKey(const ValueKey<String>('guide-dont-show')));
    await tester.pump();
    await tester.tap(find.text(AppStrings.get('guide_skip')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(_firstStep, findsNothing);
    expect(log.where(_isGuideDone), hasLength(1));
    expect(auth.shouldShowGuide('app'), isFalse);

    await auth.retryGuideDone('app');
    expect(log.where(_isGuideDone), hasLength(2));
  });

  testWidgets('the account page replays it without calling the server', (
    WidgetTester tester,
  ) async {
    final List<http.Request> log = <http.Request>[];
    await _launch(tester, fakeAuthService(startSignedIn: true, log: log));
    await _waitForGuide(tester);
    expect(_firstStep, findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('nav-tab-4')));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.text(AppStrings.get('guide_replay')));
    await tester.tap(find.text(AppStrings.get('guide_replay')));
    await _waitForGuide(tester);

    expect(_activeTab(tester), 0);
    expect(_firstStep, findsOneWidget);
    // Nothing to remember on a replay.
    expect(find.text(AppStrings.get('guide_dont_show')), findsNothing);

    await tester.tap(find.text(AppStrings.get('guide_skip')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_firstStep, findsNothing);
    expect(log.where(_isGuideDone), isEmpty);
  });

  testWidgets('the dashboard on its own has no guide wrappers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDashboardScreen(
          authService: fakeAuthService(),
        ),
      ),
    );
    expect(find.byType(GuidedStep), findsNothing);
  });
}
