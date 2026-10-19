import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/services/offline_tile_store.dart';

String tile(int vertices) => jsonEncode([
  {
    'k': 'road',
    'r': 'primary',
    'n': 'ถนนทดสอบ',
    'a': [100, 100],
    'c': false,
    'p': [
      [
        for (var i = 0; i < vertices; i++) ...[i * 2, i * 3],
      ],
    ],
  },
]);

Future<void> idle(OfflineTileStore store) async {
  for (var i = 0; i < 500 && store.activeLoads > 0; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(store.activeLoads, 0);
}

void main() {
  test(
    'LRU has a hard tile/vertex budget and no reload loop under pressure',
    () async {
      var calls = 0;
      final store = OfflineTileStore(
        loader: (key) async {
          calls++;
          return tile(20);
        },
        maxTiles: 3,
        maxVertices: 45,
      );
      addTearDown(store.dispose);
      final owner = Object();
      store.request(owner, ['a', 'b', 'c']);
      await idle(store);
      expect(store.cachedTiles, lessThanOrEqualTo(2));
      expect(store.cachedVertices, lessThanOrEqualTo(45));
      expect(calls, 3);
      store.request(owner, ['d']);
      await idle(store);
      expect(store.peek('d'), isNotNull);
      expect(store.cachedVertices, lessThanOrEqualTo(45));
    },
  );
  test('two parallel reads; stale viewport results are discarded', () async {
    final pending = <String, Completer<String>>{};
    final store = OfflineTileStore(
      loader: (key) {
        final c = Completer<String>();
        pending[key] = c;
        return c.future;
      },
    );
    addTearDown(store.dispose);
    final owner = Object();
    store.request(owner, ['a', 'b', 'c']);
    expect(pending.keys, unorderedEquals(['a', 'b']));
    store.request(owner, ['d']);
    pending['a']!.complete(tile(2));
    pending['b']!.complete(tile(2));
    for (var i = 0; i < 200 && !pending.containsKey('d'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(pending.containsKey('c'), isFalse);
    pending['d']!.complete(tile(2));
    await idle(store);
    expect(store.peek('a'), isNull);
    expect(store.peek('b'), isNull);
    expect(store.peek('d'), isNotNull);
  });
  test(
    'a corrupt tile can retry; releasing a screen stops queued reads',
    () async {
      var broken = true;
      final store = OfflineTileStore(
        loader: (key) async => broken ? 'invalid' : tile(3),
      );
      addTearDown(store.dispose);
      final owner = Object();
      store.request(owner, ['a']);
      await idle(store);
      expect(store.failures, contains('a'));
      broken = false;
      store.retryFailures();
      await idle(store);
      expect(store.failures, isEmpty);
      expect(store.peek('a'), isNotNull);
      store.release(owner);
      expect(store.wanted, isEmpty);
    },
  );
}
