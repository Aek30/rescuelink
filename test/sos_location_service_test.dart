import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/services/sos_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = SosLocationService.channel;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  SosLocationService service({
    bool allowed = true,
    Duration timeout = const Duration(seconds: 1),
  }) => SosLocationService(
    requestPermission: () async => allowed,
    timeout: timeout,
  );
  test(
    'native fresh coordinates preserve accuracy and capture timestamp',
    () async {
      final now = DateTime.now().toUtc();
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'latitude': 14.0,
          'longitude': 100.0,
          'accuracy': 12.0,
          'capturedAt': now.toIso8601String(),
        },
      );
      final fix = await service().capture();
      expect(fix.latitude, 14);
      expect(fix.accuracy, 12);
      expect(fix.capturedAt, now);
    },
  );
  test(
    'timeout diagnostics distinguish no satellites from returned fixes',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(
          code: 'timeout',
          details: {
            'providers': ['gps'],
            'satellites': 7,
            'usedSatellites': 0,
            'fixesReceived': 0,
          },
        ),
      );
      await expectLater(
        service().capture(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('GPS เปิด'),
              contains('ดาวเทียม 7 ดวง'),
              contains('ใช้คำนวณ 0 ดวง'),
            ),
          ),
        ),
      );
    },
  );
  test('denied permission never starts native GPS', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      called = true;
      return null;
    });
    await expectLater(
      service(allowed: false).capture(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('สิทธิ์'),
        ),
      ),
    );
    expect(called, isFalse);
  });
  for (final code in ['timeout', 'disabled', 'permission', 'canceled']) {
    test('native $code is translated to an actionable Thai error', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: code),
      );
      await expectLater(
        service().capture(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            isNot(contains('PlatformException')),
          ),
        ),
      );
    });
  }
  test(
    'Dart timeout cancels native request and allows a later retry',
    () async {
      final pending = Completer<Object?>();
      var canceled = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'cancel') {
          canceled = true;
          pending.complete(null);
          return null;
        }
        return pending.future;
      });
      await expectLater(
        service(timeout: const Duration(milliseconds: 10)).capture(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            SosLocationService.timeoutMessage,
          ),
        ),
      );
      expect(canceled, isTrue);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'latitude': 14.0,
          'longitude': 100.0,
          'accuracy': 10.0,
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      expect((await service().capture()).longitude, 100);
    },
  );
  test('stale coordinates are not presented as a fresh GPS fix', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'latitude': 14.0,
        'longitude': 100.0,
        'accuracy': 10.0,
        'capturedAt': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      },
    );
    await expectLater(service().capture(), throwsStateError);
  });
}
