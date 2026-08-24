import 'package:evchargerapp/models/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMnt', () {
    test('groups thousands, appends the sign and carries two decimals', () {
      expect(formatMnt(0), '0.00₮');
      expect(formatMnt(999), '999.00₮');
      expect(formatMnt(15800), '15,800.00₮');
      expect(formatMnt(5000000), '5,000,000.00₮');
    });

    test('keeps the sign on a wallet in debt', () {
      expect(formatMnt(-9200), '-9,200.00₮');
    });
  });

  group('TopUpInvoice.mergedWith', () {
    // The create response carries the QR; the poll response does not.
    final TopUpInvoice created = TopUpInvoice.fromJson(<String, dynamic>{
      'id': 'inv_1',
      'status': 'PENDING',
      'amount': 20000,
      'qrImage': 'iVBORw0KGgo=',
      'qrText': '0002010102121531',
      'shortUrl': 'https://s.qpay.mn/abc',
      'deeplinks': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Khan Bank', 'link': 'khanbank://q?qr=1'},
      ],
    });

    test('keeps the QR and deeplinks the poll response omits', () {
      // This is what /wallet/topup/{id} really answers with: no qrImage, no
      // deeplinks. Taking it wholesale used to blank the QR mid-scan.
      final TopUpInvoice polled = TopUpInvoice.fromJson(<String, dynamic>{
        'id': 'inv_1',
        'status': 'PENDING',
        'amount': 20000,
        'paidAmount': 0,
      });

      final TopUpInvoice merged = created.mergedWith(polled);

      expect(merged.qrImage, 'iVBORw0KGgo=');
      expect(merged.qrText, '0002010102121531');
      expect(merged.shortUrl, 'https://s.qpay.mn/abc');
      expect(merged.deeplinks, hasLength(1));
      expect(merged.deeplinks.single.name, 'Khan Bank');
    });

    test('takes the status and paid amount from the poll response', () {
      final TopUpInvoice polled = TopUpInvoice.fromJson(<String, dynamic>{
        'id': 'inv_1',
        'status': 'PAID',
        'amount': 20000,
        'paidAmount': 20000,
      });

      final TopUpInvoice merged = created.mergedWith(polled);

      expect(merged.status, InvoiceStatus.paid);
      expect(merged.isPaid, isTrue);
      expect(merged.paidAmount, 20000);
      // Still holds the QR, so the sheet can show what was paid.
      expect(merged.qrImage, isNotNull);
    });

    test('carries an expiry through so the sheet can stop polling', () {
      final TopUpInvoice polled = TopUpInvoice.fromJson(<String, dynamic>{
        'id': 'inv_1',
        'status': 'EXPIRED',
        'amount': 20000,
      });

      final TopUpInvoice merged = created.mergedWith(polled);

      expect(merged.status, InvoiceStatus.expired);
      expect(merged.isSettled, isTrue);
      expect(merged.isPaid, isFalse);
    });

    test('a zero amount in the poll response does not wipe the real one', () {
      final TopUpInvoice polled = TopUpInvoice.fromJson(<String, dynamic>{
        'id': 'inv_1',
        'status': 'PENDING',
      });

      expect(created.mergedWith(polled).amount, 20000);
    });
  });
}
