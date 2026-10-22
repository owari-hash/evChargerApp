import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// What a toast is telling the driver: something worked, something failed,
/// or just a note.
enum ToastKind { success, error, info }

/// One frosted-glass toast at the top of the screen — the app's single way of
/// reporting the outcome of an action, success or error, matching the web.
///
/// It sits on the root overlay, so it shows above bottom sheets and dialogs
/// too. A new toast replaces the one on screen rather than stacking.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.success,
    String? title,
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || message.trim().isEmpty) return;

    _dismissNow();
    final GlobalKey<_ToastViewState> key = GlobalKey<_ToastViewState>();
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => _ToastView(
        key: key,
        kind: kind,
        title: title,
        message: message,
        onDismiss: () => _dismissAnimated(key),
      ),
    );
    _current = entry;
    overlay.insert(entry);
    // An error stays a little longer: it usually asks the driver to act.
    _timer = Timer(
      Duration(milliseconds: kind == ToastKind.error ? 5000 : 3200),
      () => _dismissAnimated(key),
    );
  }

  static Future<void> _dismissAnimated(GlobalKey<_ToastViewState> key) async {
    _timer?.cancel();
    final OverlayEntry? entry = _current;
    await key.currentState?.hide();
    if (identical(_current, entry)) _dismissNow();
  }

  static void _dismissNow() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.kind,
    required this.message,
    required this.onDismiss,
    this.title,
  });

  final ToastKind kind;
  final String? title;
  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 220),
  )..forward();

  Future<void> hide() async {
    if (!mounted) return;
    await _anim.reverse();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;
    final AppPalette palette = context.palette;
    final (IconData icon, Color tone) = switch (widget.kind) {
      ToastKind.success => (Icons.check_rounded, const Color(0xFF10B981)),
      ToastKind.error => (Icons.priority_high_rounded, const Color(0xFFF43F5E)),
      ToastKind.info => (Icons.info_outline_rounded, const Color(0xFF38BDF8)),
    };

    final Animation<double> curve = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AnimatedBuilder(
            animation: curve,
            builder: (BuildContext context, Widget? child) => Opacity(
              opacity: _anim.value,
              child: Transform.translate(
                offset: Offset(0, -24 * (1 - curve.value)),
                child: child,
              ),
            ),
            child: Semantics(
              liveRegion: true,
              child: GestureDetector(
                onTap: widget.onDismiss,
                onVerticalDragEnd: (_) => widget.onDismiss(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(
                                    0xFF14202C,
                                  ).withValues(alpha: 0.72)
                                : Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.white.withValues(alpha: 0.9),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.45 : 0.14,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: tone,
                                  borderRadius: BorderRadius.circular(11),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: tone.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (widget.title != null)
                                      Text(
                                        widget.title!,
                                        style: TextStyle(
                                          color: palette.ink,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    Text(
                                      widget.message,
                                      style: TextStyle(
                                        color: widget.title == null
                                            ? palette.ink
                                            : palette.inkMuted,
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: widget.title == null
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
