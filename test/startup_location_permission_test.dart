import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/services/sos_location_service.dart';
import 'package:rescuelink/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final status in [0, 1, 2, 4]) {
    test(
      'automatic map checks permission without requesting it: $status',
      () async {
        final calls = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'checkPermissionStatus') return status;
          if (call.method == 'requestPermissions') {
            final permissions = call.arguments as List;
            return {for (final permission in permissions) permission: 0};
          }
          throw MissingPluginException();
        });
        expect(await SosLocationService().hasPermission(), status == 1);
        expect(calls, ['checkPermissionStatus']);
      },
    );
  }

  test('startup continues when platform permissions are unavailable', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await SosLocationService().hasPermission(), isFalse);
  });

  test('map location is included once in the shared permission request', () {
    for (final sdk in [30, 31, 32, 33, 34, 35, 36]) {
      final batch = PermissionService.requestedPermissions(sdk);
      expect(
        batch.where((p) => p == Permission.locationWhenInUse),
        hasLength(1),
      );
      expect(batch.toSet().length, batch.length);
      expect(batch, containsAll(PermissionService.requiredPermissions(sdk)));
      if (sdk >= 33) {
        expect(
          PermissionService.requiredPermissions(sdk),
          isNot(contains(Permission.locationWhenInUse)),
        );
      }
    }
  });
}
