import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

List<dynamic> _decodeTile(String text) => jsonDecode(text) as List<dynamic>;

class OfflineTileFeature {
  OfflineTileFeature(Map<String, dynamic> json)
    : kind = json['k'] as String,
      roadClass = json['r'] as String,
      name = json['n'] as String,
      closed = json['c'] as bool,
      anchor = json['a'] == null
          ? null
          : Offset(
              (json['a'][0] as num).toDouble(),
              (json['a'][1] as num).toDouble(),
            ) {
    path = Path()..fillType = PathFillType.evenOdd;
    for (final points in json['p'] as List) {
      if (points.length < 4) continue;
      path.moveTo((points[0] as num).toDouble(), (points[1] as num).toDouble());
      for (var i = 2; i < points.length; i += 2) {
        path.lineTo(
          (points[i] as num).toDouble(),
          (points[i + 1] as num).toDouble(),
        );
      }
      if (closed) path.close();
      vertices += (points as List).length ~/ 2;
    }
    bounds = path.getBounds().inflate(.01);
  }
  final String kind, roadClass, name;
  final bool closed;
  final Offset? anchor;
  late final Path path;
  late final Rect bounds;
  int vertices = 0;
}

class OfflineTile {
  OfflineTile(this.key, this.features, this.encodedBytes);
  final String key;
  final List<OfflineTileFeature> features;
  final int encodedBytes;
  int get vertices => features.fold(0, (n, f) => n + f.vertices);
}

/// Shared LRU across map screens, two reads/decodes at once, no network IO.
/// Pending requests are replaced when a viewport moves. Late completions are
/// discarded when no live viewport needs them.
class OfflineTileStore extends ChangeNotifier {
  OfflineTileStore({
    Future<String> Function(String)? loader,
    this.maxTiles = 24,
    this.maxBytes = 6 * 1024 * 1024,
    this.maxVertices = 180000,
  }) : _loader =
           loader ??
           ((key) => rootBundle.loadString('assets/maps/pathum/$key.json'));
  static final shared = OfflineTileStore();
  final Future<String> Function(String) _loader;
  final int maxTiles, maxBytes, maxVertices;
  final _cache = <String, OfflineTile>{};
  final _owners = <Object, List<String>>{};
  final _loading = <String>{};
  final _attempted = <String>{};
  final failures = <String>{};
  bool _disposed = false;
  int get cachedTiles => _cache.length;
  int get cachedBytes => _cache.values.fold(0, (n, t) => n + t.encodedBytes);
  int get cachedVertices => _cache.values.fold(0, (n, t) => n + t.vertices);
  int get activeLoads => _loading.length;
  Set<String> get wanted => _owners.values
      .toList()
      .reversed
      .expand((keys) => keys)
      .take(maxTiles)
      .toSet();
  OfflineTile? peek(String key) => _cache[key];
  void request(Object owner, List<String> keys) {
    if (_disposed) return;
    if (listEquals(_owners[owner], keys)) return;
    _attempted.clear();
    _owners.remove(owner);
    _owners[owner] = keys;
    for (final key in keys) {
      final value = _cache.remove(key);
      if (value != null) _cache[key] = value;
    }
    _drain();
  }

  void release(Object owner) {
    _owners.remove(owner);
  }

  void retryFailures() {
    failures.clear();
    _attempted.clear();
    _drain();
  }

  void _drain() {
    if (_disposed) return;
    for (final key in wanted) {
      if (_loading.length >= 2) break;
      if (_cache.containsKey(key) ||
          _loading.contains(key) ||
          failures.contains(key) ||
          _attempted.contains(key)) {
        continue;
      }
      _loading.add(key);
      _attempted.add(key);
      _load(key);
    }
  }

  Future<void> _load(String key) async {
    try {
      final text = await _loader(key);
      final decoded = await compute(_decodeTile, text);
      if (_disposed || !wanted.contains(key)) return;
      final tile = OfflineTile(
        key,
        decoded
            .map((f) => OfflineTileFeature(f as Map<String, dynamic>))
            .toList(),
        text.length * 2,
      );
      if (tile.encodedBytes > maxBytes || tile.vertices > maxVertices) {
        throw const FormatException('Tile exceeds the bounded map cache');
      }
      _cache[key] = tile;
      while (_cache.length > maxTiles ||
          cachedBytes > maxBytes ||
          cachedVertices > maxVertices) {
        _cache.remove(_cache.keys.first);
      }
    } catch (_) {
      if (!_disposed) failures.add(key);
    } finally {
      _loading.remove(key);
      if (!_disposed) {
        notifyListeners();
        _drain();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _owners.clear();
    _cache.clear();
    super.dispose();
  }
}
