import 'dart:async';
import 'package:flutter/widgets.dart';
import 'auth_service.dart';
import 'local_database_service.dart';
import 'member_service.dart';

/// Member-name drafts have their own retry lifecycle, independent of SOS/chat.
class MemberProfileSync extends ChangeNotifier with WidgetsBindingObserver {
  MemberProfileSync({
    this.auth,
    this.retryInterval = const Duration(seconds: 15),
  });
  static final instance = MemberProfileSync();
  final AuthService? auth;
  AuthService get _activeAuth => auth ?? AuthService.instance;
  final Duration retryInterval;
  Timer? _timer;
  String? _owner;
  LocalDatabaseService? _database;
  MemberProfile? profile;
  SupabaseMemberRepository? _repository;
  bool busy = false;
  int _generation = 0;

  void start() {
    if (_timer != null) return;
    _activeAuth.addListener(_scopeChanged);
    WidgetsBinding.instance.addObserver(this);
    _scopeChanged();
    _timer = Timer.periodic(retryInterval, (_) => retry());
  }

  void _scopeChanged() {
    final database = LocalDatabaseService.instance;
    if (_owner == _activeAuth.session?.userId && identical(_database, database)) {
      return;
    }
    _generation++;
    _owner = _activeAuth.session?.userId;
    _database = database;
    profile = null;
    busy = false;
    _repository = _owner == null ? null : SupabaseMemberRepository(_activeAuth);
    notifyListeners();
    unawaited(retry());
  }

  Future<void> retry() async {
    if (busy || _repository == null) return;
    final generation = _generation;
    final repository = _repository!;
    busy = true;
    try {
      final local = await repository.readLocal();
      if (generation != _generation) return;
      if (!local.pending) {
        profile = null;
        return;
      }
      profile = local;
      notifyListeners();
      final result = await repository.syncPending();
      if (generation != _generation) return;
      profile = result;
    } catch (_) {
      // Account transitions never publish the previous account's result.
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(retry());
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _activeAuth.removeListener(_scopeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
