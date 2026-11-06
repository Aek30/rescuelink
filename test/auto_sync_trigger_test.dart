import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/services/auto_sync_trigger.dart';

void main() {
  testWidgets(
    'offline skips cloud; reconnect, local edits and resume trigger once without polling',
    (tester) async {
      final changes = StreamController<List<ConnectivityResult>>.broadcast(
        sync: true,
      );
      var network = [ConnectivityResult.none];
      var calls = 0;
      final trigger = AutoSyncTrigger(
        sync: () async {
          calls++;
        },
        check: () async => network,
        changes: changes.stream,
      );
      trigger.start();
      await tester.pump();
      trigger.requestSync();
      await tester.pump(const Duration(seconds: 45));
      expect(calls, 0);
      network = [ConnectivityResult.wifi];
      changes.add(network);
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 1);
      changes.add(network);
      await tester.pump(const Duration(seconds: 45));
      expect(calls, 1);
      trigger.requestSync();
      trigger.requestSync();
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 2);
      changes.add([ConnectivityResult.none]);
      trigger.requestSync();
      await tester.pump(const Duration(seconds: 15));
      expect(calls, 2);
      changes.add(network);
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 3);
      await trigger.refresh();
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 4);
      trigger.dispose();
      await changes.close();
    },
  );

  testWidgets('events during sync are coalesced without overlapping runs', (
    tester,
  ) async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast(
      sync: true,
    );
    final first = Completer<void>();
    var calls = 0;
    final trigger = AutoSyncTrigger(
      sync: () async {
        calls++;
        if (calls == 1) await first.future;
      },
      check: () async => [ConnectivityResult.mobile],
      changes: changes.stream,
    );
    trigger.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);
    trigger.requestSync();
    trigger.requestSync();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);
    first.complete();
    await tester.pump();
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
    trigger.dispose();
    await changes.close();
  });

  testWidgets('newer network event wins over a delayed initial check', (
    tester,
  ) async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast(
      sync: true,
    );
    final check = Completer<List<ConnectivityResult>>();
    var calls = 0;
    final trigger = AutoSyncTrigger(
      sync: () async {
        calls++;
      },
      check: () => check.future,
      changes: changes.stream,
    );
    trigger.start();
    changes.add([ConnectivityResult.none]);
    check.complete([ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);
    trigger.dispose();
    await changes.close();
  });
}
