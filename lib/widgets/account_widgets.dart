import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

/// A titled card. The account, wallet, sessions and security screens are all
/// built from these, so they read as one surface.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Small pill saying whether something is confirmed.
class VerifiedChip extends StatelessWidget {
  const VerifiedChip({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tone = verified ? palette.accent : AppTheme.warningOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            verified ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 13,
            color: tone,
          ),
          const SizedBox(width: 5),
          Text(
            AppStrings.get(verified ? 'acct_verified' : 'acct_not_verified'),
            style: TextStyle(
              color: tone,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label above a value, the unit these screens report facts in.
class LabelledValue extends StatelessWidget {
  const LabelledValue({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.inkMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: emphasis ? palette.accent : palette.ink,
            fontSize: emphasis ? 16 : 14,
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

/// Full-width action, used for every primary submit on these screens.
class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.panel,
          foregroundColor: palette.onPanel,
          disabledBackgroundColor: palette.panel.withValues(alpha: 0.5),
          disabledForegroundColor: palette.onPanel.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (busy) ...<Widget>[
              const SizedBox(width: 10),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.onPanel.withValues(alpha: 0.9),
                ),
              ),
            ] else if (icon != null) ...<Widget>[
              const SizedBox(width: 8),
              Icon(icon, size: 17),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline failure notice with a retry, for a whole screen that could not load.
class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return SectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.cloud_off_rounded,
            size: 30,
            color: palette.inkMuted.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppStrings.get('retry')),
            ),
          ],
        ],
      ),
    );
  }
}

/// The banner these screens show above a form when a submit is rejected.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});

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
            size: 16,
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

/// One text input, matched to the sign-in screen's fields.
class AccountField extends StatelessWidget {
  const AccountField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscure = false,
    this.enabled = true,
    this.error,
    this.helper,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscure;
  final bool enabled;
  final String? error;
  final String? helper;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool hasError = error != null && error!.isNotEmpty;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: color, width: width),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: palette.inkMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          style: TextStyle(
            color: palette.ink,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: icon == null
                ? null
                : Icon(
                    icon,
                    size: 18,
                    color: hasError ? AppTheme.errorRed : palette.inkMuted,
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 42,
            ),
            filled: true,
            fillColor: palette.bg,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(
              icon == null ? 14 : 0,
              14,
              14,
              14,
            ),
            enabledBorder: border(
              hasError ? AppTheme.errorRed : palette.border,
              hasError ? 1.4 : 1,
            ),
            focusedBorder: border(
              hasError ? AppTheme.errorRed : palette.accent,
              1.6,
            ),
            disabledBorder: border(palette.border.withValues(alpha: 0.6), 1),
            border: border(palette.border, 1),
          ),
        ),
        if (hasError || (helper != null && helper!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 5, 2, 0),
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
}

/// Shows an API failure to the driver, using the message the API supplied.
void showApiSnack(BuildContext context, Object error) {
  final String message = error is ApiException
      ? error.message
      : 'Хүсэлт амжилтгүй боллоо. Дахин оролдоно уу.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Confirmation text snack, for an action that succeeded.
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
