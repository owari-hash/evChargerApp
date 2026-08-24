import 'package:evchargerapp/utils/money.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [text] through the formatter as if typed from empty, with the caret at
/// the end.
TextEditingValue _type(String text) {
  return const MntInputFormatter().formatEditUpdate(
    const TextEditingValue(),
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
}

/// Runs one edit through the formatter: [before] is what the field held,
/// [after] what the platform proposes, with the caret at [caret].
TextEditingValue _edit(String before, String after, int caret) {
  return const MntInputFormatter().formatEditUpdate(
    TextEditingValue(
      text: before,
      selection: TextSelection.collapsed(offset: before.length),
    ),
    TextEditingValue(
      text: after,
      selection: TextSelection.collapsed(offset: caret),
    ),
  );
}

void main() {
  group('groupThousands', () {
    test('groups from the right', () {
      expect(groupThousands(0), '0');
      expect(groupThousands(999), '999');
      expect(groupThousands(1000), '1,000');
      expect(groupThousands(8414), '8,414');
      expect(groupThousands(5000000), '5,000,000');
    });

    test('keeps a negative sign outside the digits', () {
      expect(groupThousands(-9200), '-9,200');
    });

    test('rounds to a whole tugrik', () {
      expect(groupThousands(1234.6), '1,235');
    });
  });

  group('formatAmount', () {
    test('always shows two decimals', () {
      expect(formatAmount(0), '0.00');
      expect(formatAmount(999), '999.00');
      expect(formatAmount(8414), '8,414.00');
      expect(formatAmount(5000000), '5,000,000.00');
    });

    test('keeps a fractional amount rather than rounding it away', () {
      expect(formatAmount(1234.6), '1,234.60');
      expect(formatAmount(0.5), '0.50');
    });

    test('rounds beyond two places', () {
      expect(formatAmount(1.006), '1.01');
      expect(formatAmount(1.004), '1.00');
      // Half rounds up only when the value is exactly representable. 1.005 is
      // stored as 1.00499..., so it rounds down — the same answer any
      // double-backed formatter gives, and harmless here because an amount
      // leaves the app as a whole number of tugriks.
      expect(formatAmount(0.125), '0.13');
      expect(formatAmount(1.005), '1.00');
    });

    test('keeps a negative sign outside the digits', () {
      expect(formatAmount(-9200), '-9,200.00');
      expect(formatAmount(-0.5), '-0.50');
    });

    test('groups the whole part, not the decimals', () {
      // A naive grouper run over "1234.60" would produce "1,23,4.60".
      expect(formatAmount(1234.6), '1,234.60');
      expect(formatAmount(123456.78), '123,456.78');
    });
  });

  test('both sign placements carry the decimals', () {
    expect(formatMnt(15800), '15,800.00₮');
    expect(formatMntLeading(15800), '₮15,800.00');
  });

  group('MntInputFormatter', () {
    test('groups digits as they are typed and holds the decimals', () {
      expect(_type('1').text, '1.00');
      expect(_type('100').text, '100.00');
      expect(_type('1000').text, '1,000.00');
      expect(_type('100000').text, '100,000.00');
    });

    test('ignores anything that is not a digit', () {
      expect(_type('12a3 4-5').text, '12,345.00');
    });

    test('an emptied field stays empty rather than becoming zero', () {
      expect(_type('').text, '');
    });

    test('drops leading zeros', () {
      expect(_type('007').text, '7.00');
      expect(_type('0').text, '0.00');
    });

    test('the caret never rests among the decimals', () {
      final TextEditingValue result = _type('100000');
      expect(result.text, '100,000.00');
      // Just past the last typed digit, before the decimal point.
      expect(result.selection.baseOffset, '100,000'.length);
    });

    test('editing mid-number keeps the caret on the same digit', () {
      // Caret sits after the third digit of "1234"; formatted that is "1,234",
      // where the same digit is at index 4.
      final TextEditingValue result = _edit('124', '1234', 3);
      expect(result.text, '1,234.00');
      expect(result.selection.baseOffset, 4);
    });

    test('a backspace in the decimals deletes a digit of the amount', () {
      // The platform proposes "1,234.0"; doing nothing would make the key look
      // broken, so it takes the last digit of the amount instead.
      final TextEditingValue result = _edit('1,234.00', '1,234.0', 7);
      expect(result.text, '123.00');
    });

    test('a backspace in the amount deletes only that digit', () {
      final TextEditingValue result = _edit('1,234.00', '1,23.00', 4);
      expect(result.text, '123.00');
    });

    test('deleting the last digit empties the field', () {
      expect(_edit('7.00', '.00', 0).text, '');
    });
  });

  group('amountOf', () {
    test('reads a formatted field back as whole tugriks', () {
      // The decimals are decoration: a digit sweep would read 1,250,000 here,
      // and both servers reject a top-up that is not an integer anyway.
      expect(amountOf('12,500.00'), 12500);
      expect(amountOf('5,000,000.00'), 5000000);
      expect(amountOf('0.00'), 0);
    });

    test('still reads a field that carries no decimals', () {
      expect(amountOf('12,500'), 12500);
    });

    test('an empty field has no amount', () {
      expect(amountOf(''), isNull);
      expect(amountOf('   '), isNull);
      expect(amountOf('.00'), isNull);
    });
  });

  group('wholeDigitsOf', () {
    test('stops at the decimal point', () {
      expect(wholeDigitsOf('12,500.00'), '12500');
      expect(wholeDigitsOf('12,500'), '12500');
      expect(wholeDigitsOf('.00'), '');
    });

    test('digitsOf, by contrast, counts every digit', () {
      expect(digitsOf('12,500.00'), '1250000');
    });
  });
}
