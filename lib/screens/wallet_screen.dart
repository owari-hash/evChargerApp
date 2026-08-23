import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wallet.dart';
import '../services/api_client.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import '../widgets/account_widgets.dart';

/// The driver's prepaid balance, top-ups and ledger — the app's counterpart to
/// `/account/wallet` in the kiosk.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.walletService});

  final WalletService? walletService;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletService get _wallets => widget.walletService ?? WalletService.instance;

  WalletSnapshot? _snapshot;
  String? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final WalletSnapshot snapshot = await _wallets.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(title: Text(AppStrings.get('wallet_title'))),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(palette)),
    );
  }

  Widget _buildBody(AppPalette palette) {
    if (_loading && _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final WalletSnapshot? snapshot = _snapshot;
    if (snapshot == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        children: <Widget>[
          ErrorNotice(
            message: _loadError ?? AppStrings.get('wallet_unavailable'),
            onRetry: _load,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      children: <Widget>[
        _balanceCard(palette, snapshot),
        const SizedBox(height: 12),
        if (snapshot.wallet.isFrozen)
          FormErrorBanner(message: AppStrings.get('wallet_frozen'))
        else if (snapshot.config.topUpEnabled)
          _topUpCard(palette, snapshot.config)
        else
          SectionCard(
            child: Text(
              AppStrings.get('topup_disabled'),
              style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 12),
        _tagsCard(palette, snapshot.wallet),
        const SizedBox(height: 12),
        _historyCard(palette, snapshot.entries),
      ],
    );
  }

  Widget _balanceCard(AppPalette palette, WalletSnapshot snapshot) {
    final Wallet wallet = snapshot.wallet;
    final bool debt = wallet.inDebt;
    final bool low = !debt && wallet.balance < snapshot.config.minStartBalance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.get(debt ? 'wallet_debt' : 'wallet_balance'),
            style: TextStyle(
              color: palette.onPanel.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMnt(wallet.balance.abs()),
              style: TextStyle(
                color: debt ? AppTheme.warningOrange : Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.get(debt ? 'wallet_debt_hint' : 'wallet_balance_hint'),
            style: TextStyle(
              color: palette.onPanel.withValues(alpha: 0.62),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (low) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              AppStrings.get('wallet_low_balance').replaceFirst(
                '{amount}',
                formatMnt(snapshot.config.minStartBalance),
              ),
              style: const TextStyle(
                color: AppTheme.warningOrange,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _panelStat(
                  palette,
                  AppStrings.get('wallet_topped_up'),
                  formatMnt(wallet.totalToppedUp),
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: palette.onPanel.withValues(alpha: 0.18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _panelStat(
                  palette,
                  AppStrings.get('wallet_spent'),
                  formatMnt(wallet.totalSpent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panelStat(AppPalette palette, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.onPanel.withValues(alpha: 0.6),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _topUpCard(AppPalette palette, WalletConfig config) {
    return SectionCard(
      title: AppStrings.get('topup_title'),
      subtitle: AppStrings.get('wallet_subtitle'),
      child: _TopUpForm(config: config, wallets: _wallets, onPaid: _load),
    );
  }

  Widget _tagsCard(AppPalette palette, Wallet wallet) {
    return SectionCard(
      title: AppStrings.get('wallet_linked_tags'),
      child: wallet.idTags.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.get('wallet_no_linked_tags'),
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: wallet.idTags
                  .map(
                    (String tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _historyCard(AppPalette palette, List<WalletEntry> entries) {
    return SectionCard(
      title: AppStrings.get('wallet_history'),
      child: entries.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.get('wallet_history_empty'),
                style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
              ),
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < entries.length; i++) ...<Widget>[
                  if (i > 0) Divider(color: palette.border, height: 20),
                  _entryRow(palette, entries[i]),
                ],
              ],
            ),
    );
  }

  Widget _entryRow(AppPalette palette, WalletEntry entry) {
    final bool credit = entry.isCredit;
    final Color tone = credit ? palette.accent : palette.ink;

    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (credit ? palette.accent : palette.inkMuted).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            credit ? Icons.add_rounded : Icons.bolt_rounded,
            size: 17,
            color: credit ? palette.accent : palette.inkMuted,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _entryLabel(entry),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _entrySubtitle(entry),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.inkMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${credit ? '+' : '−'}${formatMnt(entry.amount.abs())}',
              style: TextStyle(
                color: tone,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.get(
                'wallet_balance_after',
              ).replaceFirst('{balance}', formatMnt(entry.balanceAfter)),
              style: TextStyle(color: palette.inkMuted, fontSize: 10.5),
            ),
          ],
        ),
      ],
    );
  }

  String _entryLabel(WalletEntry entry) {
    switch (entry.type) {
      case WalletEntryType.topUp:
        return AppStrings.get('wallet_entry_topup');
      case WalletEntryType.charge:
        return AppStrings.get('wallet_entry_charge');
      case WalletEntryType.refund:
        return AppStrings.get('wallet_entry_refund');
      case WalletEntryType.adjustment:
        return AppStrings.get('wallet_entry_adjustment');
      case WalletEntryType.bonus:
        return AppStrings.get('wallet_entry_bonus');
    }
  }

  String _entrySubtitle(WalletEntry entry) {
    final String? description = entry.description;
    if (description != null && description.isNotEmpty) return description;
    if (entry.chargePointId != null) return entry.chargePointId!;
    final DateTime? at = entry.createdAt;
    if (at == null) return '';
    return '${at.year}-${_two(at.month)}-${_two(at.day)} ${_two(at.hour)}:${_two(at.minute)}';
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Amount picker plus the QPay invoice it opens.
class _TopUpForm extends StatefulWidget {
  const _TopUpForm({
    required this.config,
    required this.wallets,
    required this.onPaid,
  });

  final WalletConfig config;
  final WalletService wallets;
  final Future<void> Function() onPaid;

  @override
  State<_TopUpForm> createState() => _TopUpFormState();
}

class _TopUpFormState extends State<_TopUpForm> {
  final TextEditingController _amount = TextEditingController();
  int? _selectedPreset;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// The amount field is the single source of truth: a preset writes into it,
  /// so what the driver sees typed is always what will be charged.
  int? get _chosenAmount => amountOf(_amount.text);

  Future<void> _start() async {
    final int? amount = _chosenAmount;
    final WalletConfig config = widget.config;

    if (amount == null || amount <= 0) {
      setState(() => _error = AppStrings.get('topup_invalid'));
      return;
    }
    if (amount < config.minTopUp || amount > config.maxTopUp) {
      setState(
        () => _error = AppStrings.get('topup_range')
            .replaceFirst('{min}', formatMnt(config.minTopUp))
            .replaceFirst('{max}', formatMnt(config.maxTopUp)),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final TopUpInvoice invoice = await widget.wallets.startTopUp(amount);
      if (!mounted) return;
      setState(() => _creating = false);

      final num? credited = await showModalBottomSheet<num>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        // A half-finished payment must not be dismissed by a stray tap.
        isDismissible: false,
        enableDrag: false,
        builder: (BuildContext sheetContext) =>
            _InvoiceSheet(invoice: invoice, wallets: widget.wallets),
      );

      if (credited != null) {
        _amount.clear();
        setState(() => _selectedPreset = null);
        await widget.onPaid();
        if (!mounted) return;
        showSnack(
          context,
          AppStrings.get(
            'invoice_paid',
          ).replaceFirst('{amount}', formatMnt(credited)),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final WalletConfig config = widget.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.get('topup_choose'),
          style: TextStyle(
            color: palette.inkMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: config.presets
              .map((int preset) {
                final bool active = _selectedPreset == preset;
                return GestureDetector(
                  onTap: () => setState(() {
                    if (active) {
                      _selectedPreset = null;
                      _amount.clear();
                    } else {
                      _selectedPreset = preset;
                      _amount.text = preset.toString();
                      _amount.selection = TextSelection.collapsed(
                        offset: _amount.text.length,
                      );
                    }
                    _error = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: active ? palette.accent : palette.bg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: active ? palette.accent : palette.border,
                      ),
                    ),
                    child: Text(
                      formatMnt(preset),
                      style: TextStyle(
                        color: active ? Colors.white : palette.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 14),
        AccountField(
          controller: _amount,
          label: AppStrings.get('topup_custom'),
          icon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
          enabled: !_creating,
          onChanged: (String value) {
            final int? typed = int.tryParse(
              value.replaceAll(RegExp(r'[^\d]'), ''),
            );
            if (typed != _selectedPreset) {
              setState(() => _selectedPreset = null);
            }
          },
          helper: AppStrings.get('topup_range')
              .replaceFirst('{min}', formatMnt(config.minTopUp))
              .replaceFirst('{max}', formatMnt(config.maxTopUp)),
          onSubmitted: (_) => _start(),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          FormErrorBanner(message: _error!),
        ],
        const SizedBox(height: 14),
        PrimaryAction(
          label: _creating
              ? AppStrings.get('topup_submitting')
              : AppStrings.get('topup_submit'),
          busy: _creating,
          icon: Icons.qr_code_rounded,
          onPressed: _start,
        ),
      ],
    );
  }
}

/// The QPay QR, polled until QPay says the invoice is settled.
///
/// Nothing here decides that money arrived: the sheet only reflects what the
/// API reports, which in turn re-checks with QPay and credits the wallet
/// server-side. A driver cannot fake a paid balance by tampering with the app.
class _InvoiceSheet extends StatefulWidget {
  const _InvoiceSheet({required this.invoice, required this.wallets});

  final TopUpInvoice invoice;
  final WalletService wallets;

  @override
  State<_InvoiceSheet> createState() => _InvoiceSheetState();
}

class _InvoiceSheetState extends State<_InvoiceSheet> {
  /// Matches the kiosk's own cadence and cut-off.
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _pollTimeout = Duration(minutes: 10);

  late TopUpInvoice _invoice = widget.invoice;
  Timer? _poll;
  DateTime _startedAt = DateTime.now();
  bool _checking = false;
  bool _timedOut = false;
  String? _notice;
  String? _fatal;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    // QPay confirms out of band, so the sheet asks rather than making the
    // driver tap a button. It gives up after ten minutes so a sheet left open
    // does not keep hitting QPay forever.
    _poll = Timer.periodic(_pollInterval, (_) {
      if (DateTime.now().difference(_startedAt) > _pollTimeout) {
        _poll?.cancel();
        if (mounted) setState(() => _timedOut = true);
        return;
      }
      _check();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check({bool manual = false}) async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      if (manual) _notice = null;
    });

    try {
      final TopUpStatus status = await widget.wallets.checkTopUp(_invoice.id);
      if (!mounted) return;

      // Merge, never replace: the check endpoint sends no QR image and no
      // deeplinks, so taking its answer wholesale would blank the QR the
      // driver is in the middle of scanning.
      final TopUpInvoice merged = _invoice.mergedWith(status.invoice);

      if (status.paid) {
        _poll?.cancel();
        final num credited = merged.paidAmount > 0
            ? merged.paidAmount
            : merged.amount;
        Navigator.pop(context, credited);
        return;
      }

      setState(() {
        _invoice = merged;
        _checking = false;
        _notice = manual ? AppStrings.get('invoice_not_paid') : null;
        if (merged.status == InvoiceStatus.expired) {
          _fatal = AppStrings.get('invoice_expired');
          _poll?.cancel();
        } else if (merged.isSettled) {
          _fatal = AppStrings.get('invoice_canceled');
          _poll?.cancel();
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        if (manual) _notice = error.message;
      });
    }
  }

  Future<void> _openLink(String link) async {
    final Uri? uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                AppStrings.get('invoice_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.get('invoice_amount'),
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.inkMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 2),
              Text(
                formatMnt(_invoice.amount),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 18),
              if (_fatal != null)
                FormErrorBanner(message: _fatal!)
              else ...<Widget>[
                _qr(palette),
                const SizedBox(height: 16),
                Text(
                  AppStrings.get('invoice_instruction'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.inkMuted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                if (_invoice.deeplinks.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _bankGrid(palette),
                ],
              ],
              if (_notice != null) ...<Widget>[
                const SizedBox(height: 14),
                FormErrorBanner(message: _notice!),
              ],
              const SizedBox(height: 18),
              if (_fatal == null) _waitingRow(palette),
              const SizedBox(height: 14),
              if (_fatal == null)
                PrimaryAction(
                  label: _checking
                      ? AppStrings.get('invoice_checking')
                      : AppStrings.get('invoice_check'),
                  busy: _checking,
                  onPressed: () => _check(manual: true),
                ),
              if (_fatal != null || _timedOut) ...<Widget>[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.get('invoice_start_over')),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _waitingRow(AppPalette palette) {
    if (_timedOut) {
      return Text(
        AppStrings.get('invoice_timed_out'),
        textAlign: TextAlign.center,
        style: TextStyle(color: palette.inkMuted, fontSize: 12.5, height: 1.4),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: palette.accent,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            AppStrings.get('invoice_waiting'),
            style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  /// The QR itself: QPay's own PNG when it sent one, otherwise the payload
  /// rendered locally. Either way it sits on white, which scanners need.
  Widget _qr(AppPalette palette) {
    final Uint8List? png = _decodeQrImage(_invoice.qrImage);
    final String? payload = _invoice.qrText;

    Widget inner;
    if (png != null) {
      inner = Image.memory(
        png,
        width: 232,
        height: 232,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    } else if (payload != null && payload.isNotEmpty) {
      inner = QrImageView(
        data: payload,
        version: QrVersions.auto,
        size: 232,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0D2619),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0D2619),
        ),
      );
    } else {
      inner = const SizedBox(
        width: 232,
        height: 232,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: <Widget>[
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: inner,
          ),
        ),
        if (_invoice.shortUrl != null) ...<Widget>[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _openLink(_invoice.shortUrl!),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(AppStrings.get('invoice_open_link')),
          ),
        ],
      ],
    );
  }

  /// The bank apps QPay can hand this invoice off to, shown as their logos.
  ///
  /// A grid of names all looks the same at a glance; drivers recognise their
  /// bank by its mark, so the logo leads and the name labels it.
  Widget _bankGrid(AppPalette palette) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: _invoice.deeplinks
          .map((TopUpDeeplink bank) => _bankTile(palette, bank))
          .toList(growable: false),
    );
  }

  Widget _bankTile(AppPalette palette, TopUpDeeplink bank) {
    final String name = bank.name ?? AppStrings.get('invoice_open_bank');

    return SizedBox(
      width: 74,
      child: InkWell(
        onTap: () => _openLink(bank.link!),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: palette.border),
                ),
                child: _bankLogo(palette, bank, name),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// QPay serves the logos over HTTP. If one will not load — offline, or a
  /// broken URL — the tile falls back to the bank's initial rather than an
  /// empty box.
  Widget _bankLogo(AppPalette palette, TopUpDeeplink bank, String name) {
    final String? logo = bank.logo;

    Widget initial() => Container(
      color: palette.accent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        name.characters.first.toUpperCase(),
        style: TextStyle(
          color: palette.accent,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (logo == null || !logo.startsWith('http')) return initial();

    return Image.network(
      logo,
      fit: BoxFit.contain,
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.inkMuted,
                ),
              ),
            );
          },
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          initial(),
    );
  }

  /// QPay sends the QR as base64, sometimes behind a `data:` prefix.
  static Uint8List? _decodeQrImage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final String payload = raw.contains(',')
          ? raw.substring(raw.indexOf(',') + 1)
          : raw;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}
