import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A row of digit boxes for a sign-in PIN or an SMS code.
///
/// One real [TextField] lies invisibly over the boxes, so the number pad,
/// pasting, deleting and SMS code autofill all behave natively; the boxes only
/// draw what it holds.
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

  /// Shown above the boxes.
  final String? label;
  final String? error;

  /// Called once each time the last digit goes in.
  final ValueChanged<String>? onCompleted;
  final Iterable<String>? autofillHints;

  @override
  State<PinCodeField> createState() => _PinCodeFieldState();
}

class _PinCodeFieldState extends State<PinCodeField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// The value [PinCodeField.onCompleted] last fired for, so a rebuild with the
  /// same full value does not fire it twice.
  String _completed = '';

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onFocusChanged);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    final String text = widget.controller.text;
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
    final String text = widget.controller.text;
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;
    final bool focused = _focus.hasFocus;
    const double gap = 8;
    const double height = 54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            widget.label!,
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double box = math.min(
              52,
              (constraints.maxWidth - gap * (widget.length - 1)) /
                  widget.length,
            );
            final int active = math.min(text.length, widget.length - 1);

            return SizedBox(
              height: height,
              child: Stack(
                children: <Widget>[
                  Row(
                    children: List<Widget>.generate(widget.length, (int i) {
                      final bool isActive = focused && i == active;
                      final Color border = hasError
                          ? AppTheme.errorRed
                          : isActive
                          ? palette.accent
                          : palette.border;
                      return Padding(
                        padding: EdgeInsets.only(
                          right: i == widget.length - 1 ? 0 : gap,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: box,
                          height: height,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: border,
                              width: isActive || hasError ? 1.6 : 1,
                            ),
                          ),
                          child: i >= text.length
                              ? null
                              : widget.obscure
                              ? Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: palette.ink,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : Text(
                                  text[i],
                                  style: TextStyle(
                                    color: palette.ink,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
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
            );
          },
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 0),
            child: Text(
              widget.error!,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}
