import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shared join logic for public `tournaments` (and private `user_tournaments`).
class TournamentJoinService {
  TournamentJoinService._();

  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String collectionName({required bool isPublic}) =>
      isPublic ? 'tournaments' : 'user_tournaments';

  static String statusOf(Map<String, dynamic> data) {
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final players = List<String>.from(data['players'] ?? []);
    final maxPlayers = data['playerCount'] ?? 8;

    if (data['status'] == 'cancelled') return 'Cancelled';
    if (players.length >= maxPlayers) return 'Full';
    if (data['winner'] != null || (endDate != null && now.isAfter(endDate))) {
      return 'Completed';
    }
    if (startDate != null && startDate.isBefore(now)) return 'Ongoing';
    return 'Upcoming';
  }

  static bool canJoin(Map<String, dynamic> data, {String? uid}) {
    final userId = uid ?? _auth.currentUser?.uid;
    if (userId == null) return false;

    final players = List<String>.from(data['players'] ?? []);
    final maxPlayers = data['playerCount'] ?? 8;
    final status = statusOf(data);
    final roundTimes = data['roundTimes'] as Map<dynamic, dynamic>?;
    final round1Raw = roundTimes?['1'] ?? roundTimes?[1];
    var isRound1Started = false;
    if (round1Raw != null) {
      try {
        isRound1Started =
            DateTime.parse(round1Raw.toString()).isBefore(DateTime.now());
      } catch (_) {}
    }

    return status == 'Upcoming' &&
        !players.contains(userId) &&
        players.length < maxPlayers &&
        !isRound1Started;
  }

  static bool hasJoined(Map<String, dynamic> data, {String? uid}) {
    final userId = uid ?? _auth.currentUser?.uid;
    if (userId == null) return false;
    final players = List<String>.from(data['players'] ?? []);
    return players.contains(userId);
  }

  /// Joins the current user into a tournament bracket (round-1 open slot).
  static Future<void> join({
    required String tournamentId,
    bool isPublic = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please login to join tournament');
    }

    final col = collectionName(isPublic: isPublic);

    await _firestore.runTransaction((transaction) async {
      final tournamentDoc =
          await transaction.get(_firestore.collection(col).doc(tournamentId));
      if (!tournamentDoc.exists || tournamentDoc.data() == null) {
        throw Exception('Tournament not found');
      }

      final tournamentData = tournamentDoc.data()!;
      final players = List<String>.from(tournamentData['players'] ?? []);
      final maxPlayers = tournamentData['playerCount'] ?? 8;

      if (tournamentData['status'] == 'cancelled') {
        throw Exception('This tournament has been cancelled');
      }

      final liveStatus = statusOf(tournamentData);
      if (liveStatus == 'Completed') {
        throw Exception('This tournament is already completed');
      }
      if (liveStatus == 'Ongoing') {
        throw Exception('This tournament has already started');
      }
      if (liveStatus == 'Full') {
        throw Exception('Tournament is full');
      }
      if (players.contains(user.uid)) {
        throw Exception('Already joined this tournament');
      }
      if (players.length >= maxPlayers) {
        throw Exception('Tournament is full');
      }

      final roundOneMatches = await _firestore
          .collection(col)
          .doc(tournamentId)
          .collection('matches')
          .where('round', isEqualTo: 1)
          .orderBy('matchNumber')
          .get();

      DocumentReference? targetMatchRef;
      String? targetField;

      for (final match in roundOneMatches.docs) {
        final freshSnap = await transaction.get(match.reference);
        final freshData = freshSnap.data();
        if (freshData == null) continue;

        if (freshData['player1'] == null) {
          targetMatchRef = match.reference;
          targetField = 'player1';
          break;
        }
        if (freshData['player2'] == null) {
          targetMatchRef = match.reference;
          targetField = 'player2';
          break;
        }
      }

      if (targetMatchRef == null || targetField == null) {
        throw Exception('Tournament is full');
      }

      transaction.update(
        _firestore.collection('users').doc(user.uid),
        {
          'tournaments': FieldValue.arrayUnion([tournamentId]),
        },
      );
      transaction.update(
        _firestore.collection(col).doc(tournamentId),
        {
          'players': FieldValue.arrayUnion([user.uid]),
          'currentPlayers': FieldValue.increment(1),
        },
      );
      transaction.update(targetMatchRef, {targetField: user.uid});
    });
  }
}
