import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A row of digit cells for a sign-in PIN or an SMS code.
///
/// Each cell fills with the brand green and pops as its digit goes in, the way
/// a charge bar fills; a new error shakes the row. One real [TextField] lies
/// invisibly over the cells, so the number pad, pasting, deleting and SMS code
/// autofill all behave natively; the cells only draw what it holds.
class PinCodeField extends StatefulWidget {
  const PinCodeField({
    super.key,
    required this.controller,
    this.length = 4,
    this.obscure = true,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.label,
    this.error,
    this.onCompleted,
    this.autofillHints,
  });

  final TextEditingController controller;

  /// 4 for a PIN, 6 for an SMS code.
  final int length;

  /// Dots instead of digits, for a PIN.
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Shown centred above the cells.
  final String? label;
  final String? error;

  /// Called once each time the last digit goes in.
  final ValueChanged<String>? onCompleted;
  final Iterable<String>? autofillHints;

  @override
  State<PinCodeField> createState() => _PinCodeFieldState();
}

class _PinCodeFieldState extends State<PinCodeField>
    with SingleTickerProviderStateMixin {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// The value [PinCodeField.onCompleted] last fired for, so a rebuild with the
  /// same full value does not fire it twice.
  String _completed = '';
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _lastLength = widget.controller.text.length;
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PinCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    final String? error = widget.error;
    if (error != null && error.isNotEmpty && error != oldWidget.error) {
      if (!MediaQuery.of(context).disableAnimations) _shake.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onFocusChanged);
    _ownFocus?.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    final String text = widget.controller.text;
    if (text.length > _lastLength) HapticFeedback.selectionClick();
    _lastLength = text.length;

    if (text.length < widget.length) {
      _completed = '';
    } else if (text != _completed) {
      _completed = text;
      // After the frame, so a callback that clears or moves focus does not do
      // it in the middle of the text field's own update.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.text == text) {
          widget.onCompleted?.call(text);
        }
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final String text = widget.controller.text;
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;
    final bool focused = _focus.hasFocus;
    // Sized like the kiosk website's boxes, so the two read as one product.
    final double gap = widget.length > 4 ? 8 : 10;
    const double height = 56;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              widget.label!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _shake,
          builder: (BuildContext context, Widget? child) {
            final double t = _shake.value;
            // A decaying side-to-side wobble: three swings, settling to rest.
            final double dx = math.sin(t * math.pi * 6) * 9 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Fixed-size boxes, centred, shrinking only on a very narrow
              // screen — the same proportions as the website.
              final double cell = math.min(
                widget.length > 4 ? 46 : 54,
                (constraints.maxWidth - gap * (widget.length - 1)) /
                    widget.length,
              );
              final double width =
                  cell * widget.length + gap * (widget.length - 1);
              final int active = math.min(text.length, widget.length - 1);
              final Duration pop = reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 260);

              return Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    children: <Widget>[
                      Row(
                        children: List<Widget>.generate(widget.length, (int i) {
                          final bool filled = i < text.length;
                          final bool isActive = focused && i == active;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: i == widget.length - 1 ? 0 : gap,
                            ),
                            child: AnimatedScale(
                              scale: filled ? 1 : (isActive ? 1.02 : 0.96),
                              duration: pop,
                              curve: Curves.easeOutBack,
                              child: AnimatedContainer(
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                width: cell,
                                height: height,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: filled ? palette.accent : palette.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: hasError
                                        ? AppTheme.errorRed
                                        : isActive || filled
                                        ? palette.accent
                                        : (dark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : palette.border),
                                    width: hasError || isActive ? 2 : 1,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: filled
                                          ? palette.accent.withValues(
                                              alpha: 0.22,
                                            )
                                          : isActive
                                          ? palette.accent.withValues(
                                              alpha: 0.18,
                                            )
                                          : Colors.transparent,
                                      blurRadius: filled ? 16 : 12,
                                      offset: Offset(0, filled ? 3 : 0),
                                    ),
                                  ],
                                ),
                                child: AnimatedSwitcher(
                                  duration: pop,
                                  transitionBuilder:
                                      (Widget child, Animation<double> a) =>
                                          ScaleTransition(
                                            scale: a,
                                            child: child,
                                          ),
                                  child: !filled
                                      ? const SizedBox.shrink(
                                          key: ValueKey<String>('empty'),
                                        )
                                      : widget.obscure
                                      ? Container(
                                          key: const ValueKey<String>('dot'),
                                          width: 12,
                                          height: 12,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : Text(
                                          text[i],
                                          key: ValueKey<String>('d${text[i]}'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focus,
                            enabled: widget.enabled,
                            autofocus: widget.autofocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: widget.autofillHints,
                            showCursor: false,
                            enableInteractiveSelection: false,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(widget.length),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Text(
                    widget.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
