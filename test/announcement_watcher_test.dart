import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/services/announcement_service.dart';
import 'package:evchargerapp/services/announcement_watcher_service.dart';
import 'package:evchargerapp/services/notifications_store.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/announcement_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

/// The `/app/announcements` feed, as whatever [items] holds at the time.
class _FakeFeed extends AnnouncementService {
  _FakeFeed(this.items);

  List<Announcement> items;
  int calls = 0;

  @override
  Future<List<Announcement>> fetchAll() async {
    calls++;
    return items;
  }
}

Announcement _a(String id, DateTime at, {String? image}) => Announcement(
  id: id,
  title: 'Мэдээ $id',
  body: 'Агуулга $id',
  imageUrl: image,
  createdAt: at,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime now = DateTime.utc(2026, 10, 16, 9);
  late _FakeFeed feed;
  late AnnouncementWatcherService watcher;
  late List<List<Announcement>> reported;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    feed = _FakeFeed(<Announcement>[]);
    reported = <List<Announcement>>[];
    watcher = AnnouncementWatcherService(
      service: feed,
      pollInterval: const Duration(hours: 1),
      clock: () => now,
    );
  });

  tearDown(() => watcher.signOut());

  Future<void> startFor(String userId, {DateTime? createdAt}) async {
    watcher.start(
      userId: userId,
      accountCreatedAt: createdAt,
      onNew: reported.add,
    );
    await watcher.checkNow();
  }

  group('AnnouncementWatcherService', () {
    test('announcements older than the account are a silent baseline', () async {
      feed.items = <Announcement>[
        _a('old', now.subtract(const Duration(days: 30))),
      ];
      await startFor('u1', createdAt: now.subtract(const Duration(days: 1)));
      expect(reported, isEmpty);
    });

    test('one published after the account is reported once', () async {
      final DateTime created = now.subtract(const Duration(days: 10));
      feed.items = <Announcement>[_a('a1', now.subtract(const Duration(days: 2)))];
      await startFor('u1', createdAt: created);
      expect(reported.single.single.id, 'a1');

      // Seen: the next check (or a relaunch) says nothing.
      await watcher.checkNow();
      expect(reported, hasLength(1));
    });

    test('a new one arriving while the app is open is reported', () async {
      feed.items = <Announcement>[_a('old', now.subtract(const Duration(days: 3)))];
      await startFor('u1'); // no createdAt: the first run is the cutoff
      expect(reported, isEmpty);

      feed.items = <Announcement>[
        _a('new', now.add(const Duration(minutes: 5))),
        ...feed.items,
      ];
      await watcher.checkNow();
      expect(reported.single.map((Announcement a) => a.id), <String>['new']);
    });

    test('what one driver has seen does not hide it from another', () async {
      final DateTime created = now.subtract(const Duration(days: 10));
      feed.items = <Announcement>[_a('a1', now.subtract(const Duration(days: 1)))];
      await startFor('u1', createdAt: created);
      expect(reported, hasLength(1));

      watcher.signOut();
      reported.clear();
      await startFor('u2', createdAt: created);
      expect(reported.single.single.id, 'a1');

      // And back to the first driver: still seen for them.
      watcher.signOut();
      reported.clear();
      await startFor('u1', createdAt: created);
      expect(reported, isEmpty);
    });
  });

  group('app frame', () {
      testWidgets('a new announcement goes in the bell and is shown', (
      WidgetTester tester,
    ) async {
      LanguageController.set(AppLanguage.mn);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);

      final AnnouncementWatcherService original =
          AnnouncementWatcherService.instance;
      addTearDown(() {
        AnnouncementWatcherService.instance.signOut();
        AnnouncementWatcherService.instance = original;
      });
      // The stub driver has no createdAt, so the first run is the cutoff:
      // published a minute "from now" makes it news.
      feed.items = <Announcement>[
        _a('a1', DateTime.now().add(const Duration(minutes: 1)),
            image: 'https://example.com/a.png'),
      ];
      AnnouncementWatcherService.instance = AnnouncementWatcherService(
        service: feed,
        pollInterval: const Duration(hours: 1),
      );

      await tester.pumpWidget(
        EvChargerApp(
          authService: fakeAuthService(startSignedIn: true),
          startupPrompts: (_) async {},
        ),
      );
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(AnnouncementDialog), findsOneWidget);
      expect(find.text('Мэдээ a1'), findsOneWidget);
      final AppNotification filed = NotificationsStore.instance.items.value
          .firstWhere((AppNotification n) => n.kind == NotificationKind.announcement);
      expect(filed.title, 'Мэдээ a1');
      expect(filed.imageUrl, 'https://example.com/a.png');

      // Tapping outside closes it, and it does not come back.
      await tester.tapAt(const Offset(10, 10));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AnnouncementDialog), findsNothing);
      await AnnouncementWatcherService.instance.checkNow();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AnnouncementDialog), findsNothing);
      expect(
        NotificationsStore.instance.items.value.where(
          (AppNotification n) => n.kind == NotificationKind.announcement,
        ),
        hasLength(1),
      );
    });
  });
}
