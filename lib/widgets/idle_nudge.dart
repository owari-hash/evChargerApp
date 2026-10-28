import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How long a driver may sit still on a step before being pointed onward.
/// Same as the kiosk.
const Duration kIdleNudgeDelay = Duration(seconds: 10);

/// Shows a bouncing "👇 [message]" bubble above [child] once nothing has been
/// touched anywhere in the app for [kIdleNudgeDelay]. Any touch hides it and
/// starts the count again. The kiosk's `NudgeHint` / `useIdleNudge`.
///
/// [onChanged] reports when the bubble shows or hides, so a host can also
/// light up the matching step in its step bar.
class IdleNudge extends StatefulWidget {
  const IdleNudge({
    super.key,
    required this.message,
    required this.child,
    this.enabled = true,
    this.onChanged,
    this.alignment = Alignment.center,
  });

  /// Where the bubble sits over [child], e.g. over its right-hand button.
  final Alignment alignment;

  final String message;
  final Widget child;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  State<IdleNudge> createState() => _IdleNudgeState();
}

class _IdleNudgeState extends State<IdleNudge>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _visible = false;
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    // App-wide: a touch anywhere counts as the driver doing something.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _arm();
  }

  @override
  void didUpdateWidget(covariant IdleNudge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _arm();
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _timer?.cancel();
    _bounce.dispose();
    super.dispose();
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _arm();
  }

  void _arm() {
    _timer?.cancel();
    _setVisible(false);
    if (!widget.enabled) return;
    _timer = Timer(kIdleNudgeDelay, () => _setVisible(true));
  }

  void _setVisible(bool visible) {
    if (_visible == visible || !mounted) return;
    setState(() => _visible = visible);
    if (visible) {
      _bounce.repeat(reverse: true);
    } else {
      _bounce.stop();
    }
    // May run while the parent rebuilds (didUpdateWidget); tell it after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged?.call(visible);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: widget.alignment,
              child: AnimatedBuilder(
                animation: _bounce,
                builder: (BuildContext context, Widget? bubble) =>
                    Transform.translate(
                      offset: Offset(0, -6 * _bounce.value),
                      child: bubble,
                    ),
                child: Container(
                  key: const ValueKey<String>('idle-nudge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: palette.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('👇', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}
