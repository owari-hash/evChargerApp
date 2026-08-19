import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

/// Slide-to-confirm control for starting a charging session.
///
/// The knob follows the finger, springs back if released short of the
/// threshold, and glides home once past it. A travelling chevron wave hints at
/// the gesture while the control is idle.
class SwipeToSlideButton extends StatefulWidget {
  final VoidCallback onSwipeCompleted;

  /// Defaults to the localized "slide to start" label.
  final String? text;

  const SwipeToSlideButton({
    super.key,
    required this.onSwipeCompleted,
    this.text,
  });

  @override
  State<SwipeToSlideButton> createState() => _SwipeToSlideButtonState();
}

class _SwipeToSlideButtonState extends State<SwipeToSlideButton>
    with TickerProviderStateMixin {
  static const double _trackHeight = 60.0;
  static const double _knobInset = 6.0;
  static const double _knobSize = _trackHeight - (_knobInset * 2);

  /// Fraction of the track the knob must pass to count as a confirmation.
  static const double _commitThreshold = 0.75;

  double _drag = 0.0;
  bool _isCompleted = false;
  bool _isDragging = false;
  bool _passedThreshold = false;

  late final AnimationController _settle;
  Animation<double>? _settleAnimation;

  late final AnimationController _hint;
  bool _hintEnabled = true;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _hint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A looping hint is exactly what reduce-motion users ask not to see.
    final bool allowed = !MediaQuery.disableAnimationsOf(context);
    if (allowed != _hintEnabled) {
      _hintEnabled = allowed;
      if (allowed) {
        _hint.repeat();
      } else {
        _hint.stop();
        _hint.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    _hint.dispose();
    super.dispose();
  }

  void _settleTo(double target, Curve curve) {
    _settleAnimation = Tween<double>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _settle, curve: curve),
    )..addListener(() {
        setState(() => _drag = _settleAnimation!.value);
      });
    _settle.forward(from: 0.0);
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isCompleted || maxDrag <= 0) return;
    _settle.stop();
    final double next = (_drag + details.delta.dx).clamp(0.0, maxDrag);
    final bool past = next >= maxDrag * _commitThreshold;

    // One tick as the control becomes releasable, so the commit point is felt.
    if (past && !_passedThreshold) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _drag = next;
      _isDragging = true;
      _passedThreshold = past;
    });
  }

  void _handleDragEnd(double maxDrag) {
    if (_isCompleted || maxDrag <= 0) return;
    setState(() => _isDragging = false);

    if (_drag >= maxDrag * _commitThreshold) {
      setState(() => _isCompleted = true);
      _hint.stop();
      HapticFeedback.mediumImpact();
      _settleTo(maxDrag, Curves.easeOutCubic);
      widget.onSwipeCompleted();
    } else {
      _settleTo(0.0, Curves.easeOutBack);
      setState(() => _passedThreshold = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxDrag =
            math.max(0.0, constraints.maxWidth - _trackHeight);
        final double progress =
            maxDrag <= 0 ? 0.0 : (_drag / maxDrag).clamp(0.0, 1.0);

        return GestureDetector(
          onHorizontalDragUpdate: (DragUpdateDetails d) =>
              _handleDragUpdate(d, maxDrag),
          onHorizontalDragEnd: (DragEndDetails _) => _handleDragEnd(maxDrag),
          child: Container(
            height: _trackHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_trackHeight / 2),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  // Fill trailing the knob. It ends exactly at the knob's
                  // edge with a matching radius, so there is no visible seam.
                  Positioned(
                    left: 0,
                    top: _knobInset,
                    bottom: _knobInset,
                    width: _knobInset + _drag + _knobSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.accent
                            .withValues(alpha: 0.14 + (progress * 0.16)),
                        borderRadius: BorderRadius.circular(_knobSize / 2),
                      ),
                    ),
                  ),

                  // Label sits clear of the knob and fades out as it advances.
                  Positioned.fill(
                    left: _trackHeight + 4,
                    right: 14,
                    child: Center(
                      child: Opacity(
                        opacity: (1.0 - (progress * 1.8)).clamp(0.0, 1.0),
                        child: _buildLabel(palette),
                      ),
                    ),
                  ),

                  // Knob.
                  Positioned(
                    left: _knobInset + _drag,
                    child: _buildKnob(palette),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(AppPalette palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            widget.text ?? AppStrings.get('slide_default'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.onPanel.withValues(alpha: 0.82),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: _hint,
          builder: (BuildContext context, Widget? _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(3, (int i) {
                final double wave =
                    math.sin((_hint.value - (i * 0.14)) * 2 * math.pi);
                final double opacity =
                    _hintEnabled ? 0.3 + (0.7 * math.max(0.0, wave)) : 0.55;
                return SizedBox(
                  width: 10,
                  child: Opacity(
                    opacity: opacity,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: palette.accent,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKnob(AppPalette palette) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _knobSize,
      height: _knobSize,
      decoration: BoxDecoration(
        color: _isCompleted ? Colors.white : palette.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(
                alpha: _isDragging || _passedThreshold ? 0.42 : 0.24),
            blurRadius: _isDragging ? 14 : 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          _isCompleted ? Icons.check_rounded : Icons.arrow_forward_rounded,
          key: ValueKey<bool>(_isCompleted),
          color: _isCompleted ? palette.accent : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
