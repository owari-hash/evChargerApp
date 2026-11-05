import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';

/// The full-screen "top-up succeeded / failed" moment, matching the website.
///
/// Success: the badge pops in, the check draws, sparks burst, the amount
/// counts up, and it closes itself. Failure: the badge shakes, the cross
/// draws, and it waits for "Try again".
///
/// One controller drives everything and only transforms, opacity and a small
/// path are animated, so it stays smooth on low-end Android.
Future<void> showTopUpResult(
  BuildContext context, {
  required bool success,
  num amount = 0,
  num? balance,
  String? reason,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'topup-result',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _TopUpResult(
      success: success,
      amount: amount,
      balance: balance,
      reason: reason,
    ),
    transitionBuilder: (_, Animation<double> anim, _, Widget child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

const Color _green = Color(0xFF10B981);
const Color _red = Color(0xFFF43F5E);

class _TopUpResult extends StatefulWidget {
  const _TopUpResult({
    required this.success,
    required this.amount,
    this.balance,
    this.reason,
  });

  final bool success;
  final num amount;
  final num? balance;
  final String? reason;

  @override
  State<_TopUpResult> createState() => _TopUpResultState();
}

class _TopUpResultState extends State<_TopUpResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.success ? 3200 : 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    if (widget.success) {
      _c.addStatusListener((AnimationStatus s) {
        if (s == AnimationStatus.completed && mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Maps the controller to a sub-interval, in milliseconds.
  double _t(double fromMs, double toMs, [Curve curve = Curves.linear]) {
    final double total = _c.duration!.inMilliseconds.toDouble();
    final double v = ((_c.value * total - fromMs) / (toMs - fromMs)).clamp(
      0.0,
      1.0,
    );
    return curve.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    final bool mn = AppStrings.currentLanguage == AppLanguage.mn;
    final Color tone = widget.success ? _green : _red;
    final palette = context.palette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, _) {
              final double card = _t(0, 420, Curves.easeOutCubic);
              final double badge = _t(80, 640, Curves.easeOutBack);
              final double draw = _t(420, 840, Curves.easeOut);
              final double text = _t(520, 920, Curves.easeOut);
              final double shake = widget.success
                  ? 0
                  : math.sin(_t(600, 1020) * math.pi * 4) *
                        9 *
                        (1 - _t(600, 1020));

              return Opacity(
                opacity: card,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - card)),
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: palette.border),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 40,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 180,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              if (widget.success) ..._sparks(),
                              // Expanding ring behind the badge.
                              Opacity(
                                opacity: 0.9 * (1 - _t(260, 1160)),
                                child: Transform.scale(
                                  scale: 0.6 + 1.3 * _t(260, 1160),
                                  child: Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: tone.withValues(alpha: 0.25),
                                    ),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(shake, 0),
                                child: Transform.scale(
                                  scale: badge,
                                  child: Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: widget.success
                                            ? const <Color>[
                                                Color(0xFF34D399),
                                                Color(0xFF059669),
                                              ]
                                            : const <Color>[
                                                Color(0xFFFB7185),
                                                Color(0xFFE11D48),
                                              ],
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: tone.withValues(alpha: 0.6),
                                          blurRadius: 28,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: CustomPaint(
                                      painter: _MarkPainter(
                                        success: widget.success,
                                        progress: draw,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Opacity(
                          opacity: text,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - text)),
                            child: _body(mn, palette),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _sparks() {
    const List<Color> colors = <Color>[
      Color(0xFF10B981),
      Color(0xFF34D399),
      Color(0xFF22D3EE),
      Color(0xFFFBBF24),
    ];
    return List<Widget>.generate(12, (int i) {
      final double angle = i / 12 * math.pi * 2;
      final double delay = 180 + (i % 3) * 40;
      final double p = _t(delay, delay + 700, Curves.easeOutCubic);
      final double fade = p < 0.2 ? p / 0.2 : 1 - (p - 0.2) / 0.8;
      return Transform.translate(
        offset: Offset(math.cos(angle) * 74 * p, math.sin(angle) * 74 * p),
        child: Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors[i % 4],
            ),
          ),
        ),
      );
    });
  }

  Widget _body(bool mn, AppPalette palette) {
    if (widget.success) {
      final num shown = widget.amount * _t(520, 1420, Curves.easeOutCubic);
      return Column(
        children: <Widget>[
          Text(
            mn ? 'Хэтэвч цэнэглэгдлээ' : 'Wallet topped up',
            style: TextStyle(
              color: palette.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+${formatMnt(shown.round())}',
            style: const TextStyle(
              color: _green,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          if (widget.balance != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '${mn ? 'Үлдэгдэл' : 'Balance'}: ${formatMnt(widget.balance!)}',
              style: TextStyle(color: palette.inkMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          // Time until it closes itself.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: <Widget>[
                  Container(color: palette.border),
                  FractionallySizedBox(
                    widthFactor: 1 - _c.value,
                    child: Container(color: _green),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Text(
          mn ? 'Төлбөр амжилтгүй' : 'Payment failed',
          style: TextStyle(
            color: palette.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.reason ??
              (mn
                  ? 'Таны данснаас мөнгө хасагдаагүй. Дахин оролдоно уу.'
                  : 'No money was taken. Please try again.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.inkMuted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(
              backgroundColor: palette.ink,
              foregroundColor: palette.card,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(AppStrings.get('retry')),
          ),
        ),
      ],
    );
  }
}

/// Draws the check (or cross) up to [progress], like a pen stroke.
class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.success, required this.progress});

  final bool success;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final double s = size.width / 24;
    final Path path = Path();
    if (success) {
      path
        ..moveTo(7 * s, 12.5 * s)
        ..lineTo(10.5 * s, 16 * s)
        ..lineTo(17.5 * s, 8.5 * s);
    } else {
      path
        ..moveTo(8.5 * s, 8.5 * s)
        ..lineTo(15.5 * s, 15.5 * s)
        ..moveTo(15.5 * s, 8.5 * s)
        ..lineTo(8.5 * s, 15.5 * s);
    }
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final List<PathMetric> metrics = path.computeMetrics().toList();
    final double total = metrics.fold(
      0,
      (double a, PathMetric m) => a + m.length,
    );
    double left = total * progress;
    for (final PathMetric m in metrics) {
      if (left <= 0) break;
      canvas.drawPath(m.extractPath(0, math.min(left, m.length)), paint);
      left -= m.length;
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.progress != progress || old.success != success;
}
