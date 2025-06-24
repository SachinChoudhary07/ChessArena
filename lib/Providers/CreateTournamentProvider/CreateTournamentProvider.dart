import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateTournamentProvider with ChangeNotifier {
  String _tournamentName = '';
  DateTime? _startDateTime;
  int _maxPlayers = 2;
  final List<String> _invitedPlayers = [];
  final Map<int, int> _roundTimers = {}; // Round number -> timer in minutes
  final Map<int, DateTime?> _roundDateTimes =
      {}; // Round number -> match date and time

  // Getters
  String get tournamentName => _tournamentName;

  DateTime? get startDateTime => _startDateTime;

  int get maxPlayers => _maxPlayers;

  List<String> get invitedPlayers => _invitedPlayers;

  Map<int, int> get roundTimers => _roundTimers;

  Map<int, DateTime?> get roundDateTimes => _roundDateTimes;

  // Calculate number of rounds based on max players
  int get numberOfRounds {
    if (_maxPlayers <= 2) return 1;
    if (_maxPlayers <= 4) return 2;
    if (_maxPlayers <= 8) return 3;
    if (_maxPlayers <= 16) return 4;
    return 5; // For 32 players
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Setters
  void setTournamentName(String name) {
    _tournamentName = name;
    notifyListeners();
  }

  void setStartDateTime(DateTime dateTime) {
    _startDateTime = dateTime;
    notifyListeners();
  }

  void setMaxPlayers(int players) {
    _maxPlayers = players;
    // Initialize default timers for new rounds
    _initializeRoundTimers();
    notifyListeners();
  }

  void setRoundTimer(int round, int minutes) {
    _roundTimers[round] = minutes;
    notifyListeners();
  }

  void setRoundDateTime(int round, DateTime? dateTime) {
    _roundDateTimes[round] = dateTime;
    notifyListeners();
  }

  void _initializeRoundTimers() {
    _roundTimers.clear();
    _roundDateTimes.clear();
    for (int i = 1; i <= numberOfRounds; i++) {
      _roundTimers[i] = 10; // Default 10 minutes per round
      _roundDateTimes[i] = null;
    }
  }

  void addInvitedPlayer(String playerId) {
    if (!_invitedPlayers.contains(playerId)) {
      _invitedPlayers.add(playerId);
      notifyListeners();
    }
  }

  void removeInvitedPlayer(String playerId) {
    _invitedPlayers.remove(playerId);
    notifyListeners();
  }

  // Generate matches for a tournament
  List<Map<String, dynamic>> _generateMatches(
      int maxPlayers, int numberOfRounds) {
    List<Map<String, dynamic>> matches = [];

    for (int round = 1; round <= numberOfRounds; round++) {
      int matchesInRound = (maxPlayers / (1 << round)).ceil();

      for (int matchNumber = 1; matchNumber <= matchesInRound; matchNumber++) {
        matches.add({
          'round': round,
          'matchNumber': matchNumber,
          'player1': null,
          'player2': null,
          'status': 'pending',
          'winner': null,
          'winnerId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return matches;
  }

  Future<DocumentReference> createTournament() async {
    if (_tournamentName.isEmpty || _startDateTime == null) {
      throw Exception('Please fill in all required fields');
    }

    // Validate that all rounds have timers set
    for (int i = 1; i <= numberOfRounds; i++) {
      if (!_roundTimers.containsKey(i) ||
          _roundTimers[i] == null ||
          _roundTimers[i]! <= 0) {
        throw Exception('Please set timer for Round $i');
      }
    }

    // Validate that all rounds have date/time set and are in sequential order
    DateTime? previousRoundDateTime = _startDateTime;
    for (int i = 1; i <= numberOfRounds; i++) {
      if (_roundDateTimes[i] == null) {
        throw Exception('Please set date and time for Round $i');
      }

      // Validate that round date/time is after tournament start
      if (_roundDateTimes[i]!.isBefore(_startDateTime!)) {
        throw Exception(
            'Round $i date/time must be after tournament start date/time');
      }

      // Validate that round date/time is after previous round (if not first round)
      if (i > 1 && previousRoundDateTime != null) {
        if (_roundDateTimes[i]!.isBefore(previousRoundDateTime)) {
          throw Exception(
              'Round $i date/time must be after Round ${i - 1} date/time');
        }
      }

      previousRoundDateTime = _roundDateTimes[i];
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to create a tournament');
    }

    final inviteCode = _generateInviteCode();

    // Prepare round schedules
    final roundSchedules = <String, dynamic>{};
    final roundTimes = <String,
        String>{}; // For compatibility with tournament_details_screen.dart

    for (int i = 1; i <= numberOfRounds; i++) {
      roundSchedules['round_$i'] = {
        'timer': _roundTimers[i] ?? 10,
        'dateTime': _roundDateTimes[i]?.toIso8601String(),
      };
      roundTimes[i.toString()] = _roundDateTimes[i]?.toIso8601String() ?? '';
    }

    final tournament = {
      'name': _tournamentName,
      'startDateTime': _startDateTime!.toIso8601String(),
      'maxPlayers': _maxPlayers,
      'currentPlayers': 1,
      // Creator is the first player
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUser.uid,
      'players': [currentUser.uid],
      // Add creator as first player
      'invitedPlayers': _invitedPlayers,
      'matches': [],
      // Will store match data
      'winner': null,
      'inviteCode': inviteCode,
      'roundTimers': Map<String, int>.from(_roundTimers
          .map((key, value) => MapEntry(key.toString(), value ?? 10))),
      'numberOfRounds': numberOfRounds,
      'roundSchedules': roundSchedules,
      // Store detailed round schedules
      'roundTimes': roundTimes,
      // For compatibility with tournament_details_screen.dart
      'entryFee': 0,
      // Default entry fee
      'prizeAmount': 0,
      // Default prize amount
      'playerCount': _maxPlayers,
      // For compatibility with tournament_details_screen.dart
    };

    try {
      final docRef =
          await _firestore.collection('users_tournaments').add(tournament);

      // Generate and create matches
      final matches = _generateMatches(_maxPlayers, numberOfRounds);
      final matchesCollection = docRef.collection('matches');

      for (final match in matches) {
        await matchesCollection.add(match);
      }

      // Reset form
      _tournamentName = '';
      _startDateTime = null;
      _maxPlayers = 2;
      _invitedPlayers.clear();
      _roundTimers.clear();
      _roundDateTimes.clear();
      _initializeRoundTimers();
      notifyListeners();

      return docRef;
    } catch (e) {
      throw Exception('Failed to create tournament: $e');
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // Add method to join tournament
  Future<void> joinTournament(String tournamentId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to join a tournament');
    }

    final tournamentRef =
        _firestore.collection('users_tournaments').doc(tournamentId);

    try {
      await _firestore.runTransaction((transaction) async {
        final tournamentDoc = await transaction.get(tournamentRef);
        if (!tournamentDoc.exists) {
          throw Exception('Tournament not found');
        }

        final tournament = tournamentDoc.data()!;
        final players = List<String>.from(tournament['players'] ?? []);

        if (players.contains(currentUser.uid)) {
          throw Exception('Already joined this tournament');
        }

        if (players.length >= tournament['maxPlayers']) {
          throw Exception('Tournament is full');
        }

        if (tournament['status'] != 'pending') {
          throw Exception('Tournament is no longer accepting players');
        }

        players.add(currentUser.uid);
        transaction.update(tournamentRef, {
          'players': players,
          'currentPlayers': players.length,
        });
      });
    } catch (e) {
      throw Exception('Failed to join tournament: $e');
    }
  }

  Future<void> joinTournamentByCode(String inviteCode) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to join a tournament');
    }

    final tournamentQuery = await _firestore
        .collection('users_tournaments')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (tournamentQuery.docs.isEmpty) {
      throw Exception('Invalid invite code');
    }

    final tournamentDoc = tournamentQuery.docs.first;
    await joinTournament(tournamentDoc.id);
  }

  // Method to generate matches for existing tournaments
  Future<void> generateMatchesForTournament(String tournamentId) async {
    try {
      final tournamentDoc = await _firestore
          .collection('users_tournaments')
          .doc(tournamentId)
          .get();
      if (!tournamentDoc.exists) {
        throw Exception('Tournament not found');
      }

      final tournament = tournamentDoc.data()!;
      final maxPlayers = tournament['maxPlayers'] as int? ?? 8;
      final numberOfRounds = tournament['numberOfRounds'] as int? ?? 1;

      // Check if matches already exist
      final existingMatches = await _firestore
          .collection('users_tournaments')
          .doc(tournamentId)
          .collection('matches')
          .get();
      if (existingMatches.docs.isNotEmpty) {
        print('Matches already exist for tournament $tournamentId');
        return;
      }

      // Generate and create matches
      final matches = _generateMatches(maxPlayers, numberOfRounds);
      final matchesCollection = _firestore
          .collection('users_tournaments')
          .doc(tournamentId)
          .collection('matches');

      for (final match in matches) {
        await matchesCollection.add(match);
      }

      print('Generated ${matches.length} matches for tournament $tournamentId');
    } catch (e) {
      throw Exception('Failed to generate matches: $e');
    }
  }
}
