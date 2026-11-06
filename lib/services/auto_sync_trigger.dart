import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Runs on network changes and local writes, never on a polling interval.
class AutoSyncTrigger {
  AutoSyncTrigger({
    required this.sync,
    Future<List<ConnectivityResult>> Function()? check,
    Stream<List<ConnectivityResult>>? changes,
    this.debounce = const Duration(milliseconds: 400),
  }) : _check = check ?? Connectivity().checkConnectivity,
       _changes = changes ?? Connectivity().onConnectivityChanged;

  final Future<void> Function() sync;
  final Future<List<ConnectivityResult>> Function() _check;
  final Stream<List<ConnectivityResult>> _changes;
  final Duration debounce;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;
  Set<ConnectivityResult>? _network;
  bool _online = false, _disposed = false, _running = false, _requested = false;
  int _networkRevision = 0;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _changes.listen((network) {
      _networkRevision++;
      _update(network);
    }, onError: (Object error) => debugPrint('Network status: $error'));
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final revision = _networkRevision;
    try {
      final network = await _check();
      if (_disposed || revision != _networkRevision) return;
      _update(network, resumed: true);
    } catch (error) {
      // An unavailable platform monitor must not cause blind periodic retries.
      debugPrint('Network status unavailable: $error');
    }
  }

  void _update(List<ConnectivityResult> network, {bool resumed = false}) {
    if (_disposed) return;
    final current = network.toSet()..remove(ConnectivityResult.none);
    final changed = !setEquals(_network, current);
    _network = current;
    _online = current.isNotEmpty;
    if (!_online) {
      _debounce?.cancel();
      return;
    }
    if (changed || resumed) requestSync();
  }

  void requestSync() {
    if (_disposed || !_online) return;
    _requested = true;
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(_run()));
  }

  Future<void> _run() async {
    if (!_requested || _running || !_online || _disposed) return;
    _running = true;
    try {
      do {
        _requested = false;
        try {
          await sync();
        } catch (error) {
          debugPrint('Automatic sync: $error');
        }
      } while (_requested && _online && !_disposed);
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
  }
}
