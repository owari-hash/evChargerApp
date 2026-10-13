import 'package:evchargerapp/models/app_update.dart';
import 'package:evchargerapp/theme/app_theme.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/app_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppUpdateInfo _info({
  required bool force,
  String latest = '1.0.14',
  String current = '1.0.13',
  String? storeUrl = 'https://play.google.com/store/apps/details?id=mn.eplug.app',
  String notesMn = 'Хэтэвчний алдаа засагдлаа.',
  String platform = 'android',
}) {
  return AppUpdateInfo(
    platform: platform,
    currentVersion: current,
    currentBuild: 68,
    latestVersion: latest,
    latestBuild: 70,
    updateAvailable: true,
    forceUpdate: force,
    storeUrl: storeUrl,
    releaseNotesMn: notesMn,
    releaseNotesEn: 'Wallet fixes.',
  );
}

/// Pumps the dialog the way the app raises it, so barrier behaviour is real.
Future<void> _showDialog(WidgetTester tester, AppUpdateInfo info) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => AppUpdateDialog.show(context, info),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppStrings.currentLanguage = AppLanguage.mn);

  group('AppUpdateInfo', () {
    test('shouldPrompt needs both an update and somewhere to send the driver', () {
      expect(_info(force: false).shouldPrompt, isTrue);
      expect(_info(force: false, storeUrl: null).shouldPrompt, isFalse);
      expect(_info(force: false, storeUrl: '').shouldPrompt, isFalse);
    });

    test('none() never prompts', () {
      const AppUpdateInfo none = AppUpdateInfo.none();
      expect(none.shouldPrompt, isFalse);
      expect(none.forceUpdate, isFalse);
    });

    test('parses the API payload, including a null build', () {
      final AppUpdateInfo parsed = AppUpdateInfo.fromJson(<String, dynamic>{
        'platform': 'ios',
        'currentVersion': '1.0.9',
        'currentBuild': null,
        'latestVersion': '1.0.14',
        'latestBuild': 70,
        'updateAvailable': true,
        'forceUpdate': true,
        'storeUrl': 'https://apps.apple.com/mn/app/eplug/id1',
        'releaseNotes': 'Шинэчлэл',
      });

      expect(parsed.platform, 'ios');
      expect(parsed.currentBuild, isNull);
      expect(parsed.latestBuild, 70);
      expect(parsed.forceUpdate, isTrue);
      expect(parsed.releaseNotesMn, 'Шинэчлэл');
    });
  });

  group('optional update', () {
    testWidgets('offers both Later and Update', (WidgetTester tester) async {
      await _showDialog(tester, _info(force: false));

      expect(find.text(AppStrings.get('update_later')), findsOneWidget);
      expect(find.text(AppStrings.get('update_now')), findsOneWidget);
      expect(find.text(AppStrings.get('update_title')), findsOneWidget);
    });

    testWidgets('shows the release notes and the new version', (
      WidgetTester tester,
    ) async {
      await _showDialog(tester, _info(force: false));

      expect(find.text('Хэтэвчний алдаа засагдлаа.'), findsOneWidget);
      expect(find.textContaining('1.0.14'), findsWidgets);
    });

    testWidgets('tapping the barrier dismisses it', (WidgetTester tester) async {
      await _showDialog(tester, _info(force: false));
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('forced update', () {
    testWidgets('offers no way out but the store', (WidgetTester tester) async {
      await _showDialog(tester, _info(force: true));

      expect(find.text(AppStrings.get('update_title_force')), findsOneWidget);
      expect(find.text(AppStrings.get('update_later')), findsNothing);
      expect(find.text(AppStrings.get('update_now')), findsOneWidget);
    });

    testWidgets('survives a barrier tap', (WidgetTester tester) async {
      await _showDialog(tester, _info(force: true));

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('survives the system back gesture', (WidgetTester tester) async {
      await _showDialog(tester, _info(force: true));

      final bool popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // PopScope refuses the pop, so the dialog is still standing.
      expect(popped, isTrue);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('language', () {
    testWidgets('renders English copy when the app is in English', (
      WidgetTester tester,
    ) async {
      AppStrings.currentLanguage = AppLanguage.en;
      await _showDialog(tester, _info(force: false));

      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      // English notes are preferred when the app is in English.
      expect(find.text('Wallet fixes.'), findsOneWidget);
    });

    testWidgets('falls back to the other language when notes are empty', (
      WidgetTester tester,
    ) async {
      AppStrings.currentLanguage = AppLanguage.en;
      await _showDialog(
        tester,
        AppUpdateInfo(
          platform: 'android',
          currentVersion: '1.0.13',
          latestVersion: '1.0.14',
          updateAvailable: true,
          forceUpdate: false,
          storeUrl: 'https://play.google.com/store/apps/details?id=mn.eplug.app',
          releaseNotesMn: 'Зөвхөн монголоор',
          releaseNotesEn: '',
        ),
      );

      expect(find.text('Зөвхөн монголоор'), findsOneWidget);
    });
  });
}
