/// Tugrik formatting, in one place so every screen groups digits the same way.
///
/// The tugrik has no minor unit, so amounts are always whole numbers. Two
/// placements of the sign are in use across the app and both are kept: the
/// wallet and its ledger put it after the figure, the older charging screens
/// put it before. What matters is that the digits are grouped either way —
/// `₮8414` is hard to read at a glance, `₮8,414` is not.
library;

import 'package:flutter/services.dart';

/// Groups an amount into thousands: `8414` becomes `8,414`.
String groupThousands(num value) {
  final bool negative = value < 0;
  final String digits = value.abs().round().toString();
  final StringBuffer grouped = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '${negative ? '-' : ''}$grouped';
}

/// Trailing sign, e.g. `15,800₮`. Used by the wallet, matching the kiosk.
String formatMnt(num amount) => '${groupThousands(amount)}₮';

/// Leading sign, e.g. `₮15,800`. Used by the charging and station screens.
String formatMntLeading(num amount) => '₮${groupThousands(amount)}';

/// Groups digits as the driver types an amount.
///
/// Only ever applied to a money field: it throws away everything that is not a
/// digit, so it must not be used on a field that takes a code or a phone
/// number. Read the value back with [digitsOf].
class MntInputFormatter extends TextInputFormatter {
  const MntInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = digitsOf(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Leading zeros are never meaningful in an amount and make the field look
    // broken once grouping kicks in.
    final String trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final String formatted = groupThousands(int.parse(trimmed));

    // Keep the caret against the same digit it was against before, rather than
    // letting inserted separators push it to the end mid-edit.
    final int digitsBeforeCaret = digitsOf(
      newValue.text.substring(
        0,
        newValue.selection.end.clamp(0, newValue.text.length),
      ),
    ).length;

    int offset = formatted.length;
    int seen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (formatted[i] != ',') seen++;
      if (seen == digitsBeforeCaret) {
        offset = i + 1;
        break;
      }
    }
    if (digitsBeforeCaret == 0) offset = 0;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Just the digits of [text], e.g. `'12,500'` becomes `'12500'`.
String digitsOf(String text) => text.replaceAll(RegExp(r'[^\d]'), '');

/// The amount a money field currently holds, or null when it is empty.
int? amountOf(String text) {
  final String digits = digitsOf(text);
  return digits.isEmpty ? null : int.tryParse(digits);
}
