import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/media_upload_service.dart';
import 'sos_cloud_live_test.dart' show TestVault;

void main() {
  sqfliteFfiInit();
  test(
    'live private upload, checksum, metadata, retry and denied anonymous access',
    () async {
      final config = jsonDecode(
        await File('config/supabase.local.json').readAsString(),
      );
      final fixture = jsonDecode(
        await File('config/test-account.local.json').readAsString(),
      );
      final dir = await Directory.systemTemp.createTemp('media-live-');
      final storage = AccountStorage(
        factory: databaseFactoryFfi,
        directory: dir.path,
      );
      final auth = AuthService(
        storage: storage,
        vault: TestVault(),
        backend: SupabaseAuthBackend(
          config['SUPABASE_URL'],
          config['SUPABASE_PUBLISHABLE_KEY'],
        ),
      );
      final anon = SupabaseClient(
        config['SUPABASE_URL'],
        config['SUPABASE_PUBLISHABLE_KEY'],
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final id = const Uuid().v4();
      String? owner;
      try {
        await auth.initialize();
        expect(
          await auth.authenticate(
            fixture['email'],
            fixture['password'],
            register: false,
            remember: false,
            claimGuest: false,
          ),
          true,
        );
        owner = auth.session!.userId;
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
        );
        final file = File('${dir.path}/synthetic.png');
        await file.writeAsBytes(bytes);
        final media = MediaFile(
          mediaId: id,
          messageId: const Uuid().v4(),
          senderId: 'test',
          senderName: 'Synthetic test',
          receiverId: 'test',
          fileName: 'synthetic.png',
          mimeType: 'image/png',
          fileSize: bytes.length,
          checksum: sha256.convert(bytes).toString(),
          localPath: file.path,
          createdAt: DateTime.now(),
        );
        final cloud = SupabaseMediaCloud(auth);
        final progress = <int>[];
        await cloud.upload(media, owner, progress.add);
        await cloud.verify(media, owner);
        await cloud.upload(
          media,
          owner,
          (_) {},
        ); // same object path, idempotent replacement
        await cloud.verify(media, owner);
        expect(progress.last, bytes.length);
        final client = await auth.cloudClient(owner);
        expect(
          (await client.from('media_records').select().eq('id', id)).length,
          1,
        );
        expect(await cloud.signedUrl('$owner/$id', owner), contains('token='));
        await expectLater(
          anon.storage.from(SupabaseMediaCloud.bucket).download('$owner/$id'),
          throwsA(isA<StorageException>()),
        );
        await expectLater(
          anon.storage
              .from(SupabaseMediaCloud.bucket)
              .createSignedUrl('$owner/$id', 60),
          throwsA(isA<StorageException>()),
        );
        await expectLater(
          client.storage
              .from(SupabaseMediaCloud.bucket)
              .uploadBinary(
                '${const Uuid().v4()}/$id',
                bytes,
                fileOptions: const FileOptions(contentType: 'image/png'),
              ),
          throwsA(isA<StorageException>()),
        );
      } finally {
        if (owner != null) {
          final client = await auth.cloudClient(owner);
          await client.storage.from(SupabaseMediaCloud.bucket).remove([
            '$owner/$id',
          ]);
          await client.from('media_records').delete().eq('id', id);
        }
        await anon.dispose();
        await auth.signOut();
        auth.dispose();
        await storage.close();
        await dir.delete(recursive: true);
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_MEDIA'),
  );
}
