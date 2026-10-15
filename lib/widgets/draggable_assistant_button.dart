import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The assistant's floating button, which the driver can drag out of the way.
///
/// A fixed FAB sat on top of the map's own controls. This one follows the
/// finger, snaps to the nearer side edge when let go so it never rests in the
/// middle of the content, and keeps that spot for the rest of the session.
class DraggableAssistantButton extends StatefulWidget {
  const DraggableAssistantButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  State<DraggableAssistantButton> createState() =>
      _DraggableAssistantButtonState();
}

class _DraggableAssistantButtonState extends State<DraggableAssistantButton> {
  static const double _size = 52;
  static const double _margin = 12;

  /// Where the driver left it, as fractions of the free area — survives tab
  /// switches and rebuilds, and adapts if the screen size changes.
  static Offset? _saved;

  Offset? _position;
  bool _dragging = false;

  Offset _clamp(Offset p, Size area) => Offset(
    p.dx.clamp(_margin, area.width - _size - _margin),
    p.dy.clamp(_margin, area.height - _size - _margin),
  );

  /// Bottom-left by default: the map keeps its zoom and location controls on
  /// the right and its station card along the bottom centre.
  Offset _initial(Size area) => Offset(_margin, area.height * 0.62);

  void _snap(Size area) {
    final Offset p = _position!;
    final double centre = p.dx + _size / 2;
    final double x = centre < area.width / 2
        ? _margin
        : area.width - _size - _margin;
    setState(() {
      _dragging = false;
      _position = _clamp(Offset(x, p.dy), area);
    });
    final double freeW = (area.width - _size).clamp(1, double.infinity);
    final double freeH = (area.height - _size).clamp(1, double.infinity);
    _saved = Offset(_position!.dx / freeW, _position!.dy / freeH);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final Size area = Size(box.maxWidth, box.maxHeight);
        final Offset saved = _saved == null
            ? _initial(area)
            : Offset(
                _saved!.dx * (area.width - _size),
                _saved!.dy * (area.height - _size),
              );
        final Offset p = _clamp(_position ?? saved, area);

        return Stack(
          children: <Widget>[
            AnimatedPositioned(
              // Follow the finger instantly; glide only when snapping.
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: p.dx,
              top: p.dy,
              child: GestureDetector(
                onPanStart: (_) => setState(() {
                  _dragging = true;
                  _position = p;
                }),
                onPanUpdate: (DragUpdateDetails d) => setState(() {
                  _position = _clamp((_position ?? p) + d.delta, area);
                }),
                onPanEnd: (_) {
                  HapticFeedback.selectionClick();
                  _snap(area);
                },
                child: Tooltip(
                  message: widget.tooltip,
                  child: AnimatedScale(
                    scale: _dragging ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    child: Material(
                      color: palette.accent,
                      shape: const CircleBorder(),
                      elevation: _dragging ? 10 : 6,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onPressed,
                        child: const SizedBox(
                          width: _size,
                          height: _size,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
