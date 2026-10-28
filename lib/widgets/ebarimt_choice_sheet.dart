import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/charging_session.dart';
import '../services/api_client.dart';
import '../services/sessions_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import 'idle_nudge.dart';

/// "Start charging?" plus which e-Barimt the driver wants: personal or a
/// company. The same step as the kiosk's start dialog. The choice goes with
/// the start request, and the backend issues the receipt for the billed
/// amount automatically when the charge ends.
///
/// Resolves to the choice, or null when the driver cancels.
class EbarimtChoiceSheet extends StatefulWidget {
  const EbarimtChoiceSheet({super.key, this.sessionsService, this.storage});

  final SessionsService? sessionsService;
  final FlutterSecureStorage? storage;

  static Future<EbarimtChoice?> show(BuildContext context) {
    return showModalBottomSheet<EbarimtChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EbarimtChoiceSheet(),
    );
  }

  @override
  State<EbarimtChoiceSheet> createState() => _EbarimtChoiceSheetState();
}

const String _savedChoiceKey = 'ebarimt_choice';

class _EbarimtChoiceSheetState extends State<EbarimtChoiceSheet> {
  SessionsService get _sessions =>
      widget.sessionsService ?? SessionsService.instance;
  FlutterSecureStorage get _storage =>
      widget.storage ?? const FlutterSecureStorage();

  EBarimtType _type = EBarimtType.b2c;
  final TextEditingController _tin = TextEditingController();
  Timer? _debounce;

  /// The latest lookup and the number it was for.
  String? _lookupFor;
  Map<String, dynamic>? _org;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _tin.addListener(_onTinChanged);
    unawaited(_restore());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tin.dispose();
    super.dispose();
  }

  /// Starts on the driver's last choice: most people pick the same one every time.
  Future<void> _restore() async {
    try {
      final String? raw = await _storage.read(key: _savedChoiceKey);
      if (raw == null || !mounted) return;
      final EbarimtChoice saved = EbarimtChoice.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      setState(() => _type = saved.type);
      if (saved.type == EBarimtType.b2b && saved.customerTin != null) {
        _tin.text = saved.customerTin!;
      }
    } catch (_) {
      // A bad or missing saved value just means starting from "personal".
    }
  }

  String get _clean => _tin.text.replaceAll(RegExp(r'\s'), '');

  void _onTinChanged() {
    _debounce?.cancel();
    final String code = _clean;
    if (_type != EBarimtType.b2b || code.length < 5) {
      if (_org != null || _checking) {
        setState(() {
          _org = null;
          _lookupFor = null;
          _checking = false;
        });
      }
      return;
    }
    if (code == _lookupFor) return;
    setState(() => _checking = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _lookup(code));
  }

  Future<void> _lookup(String code) async {
    Map<String, dynamic> result;
    try {
      result = await _sessions.checkOrg(code);
    } on ApiException catch (err) {
      result = <String, dynamic>{'valid': false, 'error': err.message};
    } catch (_) {
      result = <String, dynamic>{'valid': false};
    }
    // The driver kept typing; this answer is for an old number.
    if (!mounted || code != _clean) return;
    setState(() {
      _org = result;
      _lookupFor = code;
      _checking = false;
    });
  }

  bool get _orgValid => _org?['valid'] == true;

  bool get _canStart =>
      _type == EBarimtType.b2c ||
      (_clean.length >= 5 && !_checking && _lookupFor == _clean && _orgValid);

  Future<void> _confirm() async {
    if (!_canStart) return;
    final EbarimtChoice choice = _type == EBarimtType.b2b
        ? EbarimtChoice(
            type: EBarimtType.b2b,
            customerTin: (_org?['tin'] ?? _clean).toString(),
            customerName: _org?['name']?.toString(),
          )
        : const EbarimtChoice(type: EBarimtType.b2c);
    try {
      await _storage.write(
        key: _savedChoiceKey,
        value: jsonEncode(choice.toJson()),
      );
    } catch (_) {}
    if (mounted) Navigator.pop(context, choice);
  }

  void _setType(EBarimtType type) {
    setState(() => _type = type);
    _onTinChanged();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt_rounded, size: 30, color: palette.accent),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.get('start_confirm_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.get('ebarimt_title'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _option(
                      palette,
                      EBarimtType.b2c,
                      Icons.person_rounded,
                      AppStrings.get('ebarimt_personal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _option(
                      palette,
                      EBarimtType.b2b,
                      Icons.apartment_rounded,
                      AppStrings.get('ebarimt_org'),
                    ),
                  ),
                ],
              ),
              if (_type == EBarimtType.b2b) ...<Widget>[
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey<String>('ebarimt-tin'),
                  controller: _tin,
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('ebarimt_org_label'),
                    hintText: AppStrings.get('ebarimt_org_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _orgStatus(palette),
              ],
              const SizedBox(height: 10),
              Text(
                AppStrings.get('ebarimt_auto_note'),
                style: TextStyle(fontSize: 12, color: palette.inkMuted),
              ),
              const SizedBox(height: 20),
              // Step 4: idle here → point at «Тийм, эхлүүлье».
              IdleNudge(
                message: AppStrings.get('nudge_start_yes'),
                enabled: _canStart,
                alignment: Alignment.centerRight,
                child: Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorRed,
                          side: BorderSide(
                            color: AppTheme.errorRed.withValues(alpha: 0.5),
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          AppStrings.get('start_confirm_cancel'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        key: const ValueKey<String>('ebarimt-start'),
                        onPressed: _canStart ? _confirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.sageGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          AppStrings.get('start_confirm_yes'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orgStatus(AppPalette palette) {
    if (_checking) {
      return Text(
        AppStrings.get('ebarimt_org_checking'),
        style: TextStyle(fontSize: 12, color: palette.inkMuted),
      );
    }
    if (_org == null || _lookupFor != _clean) return const SizedBox.shrink();
    if (_orgValid) {
      final String name = (_org?['name'] ?? _org?['tin'] ?? _clean).toString();
      return Text(
        '✓ $name',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.sageGreen,
        ),
      );
    }
    final String? error = _org?['error']?.toString();
    return Text(
      (error == null || error.isEmpty)
          ? AppStrings.get('ebarimt_org_invalid')
          : error,
      style: const TextStyle(fontSize: 12, color: AppTheme.errorRed),
    );
  }

  Widget _option(
    AppPalette palette,
    EBarimtType type,
    IconData icon,
    String label,
  ) {
    final bool active = _type == type;
    return Material(
      color: active ? palette.accent.withValues(alpha: 0.12) : palette.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey<String>('ebarimt-${type.name}'),
        onTap: () => _setType(type),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? palette.accent : palette.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 20, color: active ? palette.accent : palette.inkMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? palette.ink : palette.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
