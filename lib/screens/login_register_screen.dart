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

/// Sign in and sign up for a driver account.
///
/// Both modes live in one screen because they share the hero and the footer;
/// only the field stack between them changes. The submit button is deliberately
/// pinned outside the scrolling area so it stays reachable on a 320pt phone
/// with the keyboard up.
class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({
    super.key,
    required this.onLoginSuccess,
    AuthService? authService,
  }) : _authService = authService;

  final VoidCallback onLoginSuccess;

  /// Injectable so tests can drive the screen without a network.
  final AuthService? _authService;

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  AuthService get _auth => widget._authService ?? AuthService.instance;

  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _pending = false;
  String? _formError;
  Map<String, String> _fieldErrors = const <String, String>{};

  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  late final List<TextEditingController> _allFields = <TextEditingController>[
    _identifier,
    _password,
    _name,
    _email,
    _phone,
    _confirm,
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
    _slideshowController.dispose();
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
  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  static bool _looksLikePhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[\s()\-.+]'), '');
    return RegExp(r'^\d{8,15}$').hasMatch(digits);
  }

  static bool _strongPassword(String value) =>
      value.length >= 8 &&
      RegExp(r'[a-zA-Z]').hasMatch(value) &&
      RegExp(r'\d').hasMatch(value);

  /// How much of the form is filled in, 0..1 — what the charge rail shows.
  double get _completion {
    final List<bool> steps = _isLoginMode
        ? <bool>[
            _looksLikeEmail(_identifier.text) ||
                _looksLikePhone(_identifier.text),
            _password.text.isNotEmpty,
          ]
        : <bool>[
            // Phone is left out on purpose: the API takes it as optional, so it
            // is not part of what the driver still has to fill in.
            _name.text.trim().isNotEmpty,
            _looksLikeEmail(_email.text),
            _strongPassword(_password.text),
            _confirm.text.isNotEmpty && _confirm.text == _password.text,
          ];
    final int done = steps.where((bool ok) => ok).length;
    return done / steps.length;
  }

  Map<String, String> _validate() {
    final Map<String, String> errors = <String, String>{};
    if (_isLoginMode) {
      final String id = _identifier.text.trim();
      if (id.isEmpty) {
        errors['identifier'] = AppStrings.get('auth_required');
      } else if (!_looksLikeEmail(id) && !_looksLikePhone(id)) {
        errors['identifier'] = AppStrings.get('auth_bad_identifier');
      }
      if (_password.text.isEmpty) {
        errors['password'] = AppStrings.get('auth_required');
      }
      return errors;
    }

    if (_name.text.trim().isEmpty) {
      errors['name'] = AppStrings.get('auth_required');
    }
    if (!_looksLikeEmail(_email.text)) {
      errors['email'] = AppStrings.get('auth_bad_email');
    }
    // Optional, matching the kiosk's own sign-up form — but a number that was
    // typed still has to be a real one.
    if (_phone.text.trim().isNotEmpty && !_looksLikePhone(_phone.text)) {
      errors['phone'] = AppStrings.get('auth_bad_phone');
    }
    if (!_strongPassword(_password.text)) {
      errors['password'] = AppStrings.get('auth_password_hint');
    }
    if (_confirm.text != _password.text) {
      errors['confirmPassword'] = AppStrings.get('auth_password_mismatch');
    }
    return errors;
  }

  // ------------------------------------------------------------------- actions

  void _switchMode(bool toLogin) {
    if (_isLoginMode == toLogin) return;
    setState(() {
      _isLoginMode = toLogin;
      _formError = null;
      _fieldErrors = const <String, String>{};
    });
  }

  Future<void> _submit() async {
    if (_pending) return;
    FocusScope.of(context).unfocus();

    final Map<String, String> local = _validate();
    if (local.isNotEmpty) {
      setState(() {
        _fieldErrors = local;
        _formError = AppStrings.get('auth_check_fields');
      });
      return;
    }

    setState(() {
      _pending = true;
      _formError = null;
      _fieldErrors = const <String, String>{};
    });

    try {
      String? notice;
      if (_isLoginMode) {
        await _auth.signIn(
          identifier: _identifier.text,
          password: _password.text,
        );
      } else {
        final RegisterResult result = await _auth.register(
          name: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
          confirmPassword: _confirm.text,
        );
        final VerificationNotice? verification = result.verification;
        if (verification != null) {
          notice = verification.sent
              ? AppStrings.get(
                  'auth_verification_sent',
                ).replaceFirst('{dest}', verification.destination)
              : AppStrings.get('auth_verification_failed');
        }
      }

      if (!mounted) return;
      if (notice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice), duration: const Duration(seconds: 5)),
        );
      }
      widget.onLoginSuccess();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _formError = error.message;
        _fieldErrors = error.fields;
      });
    }
  }

  Future<void> _openForgotPassword() async {
    final TextEditingController controller = TextEditingController(
      text: _identifier.text,
    );
    final AppPalette palette = context.palette;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        bool sending = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            Future<void> send() async {
              if (sending) return;
              setSheetState(() => sending = true);
              String message;
              try {
                message = await _auth.requestPasswordReset(controller.text);
              } on ApiException catch (error) {
                message = error.message;
              }
              if (!sheetContext.mounted) return;
              Navigator.pop(sheetContext);
              if (!mounted) return;
              ScaffoldMessenger.of(
                this.context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.get('auth_forgot_title'),
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.get('auth_forgot_body'),
                    style: TextStyle(
                      color: palette.inkMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AuthField(
                    controller: controller,
                    label: AppStrings.get('phone_email'),
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.username],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: sending ? null : send,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        AppStrings.get('auth_forgot_send'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  // --------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

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
                // itself when the sign-up stack is taller than the phone.
                final double cardCap =
                    (constraints.maxHeight - brandRowHeight - outerPadding)
                        .clamp(0.0, constraints.maxHeight);

                return Column(
                  children: <Widget>[
                    SizedBox(
                      height: brandRowHeight,
                      child: _BrandRow(onToggleLanguage: _toggleLanguage),
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
                                    // Sign-up's taller card leaves little room.
                                    // Rather than clip the headline in half,
                                    // stand down entirely.
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

  void _toggleLanguage() {
    LanguageController.toggle();
    setState(() {});
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
            isLoginMode: _isLoginMode,
            enabled: !_pending,
            onChanged: _switchMode,
          ),
          // Sign-up asks for five things, so it shows how far along you are.
          // Sign-in is two fields — a meter there would be noise.
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
                    : _registerFields(palette),
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

  List<Widget> _loginFields(AppPalette palette) {
    return <Widget>[
      _Headline(
        title: AppStrings.get('auth_login_headline'),
        subtitle: AppStrings.get('auth_login_sub'),
      ),
      const SizedBox(height: 14),
      _AuthField(
        controller: _identifier,
        label: AppStrings.get('phone_email'),
        icon: Icons.person_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        enabled: !_pending,
        error: _fieldErrors['identifier'] ?? _fieldErrors['email'],
        autofillHints: const <String>[AutofillHints.username],
      ),
      const SizedBox(height: 10),
      _AuthField(
        controller: _password,
        label: AppStrings.get('password'),
        icon: Icons.lock_outline_rounded,
        obscure: _obscurePassword,
        enabled: !_pending,
        error: _fieldErrors['password'],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        autofillHints: const <String>[AutofillHints.password],
        trailing: _RevealButton(
          obscured: _obscurePassword,
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _pending ? null : _openForgotPassword,
          style: TextButton.styleFrom(
            foregroundColor: palette.inkMuted,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            AppStrings.get('forgot_password'),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ];
  }

  List<Widget> _registerFields(AppPalette palette) {
    return <Widget>[
      _Headline(
        title: AppStrings.get('auth_register_headline'),
        subtitle: AppStrings.get('auth_register_sub'),
      ),
      const SizedBox(height: 14),
      _AuthField(
        controller: _name,
        label: AppStrings.get('auth_name'),
        icon: Icons.badge_outlined,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        enabled: !_pending,
        error: _fieldErrors['name'],
        autofillHints: const <String>[AutofillHints.name],
      ),
      const SizedBox(height: 10),
      _AuthField(
        controller: _phone,
        label: AppStrings.get('auth_phone'),
        icon: Icons.phone_iphone_rounded,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        enabled: !_pending,
        error: _fieldErrors['phone'],
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[\d\s+()\-]')),
        ],
        autofillHints: const <String>[AutofillHints.telephoneNumber],
      ),
      const SizedBox(height: 10),
      _AuthField(
        controller: _email,
        label: AppStrings.get('auth_email'),
        icon: Icons.alternate_email_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        enabled: !_pending,
        error: _fieldErrors['email'],
        autofillHints: const <String>[AutofillHints.email],
      ),
      const SizedBox(height: 10),
      _AuthField(
        controller: _password,
        label: AppStrings.get('password'),
        icon: Icons.lock_outline_rounded,
        obscure: _obscurePassword,
        enabled: !_pending,
        error: _fieldErrors['password'],
        helper: AppStrings.get('auth_password_hint'),
        textInputAction: TextInputAction.next,
        autofillHints: const <String>[AutofillHints.newPassword],
        trailing: _RevealButton(
          obscured: _obscurePassword,
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      const SizedBox(height: 10),
      _AuthField(
        controller: _confirm,
        label: AppStrings.get('auth_confirm_password'),
        icon: Icons.lock_reset_rounded,
        obscure: _obscureConfirm,
        enabled: !_pending,
        error: _fieldErrors['confirmPassword'],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        autofillHints: const <String>[AutofillHints.newPassword],
        trailing: _RevealButton(
          obscured: _obscureConfirm,
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ),
      const SizedBox(height: 12),
      _TermsNotice(palette: palette),
    ];
  }

  Widget _buildSubmitButton(AppPalette palette) {
    final String label = _pending
        ? (_isLoginMode
              ? AppStrings.get('auth_signing_in')
              : AppStrings.get('auth_creating'))
        : (_isLoginMode ? AppStrings.get('login') : AppStrings.get('register'));

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
                label,
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
  const _BrandRow({required this.onToggleLanguage});

  final VoidCallback onToggleLanguage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.sageGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 20,
              color: Colors.white,
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
          const SizedBox(width: 12),
          _LanguageChip(onPressed: onToggleLanguage),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLanguage current = AppStrings.currentLanguage;

    return Semantics(
      button: true,
      label: current.label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 40,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Text(current.flag, style: const TextStyle(fontSize: 17)),
        ),
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
    this.obscure = false,
    this.enabled = true,
    this.error,
    this.helper,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final bool enabled;
  final String? error;
  final String? helper;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
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
          obscureText: obscure,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
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
            suffixIcon: trailing,
            suffixIconConstraints: const BoxConstraints(
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
        if (hasError || (helper != null && helper!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 0),
            child: Text(
              hasError ? error! : helper!,
              style: TextStyle(
                color: hasError ? AppTheme.errorRed : palette.inkMuted,
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

class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      tooltip: obscured
          ? AppStrings.get('auth_show_password')
          : AppStrings.get('auth_hide_password'),
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 19,
        color: context.palette.inkMuted,
      ),
    );
  }
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

/// The sign-up consent line, with the two documents actually reachable.
///
/// Apple expects the terms and privacy policy a registration screen refers to
/// to be openable from that screen; this used to be flat text naming two
/// documents with no way to read either.
class _TermsNotice extends StatefulWidget {
  const _TermsNotice({required this.palette});

  final AppPalette palette;

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
    final TextStyle base = TextStyle(
      color: palette.inkMuted,
      fontSize: 11.5,
      height: 1.45,
    );
    final TextStyle link = base.copyWith(
      color: palette.accent,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: palette.accent,
    );

    return Text.rich(
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
    );
  }
}
