import '../models/wallet.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import 'api_client.dart';

/// The driver's prepaid wallet: balance, ledger and QPay top-ups.
///
/// Backed by `/app-api/wallet` in evChargerKiosk, which reads the real wallet
/// out of the CSMS. No money ever moves in the app: a top-up only raises a QPay
/// invoice, and the balance changes when QPay confirms payment.
class WalletService {
  WalletService({ApiClient? client}) : _client = client ?? ApiClient.shared;

  static final WalletService instance = WalletService();

  final ApiClient _client;

  /// Balance, limits and the most recent ledger entries in one read.
  Future<WalletSnapshot> load({int entryLimit = 20}) async {
    final Map<String, dynamic> body = await _client.get(
      '/wallet',
      query: <String, String>{'limit': '$entryLimit'},
    );

    return WalletSnapshot(
      wallet: Wallet.fromJson(_map(body['wallet'])),
      config: WalletConfig.fromJson(_map(body['config'])),
      entries: (body['entries'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(WalletEntry.fromJson)
          .toList(growable: false),
      cards: (body['cards'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SavedCard.fromJson)
          .where((SavedCard c) => c.id.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// Raises an invoice for [amount] tugriks: a QPay QR to scan, or with
  /// [card] a Golomt Bank payment page ([TopUpInvoice.paymentUrl]) to open.
  /// With [saveCard] the bank keeps the card for one-tap top-ups once paid.
  ///
  /// [method] is `qpay`, `card` (Golomt's card page) or `socialpay` (pay in
  /// the SocialPay app, through Golomt).
  Future<TopUpInvoice> startTopUp(
    int amount, {
    String method = 'qpay',
    bool saveCard = false,
  }) async {
    final Map<String, dynamic> body = await _client.post(
      '/wallet/topup',
      body: <String, dynamic>{
        'amount': amount,
        'method': method,
        if (method == 'card' && saveCard) 'saveCard': true,
      },
    );
    return TopUpInvoice.fromJson(_map(body['invoice']));
  }

  /// Asks whether an invoice has been paid yet. The API rechecks with QPay and
  /// sends the new balance along once it settles, so a paid QR updates the
  /// screen in one step.
  Future<TopUpStatus> checkTopUp(String invoiceId) async {
    final Map<String, dynamic> body = await _client.get(
      '/wallet/topup/$invoiceId',
    );
    final dynamic wallet = body['wallet'];

    return TopUpStatus(
      invoice: TopUpInvoice.fromJson(_map(body['invoice'])),
      paid: body['paid'] == true,
      wallet: wallet is Map<String, dynamic> ? Wallet.fromJson(wallet) : null,
    );
  }

  /// Charges a saved card at once — no bank page. The answer is final unless
  /// the bank's reply was lost, in which case the invoice is still pending and
  /// [checkTopUp] settles it.
  Future<TopUpStatus> payWithSavedCard(int amount, String cardId) async {
    final Map<String, dynamic> body = await _client.post(
      '/wallet/topup',
      body: <String, dynamic>{
        'amount': amount,
        'method': 'saved_card',
        'cardId': cardId,
      },
    );
    final dynamic wallet = body['wallet'];
    return TopUpStatus(
      invoice: TopUpInvoice.fromJson(_map(body['invoice'])),
      paid: body['paid'] == true,
      wallet: wallet is Map<String, dynamic> ? Wallet.fromJson(wallet) : null,
    );
  }

  /// Forgets a saved card.
  Future<void> removeSavedCard(String cardId) async {
    await _client.delete('/wallet/cards/$cardId');
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};

  /// Null when a charge may start. Otherwise the message to show the driver
  /// before they tap their tag at a station only to be refused there.
  ///
  /// A zero or negative balance always blocks, regardless of config — a
  /// prepaid network has nothing to bill the session to. Below
  /// [WalletConfig.minStartBalance] blocks only when the CSMS itself enforces
  /// that floor, so the app never refuses a charge the station would accept.
  static String? startBlockReason(WalletSnapshot snapshot) {
    if (!snapshot.config.enabled) return null;
    if (snapshot.wallet.isInternal) return null;

    if (snapshot.wallet.balance <= 0) {
      return AppStrings.get('start_blocked_body_zero');
    }

    if (snapshot.config.requireBalanceToStart &&
        snapshot.wallet.balance < snapshot.config.minStartBalance) {
      return AppStrings.get(
        'start_blocked_body_min',
      ).replaceFirst('{amount}', formatMnt(snapshot.config.minStartBalance));
    }

    return null;
  }
}
