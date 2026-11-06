import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/services/sos_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = SosLocationService.channel;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  SosLocationService service() =>
      SosLocationService(requestPermission: () async => true);

  test('empty native response is rejected as an invalid location', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);

    await expectLater(
      service().capture(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('พิกัดที่ได้รับไม่สมบูรณ์หรือเก่าเกินไป'),
        ),
      ),
    );
  });

  test('future coordinates are rejected as an invalid fresh fix', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {
      'latitude': 14.0,
      'longitude': 100.0,
      'accuracy': 10.0,
      'capturedAt': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });

    await expectLater(service().capture(), throwsStateError);
  });

  test('busy native request tells the user to wait before retrying', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'busy'),
    );

    await expectLater(
      service().capture(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'กำลังอ่านตำแหน่ง กรุณารอสักครู่',
        ),
      ),
    );
  });
}
