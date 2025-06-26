import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateTournamentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final TextEditingController tournamentNameController = TextEditingController();
  final TextEditingController entryFeeController = TextEditingController();
  final TextEditingController prizeAmountController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  int selectedPlayerCount = 8; // Default to 8 players
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
        throw Exception('Round $round time must be after tournament start date');
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
      final tournamentRef = await _firestore.collection('tournaments').add({
        'name': tournamentNameController.text,
        'entryFee': double.parse(entryFeeController.text),
        'prizeAmount': double.parse(prizeAmountController.text),
        'playerCount': selectedPlayerCount,
        'startDate': startDate,
        'endDate': endDate,
        'numberOfRounds': numberOfRounds,
        'roundTimes': roundTimes.map((key, value) => MapEntry(key.toString(), value.toIso8601String())),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'winnerId': ''
      });

      // Generate matches with scheduled times
      await _generateTournamentMatches(tournamentRef.id);

      _isLoading = false;
      notifyListeners();
      
      return tournamentRef;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _generateTournamentMatches(String tournamentId) async {
    var matchesPerRound = selectedPlayerCount ~/ 2;

    for (int round = 1; round <= numberOfRounds; round++) {
      final roundTime = roundTimes[round]!;

      for (int match = 1; match <= matchesPerRound; match++) {
        await _firestore.collection('tournaments').doc(tournamentId).collection('matches').add({
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
    entryFeeController.dispose();
    prizeAmountController.dispose();
    super.dispose();
  }
}
