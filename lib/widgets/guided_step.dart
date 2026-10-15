import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_strings.dart';

/// Which step of the in-place app guide is showing, shared by every
/// [GuidedStep] on screen — the dashboard sections and the bottom bar.
///
/// The guide is asked for with [request] and starts with [begin] once the
/// dashboard has its data, so the first step never lands on a spinner.
class AppGuideController extends ChangeNotifier {
  AppGuideController({this.totalSteps = 5});

  final int totalSteps;

  int _step = -1;

  /// -1 when no guide is showing.
  int get step => _step;
  bool get isActive => _step >= 0;

  bool _requested = false;

  /// Asked for, but not yet started.
  bool get requested => _requested;

  bool _replay = false;

  /// A replay from the account page: it never touches the server flag.
  bool get isReplay => _replay;

  bool _dontShowAgain = false;

  /// The card's «Дахиж харахгүй» box.
  bool get dontShowAgain => _dontShowAgain;

  set dontShowAgain(bool value) {
    if (value == _dontShowAgain) return;
    _dontShowAgain = value;
    notifyListeners();
  }

  /// Called when the guide closes. [markDone] is true when the driver went
  /// through every step, or ticked «Дахиж харахгүй» before closing; a plain
  /// skip leaves it false. Never called for a replay.
  void Function({required bool markDone})? onFinished;

  void request({bool replay = false}) {
    if (isActive) return;
    _requested = true;
    _replay = replay;
    _dontShowAgain = false;
    notifyListeners();
  }

  void begin() {
    if (!_requested) return;
    _requested = false;
    _step = 0;
    notifyListeners();
  }

  void next() {
    if (!isActive) return;
    if (_step < totalSteps - 1) {
      _step++;
      notifyListeners();
    } else {
      _close(completed: true);
    }
  }

  /// «Алгасах».
  void skip() => _close(completed: false);

  void _close({required bool completed}) {
    if (!isActive && !_requested) return;
    final bool replay = _replay;
    final bool markDone = completed || _dontShowAgain;
    _step = -1;
    _requested = false;
    _replay = false;
    _dontShowAgain = false;
    notifyListeners();
    if (!replay) onFinished?.call(markDone: markDone);
  }

  /// Drops the guide without counting it as seen — on sign-out, say.
  void cancel() {
    if (!isActive && !_requested) return;
    _step = -1;
    _requested = false;
    _replay = false;
    _dontShowAgain = false;
    notifyListeners();
  }
}

/// Ported from sukhApp's `GuidedComponent`: wraps a section of the screen in
/// place, without an overlay. While the guide runs, every other section fades
/// back, the current one gets a pulsing green frame, and a tooltip card is
/// laid out right above or below it.
class GuidedStep extends StatefulWidget {
  /// Set by the app frame; anything can replay the guide through [trigger].
  static VoidCallback? onTriggerGuide;
  static void trigger() => onTriggerGuide?.call();

  final int stepIndex;
  final int activeStep;
  final int totalSteps;
  final String title;
  final String description;
  final String tag;
  final IconData icon;
  final bool tipBelow;
  final double borderRadius;
  final EdgeInsets? tipMargin;

  /// Extra room inside the rounded clip. A section with no card of its own
  /// (a heading on the bare page) needs some, or the frame's rounded corner
  /// clips its first letters.
  final EdgeInsets contentPadding;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// The «Дахиж харахгүй» box. Hidden when [onDontShowAgainChanged] is null,
  /// as on a replay, where there is nothing to remember.
  final bool dontShowAgain;
  final ValueChanged<bool>? onDontShowAgainChanged;
  final Widget child;

  const GuidedStep({
    super.key,
    required this.stepIndex,
    required this.activeStep,
    required this.totalSteps,
    required this.title,
    required this.description,
    required this.tag,
    required this.icon,
    this.tipBelow = true,
    this.borderRadius = 24.0,
    this.tipMargin,
    this.contentPadding = EdgeInsets.zero,
    required this.onNext,
    required this.onSkip,
    this.dontShowAgain = false,
    this.onDontShowAgainChanged,
    required this.child,
  });

  /// Builds a step straight off a shared [AppGuideController].
  factory GuidedStep.of({
    Key? key,
    required AppGuideController guide,
    required int stepIndex,
    required String title,
    required String description,
    required String tag,
    required IconData icon,
    bool tipBelow = true,
    double borderRadius = 24.0,
    EdgeInsets? tipMargin,
    EdgeInsets contentPadding = EdgeInsets.zero,
    required Widget child,
  }) {
    return GuidedStep(
      key: key,
      stepIndex: stepIndex,
      activeStep: guide.step,
      totalSteps: guide.totalSteps,
      title: title,
      description: description,
      tag: tag,
      icon: icon,
      tipBelow: tipBelow,
      borderRadius: borderRadius,
      tipMargin: tipMargin,
      contentPadding: contentPadding,
      onNext: guide.next,
      onSkip: guide.skip,
      dontShowAgain: guide.dontShowAgain,
      onDontShowAgainChanged: guide.isReplay
          ? null
          : (bool value) => guide.dontShowAgain = value,
      child: child,
    );
  }

  @override
  State<GuidedStep> createState() => _GuidedStepState();
}

class _GuidedStepState extends State<GuidedStep> with TickerProviderStateMixin {
  static const Color _emerald = Color(0xFF10B981);
  static const Color _mint = Color(0xFF34D399);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _floatController;
  late AnimationController _cardAnimController;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _cardFadeAnimation;

  bool get _isCurrent => widget.activeStep == widget.stepIndex;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _cardScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutBack),
    );
    _cardFadeAnimation = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeIn,
    );

    if (_isCurrent) _activate();
  }

  @override
  void didUpdateWidget(covariant GuidedStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasActive = oldWidget.activeStep == oldWidget.stepIndex;

    if (_isCurrent && !wasActive) {
      _cardAnimController.reset();
      _activate();
    } else if (!_isCurrent && wasActive) {
      _cardAnimController.reverse();
      // Unlike sukhApp the loops only run on the current step: idle
      // repeating tickers on every section cost battery and never settle.
      _pulseController.stop();
      _floatController.stop();
    }
  }

  void _activate() {
    _cardAnimController.forward();
    _pulseController.repeat(reverse: true);
    _floatController.repeat(reverse: true);
    _scrollToSelf();
  }

  void _scrollToSelf() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
          alignment: 0.22,
        );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  void _handleNext() {
    HapticFeedback.lightImpact();
    widget.onNext();
  }

  void _handleSkip() {
    HapticFeedback.mediumImpact();
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuideActive = widget.activeStep >= 0;
    final bool isCurrent = _isCurrent;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: (!isGuideActive || isCurrent) ? 1.0 : 0.32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.tipBelow && isCurrent) ...[
            _buildAnimatedTipCard(pointingDown: true),
            const SizedBox(height: 16),
          ],

          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (BuildContext context, Widget? child) {
              if (!isCurrent) return child!;
              final double pulseVal = _pulseAnimation.value;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius + 4),
                  boxShadow: [
                    BoxShadow(
                      color: _emerald.withValues(alpha: 0.10 + 0.08 * pulseVal),
                      blurRadius: 10 + 6 * pulseVal,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    // Opaque, so the glow does not tint a section that has
                    // no background of its own.
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(
                      widget.borderRadius + 4,
                    ),
                    border: Border.all(
                      color: _emerald.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: Padding(
                      padding: widget.contentPadding,
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: widget.child,
          ),

          if (widget.tipBelow && isCurrent) ...[
            const SizedBox(height: 16),
            _buildAnimatedTipCard(pointingDown: false),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedTipCard({required bool pointingDown}) {
    final bool isLast = widget.stepIndex == widget.totalSteps - 1;

    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _cardAnimController]),
      builder: (BuildContext context, Widget? child) {
        final double floatOffsetY = sin(_floatController.value * pi) * 3.5;

        return Transform.translate(
          offset: Offset(0, floatOffsetY),
          child: FadeTransition(
            opacity: _cardFadeAnimation,
            child: ScaleTransition(
              scale: _cardScaleAnimation,
              alignment: pointingDown
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            margin:
                widget.tipMargin ?? const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF14532D),
                  Color(0xFF093928),
                  Color(0xFF042419),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _mint.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: _emerald.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned(
                    top: -25,
                    right: -25,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _mint.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: _tagPill()),
                            const SizedBox(width: 10),
                            Text(
                              '${widget.stepIndex + 1} / ${widget.totalSteps}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.description,
                          style: TextStyle(
                            color: const Color(
                              0xFFD1FAE5,
                            ).withValues(alpha: 0.95),
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _controls(isLast),
                        if (widget.onDontShowAgainChanged != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          const SizedBox(height: 4),
                          _dontShowAgainToggle(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: !pointingDown ? -9.5 : null,
            bottom: pointingDown ? -9.5 : null,
            child: _PointerTriangle(
              pointingUp: !pointingDown,
              color: pointingDown
                  ? const Color(0xFF042419)
                  : const Color(0xFF14532D),
              borderColor: _mint.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagPill() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _mint.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _mint.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: _mint, size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                widget.tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6EE7B7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dontShowAgainToggle() {
    final bool checked = widget.dontShowAgain;
    return Semantics(
      checked: checked,
      label: AppStrings.get('guide_dont_show'),
      child: GestureDetector(
        key: const ValueKey<String>('guide-dont-show'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onDontShowAgainChanged?.call(!checked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: checked ? _mint : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: checked
                        ? _mint
                        : Colors.white.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Color(0xFF042419),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppStrings.get('guide_dont_show'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: checked ? 0.85 : 0.6),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(bool isLast) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _handleSkip,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(
              AppStrings.get('guide_skip'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: List<Widget>.generate(widget.totalSteps, (int index) {
                final bool isStepActive = index == widget.stepIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isStepActive ? 18 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isStepActive
                        ? _mint
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isStepActive
                        ? [
                            BoxShadow(
                              color: _mint.withValues(alpha: 0.25),
                              blurRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
        ),

        ElevatedButton(
          key: const ValueKey<String>('guide-next'),
          onPressed: _handleNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: _emerald,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: _emerald.withValues(alpha: 0.5),
            padding: EdgeInsets.symmetric(
              horizontal: isLast ? 16 : 14,
              vertical: 8,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.get(isLast ? 'guide_done' : 'guide_next'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                size: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PointerTriangle extends StatelessWidget {
  final bool pointingUp;
  final Color color;
  final Color borderColor;

  const _PointerTriangle({
    required this.pointingUp,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 10),
      painter: _PointerTrianglePainter(
        pointingUp: pointingUp,
        fillColor: color,
        strokeColor: borderColor,
      ),
    );
  }
}

class _PointerTrianglePainter extends CustomPainter {
  final bool pointingUp;
  final Color fillColor;
  final Color strokeColor;

  _PointerTrianglePainter({
    required this.pointingUp,
    required this.fillColor,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path fillPath = Path();
    if (pointingUp) {
      fillPath.moveTo(size.width / 2, 0);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
    } else {
      fillPath.moveTo(0, 0);
      fillPath.lineTo(size.width, 0);
      fillPath.lineTo(size.width / 2, size.height);
    }
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    final Path strokePath = Path();
    if (pointingUp) {
      strokePath.moveTo(0, size.height);
      strokePath.lineTo(size.width / 2, 0);
      strokePath.lineTo(size.width, size.height);
    } else {
      strokePath.moveTo(0, 0);
      strokePath.lineTo(size.width / 2, size.height);
      strokePath.lineTo(size.width, 0);
    }

    canvas.drawPath(
      strokePath,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PointerTrianglePainter oldDelegate) {
    return oldDelegate.pointingUp != pointingUp ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeColor != strokeColor;
  }
}
