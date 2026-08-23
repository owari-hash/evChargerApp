import '../models/wallet.dart';
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
    );
  }

  /// Raises a QPay invoice for [amount] tugriks and returns the QR to scan.
  Future<TopUpInvoice> startTopUp(int amount) async {
    final Map<String, dynamic> body = await _client.post(
      '/wallet/topup',
      body: <String, dynamic>{'amount': amount},
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

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};
}
