import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_info.dart';
import '../utils/app_strings.dart';
import '../widgets/biometric_prompt.dart';
import '../widgets/legal_sheet.dart';
import '../widgets/pin_code_field.dart';

/// Sign in, sign up, and reset a forgotten PIN.
///
/// Laid out like the kiosk website's sign-in page on a phone: one card holding
/// the sign-in / sign-up switch, the page title, the step, and the button, so
/// the app and the website read as the same product. Signing in is a phone
/// number and a 4-digit PIN, or Face ID / a fingerprint once turned on. Signing
/// up and resetting a PIN are the same three steps — the phone number, the SMS
/// code, a new PIN typed twice — so they share one flow.
class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({
    super.key,
    required this.onLoginSuccess,
    AuthService? authService,
    BiometricService? biometricService,
  }) : _authService = authService,
       _biometricService = biometricService,
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
    BiometricService? biometricService,
  }) : _authService = authService,
       _biometricService = biometricService,
       sheetReason = reason,
       onLoginSuccess = _ignored;

  static void _ignored() {}

  final VoidCallback onLoginSuccess;

  /// Why the driver is being asked. Null for the full-screen presentation.
  final String? sheetReason;

  /// True when this is the modal presentation rather than the full screen.
  bool get isSheet => sheetReason != null;

  /// Injectable so tests can drive the screen without a network or a device.
  final AuthService? _authService;
  final BiometricService? _biometricService;

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

enum _Mode { login, signup, reset }

/// Where sign-up or a PIN reset has got to.
enum _Step { phone, code, pin }

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  AuthService get _auth => widget._authService ?? AuthService.instance;
  BiometricService get _bio =>
      widget._biometricService ?? BiometricService.instance;

  /// How long "resend code" stays disabled after a code goes out.
  static const int _resendSeconds = 60;

  static final Uri _helpUrl = Uri.parse('https://eplug.mn/help');

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

  /// Set when Face ID / fingerprint sign-in is on for this device.
  BiometricKind? _biometricKind;

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

  bool get _isLoginMode => _mode == _Mode.login;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController field in _allFields) {
      field.addListener(_onFieldChanged);
    }
    _loadBiometrics();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBiometrics() async {
    final BiometricKind? kind = await _bio.availableKind();
    final bool enabled = kind != null && await _bio.isEnabled();
    if (mounted) setState(() => _biometricKind = enabled ? kind : null);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
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

  /// The API masks the number as `********8844`; it reads better as `•••• 8844`.
  static String _prettyDestination(String masked) {
    final String digits = masked.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4
        ? '•••• ${digits.substring(digits.length - 4)}'
        : masked;
  }

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
  /// shown and the error comes back; null means it went through.
  Future<ApiException?> _run(Future<void> Function() request) async {
    setState(() {
      _pending = true;
      _formError = null;
      _fieldErrors = const <String, String>{};
    });
    try {
      await request();
      if (mounted) setState(() => _pending = false);
      return null;
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _pending = false;
          _formError = error.message;
          _fieldErrors = error.fields;
        });
      }
      return error;
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

    final String phone = _phone.text;
    final String pin = _pin.text;
    final ApiException? error = await _run(
      () => _auth.signIn(phone: phone, pin: pin),
    );
    if (!mounted) return;
    if (error == null) return _signedIn(phone: phone, pin: pin);
    _pin.clear();
  }

  Future<void> _signInWithBiometrics() async {
    if (_pending) return;
    FocusScope.of(context).unfocus();

    final SavedCredentials? saved = await _bio.unlock(
      reason: AppStrings.get('bio_reason'),
    );
    if (saved == null || !mounted) return;

    _phone.text = saved.phone;
    final ApiException? error = await _run(
      () => _auth.signIn(phone: saved.phone, pin: saved.pin),
    );
    if (!mounted) return;
    if (error == null) return _finished();

    // The remembered PIN no longer works — it was changed or reset somewhere
    // else — so forget it rather than fail the same way next time.
    if (error.statusCode == 401) {
      await _bio.disable();
      if (!mounted) return;
      setState(() {
        _biometricKind = null;
        _formError = AppStrings.get('bio_stale');
      });
    }
  }

  /// Texts a code for the current mode, and starts the resend countdown.
  Future<bool> _requestCode() async {
    CodeSent? sent;
    final ApiException? error = await _run(() async {
      sent = _mode == _Mode.signup
          ? await _auth.sendSignupCode(_phone.text)
          : await _auth.sendPinResetCode(_phone.text);
    });
    if (!mounted || error != null || sent == null) return false;

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
    final ApiException? error = await _run(() async {
      ticket = _mode == _Mode.signup
          ? await _auth.verifySignupCode(phone: _phone.text, code: _code.text)
          : await _auth.verifyPinResetCode(
              phone: _phone.text,
              code: _code.text,
            );
    });
    if (!mounted) return;
    if (error != null) {
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

    final String phone = _phone.text;
    final String pin = _newPin.text;
    final String ticket = _ticket ?? '';
    final ApiException? error = await _run(
      () => _mode == _Mode.signup
          ? _auth.completeSignup(ticket: ticket, pin: pin, confirmPin: pin)
          : _auth.resetPin(ticket: ticket, pin: pin, confirmPin: pin),
    );
    if (!mounted) return;
    if (error == null) return _signedIn(phone: phone, pin: pin);

    // The verified-phone ticket ran out: only starting over can fix that.
    if (_fieldErrors.containsKey('ticket')) {
      final String? message = _formError;
      _restartFlow();
      setState(() => _formError = message);
    }
  }

  /// A PIN has just worked: offer Face ID / fingerprint for next time, then
  /// carry on to wherever the driver was going.
  Future<void> _signedIn({required String phone, required String pin}) async {
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    await offerBiometricSignIn(navigator, _bio, phone: phone, pin: pin);
    if (mounted) _finished();
  }

  void _finished() {
    if (widget.isSheet && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
    widget.onLoginSuccess();
  }

  Future<void> _openHelp() async {
    try {
      await launchUrl(_helpUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      /* Nothing more useful to do than stay on the form. */
    }
  }

  // --------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    if (widget.isSheet) return _sheetBody(palette);

    return Scaffold(
      backgroundColor: palette.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxHeight < 640;
            // The smallest iPhones get tighter spacing, so the button is on
            // screen without scrolling.
            final bool tight = constraints.maxHeight < 600;
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                tight
                    ? 8
                    : compact
                    ? 12
                    : 20,
                16,
                28,
              ),
              child: Column(
                children: <Widget>[
                  _Entrance(child: _card(palette, compact, tight: tight)),
                  const SizedBox(height: 14),
                  _below(palette),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The modal presentation: the same card in a sheet, headed by why it was
  /// raised.
  Widget _sheetBody(AppPalette palette) {
    final MediaQueryData media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ColoredBox(
            color: palette.bg,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.inkMuted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.sheetReason!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.inkMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(palette, true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The card: switch, title, step, error, fields and button — in the website's
  /// order.
  Widget _card(AppPalette palette, bool compact, {bool tight = false}) {
    final double sectionGap = tight
        ? 14
        : compact
        ? 22
        : 28;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool signup = _mode == _Mode.signup;

    final String title = AppStrings.get(switch (_mode) {
      _Mode.login => 'auth_login_headline',
      _Mode.signup => 'auth_register_headline',
      _Mode.reset => 'auth_reset_headline',
    });
    final String subtitle = AppStrings.get(switch (_mode) {
      _Mode.login => 'auth_login_sub',
      _Mode.signup => 'auth_register_sub',
      _Mode.reset => 'auth_reset_sub',
    });
    final String stepTitle = AppStrings.get(switch (_step) {
      _Step.phone => 'auth_phone_step',
      _Step.code => 'auth_code_headline',
      _Step.pin => signup ? 'auth_pin_headline' : 'auth_reset_pin_headline',
    });

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 448),
      padding: EdgeInsets.all(
        tight
            ? 16
            : compact
            ? 20
            : 24,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // A PIN reset has no switch, like the website's reset page.
          if (_mode != _Mode.reset) ...<Widget>[
            _SegmentedCapsule(
              isLoginMode: _isLoginMode,
              enabled: !_pending,
              onChanged: (bool toLogin) =>
                  _setMode(toLogin ? _Mode.login : _Mode.signup),
            ),
            SizedBox(height: sectionGap),
          ],
          _Headline(title: title, subtitle: subtitle, compact: compact, tight: tight),
          SizedBox(height: sectionGap),
          if (!_isLoginMode) ...<Widget>[
            _StepHeader(title: stepTitle, step: _step.index + 1),
            SizedBox(height: tight ? 12 : 20),
          ],
          ..._errorBlock(),
          _StepTransition(
            child: Column(
              key: ValueKey<String>('${_mode.name}-${_step.name}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _isLoginMode
                  ? _loginFields(palette)
                  : _flowFields(palette),
            ),
          ),
          SizedBox(height: tight ? 14 : 20),
          _actions(palette),
          if (_mode == _Mode.reset) ...<Widget>[
            const SizedBox(height: 10),
            Center(
              child: _textLink(
                AppStrings.get('auth_back_to_login'),
                _pending ? null : () => _setMode(_Mode.login),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Under the card, as on the website: the help link, then the version.
  Widget _below(AppPalette palette) {
    return Column(
      children: <Widget>[
        TextButton(
          onPressed: _openHelp,
          style: TextButton.styleFrom(foregroundColor: palette.inkMuted),
          child: Text(
            AppStrings.get('auth_help_center'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const _FooterNote(),
      ],
    );
  }

  /// The API's or the form's error, where the website shows its alert.
  List<Widget> _errorBlock() {
    if (_formError == null) return const <Widget>[];
    return <Widget>[
      _ErrorBanner(message: _formError!),
      const SizedBox(height: 18),
    ];
  }

  Widget _textLink(String label, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.palette.accent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  List<Widget> _loginFields(AppPalette palette) {
    return <Widget>[
      _PhoneField(
        controller: _phone,
        label: AppStrings.get('auth_phone'),
        enabled: !_pending,
        error: _fieldErrors['phone'],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 18),
      PinCodeField(
        controller: _pin,
        label: AppStrings.get('auth_pin'),
        enabled: !_pending,
        error: _fieldErrors['pin'],
        autofillHints: const <String>[AutofillHints.password],
      ),
      const SizedBox(height: 4),
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
    final TextStyle body = TextStyle(
      color: palette.inkMuted,
      fontSize: 14,
      height: 1.45,
    );

    return switch (_step) {
      _Step.phone => <Widget>[
        _PhoneField(
          controller: _phone,
          label: AppStrings.get('auth_phone'),
          hint: AppStrings.get('auth_phone_hint'),
          enabled: !_pending,
          error: _fieldErrors['phone'],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        if (signup) ...<Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height < 600 ? 10 : 16),
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
        ],
      ],
      _Step.code => <Widget>[
        Text(
          AppStrings.get(
            'auth_code_sub',
          ).replaceFirst('{dest}', _prettyDestination(_destination)),
          style: body,
        ),
        const SizedBox(height: 18),
        PinCodeField(
          controller: _code,
          label: AppStrings.get('auth_code'),
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
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              AppStrings.get('auth_dev_code').replaceFirst('{code}', _devCode!),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkMuted, fontSize: 13),
            ),
          ),
        const SizedBox(height: 6),
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
        Text(
          AppStrings.get(signup ? 'auth_pin_sub' : 'auth_reset_pin_sub'),
          style: body,
        ),
        const SizedBox(height: 18),
        PinCodeField(
          controller: _newPin,
          label: AppStrings.get('auth_new_pin'),
          autofocus: true,
          enabled: !_pending,
          error: _fieldErrors['pin'],
          autofillHints: const <String>[AutofillHints.newPassword],
          onCompleted: (_) => _confirmFocus.requestFocus(),
        ),
        const SizedBox(height: 18),
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

  Widget _actions(AppPalette palette) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // The website's brand button: bright green, with dark text in dark mode.
    final Color fill = palette.accent;
    final Color label = dark ? const Color(0xFF04201A) : Colors.white;

    return Row(
      children: <Widget>[
        Expanded(
          child: _Pressable(
            enabled: !_pending,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _pending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: fill,
                  foregroundColor: label,
                  disabledBackgroundColor: fill.withValues(alpha: 0.55),
                  disabledForegroundColor: label.withValues(alpha: 0.85),
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (_pending) ...<Widget>[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: label,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        _submitLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isLoginMode && _biometricKind != null) ...<Widget>[
          const SizedBox(width: 12),
          _Pressable(
            enabled: !_pending,
            child: _BiometricButton(
              kind: _biometricKind!,
              onPressed: _pending ? null : _signInWithBiometrics,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------- pieces

/// The one orchestrated entrance: the card rises into place as the screen
/// opens. Nothing else animates on its own.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Moving between steps: the old step fades away as the new one slides in
/// from the side, so the driver sees they moved forward.
class _StepTransition extends StatelessWidget {
  const _StepTransition({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      reverseDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[...previous, ?current],
      ),
      child: child,
    );
  }
}

/// Presses in slightly under a finger, like a native button.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The sign-in / sign-up switch: a tinted track with a raised thumb that slides
/// to the chosen side, as on the website.
class _SegmentedCapsule extends StatelessWidget {
  const _SegmentedCapsule({
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: isLoginMode
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dark ? palette.bg : Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: palette.border),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(loginSegment) : null,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              // From the text theme, so it keeps Geist: a bare TextStyle here
              // would replace the inherited one and fall back to the system
              // font.
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: active ? palette.ink : palette.inkMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

/// The step's own title with "Step 2 of 3" beside it and three bars under
/// both — the website's step header.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.step});

  final String title;

  /// 1-based.
  final int step;

  static const int _steps = 3;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: (Widget? current, List<Widget> previous) =>
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[...previous, ?current],
                    ),
                child: Text(
                  title,
                  key: ValueKey<String>(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppStrings.get('auth_step_of').replaceFirst('{step}', '$step'),
              style: TextStyle(
                color: palette.inkMuted,
                fontSize: 13.5,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (int i = 1; i <= _steps; i++) ...<Widget>[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= step ? palette.accent : palette.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The page title and the line under it, as at the top of the website's card.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.tight = false,
  });

  final String title;
  final String subtitle;
  final bool compact;
  final bool tight;

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
            fontSize: tight
                ? 24
                : compact
                ? 26
                : 28,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        SizedBox(height: tight ? 6 : 8),
        Text(
          subtitle,
          style: TextStyle(
            color: palette.inkMuted,
            fontSize: tight ? 14 : 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// The phone number with the country code fixed in front, bordered like the
/// website's field.
class _PhoneField extends StatefulWidget {
  const _PhoneField({
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
    this.error,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;

  /// One line under the field, while there is no error to show instead.
  final String? hint;
  final bool enabled;
  final String? error;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;
    const InputBorder none = InputBorder.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              color: palette.ink,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 56,
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? AppTheme.errorRed
                  : _focus.hasFocus
                  ? palette.accent
                  : palette.border,
              width: hasError || _focus.hasFocus ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 16),
              Text(
                '+976',
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 24, color: palette.border),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  autofillHints: const <String>[AutofillHints.telephoneNumber],
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  cursorColor: palette.accent,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 16,
                    letterSpacing: 0.4,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: none,
                    enabledBorder: none,
                    focusedBorder: none,
                    disabledBorder: none,
                    errorBorder: none,
                    hintText: '9911 2233',
                    hintStyle: TextStyle(
                      color: palette.inkMuted.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        if (hasError || widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              hasError ? widget.error! : widget.hint!,
              style: TextStyle(
                color: hasError ? AppTheme.errorRed : palette.inkMuted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}

/// A round button beside the primary one: Face ID on iPhone, the fingerprint
/// on Android.
class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.kind, required this.onPressed});

  final BiometricKind kind;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Semantics(
      button: true,
      label: biometricSignInLabel(kind),
      child: Tooltip(
        message: biometricSignInLabel(kind),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.card,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border),
            ),
            child: Center(
              child: BiometricGlyph(
                kind: kind,
                color: palette.accent,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What went wrong, in the API's own words — styled like the website's alert.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppTheme.errorRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The website footer's line — company, rights and version — so testers can
/// report what they are on.
class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        AppStrings.get('footer_rights')
            .replaceFirst('{year}', '${DateTime.now().year}')
            .replaceFirst('{version}', kAppVersion),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: palette.inkMuted.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

/// The sign-up consent checkbox, with the two documents actually reachable.
///
/// Apple expects the terms and privacy policy a registration screen refers to
/// to be openable from that screen, so both names are links that open them in
/// a sheet inside the app; tapping anywhere else on the sentence ticks the box.
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
  /// Held on the state so they are disposed with the screen. A recognizer built
  /// inline in `build` is never released.
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = () => _open(LegalTab.terms);
    _privacyTap = TapGestureRecognizer()..onTap = () => _open(LegalTab.privacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// Accepting from the bottom of the sheet ticks the box.
  Future<void> _open(LegalTab tab) async {
    final bool accepted = await showLegalSheet(
      context,
      initialTab: tab,
      offerAccept: widget.enabled && !widget.accepted,
    );
    if (accepted && mounted) widget.onChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = widget.palette;
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;
    final TextStyle base = TextStyle(
      color: palette.ink,
      fontSize: 14,
      height: 1.2,
    );
    final TextStyle link = base.copyWith(
      color: palette.accent,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: palette.accent.withValues(alpha: 0.5),
      decorationThickness: 1.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: widget.accepted,
                onChanged: widget.enabled
                    ? (bool? value) => widget.onChanged(value ?? false)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                activeColor: palette.accent,
                checkColor: Colors.white,
                side: BorderSide(
                  color: hasError ? AppTheme.errorRed : palette.inkMuted,
                  width: 1.5,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.enabled
                    ? () => widget.onChanged(!widget.accepted)
                    : null,
                // One line, level with the box. A narrow phone shrinks the
                // sentence rather than wrapping it below the checkbox.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
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
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 6, 4, 0),
            child: Text(
              widget.error!,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}
