import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Handles realtime presence using Firebase Realtime Database.
///
/// Schema:
///   /status/{uid} {
///     state: 'online' | 'offline',
///     last_changed: ServerValue.timestamp
///   }
class PresenceService {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  StreamSubscription<DatabaseEvent>? _connSub;
  DatabaseReference? _statusRef;

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    final user = _auth.currentUser;
    if (user == null) return;

    _started = true;

    _statusRef = _rtdb.ref('status/${user.uid}');
    final connectedRef = _rtdb.ref('.info/connected');

    _connSub = connectedRef.onValue.listen((DatabaseEvent event) async {
      final connected = event.snapshot.value == true;
      if (!connected) {
        // Not connected; rely on onDisconnect to set offline when possible
        return;
      }

      // When connected, set up onDisconnect offline payload
      await _statusRef!.onDisconnect().set({
        'state': 'offline',
        'last_changed': ServerValue.timestamp,
      });

      // Immediately mark online
      await _statusRef!.set({
        'state': 'online',
        'last_changed': ServerValue.timestamp,
      });
    });
  }

  Future<void> stop() async {
    _started = false;
    await _connSub?.cancel();
    _connSub = null;

    final user = _auth.currentUser;
    if (user == null) return;
    _statusRef ??= _rtdb.ref('status/${user.uid}');
    try {
      await _statusRef!.set({
        'state': 'offline',
        'last_changed': ServerValue.timestamp,
      });
    } catch (_) {}
  }
}
