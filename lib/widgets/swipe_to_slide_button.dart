import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SwipeToSlideButton extends StatefulWidget {
  final VoidCallback onSwipeCompleted;
  final String text;

  const SwipeToSlideButton({
    super.key,
    required this.onSwipeCompleted,
    this.text = 'Эхлүүлэхийн тулд гулсуулна уу',
  });

  @override
  State<SwipeToSlideButton> createState() => _SwipeToSlideButtonState();
}

class _SwipeToSlideButtonState extends State<SwipeToSlideButton>
    with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  bool _isCompleted = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - 56;

        return Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.darkForest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Background Pulsing Glow Track
              Positioned.fill(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        color: AppTheme.sageGreen,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Active Swipe Progress Fill
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _dragValue + 56,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.sageGreen.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),

              // Draggable Slider Knob Handle
              Positioned(
                left: _dragValue,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isCompleted) return;
                    setState(() {
                      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isCompleted) return;
                    if (_dragValue >= maxDrag * 0.8) {
                      setState(() {
                        _dragValue = maxDrag;
                        _isCompleted = true;
                      });
                      widget.onSwipeCompleted();
                    } else {
                      setState(() {
                        _dragValue = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.sageGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.sageGreen.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
