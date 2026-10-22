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
import '../widgets/glass.dart';

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
        else if (snapshot.config.anyTopUpEnabled)
          _topUpCard(palette, snapshot)
        else
          SectionCard(
            child: Text(
              AppStrings.get('topup_disabled'),
              style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
            ),
          ),
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
          if (debt) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              AppStrings.get('wallet_debt_hint'),
              style: TextStyle(
                color: palette.onPanel.withValues(alpha: 0.62),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (wallet.isInternal) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.sageGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.sageGreen.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: AppTheme.sageGreen,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Дотоод хэрэглэгч · Үнэ төлбөргүй',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (low && !wallet.isInternal) ...<Widget>[
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

  Widget _topUpCard(AppPalette palette, WalletSnapshot snapshot) {
    return SectionCard(
      title: AppStrings.get('topup_title'),
      subtitle: AppStrings.get('wallet_subtitle'),
      child: _TopUpForm(
        config: snapshot.config,
        cards: snapshot.cards,
        wallets: _wallets,
        onPaid: _load,
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

/// Amount picker plus the invoice it opens: a QPay QR, or a Golomt Bank card
/// page the driver pays on in the browser.
class _TopUpForm extends StatefulWidget {
  const _TopUpForm({
    required this.config,
    required this.wallets,
    required this.onPaid,
    this.cards = const <SavedCard>[],
  });

  final WalletConfig config;

  /// Bank cards saved for one-tap top-ups.
  final List<SavedCard> cards;
  final WalletService wallets;
  final Future<void> Function() onPaid;

  @override
  State<_TopUpForm> createState() => _TopUpFormState();
}

class _TopUpFormState extends State<_TopUpForm> {
  final TextEditingController _amount = TextEditingController();
  int? _selectedPreset;
  bool _creating = false;

  /// Every failure is reported as a toast, the same as on the web.
  void _fail(String message) {
    if (mounted) AppToast.show(context, message, kind: ToastKind.error);
  }

  /// Keep the card on the bank page for one-tap top-ups next time.
  bool _saveCard = true;

  /// QPay (QR, SocialPay and any bank app) or a card — the same two choices
  /// as the web. Under "card", a saved card or (null) a new one.
  late bool _payByCard = !widget.config.topUpEnabled;
  late String? _cardId = _payByCard && widget.cards.isNotEmpty
      ? widget.cards.first.id
      : null;
  String? _payingCardId;
  late List<SavedCard> _cards = widget.cards;

  @override
  void didUpdateWidget(covariant _TopUpForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reload after a payment brings the freshly saved card along.
    if (!identical(oldWidget.cards, widget.cards)) _cards = widget.cards;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// The amount field is the single source of truth: a preset writes into it,
  /// so what the driver sees typed is always what will be charged.
  int? get _chosenAmount => amountOf(_amount.text);

  /// The amount when it is within limits; otherwise shows why and is null.
  int? _validAmount() {
    final int? amount = _chosenAmount;
    final WalletConfig config = widget.config;

    if (amount == null || amount <= 0) {
      _fail(AppStrings.get('topup_invalid'));
      return null;
    }
    if (amount < config.minTopUp || amount > config.maxTopUp) {
      _fail(
        AppStrings.get('topup_range')
            .replaceFirst('{min}', formatMnt(config.minTopUp))
            .replaceFirst('{max}', formatMnt(config.maxTopUp)),
      );
      return null;
    }
    return amount;
  }

  Future<void> _start({bool card = false}) async {
    final int? amount = _validAmount();
    if (amount == null) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _creating = true;
    });

    try {
      final TopUpInvoice invoice = await widget.wallets.startTopUp(
        amount,
        card: card,
        saveCard: card && widget.config.savedCardsEnabled && _saveCard,
      );
      if (!mounted) return;
      setState(() => _creating = false);

      // The card page opens straight away; the sheet underneath waits for
      // the payment, so closing the browser lands the driver on its result.
      if (invoice.isCard) await openPaymentPage(invoice.paymentUrl!);
      if (!mounted) return;

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
      setState(() => _creating = false);
      _fail(error.message);
    }
  }

  /// Charges a saved card after the driver confirms — no bank page opens.
  Future<void> _payWithSaved(SavedCard card) async {
    final int? amount = _validAmount();
    if (amount == null) return;
    FocusScope.of(context).unfocus();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppStrings.get('saved_card_confirm_title')),
        content: Text(
          AppStrings.get('saved_card_confirm_body')
              .replaceFirst('{card}', card.label)
              .replaceFirst('{amount}', formatMnt(amount)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.get('saved_card_confirm_yes')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _payingCardId = card.id);
    try {
      final TopUpStatus status = await widget.wallets.payWithSavedCard(
        amount,
        card.id,
      );
      if (!mounted) return;
      setState(() => _payingCardId = null);

      if (status.paid) {
        final num credited = status.invoice.paidAmount > 0
            ? status.invoice.paidAmount
            : status.invoice.amount;
        _amount.clear();
        setState(() => _selectedPreset = null);
        await widget.onPaid();
        if (!mounted) return;
        showSnack(
          context,
          AppStrings.get('invoice_paid')
              .replaceFirst('{amount}', formatMnt(credited)),
        );
        return;
      }
      if (status.invoice.status == InvoiceStatus.failed) {
        _fail(status.invoice.declineReason ?? AppStrings.get('card_failed'));
        return;
      }
      // The bank's answer was lost on the way: wait for it like a card page.
      final num? credited = await showModalBottomSheet<num>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (BuildContext sheetContext) =>
            _InvoiceSheet(invoice: status.invoice, wallets: widget.wallets),
      );
      if (credited != null) await widget.onPaid();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _payingCardId = null);
      _fail(error.message);
    }
  }

  Future<void> _removeSaved(SavedCard card) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppStrings.get('saved_card_remove_title')),
        content: Text(
          AppStrings.get('saved_card_remove_body')
              .replaceFirst('{card}', card.label),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('saved_card_remove_yes')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.wallets.removeSavedCard(card.id);
    } on ApiException catch (error) {
      // Already gone on the server is the outcome the driver wanted.
      if (error.statusCode != 404) {
        _fail(error.message);
        return;
      }
    }
    if (!mounted) return;
    setState(
      () => _cards = _cards
          .where((SavedCard c) => c.id != card.id)
          .toList(growable: false),
    );
  }

  /// The selected saved card, or null when paying with a new card.
  SavedCard? get _selectedCard {
    for (final SavedCard c in _cards) {
      if (c.id == _cardId) return c;
    }
    return null;
  }

  void _choosePayByCard(bool card) {
    setState(() {
      _payByCard = card;
      // Choosing "card" preselects the driver's saved card, like the web.
      _cardId = card && _cards.isNotEmpty ? _cards.first.id : null;
    });
  }

  /// The one button: does whatever the chosen method means.
  void _pay() {
    if (!_payByCard) {
      _start();
    } else if (_selectedCard != null) {
      _payWithSaved(_selectedCard!);
    } else {
      _start(card: true);
    }
  }

  String _payLabel() {
    if (_creating || _payingCardId != null) {
      return AppStrings.get(
        _payingCardId != null ? 'saved_card_paying' : 'topup_submitting',
      );
    }
    final int? amount = _chosenAmount;
    if (amount == null || amount <= 0) {
      return AppStrings.get('topup_choose_first');
    }
    final String money = formatMnt(amount);
    if (!_payByCard) {
      return AppStrings.get('topup_cta_qr').replaceFirst('{amount}', money);
    }
    final SavedCard? card = _selectedCard;
    if (card != null) {
      return AppStrings.get(
        'saved_card_pay',
      ).replaceFirst('{card}', card.label).replaceFirst('{amount}', money);
    }
    return AppStrings.get('topup_cta_card').replaceFirst('{amount}', money);
  }

  /// A saved card as a pill: tap to choose it, × to forget it.
  Widget _cardChip(AppPalette palette, SavedCard card, bool busy) {
    final bool active = _cardId == card.id;
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: palette.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? palette.accent : palette.border,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: busy ? null : () => setState(() => _cardId = card.id),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? palette.accent : palette.border,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  card.label,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.get('saved_card_remove'),
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: busy ? null : () => _removeSaved(card),
            icon: Icon(Icons.close_rounded, color: palette.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _newCardChip(AppPalette palette, bool busy) {
    final bool active = _cardId == null;
    return GestureDetector(
      onTap: busy ? null : () => setState(() => _cardId = null),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? palette.accent : palette.border,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.add_rounded,
              size: 16,
              color: active ? palette.ink : palette.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              AppStrings.get('topup_new_card'),
              style: TextStyle(
                color: active ? palette.ink : palette.inkMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final WalletConfig config = widget.config;
    final bool busy = _creating || _payingCardId != null;

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
                      _amount.text = formatAmount(preset);
                      // Caret before the decorative decimals, where typing
                      // actually changes the amount.
                      _amount.selection = TextSelection.collapsed(
                        offset: _amount.text.indexOf('.'),
                      );
                    }
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
          inputFormatters: const <TextInputFormatter>[MntInputFormatter()],
          onChanged: (String value) {
            // `amountOf`, not a digit sweep: the trailing `.00` the formatter
            // holds is decoration, and counting it would read 12,500.00 as
            // 1,250,000 and unselect a preset the driver had just tapped.
            if (amountOf(value) != _selectedPreset) {
              setState(() => _selectedPreset = null);
            }
          },
          helper: AppStrings.get('topup_range')
              .replaceFirst('{min}', formatMnt(config.minTopUp))
              .replaceFirst('{max}', formatMnt(config.maxTopUp)),
          onSubmitted: (_) => _pay(),
        ),
        if (config.topUpEnabled && config.cardTopUpEnabled) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            AppStrings.get('topup_method'),
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          GlassSegmented(
            value: _payByCard ? 1 : 0,
            enabled: !busy,
            onChanged: (int i) => _choosePayByCard(i == 1),
            options: <(IconData, String)>[
              (Icons.qr_code_2_rounded, AppStrings.get('topup_method_qpay')),
              (Icons.credit_card_rounded, AppStrings.get('topup_method_card')),
            ],
          ),
        ],
        if (config.cardTopUpEnabled || config.topUpEnabled) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            AppStrings.get(
              _payByCard ? 'topup_method_card_hint' : 'topup_method_qpay_hint',
            ),
            style: TextStyle(color: palette.inkMuted, fontSize: 12),
          ),
        ],
        if (_payByCard && _cards.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SavedCard card in _cards)
                _cardChip(palette, card, busy),
              _newCardChip(palette, busy),
            ],
          ),
        ],
        if (_payByCard && _cardId == null && config.savedCardsEnabled) ...<Widget>[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _saveCard = !_saveCard),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: <Widget>[
                Checkbox(
                  value: _saveCard,
                  onChanged: (bool? v) =>
                      setState(() => _saveCard = v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    AppStrings.get('card_save'),
                    style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryAction(
          label: _payLabel(),
          busy: busy,
          icon: _payByCard
              ? Icons.credit_card_rounded
              : Icons.qr_code_rounded,
          onPressed: busy ? null : _pay,
        ),
      ],
    );
  }
}

/// Opens Golomt Bank's card page in an in-app browser tab (Safari View
/// Controller / Custom Tabs), falling back to the system browser.
Future<void> openPaymentPage(String link) async {
  final Uri? uri = Uri.tryParse(link);
  if (uri == null) return;
  final bool opened = await launchUrl(
    uri,
    mode: LaunchMode.inAppBrowserView,
  ).catchError((Object _) => false);
  if (!opened) await launchUrl(uri, mode: LaunchMode.externalApplication);
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

      if (manual) {
        AppToast.show(
          context,
          AppStrings.get('invoice_not_paid'),
          kind: ToastKind.info,
        );
      }
      setState(() {
        _invoice = merged;
        _checking = false;
        if (merged.status == InvoiceStatus.expired) {
          _fatal = AppStrings.get('invoice_expired');
          _poll?.cancel();
        } else if (merged.isCard && merged.status == InvoiceStatus.failed) {
          _fatal = merged.declineReason ?? AppStrings.get('card_failed');
          _poll?.cancel();
        } else if (merged.isSettled) {
          _fatal = AppStrings.get('invoice_canceled');
          _poll?.cancel();
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _checking = false);
      if (manual) AppToast.show(context, error.message, kind: ToastKind.error);
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
                AppStrings.get(
                  _invoice.isCard ? 'card_title' : 'invoice_title',
                ),
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
              else if (_invoice.isCard)
                _cardPayment(palette)
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

  /// A card invoice has no QR: the driver pays on Golomt Bank's page, which
  /// can be reopened here, or hands off to the SocialPay app.
  Widget _cardPayment(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.credit_card_rounded,
              size: 34,
              color: palette.accent,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppStrings.get('card_instruction'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.inkMuted,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        if (_invoice.paymentUrl != null) ...<Widget>[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => openPaymentPage(_invoice.paymentUrl!),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(AppStrings.get('card_open')),
          ),
        ],
      ],
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
  static bool _isSocialPay(TopUpDeeplink d) =>
      RegExp(r'social\s*pay', caseSensitive: false).hasMatch(d.name ?? '');

  Widget _bankGrid(AppPalette palette) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      // SocialPay is the app most drivers reach for, so it leads.
      children:
          ([..._invoice.deeplinks]..sort(
                (TopUpDeeplink a, TopUpDeeplink b) =>
                    (_isSocialPay(b) ? 1 : 0) - (_isSocialPay(a) ? 1 : 0),
              ))
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
