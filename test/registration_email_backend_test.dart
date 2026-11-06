import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'signup_backend_test.dart' show MemoryPkceStorage;

void main() {
  for (final registered in [true, false, null]) {
    test(
      'email lookup is read-only and handles deployment readiness: $registered',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final backend = SupabaseAuthBackend(
          'http://127.0.0.1:${server.port}',
          'local-key',
          pkceStorage: MemoryPkceStorage(),
        );
        final handled = server.first.then((request) async {
          expect(request.uri.path, '/rest/v1/rpc/registration_email_exists');
          expect(jsonDecode(await utf8.decoder.bind(request).join()), {
            'p_email': 'member@example.com',
          });
          request.response.headers.contentType = ContentType.json;
          if (registered == null) {
            request.response.statusCode = 404;
            request.response.write(
              jsonEncode({
                'code': 'PGRST202',
                'message': 'Function not installed',
              }),
            );
          } else {
            request.response.write(jsonEncode(registered));
          }
          await request.response.close();
        });
        expect(
          await backend.emailRegistered(' Member@Example.com '),
          registered,
        );
        await handled;
      },
    );
  }
}
