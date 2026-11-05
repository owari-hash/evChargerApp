import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// The bank's card page sends the driver back with `eplug://wallet/topup?id=…`.
///
/// On that link the in-app browser is closed (iOS; on Android the
/// `singleTask` activity already sits on top of the Custom Tab) and [signal]
/// ticks, so an open payment sheet checks the invoice at once instead of
/// waiting for its next poll — and the result animation plays right away.
class TopUpReturn {
  TopUpReturn._();

  static final ValueNotifier<int> signal = ValueNotifier<int>(0);

  /// The payment id the bank page named, if it named one.
  static String? lastPaymentId;

  static StreamSubscription<Uri>? _sub;

  static void start() {
    if (_sub != null) return;
    _sub = AppLinks().uriLinkStream.listen(_handle, onError: (Object _) {});
  }

  static void _handle(Uri uri) {
    if (uri.scheme != 'eplug' || uri.host != 'wallet') return;
    lastPaymentId = uri.queryParameters['id'];
    unawaited(closeInAppWebView().catchError((Object _) {}));
    signal.value++;
  }
}
