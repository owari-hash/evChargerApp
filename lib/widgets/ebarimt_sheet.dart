import 'dart:async';

import 'package:flutter/material.dart';
import '../models/charging_session.dart';
import '../services/api_client.dart';
import '../services/sessions_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';

/// Requests a real Mongolian e-Barimt tax receipt for a past session —
/// the app's counterpart to evChargerKiosk's `EbarimtModal`. Every figure and
/// QR code here comes back from `POST /sessions/:id/ebarimt`; nothing is
/// invented on the device.
class EbarimtSheet extends StatefulWidget {
  const EbarimtSheet({super.key, required this.session, this.onSuccess});

  final ChargingSession session;
  final ValueChanged<ChargingSession>? onSuccess;

  static Future<void> show(BuildContext context, ChargingSession session) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EbarimtSheet(session: session),
    );
  }

  @override
  State<EbarimtSheet> createState() => _EbarimtSheetState();
}

class _EbarimtSheetState extends State<EbarimtSheet> {
  late EBarimtType _type =
      widget.session.ebarimt?.type ??
      widget.session.ebarimtRequest?.type ??
      EBarimtType.b2c;
  late final TextEditingController _tin = TextEditingController(
    text:
        widget.session.ebarimt?.customerTin ??
        widget.session.ebarimtRequest?.customerTin ??
        '',
  );
  late EBarimtData? _ebarimt = widget.session.ebarimt;
  bool _loading = false;
  String? _error;

  /// The driver chose a receipt when they pressed Charge, and the backend is
  /// issuing it on its own: wait for it rather than asking again.
  bool _waiting = false;
  Timer? _poll;
  int _polls = 0;

  /// About two minutes of checking, as on the kiosk.
  static const int _maxPolls = 40;

  @override
  void initState() {
    super.initState();
    final ChargingSession s = widget.session;
    final bool issued = s.ebarimt?.status == EBarimtStatus.success;
    if (s.ebarimtRequest != null &&
        !issued &&
        s.ebarimt?.status != EBarimtStatus.failed &&
        (s.cost ?? 0) > 0) {
      _waiting = true;
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkIssued());
      unawaited(_checkIssued());
    }
  }

  Future<void> _checkIssued() async {
    _polls++;
    ChargingSession? latest;
    try {
      latest = await SessionsService.instance.find(widget.session.transactionId);
    } on ApiException {
      // A missed poll is retried on the next tick.
    }
    if (!mounted) return;
    final EBarimtData? eb = latest?.ebarimt;
    if (eb?.status == EBarimtStatus.success) {
      _poll?.cancel();
      setState(() {
        _ebarimt = eb;
        _waiting = false;
      });
      if (latest != null) widget.onSuccess?.call(latest);
      return;
    }
    if (eb?.status == EBarimtStatus.failed || _polls >= _maxPolls) {
      _poll?.cancel();
      setState(() {
        _waiting = false;
        _error = AppStrings.get('ebarimt_failed');
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_type == EBarimtType.b2b && _tin.text.trim().length < 5) {
      setState(() => _error = 'Байгууллагын регистрийн дугаарыг оруулна уу');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ChargingSession updated = await SessionsService.instance
          .requestEbarimt(
            widget.session.transactionId,
            type: _type,
            customerTin: _type == EBarimtType.b2b ? _tin.text.trim() : null,
          );
      if (!mounted) return;
      setState(() {
        _ebarimt = updated.ebarimt;
        _loading = false;
      });
      widget.onSuccess?.call(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final EBarimtData? ebarimt = _ebarimt;
    final String? qrUrl = ebarimt?.qrData == null
        ? null
        : 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent(ebarimt!.qrData!)}';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'И-Баримт олгох',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Same line as the kiosk's И-Баримт page.
                      Text(
                        'Таны зарцуулсан цахилгааны НӨАТ-ийн баримт',
                        style: TextStyle(fontSize: 12, color: palette.inkMuted),
                      ),
                      Text(
                        widget.session.displayLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: palette.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: palette.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _summaryRow(
                    palette,
                    'Хэрэглэсэн эрчим хүч',
                    '${widget.session.energyKwh.toStringAsFixed(2)} кВт·ц',
                  ),
                  const SizedBox(height: 6),
                  _summaryRow(
                    palette,
                    'Нийт төлбөр',
                    widget.session.cost == null
                        ? '—'
                        : formatMnt(widget.session.cost!),
                    emphasis: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (ebarimt?.status == EBarimtStatus.success)
              _successView(palette, ebarimt!, qrUrl)
            else if (_waiting)
              _waitingView(palette)
            else
              _formView(palette),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    AppPalette palette,
    String label,
    String value, {
    bool emphasis = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: palette.inkMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasis ? 15 : 13,
            fontWeight: emphasis ? FontWeight.w900 : FontWeight.w700,
            color: emphasis ? palette.accent : palette.ink,
          ),
        ),
      ],
    );
  }

  Widget _waitingView(AppPalette palette) {
    final EbarimtChoice request = widget.session.ebarimtRequest!;
    final String who = request.type == EBarimtType.b2b
        ? '${AppStrings.get('ebarimt_org')} · ${request.customerName ?? request.customerTin ?? ''}'
        : AppStrings.get('ebarimt_personal');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.get('ebarimt_pending'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  who,
                  style: TextStyle(fontSize: 12, color: palette.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formView(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: _typeTab(palette, EBarimtType.b2c, 'Иргэн (B2C)')),
              Expanded(
                child: _typeTab(palette, EBarimtType.b2b, 'Байгууллага (B2B)'),
              ),
            ],
          ),
        ),
        if (_type == EBarimtType.b2b) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _tin,
            decoration: InputDecoration(
              labelText: 'Байгууллагын регистрийн дугаар',
              hintText: 'жишээ нь: 6123456',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: palette.panel,
              foregroundColor: palette.onPanel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('И-Баримт үүсгэх'),
          ),
        ),
      ],
    );
  }

  Widget _typeTab(AppPalette palette, EBarimtType type, String label) {
    final bool active = _type == type;
    return InkWell(
      onTap: () => setState(() {
        _type = type;
        _error = null;
      }),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? palette.card : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? palette.ink : palette.inkMuted,
          ),
        ),
      ),
    );
  }

  Widget _successView(AppPalette palette, EBarimtData ebarimt, String? qrUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(Icons.check_circle_rounded, color: palette.accent, size: 28),
              const SizedBox(height: 6),
              Text(
                ebarimt.type == EBarimtType.b2b
                    ? 'Байгууллагын регистрт (${ebarimt.customerTin}) бүртгэгдлээ.'
                    : 'Хувь хүний И-Баримт амжилттай үүслээ.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: palette.ink),
              ),
            ],
          ),
        ),
        if (qrUrl != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(qrUrl, width: 180, height: 180),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _summaryRow(palette, 'Сугалааны №', ebarimt.lottery ?? '—'),
              const SizedBox(height: 8),
              _summaryRow(
                palette,
                'НӨАТ-ын дүн',
                formatMnt(ebarimt.totalVAT),
              ),
              const SizedBox(height: 8),
              _summaryRow(
                palette,
                'Баримтын №',
                ebarimt.receiptId ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: palette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Хаах'),
          ),
        ),
      ],
    );
  }
}
