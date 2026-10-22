import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft coloured light behind a screen, so the frosted cards on top have
/// something to blur — without it, glass just reads as grey. The same look
/// as the web account area.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;
    return Stack(
      children: <Widget>[
        Positioned(
          top: -120,
          left: -90,
          child: _Glow(
            size: 320,
            color: const Color(
              0xFF10B981,
            ).withValues(alpha: isDark ? 0.22 : 0.20),
          ),
        ),
        Positioned(
          top: 180,
          right: -120,
          child: _Glow(
            size: 300,
            color: const Color(
              0xFF22D3EE,
            ).withValues(alpha: isDark ? 0.12 : 0.14),
          ),
        ),
        Positioned(
          bottom: -140,
          left: 40,
          child: _Glow(
            size: 320,
            color: const Color(
              0xFF34D399,
            ).withValues(alpha: isDark ? 0.10 : 0.12),
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// A frosted, translucent card — iOS-style glass — with an optional tap.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 22,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF10281C).withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // A faint sheen from the top-left, like light on glass.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? <Color>[
                            const Color(0xFF1C2A38).withValues(alpha: 0.62),
                            const Color(0xFF14202C).withValues(alpha: 0.48),
                          ]
                        : <Color>[
                            Colors.white.withValues(alpha: 0.80),
                            Colors.white.withValues(alpha: 0.58),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.09)
                        : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An iOS-style segmented control: a frosted track with one glass pill that
/// springs between the options — the web's payment switch, in Flutter.
class GlassSegmented extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<(IconData, String)> options;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;
    final AppPalette palette = context.palette;
    final double step = options.length <= 1 ? 0 : 2 / (options.length - 1);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFF0D1F17).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.7),
        ),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            alignment: Alignment(-1 + step * value, 0),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            child: FractionallySizedBox(
              widthFactor: 1 / options.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? <Color>[
                            const Color(0xFF34D399).withValues(alpha: 0.30),
                            const Color(0xFF10B981).withValues(alpha: 0.12),
                          ]
                        : <Color>[Colors.white, const Color(0xFFF0FDF6)],
                  ),
                  border: Border.all(
                    color: const Color(
                      0xFF10B981,
                    ).withValues(alpha: isDark ? 0.38 : 0.28),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              for (int i = 0; i < options.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == value,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled ? () => onChanged(i) : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            options[i].$1,
                            size: 18,
                            color: i == value
                                ? palette.accent
                                : palette.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: i == value
                                  ? palette.ink
                                  : palette.inkMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            child: Text(options[i].$2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
