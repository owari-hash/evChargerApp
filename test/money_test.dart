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

    test('rounds, since the tugrik has no minor unit', () {
      expect(groupThousands(1234.6), '1,235');
    });
  });

  test('both sign placements group the same digits', () {
    expect(formatMnt(15800), '15,800₮');
    expect(formatMntLeading(15800), '₮15,800');
  });

  group('MntInputFormatter', () {
    test('groups digits as they are typed', () {
      expect(_type('1').text, '1');
      expect(_type('100').text, '100');
      expect(_type('1000').text, '1,000');
      expect(_type('100000').text, '100,000');
    });

    test('ignores anything that is not a digit', () {
      expect(_type('12a3 4-5').text, '12,345');
    });

    test('an emptied field stays empty rather than becoming zero', () {
      expect(_type('').text, '');
    });

    test('drops leading zeros', () {
      expect(_type('007').text, '7');
      expect(_type('0').text, '0');
    });

    test('leaves the caret against the digit it was typed after', () {
      final TextEditingValue result = _type('100000');
      expect(result.text, '100,000');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('editing mid-number keeps the caret on the same digit', () {
      // Caret sits after the third digit of "1234"; formatted that is "1,234",
      // where the same digit is at index 4.
      final TextEditingValue result = const MntInputFormatter()
          .formatEditUpdate(
            const TextEditingValue(text: '124'),
            const TextEditingValue(
              text: '1234',
              selection: TextSelection.collapsed(offset: 3),
            ),
          );

      expect(result.text, '1,234');
      expect(result.selection.baseOffset, 4);
    });
  });

  group('amountOf', () {
    test('reads a grouped field back as a number', () {
      expect(amountOf('12,500'), 12500);
      expect(amountOf('5,000,000'), 5000000);
    });

    test('an empty field has no amount', () {
      expect(amountOf(''), isNull);
      expect(amountOf('   '), isNull);
    });
  });
}
