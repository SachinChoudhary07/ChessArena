import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateTournamentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  final TextEditingController tournamentNameController =
      TextEditingController();
  final formKey = GlobalKey<FormState>();

  int selectedPlayerCount = 4; // Default to 4 players
  DateTime? startDate;
  DateTime? endDate;

  // Map to store round times (key: round number, value: DateTime)
  final Map<int, DateTime> roundTimes = {};

  int get numberOfRounds => _calculateRounds(selectedPlayerCount);

  void setRoundTime(int round, DateTime time) {
    roundTimes[round] = time;
    notifyListeners();
  }

  Future<DocumentReference> createTournament() async {
    if (!formKey.currentState!.validate()) {
      throw Exception('Please fill in all required fields');
    }

    // Validate dates
    if (startDate == null) {
      throw Exception('Please select a start date');
    }
    if (endDate == null) {
      throw Exception('Please select an end date');
    }
    if (endDate!.isBefore(startDate!)) {
      throw Exception('End date must be after start date');
    }

    // Validate round times
    if (roundTimes.length != numberOfRounds) {
      throw Exception('Please set time for all rounds');
    }

    // Validate round times are in sequence
    for (int round = 1; round <= numberOfRounds; round++) {
      if (!roundTimes.containsKey(round)) {
        throw Exception('Please set time for round $round');
      }

      // Check if round time is after start date and before end date
      if (roundTimes[round]!.isBefore(startDate!)) {
        throw Exception(
            'Round $round time must be after tournament start date');
      }
      if (roundTimes[round]!.isAfter(endDate!)) {
        throw Exception('Round $round time must be before tournament end date');
      }

      // Check if rounds are in chronological order
      if (round > 1 && roundTimes[round]!.isBefore(roundTimes[round - 1]!)) {
        throw Exception('Round $round time must be after round ${round - 1}');
      }
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Create tournament document
      final tournamentRef =
          await _firestore.collection('user_tournaments').add({
        'name': tournamentNameController.text,
        'playerCount': selectedPlayerCount,
        'startDate': Timestamp.fromDate(startDate!),
        'endDate': Timestamp.fromDate(endDate!),
        'numberOfRounds': numberOfRounds,
        'roundTimes': roundTimes.map(
            (key, value) => MapEntry(key.toString(), value.toIso8601String())),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'winnerId': '',
        'players': [], // Initialize empty players array
        'currentPlayers': 0, // Initialize current players count
        'creatorId': _auth.currentUser?.uid, // Add creator ID
      });

      // Generate matches with scheduled times
      await _generateTournamentMatches(tournamentRef.id);

      // Automatically join the tournament creator
      await joinTournament(tournamentRef.id);

      _isLoading = false;
      notifyListeners();

      return tournamentRef;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> joinTournament(String tournamentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Please login to join tournament');
      }

      await _firestore.runTransaction((transaction) async {
        await transaction.get(_firestore.collection('users').doc(user.uid));

        // 2. Get tournament data
        final tournamentDoc = await transaction
            .get(_firestore.collection('user_tournaments').doc(tournamentId));
        final tournamentData = tournamentDoc.data()!;
        final players = List<String>.from(tournamentData['players'] ?? []);
        final maxPlayers = tournamentData['playerCount'] ?? 8;

        // Check if tournament is cancelled
        if (tournamentData['status'] == 'cancelled') {
          throw Exception('This tournament has been cancelled');
        }
        if (tournamentData['status'] == 'completed' ||
            tournamentData['winner'] != null) {
          throw Exception('This tournament is already completed');
        }
        final endDate = tournamentData['endDate'] as Timestamp?;
        if (endDate != null && DateTime.now().isAfter(endDate.toDate())) {
          throw Exception('This tournament is already completed');
        }

        if (players.contains(user.uid)) {
          throw Exception('Already joined this tournament');
        }

        if (players.length >= maxPlayers) {
          throw Exception('Tournament is full');
        }

        // 3. Get all round-1 matches
        final roundOneMatches = await _firestore
            .collection('user_tournaments')
            .doc(tournamentId)
            .collection('matches')
            .where('round', isEqualTo: 1)
            .orderBy('matchNumber')
            .get();

        // 4. Find the first available slot by reading each match
        DocumentReference? targetMatchRef;
        String? targetField;

        for (final match in roundOneMatches.docs) {
          final matchRef = match.reference;
          final freshSnap = await transaction.get(matchRef);
          final freshData = freshSnap.data();

          if (freshData == null) continue;

          if (freshData['player1'] == null) {
            targetMatchRef = matchRef;
            targetField = 'player1';
            break;
          }

          if (freshData['player2'] == null) {
            targetMatchRef = matchRef;
            targetField = 'player2';
            break;
          }
        }

        if (targetMatchRef == null || targetField == null) {
          throw Exception('Tournament is full');
        }

        // ---------- WRITES SECTION ----------
        // 1. Update user's tournaments list
        transaction.update(
          _firestore.collection('users').doc(user.uid),
          {
            'tournaments': FieldValue.arrayUnion([tournamentId])
          },
        );

        // 2. Update tournament's player list
        transaction.update(
          _firestore.collection('user_tournaments').doc(tournamentId),
          {
            'players': FieldValue.arrayUnion([user.uid]),
            'currentPlayers': FieldValue.increment(1),
          },
        );

        // 3. Update the match with the player
        transaction.update(
          targetMatchRef,
          {targetField: user.uid},
        );
      });

      print('Successfully joined tournament: $tournamentId');
      //want to clear the form and time
      tournamentNameController.clear();
      startDate = null;
      endDate = null;
      roundTimes.clear();
      notifyListeners();
    } catch (e) {
      print('Error joining tournament: $e');
      rethrow;
    }
  }

  Future<void> _generateTournamentMatches(String tournamentId) async {
    var matchesPerRound = selectedPlayerCount ~/ 2;

    for (int round = 1; round <= numberOfRounds; round++) {
      final roundTime = roundTimes[round]!;

      for (int match = 1; match <= matchesPerRound; match++) {
        await _firestore
            .collection('user_tournaments')
            .doc(tournamentId)
            .collection('matches')
            .add({
          'round': round,
          'matchNumber': match,
          'status': 'pending',
          'player1': null,
          'player2': null,
          'winner': null,
          'scheduledTime': roundTime.toIso8601String(),
        });
      }
      matchesPerRound ~/= 2;
    }
  }

  int _calculateRounds(int playerCount) {
    return (playerCount / 2).ceil().toInt();
  }

  void setStartDate(DateTime date) {
    startDate = date;
    notifyListeners();
  }

  void setEndDate(DateTime date) {
    endDate = date;
    notifyListeners();
  }

  @override
  void dispose() {
    tournamentNameController.dispose();
    super.dispose();
  }
}
