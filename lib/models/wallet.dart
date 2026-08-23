/// Prepaid wallet types, mirroring `src/lib/csms/wallet.ts` in evChargerKiosk.
///
/// The wallet itself lives in the CSMS (`evChargerBack`); the kiosk's
/// `/app-api/wallet` routes scope every read to the signed-in driver before
/// delegating, so the app only ever sees its own balance.
library;

// Money formatting lives in one place; re-exported so the screens and tests
// that already reach for it through this model keep working.
export '../utils/money.dart' show formatMnt;

enum WalletStatus { active, frozen }

class Wallet {
  const Wallet({
    required this.id,
    required this.balance,
    required this.currency,
    required this.status,
    required this.totalToppedUp,
    required this.totalSpent,
    this.idTags = const <String>[],
    this.lastTopUpAt,
    this.lastSpendAt,
  });

  final String id;

  /// May be negative: a session that outran the balance is allowed to push the
  /// wallet into debt rather than silently writing the shortfall off.
  final num balance;

  final String currency;
  final WalletStatus status;
  final num totalToppedUp;
  final num totalSpent;

  /// Charge tags that spend from this balance.
  final List<String> idTags;

  final DateTime? lastTopUpAt;
  final DateTime? lastSpendAt;

  bool get isFrozen => status == WalletStatus.frozen;
  bool get inDebt => balance < 0;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: (json['id'] ?? '').toString(),
      balance: _num(json['balance']),
      currency: (json['currency'] ?? 'MNT').toString(),
      status: (json['status'] ?? 'ACTIVE').toString().toUpperCase() == 'FROZEN'
          ? WalletStatus.frozen
          : WalletStatus.active,
      totalToppedUp: _num(json['totalToppedUp']),
      totalSpent: _num(json['totalSpent']),
      idTags: _stringList(json['idTags']),
      lastTopUpAt: _date(json['lastTopUpAt']),
      lastSpendAt: _date(json['lastSpendAt']),
    );
  }
}

enum WalletEntryType { topUp, charge, refund, adjustment, bonus }

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.description,
    this.chargePointId,
    this.transactionId,
  });

  final String id;
  final WalletEntryType type;

  /// Signed: positive credits the wallet, negative debits it.
  final num amount;

  final num balanceAfter;
  final DateTime? createdAt;
  final String? description;
  final String? chargePointId;
  final int? transactionId;

  bool get isCredit => amount >= 0;

  factory WalletEntry.fromJson(Map<String, dynamic> json) {
    return WalletEntry(
      id: (json['id'] ?? '').toString(),
      type: _entryType((json['type'] ?? '').toString()),
      amount: _num(json['amount']),
      balanceAfter: _num(json['balanceAfter']),
      createdAt: _date(json['createdAt']),
      description: _text(json['description']),
      chargePointId: _text(json['chargePointId']),
      transactionId: json['transactionId'] is num
          ? (json['transactionId'] as num).toInt()
          : null,
    );
  }

  static WalletEntryType _entryType(String raw) {
    switch (raw.toUpperCase()) {
      case 'TOPUP':
        return WalletEntryType.topUp;
      case 'REFUND':
        return WalletEntryType.refund;
      case 'BONUS':
        return WalletEntryType.bonus;
      case 'ADJUSTMENT':
        return WalletEntryType.adjustment;
      default:
        return WalletEntryType.charge;
    }
  }
}

/// Top-up limits and presets, set by the CSMS environment.
class WalletConfig {
  const WalletConfig({
    required this.enabled,
    required this.topUpEnabled,
    required this.presets,
    required this.minTopUp,
    required this.maxTopUp,
    required this.minStartBalance,
  });

  final bool enabled;

  /// False when QPay is switched off — the top-up button has to be hidden.
  final bool topUpEnabled;

  final List<int> presets;
  final int minTopUp;
  final int maxTopUp;
  final int minStartBalance;

  factory WalletConfig.fromJson(Map<String, dynamic> json) {
    return WalletConfig(
      enabled: json['enabled'] != false,
      topUpEnabled: json['topUpEnabled'] == true,
      presets: (json['presets'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic v) => _num(v).round())
          .toList(growable: false),
      minTopUp: _num(json['minTopUp']).round(),
      maxTopUp: _num(json['maxTopUp']).round(),
      minStartBalance: _num(json['minStartBalance']).round(),
    );
  }
}

/// Everything the wallet screen needs in one read.
class WalletSnapshot {
  const WalletSnapshot({
    required this.wallet,
    required this.config,
    required this.entries,
  });

  final Wallet wallet;
  final WalletConfig config;
  final List<WalletEntry> entries;
}

enum InvoiceStatus {
  pending,
  partiallyPaid,
  paid,
  canceled,
  expired,
  refunded,
  failed,
}

/// A QPay invoice raised for a top-up; carries what a QR needs.
class TopUpInvoice {
  const TopUpInvoice({
    required this.id,
    required this.status,
    required this.amount,
    this.paidAmount = 0,
    this.qrText,
    this.qrImage,
    this.shortUrl,
    this.deeplinks = const <TopUpDeeplink>[],
    this.expiresAt,
  });

  final String id;
  final InvoiceStatus status;
  final num amount;

  /// What QPay has actually taken so far.
  final num paidAmount;

  /// Payload to render as a QR when the API sent no image.
  final String? qrText;

  /// Base64 PNG of the QR, ready to draw.
  final String? qrImage;

  final String? shortUrl;
  final List<TopUpDeeplink> deeplinks;
  final DateTime? expiresAt;

  bool get isPaid => status == InvoiceStatus.paid;
  bool get isSettled =>
      status == InvoiceStatus.canceled ||
      status == InvoiceStatus.expired ||
      status == InvoiceStatus.failed;

  factory TopUpInvoice.fromJson(Map<String, dynamic> json) {
    return TopUpInvoice(
      id: (json['id'] ?? '').toString(),
      status: _invoiceStatus((json['status'] ?? '').toString()),
      amount: _num(json['amount']),
      paidAmount: _num(json['paidAmount']),
      qrText: _text(json['qrText']),
      qrImage: _text(json['qrImage']),
      shortUrl: _text(json['shortUrl']),
      deeplinks: (json['deeplinks'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TopUpDeeplink.fromJson)
          .where((TopUpDeeplink d) => d.link != null)
          .toList(growable: false),
      expiresAt: _date(json['expiresAt']),
    );
  }

  /// Folds a poll response into the invoice already on screen.
  ///
  /// The check endpoint answers from `/payments/:id/check`, which strips
  /// `qrImage` (a large base64 blob) and sends no deeplinks. Replacing the
  /// invoice wholesale would therefore blank the QR the driver is mid-scan of,
  /// so only the fields that can actually change are taken from [update].
  TopUpInvoice mergedWith(TopUpInvoice update) {
    return TopUpInvoice(
      id: id,
      status: update.status,
      amount: update.amount > 0 ? update.amount : amount,
      paidAmount: update.paidAmount,
      qrText: update.qrText ?? qrText,
      qrImage: update.qrImage ?? qrImage,
      shortUrl: update.shortUrl ?? shortUrl,
      deeplinks: update.deeplinks.isNotEmpty ? update.deeplinks : deeplinks,
      expiresAt: update.expiresAt ?? expiresAt,
    );
  }

  static InvoiceStatus _invoiceStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'PAID':
        return InvoiceStatus.paid;
      case 'PARTIALLY_PAID':
        return InvoiceStatus.partiallyPaid;
      case 'CANCELED':
        return InvoiceStatus.canceled;
      case 'EXPIRED':
        return InvoiceStatus.expired;
      case 'REFUNDED':
        return InvoiceStatus.refunded;
      case 'FAILED':
        return InvoiceStatus.failed;
      default:
        return InvoiceStatus.pending;
    }
  }
}

/// One bank app QPay can hand the invoice off to.
class TopUpDeeplink {
  const TopUpDeeplink({this.name, this.link, this.logo});

  final String? name;
  final String? link;
  final String? logo;

  factory TopUpDeeplink.fromJson(Map<String, dynamic> json) => TopUpDeeplink(
    name: _text(json['name']),
    link: _text(json['link']),
    logo: _text(json['logo']),
  );
}

/// Result of polling a top-up: the invoice, and the new balance once it is paid.
class TopUpStatus {
  const TopUpStatus({required this.invoice, required this.paid, this.wallet});

  final TopUpInvoice invoice;
  final bool paid;
  final Wallet? wallet;
}

num _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String? _text(dynamic value) {
  if (value == null) return null;
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  final String? text = _text(value);
  return text == null ? null : DateTime.tryParse(text);
}

List<String> _stringList(dynamic value) =>
    (value as List<dynamic>? ?? <dynamic>[])
        .map((dynamic v) => v.toString())
        .toList(growable: false);
