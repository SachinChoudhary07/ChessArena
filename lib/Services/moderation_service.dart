import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationService {
  static const List<String> _blockedWords = [
    'kill yourself',
    'suicide',
    'nazi',
    'fuck',
    'shit',
    'bitch',
    'asshole',
  ];

  static String sanitizeChat(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    for (final word in _blockedWords) {
      if (lower.contains(word)) {
        text = text.replaceAll(RegExp(word, caseSensitive: false), '***');
      }
    }
    return text;
  }

  static bool isDisallowed(String raw) {
    final lower = raw.toLowerCase();
    return _blockedWords.any(lower.contains);
  }

  static Future<void> blockUser(String blockedUid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || blockedUid.isEmpty || blockedUid == me.uid) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(me.uid)
        .collection('blocked')
        .doc(blockedUid)
        .set({
      'blockedUid': blockedUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<bool> isBlocked(String otherUid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me.uid)
        .collection('blocked')
        .doc(otherUid)
        .get();
    return doc.exists;
  }

  static Future<void> reportUser({
    required String reportedUid,
    required String reason,
    String? messageText,
    String? roomCode,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    await FirebaseFirestore.instance.collection('reports').add({
      'reporterId': me.uid,
      'reportedUid': reportedUid,
      'reason': reason,
      'messageText': messageText,
      'roomCode': roomCode,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
