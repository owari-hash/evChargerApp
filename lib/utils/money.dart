/// Tugrik formatting, in one place so every screen renders an amount the same
/// way.
///
/// Every ₮ figure carries two decimal places — `15,800.00₮` — and digits are
/// grouped into thousands, because `₮8414` is hard to read at a glance and
/// `₮8,414.00` is not. Two placements of the sign are in use across the app and
/// both are kept: the wallet and its ledger put it after the figure, the older
/// charging screens put it before.
///
/// The decimals are presentation only. The tugrik has no minor unit in
/// circulation and both servers validate a top-up with `z.number().int()`, so
/// an amount always leaves the app as a whole number — see [amountOf].
library;

import 'package:flutter/services.dart';

/// How many decimal places every ₮ figure shows.
const int _decimals = 2;

/// The decoration appended to a money field while the driver types, e.g. the
/// `.00` in `12,500.00`. Never part of the value that is submitted.
const String _fraction = '.00';

/// Groups a digit string into thousands: `'8414'` becomes `'8,414'`.
String _group(String digits) {
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return grouped.toString();
}

/// Groups an amount into whole thousands: `8414` becomes `8,414`.
///
/// Rounds to the nearest tugrik. Use [formatAmount] for anything shown to a
/// driver; this is the primitive the money field builds its integer part from.
String groupThousands(num value) {
  final bool negative = value < 0;
  return '${negative ? '-' : ''}${_group(value.abs().round().toString())}';
}

/// An amount with grouped thousands and two decimals: `8414` becomes
/// `8,414.00`, `1234.6` becomes `1,234.60`.
String formatAmount(num value) {
  final bool negative = value < 0;
  final String fixed = value.abs().toDouble().toStringAsFixed(_decimals);
  final int dot = fixed.indexOf('.');
  final String whole = _group(fixed.substring(0, dot));
  return '${negative ? '-' : ''}$whole${fixed.substring(dot)}';
}

/// Trailing sign, e.g. `15,800.00₮`. Used by the wallet, matching the kiosk.
String formatMnt(num amount) => '${formatAmount(amount)}₮';

/// Leading sign, e.g. `₮15,800.00`. Used by the charging and station screens.
String formatMntLeading(num amount) => '₮${formatAmount(amount)}';

/// Groups digits as the driver types an amount, holding a `.00` on the end.
///
/// Only ever applied to a money field: it throws away everything that is not a
/// digit, so it must not be used on a field that takes a code or a phone
/// number. Read the value back with [amountOf], never with [digitsOf] — the
/// two decoration zeros are not part of the amount.
class MntInputFormatter extends TextInputFormatter {
  const MntInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = wholeDigitsOf(newValue.text);

    // A backspace that landed in the `.00` leaves the whole part untouched,
    // which would make the key look broken. Read it as deleting the last digit
    // of the amount, which is what the driver was reaching for.
    final bool shrank = newValue.text.length < oldValue.text.length;
    if (shrank &&
        oldValue.text.endsWith(_fraction) &&
        !newValue.text.endsWith(_fraction) &&
        digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    if (digits.isEmpty) return const TextEditingValue(text: '');

    // Leading zeros are never meaningful in an amount and make the field look
    // broken once grouping kicks in.
    final String trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final String whole = _group(trimmed);
    final String text = '$whole$_fraction';

    // Keep the caret against the same digit it was against before, rather than
    // letting inserted separators push it to the end mid-edit. It is never
    // allowed past the decimal point: the decimals are decoration, and a caret
    // sitting among them would make typing do nothing.
    final int digitsBeforeCaret = wholeDigitsOf(
      newValue.text.substring(
        0,
        newValue.selection.end.clamp(0, newValue.text.length),
      ),
    ).length;

    int offset = whole.length;
    if (digitsBeforeCaret == 0) {
      offset = 0;
    } else {
      int seen = 0;
      for (int i = 0; i < whole.length; i++) {
        if (whole[i] != ',') seen++;
        if (seen == digitsBeforeCaret) {
          offset = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Just the digits of [text], e.g. `'12,500'` becomes `'12500'`.
///
/// Counts every digit, decimals included, so `'12,500.00'` becomes `'1250000'`.
/// That is almost never what a caller of a money field wants — see
/// [wholeDigitsOf] and [amountOf].
String digitsOf(String text) => text.replaceAll(RegExp(r'[^\d]'), '');

/// The digits of the whole-tugrik part of [text]: `'12,500.00'` becomes
/// `'12500'`.
///
/// Everything from the first decimal point on is decoration the driver does not
/// edit, so it must not be read back as two more zeros.
String wholeDigitsOf(String text) {
  final int dot = text.indexOf('.');
  return digitsOf(dot < 0 ? text : text.substring(0, dot));
}

/// The amount a money field currently holds, or null when it is empty.
///
/// Always a whole number of tugriks: the `.00` a field displays is presentation
/// only, and both the kiosk and the CSMS reject a top-up that is not an
/// integer.
int? amountOf(String text) {
  final String digits = wholeDigitsOf(text);
  return digits.isEmpty ? null : int.tryParse(digits);
}
