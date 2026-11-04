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
            ).withValues(alpha: isDark ? 0.30 : 0.20),
          ),
        ),
        Positioned(
          top: 180,
          right: -120,
          child: _Glow(
            size: 300,
            color: const Color(
              0xFF22D3EE,
            ).withValues(alpha: isDark ? 0.16 : 0.14),
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

    // Liquid-glass entrance: the empty panel assembles, then the content
    // comes into focus from a blur. Plays once on mount.
    return _GlassAssemble(
      child: DecoratedBox(
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
                              const Color(0xFF15281F).withValues(alpha: 0.62),
                              const Color(0xFF0A1712).withValues(alpha: 0.48),
                            ]
                          : <Color>[
                              Colors.white.withValues(alpha: 0.80),
                              Colors.white.withValues(alpha: 0.58),
                            ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.11)
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      // Light catching the top edge of the glass.
                      Positioned(
                        top: 0,
                        left: borderRadius * 0.6,
                        right: borderRadius * 0.6,
                        child: IgnorePointer(
                          child: Container(
                            height: 1.2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.35 : 0.9,
                                  ),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: padding,
                        child: GlassFocusIn(child: child),
                      ),
                    ],
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

/// The panel half of the liquid-glass entrance. Every card picks the next
/// move in the cycle (zoom, slide left, drop, slide right, unfold) and a
/// staggered start, so cards that appear together never move alike.
class _GlassAssemble extends StatefulWidget {
  const _GlassAssemble({required this.child});

  final Widget child;

  @override
  State<_GlassAssemble> createState() => _GlassAssembleState();
}

enum _Move { zoom, left, drop, right, unfold }

class _GlassAssembleState extends State<_GlassAssemble> {
  static int _next = 0;

  late final int _slot = _next++;
  late final _Move _move = _Move.values[_slot % _Move.values.length];
  late final int _delayMs = (_slot % 4) * 70;

  @override
  Widget build(BuildContext context) {
    return _Replay(
      delay: Duration(milliseconds: _delayMs),
      duration: const Duration(milliseconds: 650),
      builder: (double t, Widget child) {
        final double r = 1 - t;
        final Widget moved = switch (_move) {
          _Move.zoom => Transform.scale(scale: 0.94 + 0.06 * t, child: child),
          _Move.left => Transform.translate(
            offset: Offset(-28 * r, 0),
            child: child,
          ),
          _Move.right => Transform.translate(
            offset: Offset(28 * r, 0),
            child: child,
          ),
          _Move.drop => Transform.translate(
            offset: Offset(0, -18 * r),
            child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
          ),
          _Move.unfold => Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(-0.38 * r),
            child: child,
          ),
        };
        return Opacity(opacity: t, child: moved);
      },
      child: widget.child,
    );
  }
}

/// The content half: comes into focus from a blur, a beat after its panel.
class GlassFocusIn extends StatelessWidget {
  const GlassFocusIn({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 200),
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Replay(
      delay: delay,
      duration: const Duration(milliseconds: 700),
      builder: (double t, Widget child) {
        final Widget moved = Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - t)),
            child: child,
          ),
        );
        // No filter once settled: a zero blur still costs a layer.
        if (t >= 1) return moved;
        final double sigma = 10 * (1 - t);
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: moved,
        );
      },
      child: child,
    );
  }
}

/// An iOS-style segmented control: a frosted track with one glass pill that
/// slides between the options — the web's payment switch, in Flutter.
///
/// The pill is measured from the track's real width, and every option fills
/// its whole segment with the icon and label centred, so nothing sits off to
/// one side whatever the screen width.
class GlassSegmented extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.images,
  });

  final List<(IconData, String)> options;

  /// Optional brand logos (asset paths) shown instead of an option's icon,
  /// index for index with [options].
  final List<String?>? images;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  static const double _height = 52;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;
    final AppPalette palette = context.palette;

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFF0D1F17).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.75),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double segment = (box.maxWidth - _inset * 2) / options.length;
          return Stack(
            children: <Widget>[
              // The sliding glass pill.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                top: _inset,
                bottom: _inset,
                left: _inset + segment * value,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? <Color>[
                              const Color(0xFF34D399).withValues(alpha: 0.32),
                              const Color(0xFF10B981).withValues(alpha: 0.14),
                            ]
                          : <Color>[Colors.white, const Color(0xFFEFFDF5)],
                    ),
                    border: Border.all(
                      color: const Color(
                        0xFF10B981,
                      ).withValues(alpha: isDark ? 0.42 : 0.30),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: isDark
                            ? const Color(0xFF10B981).withValues(alpha: 0.30)
                            : Colors.black.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // The options, each filling its segment, content centred.
              Positioned.fill(
                left: _inset,
                right: _inset,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < options.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == value,
                          label: options[i].$2,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: enabled ? () => onChanged(i) : null,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (images != null &&
                                      i < images!.length &&
                                      images![i] != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        images![i]!,
                                        // Same box as the icons beside it.
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  else
                                    Icon(
                                      options[i].$1,
                                      size: 20,
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
                                      fontSize: 15,
                                      height: 1,
                                      // One weight for every option: a bolder
                                      // selected label is wider and shifted
                                      // the spacing each time it changed.
                                      fontWeight: FontWeight.w700,
                                    ),
                                    child: Text(options[i].$2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Night-glass building blocks (Waze-style), in Eplug's emerald.
// ---------------------------------------------------------------------------

/// Eplug's glow colours: the brand emerald and a lighter mint for highlights.
class GlassTones {
  GlassTones._();

  static const Color emerald = Color(0xFF10B981);
  static const Color mint = Color(0xFF34D399);
  static const Color deep = Color(0xFF047857);

  /// Lit-from-above emerald, for primary pills and the active state.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF34D399), Color(0xFF10B981), Color(0xFF047857)],
    stops: <double>[0, 0.45, 1],
  );
}

/// Frosted fill and edge shared by every night-glass surface.
BoxDecoration glassDecoration({
  required double radius,
  double tint = 1,
  bool lit = true,
}) {
  final bool isDark = ThemeController.isDark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? <Color>[
              Colors.white.withValues(alpha: 0.085 * tint),
              Colors.white.withValues(alpha: 0.025 * tint),
            ]
          : <Color>[
              Colors.white.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.62),
            ],
    ),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: lit ? 0.13 : 0.07)
          : Colors.white.withValues(alpha: 0.9),
    ),
  );
}

/// A blurred, frosted slab — the base of sheets and floating panels.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.blur = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : const Color(0xFF10281C).withValues(alpha: 0.16),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? <Color>[
                        const Color(0xFF13241D).withValues(alpha: 0.86),
                        const Color(0xFF07110D).withValues(alpha: 0.92),
                      ]
                    : <Color>[
                        Colors.white.withValues(alpha: 0.9),
                        const Color(0xFFF2F8F4).withValues(alpha: 0.86),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white,
                ),
                left: BorderSide(
                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.8),
                ),
                right: BorderSide(
                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.8),
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Round frosted button (back, favourite, mic, close…), with a press dip.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 42,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  /// Icon colour; the palette's ink by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Widget button = _Pressable(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: glassDecoration(
          radius: size / 2,
        ).copyWith(shape: BoxShape.rectangle),
        child: Icon(
          icon,
          size: size * 0.46,
          color: color ?? context.palette.ink,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Waze-style strip of figures split by hairlines: «14 min | 7.8 mi | 10:02».
class GlassStatStrip extends StatelessWidget {
  const GlassStatStrip({super.key, required this.items, this.leading});

  /// (value, label) pairs.
  final List<(String, String)> items;

  /// Optional icon at the start of the strip, like Waze's car.
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool isDark = ThemeController.isDark;
    final Color divider = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFF0D1F17).withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: glassDecoration(radius: 20),
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              Icon(leading, color: GlassTones.mint, size: 24),
              const SizedBox(width: 12),
            ],
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0)
                VerticalDivider(width: 1, thickness: 1, color: divider),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].$1,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: palette.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Primary or secondary pill. The primary one is lit emerald with a white
/// disc at the end holding its icon — Waze's «Start drive».
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool enabled = onPressed != null;
    final BorderRadius radius = BorderRadius.circular(height / 2);

    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (!primary && icon != null) ...<Widget>[
          Icon(icon, size: 19, color: GlassTones.mint),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: primary
                  ? Colors.white
                  : (ThemeController.isDark ? GlassTones.mint : palette.accent),
            ),
          ),
        ),
        if (primary && icon != null) ...<Widget>[
          const SizedBox(width: 10),
          Container(
            width: height - 16,
            height: height - 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 19, color: GlassTones.deep),
          ),
        ],
      ],
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: _Pressable(
        onTap: onPressed,
        child: Container(
          height: height,
          padding: EdgeInsets.only(
            left: 20,
            right: primary && icon != null ? 8 : 20,
          ),
          decoration: primary
              ? BoxDecoration(
                  borderRadius: radius,
                  gradient: GlassTones.primary,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: GlassTones.emerald.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                )
              : glassDecoration(radius: height / 2),
          child: content,
        ),
      ),
    );
  }
}

/// Grouped list rows on one glass slab, split by hairlines — Waze's «Traffic
/// condition / Tolls / Gas saving» block.
class GlassGroup extends StatelessWidget {
  const GlassGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Color divider = ThemeController.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFF0D1F17).withValues(alpha: 0.06);
    return Container(
      decoration: glassDecoration(radius: 20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, thickness: 1, indent: 54, color: divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row of a [GlassGroup]: tinted icon, title, optional caption, trailing
/// text and a chevron when tappable.
class GlassRow extends StatelessWidget {
  const GlassRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone = GlassTones.mint,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final Color tone;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: tone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? palette.ink,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ],
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.inkMuted,
                size: 22,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Glossy glass orb (the Waze splash bubble) around [child], with a soft
/// halo. [glow] scales the halo, so a caller can breathe it.
class GlassBubble extends StatelessWidget {
  const GlassBubble({
    super.key,
    required this.child,
    this.size = 168,
    this.glow = 1,
  });

  final Widget child;
  final double size;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Halo.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: GlassTones.emerald.withValues(alpha: 0.45 * glow),
                  blurRadius: 60 * glow,
                  spreadRadius: 6 * glow,
                ),
              ],
            ),
          ),
          // The orb: deep at the rim, lit in the middle.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.3),
                radius: 0.95,
                colors: <Color>[
                  const Color(0xFF1E5C45).withValues(alpha: 0.95),
                  const Color(0xFF0B2A20).withValues(alpha: 0.95),
                  const Color(0xFF03110C),
                ],
                stops: const <double>[0, 0.6, 1],
              ),
              border: Border.all(
                color: GlassTones.mint.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
          ),
          child,
          // Specular highlight across the top of the glass.
          Positioned(
            top: size * 0.07,
            child: Container(
              width: size * 0.62,
              height: size * 0.3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(size * 0.31, size * 0.15),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.42),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts [child] in once, after [delay]. Finite, so tests that
/// pump until settled are not held up.
class GlassEntrance extends StatelessWidget {
  const GlassEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
    this.from,
    this.scale = 1,
  });

  final Widget child;
  final Duration delay;

  /// Vertical travel; ignored when [from] is given.
  final double offset;

  /// Where the child starts, relative to its resting place.
  final Offset? from;

  /// Starting scale (1 = none).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final Offset start = from ?? Offset(0, offset);
    return _Replay(
      delay: delay,
      duration: const Duration(milliseconds: 560),
      builder: (double t, Widget child) {
        final double r = 1 - t;
        final Widget moved = Opacity(
          opacity: t,
          child: Transform.translate(
            offset: start * r,
            child: scale == 1
                ? child
                : Transform.scale(scale: scale + (1 - scale) * t, child: child),
          ),
        );
        if (t >= 1) return moved;
        final double sigma = 8 * r;
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: moved,
        );
      },
      child: child,
    );
  }
}

/// Bumped by the tab bar each time a tab is opened, so the entrances on a
/// screen kept alive in an IndexedStack play again when it comes into view —
/// without rebuilding the screen or losing its state.
class EntranceReplay extends InheritedWidget {
  const EntranceReplay({super.key, required this.epoch, required super.child});

  final int epoch;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EntranceReplay>()?.epoch ?? 0;

  @override
  bool updateShouldNotify(EntranceReplay oldWidget) => oldWidget.epoch != epoch;
}

/// A one-shot 0→1 animation after [delay] that runs on mount and again
/// whenever the surrounding [EntranceReplay] epoch changes. Finite, so tests
/// that pump until settled still settle.
class _Replay extends StatefulWidget {
  const _Replay({
    required this.builder,
    required this.child,
    required this.duration,
    this.delay = Duration.zero,
  });

  final Widget Function(double t, Widget child) builder;
  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<_Replay> createState() => _ReplayState();
}

class _ReplayState extends State<_Replay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration + widget.delay,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMilliseconds /
          (widget.duration + widget.delay).inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  int? _epoch;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final int epoch = EntranceReplay.of(context);
    if (_epoch != epoch) {
      _epoch = epoch;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (BuildContext context, Widget? child) =>
          widget.builder(_t.value, child!),
      child: widget.child,
    );
  }
}

/// Shrinks a touch while pressed, like an iOS control.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
