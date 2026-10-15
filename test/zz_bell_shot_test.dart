import 'dart:io';
import 'dart:ui' as ui;

import 'package:evchargerapp/main.dart';
import 'package:evchargerapp/services/notifications_store.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';
import 'package:evchargerapp/utils/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth.dart';

const String _out = '/private/tmp/claude-501/-Users-macbookairm4-evChargerApp/1567d0f9-29e8-4847-bd87-77922e9a592a/scratchpad/notif_shots';

Future<void> _noPrompts(BuildContext context) async {}

Future<void> _shot(WidgetTester tester, String name) async {
  final RenderRepaintBoundary b = tester.renderObject(find.byType(RepaintBoundary).first);
  await tester.runAsync(() async {
    final ui.Image im = await b.toImage(pixelRatio: 1.0);
    final ByteData? png = await im.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('bell shots', (WidgetTester tester) async {
    OcppMockService.enablePeriodicTimer = false;
    AppStrings.currentLanguage = AppLanguage.mn;
    final FontLoader geist = FontLoader('Geist');
    for (final String w in <String>['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
      geist.addFont(rootBundle.load('assets/fonts/Geist-$w.ttf'));
    }
    await geist.load();
    final FontLoader icons = FontLoader('MaterialIcons');
    icons.addFont(Future<ByteData>.value(ByteData.sublistView(File('/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
    await icons.load();

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(RepaintBoundary(child: EvChargerApp(authService: fakeAuthService(startSignedIn: true), startupPrompts: _noPrompts)));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final NotificationsStore store = NotificationsStore.instance;
    await tester.runAsync(() async {
      await store.add(kind: NotificationKind.wallet, title: 'Хэтэвч цэнэглэгдлээ', body: '+20,000₮ · QPay');
      await store.add(kind: NotificationKind.chargeStarted, title: 'Цэнэглэлт эхэллээ', body: 'Зайсан Хилл · 14:05 цагаас эхэлсэн');
      await store.add(kind: NotificationKind.chargeStopped, title: 'Цэнэглэлт дууслаа', body: 'Зайсан Хилл · 18.40 кВт·ц · 9,200₮');
    });
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _shot(tester, 'app_topbar_bell');
    await tester.tap(find.byIcon(Icons.notifications_rounded).first);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _shot(tester, 'app_bell_sheet');
  });
}
