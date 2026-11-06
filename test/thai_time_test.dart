import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/utils/thai_time.dart';

void main() {
  test('screenshot UTC timestamp displays as Thailand time', () {
    expect(
      ThaiTime.format(DateTime.parse('2026-11-04 02:34:00.065466+00')),
      '04/11/2026 09:34:00',
    );
  });

  test(
    'timezone offsets describe the same instant and are not added twice',
    () {
      for (final input in [
        '2026-11-04T02:34:00Z',
        '2026-11-04T09:34:00+07:00',
        '2026-11-03T21:34:00-05:00',
      ]) {
        expect(ThaiTime.format(DateTime.parse(input)), '04/11/2026 09:34:00');
      }
    },
  );

  test('Bangkok conversion rolls into the next day and year', () {
    final original = DateTime.utc(2026, 12, 31, 20, 15);
    expect(ThaiTime.format(original), '01/01/2027 03:15:00');
    expect(original.hour, 20);
    expect(original.year, 2026);
  });
}
