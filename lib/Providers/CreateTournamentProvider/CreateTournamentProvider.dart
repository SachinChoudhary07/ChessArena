import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class CreateTournamentProvider with ChangeNotifier {
  String _tournamentName = '';
  DateTime? _startDate;
  TimeOfDay? _startTime;
  int _maxPlayers = 2;
  final List<String> _invitedPlayers = [];

  // Getters
  String get tournamentName => _tournamentName;

  DateTime? get startDate => _startDate;

  TimeOfDay? get startTime => _startTime;

  int get maxPlayers => _maxPlayers;

  List<String> get invitedPlayers => _invitedPlayers;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Setters
  void setTournamentName(String name) {
    _tournamentName = name;
    notifyListeners();
  }

  void setStartDate(DateTime date) {
    _startDate = date;
    notifyListeners();
  }

  void setStartTime(TimeOfDay time) {
    _startTime = time;
    notifyListeners();
  }

  void setMaxPlayers(int players) {
    _maxPlayers = players;
    notifyListeners();
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

  Future<DocumentReference> createTournament() async {
    if (_tournamentName.isEmpty || _startDate == null || _startTime == null) {
      throw Exception('Please fill in all required fields');
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to create a tournament');
    }

    // Combine date and time
    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final inviteCode = _generateInviteCode();

    final tournament = {
      'name': _tournamentName,
      'startDateTime': startDateTime.toIso8601String(),
      'maxPlayers': _maxPlayers,
      'currentPlayers': 1, // Creator is the first player
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUser.uid,
      'players': [currentUser.uid], // Add creator as first player
      'invitedPlayers': _invitedPlayers,
      'matches': [], // Will store match data
      'winner': null,
      'inviteCode': inviteCode,
    };

    try {
      final docRef = await _firestore.collection('users_tournaments').add(tournament);

      // Reset form
      _tournamentName = '';
      _startDate = null;
      _startTime = null;
      _maxPlayers = 2;
      _invitedPlayers.clear();
      notifyListeners();

      return docRef;
    } catch (e) {
      throw Exception('Failed to create tournament: $e');
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Add method to join tournament
  Future<void> joinTournament(String tournamentId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to join a tournament');
    }

    final tournamentRef = _firestore.collection('tournaments').doc(tournamentId);

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

    final tournamentQuery = await _firestore.collection('tournaments').where('inviteCode', isEqualTo: inviteCode).limit(1).get();

    if (tournamentQuery.docs.isEmpty) {
      throw Exception('Invalid invite code');
    }

    final tournamentDoc = tournamentQuery.docs.first;
    await joinTournament(tournamentDoc.id);
  }
}
