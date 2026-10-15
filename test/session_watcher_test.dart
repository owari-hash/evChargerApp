import 'package:evchargerapp/models/charging_session.dart';
import 'package:evchargerapp/models/wallet.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/notifications_store.dart';
import 'package:evchargerapp/services/session_watcher_service.dart';
import 'package:evchargerapp/services/sessions_service.dart';
import 'package:evchargerapp/services/wallet_service.dart';
import 'package:evchargerapp/services/wallet_watcher_service.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:evchargerapp/widgets/charge_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

Map<String, dynamic> session(
  int id, {
  required String status,
  String station = 'Сүхбаатарын талбай',
  num energyKwh = 0,
  num? cost,
}) => <String, dynamic>{
  'transactionId': id,
  'chargePointId': 'CP-$id',
  'stationName': station,
  'connectorId': 1,
  'idTag': 'TAG-001',
  'status': status,
  'startTimestamp': '2026-10-15T06:05:00.000Z',
  if (status != 'Active') 'stopTimestamp': '2026-10-15T06:47:00.000Z',
  'energyKwh': energyKwh,
  'cost': ?cost,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> sessions;
  late SessionWatcherService watcher;
  late List<SessionEvent> events;

  setUp(() {
    LanguageController.set(AppLanguage.mn);
    sessions = <Map<String, dynamic>>[];
    events = <SessionEvent>[];
    final ApiClient client = fakeApiClient(
      startSignedIn: true,
      sessions: () => sessions,
    );
    watcher = SessionWatcherService(
      sessions: SessionsService(client: client),
      // Long enough that only the explicit checks below run.
      pollInterval: const Duration(hours: 1),
      followUpDelays: const <Duration>[],
    );
  });

  tearDown(() => watcher.signOut());

  Future<void> startAndBaseline(String userId) async {
    watcher.start(userId: userId, onEvent: events.add);
    await watcher.checkNow();
  }

  test('the first list is a silent baseline', () async {
    sessions = <Map<String, dynamic>>[
      session(12, status: 'Active'),
      session(11, status: 'Completed', energyKwh: 9, cost: 4500),
      session(10, status: 'Rejected'),
    ];
    await startAndBaseline('usr_a');
    await watcher.checkNow();

    expect(events, isEmpty);
  });

  test('a charge that was already running finishing is reported', () async {
    sessions = <Map<String, dynamic>>[session(12, status: 'Active')];
    await startAndBaseline('usr_a');

    sessions = <Map<String, dynamic>>[
      session(12, status: 'Completed', energyKwh: 18.4, cost: 9200),
    ];
    await watcher.checkNow();

    expect(events.map((e) => e.type), <SessionEventType>[SessionEventType.stopped]);
  });

  test('a new active session gives a start notification', () async {
    sessions = <Map<String, dynamic>>[
      session(11, status: 'Completed', energyKwh: 9, cost: 4500),
    ];
    await startAndBaseline('usr_a');

    sessions = <Map<String, dynamic>>[
      session(12, status: 'Active', station: 'Зайсан'),
      ...sessions,
    ];
    await watcher.checkNow();

    expect(events, hasLength(1));
    expect(events.single.type, SessionEventType.started);
    expect(events.single.session.transactionId, 12);
    expect(events.single.confirmedInApp, isFalse);

    final text = chargeNotificationText(events.single);
    expect(text.title, 'Цэнэглэлт эхэллээ');
    expect(text.body, startsWith('Зайсан · '));
    expect(text.body, endsWith('цагаас эхэлсэн'));
  });

  test('active → completed gives a stop notification with kWh and cost', () async {
    await startAndBaseline('usr_a');
    sessions = <Map<String, dynamic>>[session(12, status: 'Active')];
    await watcher.checkNow();

    sessions = <Map<String, dynamic>>[
      session(12, status: 'Completed', energyKwh: 18.4, cost: 9200),
    ];
    await watcher.checkNow();

    expect(events.map((e) => e.type), <SessionEventType>[
      SessionEventType.started,
      SessionEventType.stopped,
    ]);
    final text = chargeNotificationText(events.last);
    expect(text.title, 'Цэнэглэлт дууслаа');
    expect(text.body, 'Сүхбаатарын талбай · 18.40 кВт·ц · 9,200.00₮');

    LanguageController.set(AppLanguage.en);
    final en = chargeNotificationText(events.last);
    expect(en.title, 'Charging finished');
    expect(en.body, 'Сүхбаатарын талбай · 18.40 kWh · 9,200.00₮');
  });

  test('active → rejected also counts as finished', () async {
    await startAndBaseline('usr_a');
    sessions = <Map<String, dynamic>>[session(12, status: 'Active')];
    await watcher.checkNow();
    sessions = <Map<String, dynamic>>[session(12, status: 'Rejected')];
    await watcher.checkNow();

    expect(events.last.type, SessionEventType.stopped);
    // Nothing metered: just the station.
    expect(chargeNotificationText(events.last).body, 'Сүхбаатарын талбай');
  });

  test('no duplicates across polls', () async {
    await startAndBaseline('usr_a');
    sessions = <Map<String, dynamic>>[session(12, status: 'Active')];
    await watcher.checkNow();
    await watcher.checkNow();
    // The dashboard sharing its own poll of the same list.
    watcher.ingest(sessions.map(ChargingSession.fromJson).toList());

    sessions = <Map<String, dynamic>>[
      session(12, status: 'Completed', energyKwh: 5, cost: 2500),
    ];
    await watcher.checkNow();
    await watcher.checkNow();
    // A later refund is not a second finish.
    sessions = <Map<String, dynamic>>[
      session(12, status: 'Refunded', energyKwh: 5, cost: 2500),
    ];
    await watcher.checkNow();

    expect(events.map((e) => e.type), <SessionEventType>[
      SessionEventType.started,
      SessionEventType.stopped,
    ]);
  });

  test('older sessions sliding into the window are not news', () async {
    sessions = <Map<String, dynamic>>[session(20, status: 'Completed')];
    await startAndBaseline('usr_a');
    sessions = <Map<String, dynamic>>[
      session(20, status: 'Completed'),
      session(15, status: 'Completed'),
    ];
    await watcher.checkNow();

    expect(events, isEmpty);
  });

  test('a whole short charge between two polls reports the finish', () async {
    await startAndBaseline('usr_a');
    sessions = <Map<String, dynamic>>[
      session(30, status: 'Completed', energyKwh: 2, cost: 1000),
    ];
    await watcher.checkNow();

    expect(events.map((e) => e.type), <SessionEventType>[SessionEventType.stopped]);
  });

  test("the app's own start and stop are marked as already confirmed", () async {
    await startAndBaseline('usr_a');
    watcher.noteLocalStart();
    sessions = <Map<String, dynamic>>[session(12, status: 'Active')];
    await watcher.checkNow();
    watcher.noteLocalStop(12, confirmedInApp: true);
    sessions = <Map<String, dynamic>>[session(12, status: 'Completed')];
    await watcher.checkNow();

    expect(events.map((e) => e.confirmedInApp), <bool>[true, true]);

    // Only one start is accounted for by one tap.
    sessions = <Map<String, dynamic>>[session(13, status: 'Active'), ...sessions];
    await watcher.checkNow();
    expect(events.last.confirmedInApp, isFalse);
  });

  test('sign-out isolation: the next driver starts from their own baseline', () async {
    sessions = <Map<String, dynamic>>[session(12, status: 'Active')];
    await startAndBaseline('usr_a');

    watcher.signOut();
    // Driver B signs in on the same phone. Their list has nothing in common
    // with A's, and must not read as "A's charge finished" or "new charges".
    sessions = <Map<String, dynamic>>[
      session(50, status: 'Active'),
      session(49, status: 'Completed'),
    ];
    await startAndBaseline('usr_b');
    await watcher.checkNow();

    expect(events, isEmpty);
  });

  group('per-account storage', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

    test('the bell history follows the signed-in driver', () async {
      final NotificationsStore store = NotificationsStore();
      await store.setUser('usr_a');
      await store.add(
        kind: NotificationKind.chargeStopped,
        title: 'Цэнэглэлт дууслаа',
        body: 'Зайсан · 9,200.00₮',
        transactionId: 12,
      );
      expect(store.items.value, hasLength(1));
      expect(store.unread.value, 1);

      await store.setUser(null);
      expect(store.items.value, isEmpty);
      expect(store.unread.value, 0);
      // Signed out: nothing to file it under.
      await store.add(kind: NotificationKind.wallet, title: 'x', body: 'y');

      await store.setUser('usr_b');
      expect(store.items.value, isEmpty);

      // A fresh launch for A finds A's history again, kind and charge intact.
      final NotificationsStore relaunched = NotificationsStore();
      await relaunched.setUser('usr_a');
      expect(relaunched.items.value, hasLength(1));
      expect(relaunched.items.value.single.kind, NotificationKind.chargeStopped);
      expect(relaunched.items.value.single.transactionId, 12);
    });

    test('the old device-wide history is not shown to anyone', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'app_notifications':
            '[{"id":"1","kind":"wallet","title":"Цэнэглэлт","body":"+₮20,000","at":"2026-10-01T00:00:00.000Z"}]',
      });
      final NotificationsStore store = NotificationsStore();
      await store.setUser('usr_b');
      expect(store.items.value, isEmpty);
      expect(await const FlutterSecureStorage().read(key: 'app_notifications'), isNull);
    });

    test("the wallet watcher's marker is per driver", () async {
      // A's marker from before markers were per account, and A's own.
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'wallet_watcher_last_seen_entry': 'e_from_driver_a',
        WalletWatcherService.lastSeenKeyFor('usr_a'): 'e_from_driver_a',
      });
      final WalletWatcherService wallet = WalletWatcherService(
        wallet: WalletService(client: fakeApiClient(startSignedIn: true)),
      );
      final List<WalletEntry> popped = <WalletEntry>[];

      // B's first poll: their latest entry (e_1) is a baseline, not news.
      await wallet.pollOnce(userId: 'usr_b', onNewEntry: popped.add);
      await wallet.pollOnce(userId: 'usr_b', onNewEntry: popped.add);
      expect(popped, isEmpty);
      expect(
        await const FlutterSecureStorage().read(
          key: WalletWatcherService.lastSeenKeyFor('usr_b'),
        ),
        'e_1',
      );
      expect(
        await const FlutterSecureStorage().read(
          key: WalletWatcherService.lastSeenKeyFor('usr_a'),
        ),
        'e_from_driver_a',
      );
    });
  });
}
