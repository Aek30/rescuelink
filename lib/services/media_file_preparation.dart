import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';

/// Persist and hash in one pass without running SHA-256 on the UI isolate.
Future<({String checksum, int size})> prepareMediaFile(
  String sourcePath,
  String destinationPath,
) => Isolate.run(() => _prepare(sourcePath, destinationPath));

Future<({String checksum, int size})> _prepare(
  String sourcePath,
  String destinationPath,
) async {
  final output = File(destinationPath).openWrite();
  final result = _DigestResult();
  final hash = sha256.startChunkedConversion(result);
  var size = 0;
  try {
    // addStream provides file-write backpressure and bounds memory usage.
    await output.addStream(
      File(sourcePath).openRead().map((bytes) {
        hash.add(bytes);
        size += bytes.length;
        return bytes;
      }),
    );
    await output.close();
    hash.close();
    return (checksum: result.value.toString(), size: size);
  } catch (_) {
    try {
      await output.close();
    } catch (_) {}
    final partial = File(destinationPath);
    if (await partial.exists()) await partial.delete();
    rethrow;
  }
}

Future<String> checksumMediaFile(String path) => Isolate.run(() async {
  return (await sha256.bind(File(path).openRead()).first).toString();
});

class _DigestResult implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
