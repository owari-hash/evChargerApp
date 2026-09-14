import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_info.dart';
import '../utils/app_strings.dart';
import '../widgets/pin_code_field.dart';

/// Sign in, sign up, and reset a forgotten PIN.
///
/// Signing in is a phone number and a 4-digit PIN. Signing up and resetting a
/// PIN are the same three steps — the phone number, the SMS code, a new PIN
/// typed twice — so they share one flow. Everything lives in one screen because
/// the modes share the hero and the footer; only the field stack between them
/// changes. The submit button is deliberately pinned outside the scrolling area
/// so it stays reachable on a 320pt phone with the keyboard up.
class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({
    super.key,
    required this.onLoginSuccess,
    AuthService? authService,
  }) : _authService = authService,
       sheetReason = null;

  /// Sign-in raised over whatever the driver was already doing, because they
  /// reached for something that needs an account.
  ///
  /// Pops `true` once they are signed in so the caller can carry on with the
  /// action it interrupted — the driver taps "start charging" once, not twice.
  const LoginRegisterScreen.sheet({
    super.key,
    required String reason,
    AuthService? authService,
  }) : _authService = authService,
       sheetReason = reason,
       onLoginSuccess = _ignored;

  static void _ignored() {}

  final VoidCallback onLoginSuccess;

  /// Why the driver is being asked. Null for the full-screen presentation.
  final String? sheetReason;

  /// True when this is the modal presentation rather than the full screen.
  bool get isSheet => sheetReason != null;

  /// Injectable so tests can drive the screen without a network.
  final AuthService? _authService;

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

enum _Mode { login, signup, reset }

/// Where sign-up or a PIN reset has got to.
enum _Step { phone, code, pin }

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  AuthService get _auth => widget._authService ?? AuthService.instance;

  /// How long "resend code" stays disabled after a code goes out.
  static const int _resendSeconds = 60;

  _Mode _mode = _Mode.login;
  _Step _step = _Step.phone;
  bool _pending = false;
  bool _acceptedTerms = false;
  String? _formError;
  Map<String, String> _fieldErrors = const <String, String>{};

  /// Masked number the code went to.
  String _destination = '';

  /// The code itself, when a development server echoes it back instead of
  /// texting it.
  String? _devCode;

  /// Proof from the code step that the number is the driver's; spent on the
  /// PIN step.
  String? _ticket;

  int _resendIn = 0;
  Timer? _resendTimer;

  final TextEditingController _phone = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _newPin = TextEditingController();
  final TextEditingController _confirmPin = TextEditingController();
  final FocusNode _confirmFocus = FocusNode();

  late final List<TextEditingController> _allFields = <TextEditingController>[
    _phone,
    _pin,
    _code,
    _newPin,
    _confirmPin,
  ];

  late PageController _slideshowController;
  int _activeSlide = 0;
  Timer? _slideshowTimer;

  final List<Map<String, String>> _slides = <Map<String, String>>[
    <String, String>{
      'titleKey': 'slideshow1_title',
      'subKey': 'slideshow1_sub',
      'image': 'assets/images/banner.jpg',
    },
    <String, String>{
      'titleKey': 'slideshow2_title',
      'subKey': 'slideshow2_sub',
      'image': 'assets/images/bmw_x5.jpg',
    },
  ];

  bool get _isLoginMode => _mode == _Mode.login;

  @override
  void initState() {
    super.initState();
    _slideshowController = PageController();
    _startSlideshowTimer();
    // The charge rail reads the fields on every keystroke.
    for (final TextEditingController field in _allFields) {
      field.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _startSlideshowTimer() {
    _slideshowTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_slideshowController.hasClients) {
        final int nextPage = (_activeSlide + 1) % _slides.length;
        _slideshowController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _resendTimer?.cancel();
    _slideshowController.dispose();
    _confirmFocus.dispose();
    for (final TextEditingController field in _allFields) {
      field
        ..removeListener(_onFieldChanged)
        ..dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- validation

  /// Mirrors the API's own rules so an obvious mistake is caught before a round
  /// trip. The server stays the authority; this only saves the driver a wait.
  static bool _looksLikePhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[\s()\-.+]'), '');
    return RegExp(r'^\d{8,15}$').hasMatch(digits);
  }

  static bool _isPin(String value) => RegExp(r'^\d{4}$').hasMatch(value);

  /// How far through sign-up or a reset the driver is, 0..1 — what the charge
  /// rail shows.
  double get _completion => switch (_step) {
    _Step.phone => _looksLikePhone(_phone.text) ? 1 / 3 : 0,
    _Step.code => (1 + _code.text.length / 6) / 3,
    _Step.pin => (2 + (_newPin.text.length + _confirmPin.text.length) / 8) / 3,
  };

  void _showLocalErrors(Map<String, String> errors) {
    setState(() {
      _fieldErrors = errors;
      _formError = AppStrings.get('auth_check_fields');
    });
  }

  // ------------------------------------------------------------------- actions

  /// Back to the phone step, keeping the number typed so far.
  void _restartFlow() {
    for (final TextEditingController field in <TextEditingController>[
      _pin,
      _code,
      _newPin,
      _confirmPin,
    ]) {
      field.clear();
    }
    _resendTimer?.cancel();
    setState(() {
      _step = _Step.phone;
      _resendIn = 0;
      _ticket = null;
      _devCode = null;
      _formError = null;
      _fieldErrors = const <String, String>{};
    });
  }

  void _setMode(_Mode mode) {
    if (_mode == mode) return;
    _restartFlow();
    setState(() => _mode = mode);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  /// Runs one request with the button busy. On failure the API's own words are
  /// shown and false comes back.
  Future<bool> _run(Future<void> Function() request) async {
    setState(() {
      _pending = true;
      _formError = null;
      _fieldErrors = const <String, String>{};
    });
    try {
      await request();
      if (mounted) setState(() => _pending = false);
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _pending = false;
          _formError = error.message;
          _fieldErrors = error.fields;
        });
      }
      return false;
    }
  }

  Future<void> _submit() async {
    if (_pending) return;
    FocusScope.of(context).unfocus();

    if (_isLoginMode) return _signIn();
    return switch (_step) {
      _Step.phone => _sendCode(),
      _Step.code => _verifyCode(),
      _Step.pin => _savePin(),
    };
  }

  Future<void> _signIn() async {
    final Map<String, String> local = <String, String>{
      if (!_looksLikePhone(_phone.text))
        'phone': AppStrings.get('auth_bad_phone'),
      if (!_isPin(_pin.text)) 'pin': AppStrings.get('auth_bad_pin'),
    };
    if (local.isNotEmpty) return _showLocalErrors(local);

    final bool ok = await _run(
      () => _auth.signIn(phone: _phone.text, pin: _pin.text),
    );
    if (!mounted) return;
    if (ok) return _finished();
    _pin.clear();
  }

  /// Texts a code for the current mode, and starts the resend countdown.
  Future<bool> _requestCode() async {
    CodeSent? sent;
    final bool ok = await _run(() async {
      sent = _mode == _Mode.signup
          ? await _auth.sendSignupCode(_phone.text)
          : await _auth.sendPinResetCode(_phone.text);
    });
    if (!mounted || !ok || sent == null) return false;

    _code.clear();
    setState(() {
      _destination = sent!.destination;
      _devCode = sent!.devCode;
    });
    _startResendTimer();
    return true;
  }

  Future<void> _sendCode() async {
    final Map<String, String> local = <String, String>{
      if (!_looksLikePhone(_phone.text))
        'phone': AppStrings.get('auth_bad_phone'),
      if (_mode == _Mode.signup && !_acceptedTerms)
        'acceptTerms': AppStrings.get('auth_terms_required'),
    };
    if (local.isNotEmpty) return _showLocalErrors(local);

    if (await _requestCode() && mounted) {
      setState(() => _step = _Step.code);
    }
  }

  Future<void> _resendCode() async {
    if (_pending || _resendIn > 0) return;
    await _requestCode();
  }

  Future<void> _verifyCode() async {
    if (_code.text.length != 6) {
      return _showLocalErrors(<String, String>{
        'code': AppStrings.get('auth_bad_code'),
      });
    }

    String? ticket;
    final bool ok = await _run(() async {
      ticket = _mode == _Mode.signup
          ? await _auth.verifySignupCode(phone: _phone.text, code: _code.text)
          : await _auth.verifyPinResetCode(
              phone: _phone.text,
              code: _code.text,
            );
    });
    if (!mounted) return;
    if (!ok) {
      _code.clear();
      return;
    }

    _resendTimer?.cancel();
    setState(() {
      _ticket = ticket;
      _devCode = null;
      _resendIn = 0;
      _step = _Step.pin;
    });
  }

  /// Runs as soon as the repeat is complete, so a typo is caught before the
  /// driver reaches for the button.
  void _checkConfirm(String value) {
    if (value == _newPin.text) {
      if (_fieldErrors.isNotEmpty) {
        setState(() => _fieldErrors = const <String, String>{});
      }
      return;
    }
    _confirmPin.clear();
    setState(() {
      _fieldErrors = <String, String>{
        'confirmPin': AppStrings.get('auth_pin_mismatch'),
      };
    });
  }

  Future<void> _savePin() async {
    if (!_isPin(_newPin.text)) {
      return _showLocalErrors(<String, String>{
        'pin': AppStrings.get('auth_bad_pin'),
      });
    }
    if (_confirmPin.text != _newPin.text) {
      _confirmPin.clear();
      _confirmFocus.requestFocus();
      return _showLocalErrors(<String, String>{
        'confirmPin': AppStrings.get('auth_pin_mismatch'),
      });
    }

    final String ticket = _ticket ?? '';
    final bool ok = await _run(
      () => _mode == _Mode.signup
          ? _auth.completeSignup(
              ticket: ticket,
              pin: _newPin.text,
              confirmPin: _confirmPin.text,
            )
          : _auth.resetPin(
              ticket: ticket,
              pin: _newPin.text,
              confirmPin: _confirmPin.text,
            ),
    );
    if (!mounted) return;
    if (ok) return _finished();

    // The verified-phone ticket ran out: only starting over can fix that.
    if (_fieldErrors.containsKey('ticket')) {
      final String? message = _formError;
      _restartFlow();
      setState(() => _formError = message);
    }
  }

  void _finished() {
    if (widget.isSheet && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
    widget.onLoginSuccess();
  }

  // --------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (widget.isSheet) return _sheetBody(palette);

    return Scaffold(
      // The image runs edge to edge behind everything, so there is no second
      // surface for the scaffold colour to show through at the card's corners.
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _backdrop(palette),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double bottomInset = MediaQuery.of(
                  context,
                ).padding.bottom;
                const double brandRowHeight = 56;
                final double outerPadding = 14 + bottomInset;

                // Cap the card at exactly what is left once the brand row and
                // the card's own margins are accounted for. The column can then
                // never be over-committed, whatever the card wants to be: it
                // sits at its natural height when short, and scrolls inside
                // itself when a step is taller than the phone.
                final double cardCap =
                    (constraints.maxHeight - brandRowHeight - outerPadding)
                        .clamp(0.0, constraints.maxHeight);

                return Column(
                  children: <Widget>[
                    SizedBox(
                      height: brandRowHeight,
                      child: const _BrandRow(),
                    ),
                    // Takes every point the card does not, which is what keeps
                    // the card on the bottom edge. Scrollable so it tolerates
                    // being squeezed to nothing without the copy overflowing,
                    // and reversed so the headline stays against the card.
                    Expanded(
                      child: keyboardOpen
                          ? const SizedBox.shrink()
                          : LayoutBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    BoxConstraints heroBox,
                                  ) {
                                    // A taller card leaves little room. Rather
                                    // than clip the headline in half, stand
                                    // down entirely.
                                    if (heroBox.maxHeight < _fullCopyHeight) {
                                      return const SizedBox.shrink();
                                    }
                                    return Align(
                                      alignment: Alignment.bottomLeft,
                                      child: _heroCopy(),
                                    );
                                  },
                            ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, outerPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: cardCap),
                        child: _formCard(palette),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The modal presentation: the same form card, without the hero screen
  /// around it. Capped at 90% of the viewport so a taller step scrolls inside
  /// the card instead of running off the top of the sheet.
  Widget _sheetBody(AppPalette palette) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Text(
                widget.sheetReason!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  shadows: <Shadow>[
                    Shadow(color: Colors.black54, blurRadius: 12),
                  ],
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _formCard(palette),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-bleed slideshow under a scrim heavy enough to keep white text legible
  /// wherever the photograph happens to be bright.
  Widget _backdrop(AppPalette palette) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Blurred: the photographs are atmosphere, not subject matter, and a
        // sharp image behind text competes with it. Clamped so the blur does
        // not pull transparent edges into the frame.
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
            tileMode: TileMode.clamp,
          ),
          child: PageView.builder(
            controller: _slideshowController,
            onPageChanged: (int index) => setState(() => _activeSlide = index),
            itemCount: _slides.length,
            itemBuilder: (BuildContext context, int index) {
              return Image.asset(
                _slides[index]['image']!,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                      return Container(
                        color: palette.panel,
                        child: Center(
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 96,
                            color: palette.accent,
                          ),
                        ),
                      );
                    },
              );
            },
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.66),
                Colors.black.withValues(alpha: 0.20),
                Colors.black.withValues(alpha: 0.70),
              ],
              stops: const <double>[0.0, 0.42, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  /// Room the headline block needs before it is worth drawing at all.
  static const double _fullCopyHeight = 140;

  /// Height of two lines of the headline, and of the line beneath it. Both are
  /// reserved whether or not this slide fills them, so moving between slides
  /// does not shift everything below.
  static const double _titleHeight = 60;
  static const double _subtitleHeight = 36;

  /// The slide's headline, sitting on the image rather than in a panel.
  Widget _heroCopy() {
    final Map<String, String> slide = _slides[_activeSlide];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: _titleHeight,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                AppStrings.get(slide['titleKey']!),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: _subtitleHeight,
            child: Text(
              AppStrings.get(slide['subKey']!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The form, floating clear of every edge so it reads as a card on the photo
  /// instead of a panel welded to the bottom of the screen.
  Widget _formCard(AppPalette palette) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ModeSwitch(
            // A PIN reset belongs to signing in.
            isLoginMode: _mode != _Mode.signup,
            enabled: !_pending,
            onChanged: (bool toLogin) =>
                _setMode(toLogin ? _Mode.login : _Mode.signup),
          ),
          // Sign-up and a reset are three steps, so they show how far along
          // the driver is. Sign-in is two fields — a meter there is noise.
          if (!_isLoginMode) ...<Widget>[
            const SizedBox(height: 14),
            _ChargeRail(completion: _completion),
          ],
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: _isLoginMode
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _isLoginMode
                    ? _loginFields(palette)
                    : _flowFields(palette),
              ),
            ),
          ),
          if (_formError != null) ...<Widget>[
            const SizedBox(height: 12),
            _ErrorBanner(message: _formError!),
          ],
          const SizedBox(height: 14),
          _buildSubmitButton(palette),
          const SizedBox(height: 10),
          const _FooterNote(),
        ],
      ),
    );
  }

  Widget _phoneField() {
    return _AuthField(
      controller: _phone,
      label: AppStrings.get('auth_phone'),
      icon: Icons.phone_iphone_rounded,
      keyboardType: TextInputType.phone,
      textInputAction: _isLoginMode
          ? TextInputAction.next
          : TextInputAction.done,
      enabled: !_pending,
      error: _fieldErrors['phone'],
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[\d\s+()\-]')),
      ],
      onSubmitted: _isLoginMode ? null : (_) => _submit(),
      autofillHints: const <String>[AutofillHints.telephoneNumber],
    );
  }

  Widget _textLink(String label, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.palette.inkMuted,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  List<Widget> _loginFields(AppPalette palette) {
    return <Widget>[
      _Headline(
        title: AppStrings.get('auth_login_headline'),
        subtitle: AppStrings.get('auth_login_sub'),
      ),
      const SizedBox(height: 14),
      _phoneField(),
      const SizedBox(height: 10),
      PinCodeField(
        controller: _pin,
        label: AppStrings.get('auth_pin'),
        enabled: !_pending,
        error: _fieldErrors['pin'],
        autofillHints: const <String>[AutofillHints.password],
      ),
      Align(
        alignment: Alignment.centerRight,
        child: _textLink(
          AppStrings.get('forgot_pin'),
          _pending ? null : () => _setMode(_Mode.reset),
        ),
      ),
    ];
  }

  List<Widget> _flowFields(AppPalette palette) {
    final bool signup = _mode == _Mode.signup;

    return switch (_step) {
      _Step.phone => <Widget>[
        _Headline(
          title: AppStrings.get(
            signup ? 'auth_register_headline' : 'auth_reset_headline',
          ),
          subtitle: AppStrings.get(
            signup ? 'auth_register_sub' : 'auth_reset_sub',
          ),
        ),
        const SizedBox(height: 14),
        _phoneField(),
        if (signup) ...<Widget>[
          const SizedBox(height: 12),
          _TermsNotice(
            palette: palette,
            accepted: _acceptedTerms,
            enabled: !_pending,
            error: _fieldErrors['acceptTerms'],
            onChanged: (bool value) => setState(() {
              _acceptedTerms = value;
              _fieldErrors = Map<String, String>.of(_fieldErrors)
                ..remove('acceptTerms');
            }),
          ),
        ] else
          Align(
            alignment: Alignment.centerRight,
            child: _textLink(
              AppStrings.get('auth_back_to_login'),
              _pending ? null : () => _setMode(_Mode.login),
            ),
          ),
      ],
      _Step.code => <Widget>[
        _Headline(
          title: AppStrings.get('auth_code_headline'),
          subtitle: AppStrings.get(
            'auth_code_sub',
          ).replaceFirst('{dest}', _destination),
        ),
        const SizedBox(height: 14),
        PinCodeField(
          controller: _code,
          length: 6,
          obscure: false,
          autofocus: true,
          enabled: !_pending,
          error: _fieldErrors['code'],
          autofillHints: const <String>[AutofillHints.oneTimeCode],
          // The sixth digit sends it; there is nothing else to fill in.
          onCompleted: (_) => _submit(),
        ),
        if (_devCode != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              AppStrings.get('auth_dev_code').replaceFirst('{code}', _devCode!),
              style: TextStyle(color: palette.inkMuted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: <Widget>[
            _textLink(
              AppStrings.get('auth_change_number'),
              _pending ? null : _restartFlow,
            ),
            _textLink(
              _resendIn > 0
                  ? AppStrings.get(
                      'auth_resend_in',
                    ).replaceFirst('{s}', '$_resendIn')
                  : AppStrings.get('auth_resend'),
              _pending || _resendIn > 0 ? null : _resendCode,
            ),
          ],
        ),
      ],
      _Step.pin => <Widget>[
        _Headline(
          title: AppStrings.get(
            signup ? 'auth_pin_headline' : 'auth_reset_pin_headline',
          ),
          subtitle: AppStrings.get(
            signup ? 'auth_pin_sub' : 'auth_reset_pin_sub',
          ),
        ),
        const SizedBox(height: 14),
        PinCodeField(
          controller: _newPin,
          label: AppStrings.get('auth_new_pin'),
          autofocus: true,
          enabled: !_pending,
          error: _fieldErrors['pin'],
          autofillHints: const <String>[AutofillHints.newPassword],
          onCompleted: (_) => _confirmFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        PinCodeField(
          controller: _confirmPin,
          focusNode: _confirmFocus,
          label: AppStrings.get('auth_confirm_pin'),
          enabled: !_pending,
          error: _fieldErrors['confirmPin'],
          autofillHints: const <String>[AutofillHints.newPassword],
          onCompleted: _checkConfirm,
        ),
      ],
    };
  }

  String get _submitLabel {
    if (_isLoginMode) {
      return AppStrings.get(_pending ? 'auth_signing_in' : 'login');
    }
    return switch (_step) {
      _Step.phone => AppStrings.get(
        _pending ? 'auth_sending' : 'auth_send_code',
      ),
      _Step.code => AppStrings.get(
        _pending ? 'auth_checking' : 'auth_verify_code',
      ),
      _Step.pin =>
        _mode == _Mode.signup
            ? AppStrings.get(_pending ? 'auth_creating' : 'register')
            : AppStrings.get(_pending ? 'auth_saving' : 'auth_save_pin'),
    };
  }

  Widget _buildSubmitButton(AppPalette palette) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _pending ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.panel,
          foregroundColor: palette.onPanel,
          disabledBackgroundColor: palette.panel.withValues(alpha: 0.55),
          disabledForegroundColor: palette.onPanel.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                _submitLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (_pending)
              SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.onPanel.withValues(alpha: 0.9),
                ),
              )
            else
              const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- pieces

/// The wordmark and the language switcher, over the backdrop.
class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/ev logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  AppStrings.get('appName'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  AppStrings.get('tagline'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented sign-in / sign-up switch with a sliding thumb.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.isLoginMode,
    required this.onChanged,
    this.enabled = true,
  });

  final bool isLoginMode;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: isLoginMode
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              _segment(context, AppStrings.get('login'), isLoginMode, true),
              _segment(
                context,
                AppStrings.get('register'),
                !isLoginMode,
                false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    bool active,
    bool loginSegment,
  ) {
    final AppPalette palette = context.palette;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        child: InkWell(
          onTap: enabled ? () => onChanged(loginSegment) : null,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: active ? palette.onPanel : palette.inkMuted,
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.1,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

/// How much of the form is done, drawn as the state-of-charge readout this app
/// uses everywhere else. The bolt rides the fill.
class _ChargeRail extends StatelessWidget {
  const _ChargeRail({required this.completion});

  final double completion;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int percent = (completion * 100).round();
    final bool full = completion >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppStrings.get('auth_charge_label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: TextStyle(
                color: full ? palette.accent : palette.inkMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            return SizedBox(
              height: 4,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const SizedBox(width: double.infinity, height: 4),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: width * completion.clamp(0.0, 1.0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: palette.ink,
            fontSize: 22,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: palette.inkMuted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// One text input, styled once so every field on the screen matches.
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final String? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool hasError = error != null && error!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
          style: TextStyle(
            color: palette.ink,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(
              color: palette.inkMuted.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              size: 19,
              color: hasError ? AppTheme.errorRed : palette.inkMuted,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            filled: true,
            fillColor: palette.card,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder: _border(
              hasError ? AppTheme.errorRed : palette.border,
              hasError ? 1.4 : 1,
            ),
            focusedBorder: _border(
              hasError ? AppTheme.errorRed : palette.accent,
              1.6,
            ),
            disabledBorder: _border(palette.border.withValues(alpha: 0.6), 1),
            border: _border(palette.border, 1),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 0),
            child: Text(
              error!,
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

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// What went wrong, in the API's own words.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 17,
            color: AppTheme.errorRed,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Build version, so testers can report what they are on.
class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Center(
      child: Text(
        'v$kAppVersion',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          color: palette.inkMuted.withValues(alpha: 0.85),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// The sign-up consent checkbox, with the two documents actually reachable.
///
/// Apple expects the terms and privacy policy a registration screen refers to
/// to be openable from that screen, so both names are links; tapping anywhere
/// else on the sentence ticks the box.
class _TermsNotice extends StatefulWidget {
  const _TermsNotice({
    required this.palette,
    required this.accepted,
    required this.onChanged,
    this.enabled = true,
    this.error,
  });

  final AppPalette palette;
  final bool accepted;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final String? error;

  @override
  State<_TermsNotice> createState() => _TermsNoticeState();
}

class _TermsNoticeState extends State<_TermsNotice> {
  static final Uri _termsUrl = Uri.parse('https://eplug.mn/legal/terms');
  static final Uri _privacyUrl = Uri.parse('https://eplug.mn/legal/privacy');

  /// Held on the state so they are disposed with the screen. A recognizer built
  /// inline in `build` is never released.
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = () => _open(_termsUrl);
    _privacyTap = TapGestureRecognizer()..onTap = () => _open(_privacyUrl);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _open(Uri url) async {
    bool ok = false;
    try {
      ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (ok || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.get('link_open_failed'))));
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = widget.palette;
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;
    final TextStyle base = TextStyle(
      color: palette.inkMuted,
      fontSize: 12,
      height: 1.5,
      letterSpacing: 0.1,
    );
    // Accent, weight and a rule are three ways of saying the same thing. The
    // rule is the one a colourblind driver still sees, so it stays and the
    // weight drops back — the line reads as a sentence with two links in it,
    // not as two buttons with words around them.
    final TextStyle link = base.copyWith(
      color: palette.accent,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: palette.accent.withValues(alpha: 0.45),
      decorationThickness: 1.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: widget.accepted,
                onChanged: widget.enabled
                    ? (bool? value) => widget.onChanged(value ?? false)
                    : null,
                activeColor: palette.accent,
                side: BorderSide(
                  color: hasError ? AppTheme.errorRed : palette.inkMuted,
                  width: 1.4,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: widget.enabled
                    ? () => widget.onChanged(!widget.accepted)
                    : null,
                child: Text.rich(
                  TextSpan(
                    style: base,
                    children: <InlineSpan>[
                      TextSpan(text: AppStrings.get('auth_terms_prefix')),
                      TextSpan(
                        text: AppStrings.get('auth_terms_terms'),
                        style: link,
                        recognizer: _termsTap,
                      ),
                      TextSpan(text: AppStrings.get('auth_terms_middle')),
                      TextSpan(
                        text: AppStrings.get('auth_terms_privacy'),
                        style: link,
                        recognizer: _privacyTap,
                      ),
                      TextSpan(text: AppStrings.get('auth_terms_suffix')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(38, 2, 4, 0),
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
