import 'dart:math';

import 'package:chess_cash/Providers/CreateTournamentProvider/CreateTournamentProvider.dart';
import 'package:chess_cash/Screens/TournamentScreens/tournament_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class CreateTournament extends StatefulWidget {
  const CreateTournament({super.key});

  @override
  State<CreateTournament> createState() => _CreateTournamentState();
}

class _CreateTournamentState extends State<CreateTournament>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _roomCodeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _joinTournamentByRoomCode() async {
    if (_roomCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a room code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Please login to join tournament');
      }

      // Find tournament by room code
      final tournamentsQuery = await _firestore
          .collection('user_tournaments')
          .where('roomCode', isEqualTo: _roomCodeController.text.toUpperCase())
          .get();

      if (tournamentsQuery.docs.isEmpty) {
        throw Exception('Tournament not found with this room code');
      }

      final tournamentDoc = tournamentsQuery.docs.first;
      final tournamentData = tournamentDoc.data();
      final tournamentId = tournamentDoc.id;
      final entryFee = (tournamentData['entryFee'] ?? 0.0).toDouble();
      final players = List<String>.from(tournamentData['players'] ?? []);
      final maxPlayers = tournamentData['playerCount'] ?? 8;
      final status = tournamentData['status'] ?? 'pending';

      // Check if tournament is cancelled
      if (status == 'cancelled') {
        throw Exception('This tournament has been cancelled');
      }

      // Check if already joined
      if (players.contains(user.uid)) {
        throw Exception('You have already joined this tournament');
      }

      // Check if tournament is full
      if (players.length >= maxPlayers) {
        throw Exception('Tournament is full');
      }

      // Get user's current balance
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final double userBalance = (userDoc.data()?['Balance'] ?? 0).toDouble();

      if (userBalance < entryFee) {
        throw Exception(
            'Insufficient balance! Need ₹${entryFee.toStringAsFixed(2)} to join');
      }

      // Start a transaction to handle balance deduction and tournament joining
      await _firestore.runTransaction((transaction) async {
        // Get fresh user data
        final freshUserDoc =
            await transaction.get(_firestore.collection('users').doc(user.uid));
        final double currentBalance =
            (freshUserDoc.data()?['Balance'] ?? 0).toDouble();

        if (currentBalance < entryFee) {
          throw Exception('Insufficient balance');
        }

        // Get fresh tournament data
        final freshTournamentDoc = await transaction
            .get(_firestore.collection('user_tournaments').doc(tournamentId));
        final freshTournamentData = freshTournamentDoc.data()!;
        final freshPlayers =
            List<String>.from(freshTournamentData['players'] ?? []);
        final freshMaxPlayers = freshTournamentData['playerCount'] ?? 8;

        if (freshPlayers.contains(user.uid)) {
          throw Exception('Already joined this tournament');
        }

        if (freshPlayers.length >= freshMaxPlayers) {
          throw Exception('Tournament is full');
        }

        // Get all round-1 matches
        final roundOneMatches = await _firestore
            .collection('user_tournaments')
            .doc(tournamentId)
            .collection('matches')
            .where('round', isEqualTo: 1)
            .orderBy('matchNumber')
            .get();

        // Find the first available slot
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

        // Update user's balance and tournaments list
        transaction.update(
          _firestore.collection('users').doc(user.uid),
          {
            'Balance': currentBalance - entryFee,
            'tournaments': FieldValue.arrayUnion([tournamentId])
          },
        );

        // Add transaction record for entry fee
        final transactionRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc();

        transaction.set(transactionRef, {
          'amount': -entryFee,
          'type': 'Tournament Entry',
          'description': 'Entry fee for tournament: $tournamentId',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
          'tournamentId': tournamentId,
        });

        // Update tournament's player list
        transaction.update(
          _firestore.collection('user_tournaments').doc(tournamentId),
          {
            'players': FieldValue.arrayUnion([user.uid]),
            'currentPlayers': FieldValue.increment(1),
          },
        );

        // Update the match with the player
        transaction.update(
          targetMatchRef,
          {targetField: user.uid},
        );
      });

      // Clear the room code field
      _roomCodeController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Successfully joined tournament: ${tournamentData['name']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      print('Error joining tournament: $e');
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create/Join Contest'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create'),
            Tab(text: 'Join'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(),
          _buildJoinTab(),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return Consumer<CreateTournamentProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: provider.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tournament Name
                TextFormField(
                  controller: provider.tournamentNameController,
                  decoration: const InputDecoration(
                    labelText: 'Contest Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a Contest name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Entry Fee
                TextFormField(
                  controller: provider.entryFeeController,
                  decoration: const InputDecoration(
                    labelText: 'Entry Fee',
                    border: OutlineInputBorder(),
                    prefixText: '₹',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter entry fee';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) < 0) {
                      return 'Entry fee cannot be negative';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Prize Amount
                TextFormField(
                  controller: provider.prizeAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Prize Amount',
                    border: OutlineInputBorder(),
                    prefixText: '₹',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter prize amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) < 0) {
                      return 'Prize amount cannot be negative';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Player Count Dropdown
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: provider.selectedPlayerCount,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: [4, 6, 8, 16, 32, 64]
                          .map((number) => DropdownMenuItem(
                                value: number,
                                child: Text('$number players'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            provider.selectedPlayerCount = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Start Date
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(provider.startDate == null
                      ? 'Select start date'
                      : '${provider.startDate!.day}/${provider.startDate!.month}/${provider.startDate!.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: provider.startDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      provider.setStartDate(date);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // End Date
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(provider.endDate == null
                      ? 'Select end date'
                      : '${provider.endDate!.day}/${provider.endDate!.month}/${provider.endDate!.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: provider.endDate ??
                          (provider.startDate ?? DateTime.now()),
                      firstDate: provider.startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      provider.setEndDate(date);
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Round Times Section
                Text(
                  'Round Times (${provider.numberOfRounds} ${provider.numberOfRounds == 1 ? 'Round' : 'Rounds'})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Round time pickers
                ...List.generate(provider.numberOfRounds, (index) {
                  final round = index + 1;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text('Round $round'),
                      subtitle: Text(provider.roundTimes[round] == null
                          ? 'Select time for round $round'
                          : '${provider.roundTimes[round]!.day}/${provider.roundTimes[round]!.month}/${provider.roundTimes[round]!.year} at ${provider.roundTimes[round]!.hour.toString().padLeft(2, '0')}:${provider.roundTimes[round]!.minute.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        // Determine minimum date for this round
                        DateTime minimumDate = DateTime.now();
                        if (round == 1) {
                          minimumDate = provider.startDate ?? DateTime.now();
                        } else {
                          final previousRoundTime =
                              provider.roundTimes[round - 1];
                          if (previousRoundTime != null) {
                            minimumDate = previousRoundTime;
                          }
                        }

                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              provider.roundTimes[round] ?? minimumDate,
                          firstDate: minimumDate,
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: provider.roundTimes[round] != null
                                ? TimeOfDay.fromDateTime(
                                    provider.roundTimes[round]!)
                                : TimeOfDay.now(),
                          );
                          if (time != null) {
                            final combinedDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            provider.setRoundTime(round, combinedDateTime);
                          }
                        }
                      },
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Create Tournament Button
                ElevatedButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          if (provider.formKey.currentState!.validate()) {
                            try {
                              final tournamentRef =
                                  await provider.createTournament();
                              final roomCode = _generateRoomCode();

                              // Update tournament with room code
                              await tournamentRef
                                  .update({'roomCode': roomCode});

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Contest Created Successfully! You have been automatically joined. Room Code: $roomCode'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 3),
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: provider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Create Contest',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJoinTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Join Contest',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _roomCodeController,
            decoration: const InputDecoration(
              labelText: 'Enter Room Code',
              border: OutlineInputBorder(),
              hintText: 'e.g., ABC123',
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a room code';
              }
              if (value.length != 6) {
                return 'Room code must be 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isJoining ? null : _joinTournamentByRoomCode,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isJoining
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Join Contest',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 32),

          // Joined Tournaments Section
          const Text(
            'My Joined Contest',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Joined Tournaments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('user_tournaments')
                  .where('players', arrayContains: _auth.currentUser?.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final tournaments = snapshot.data?.docs ?? [];

                if (tournaments.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Contest joined yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Join a Contest using a room code above',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    final tournament = tournaments[index];
                    final data = tournament.data() as Map<String, dynamic>;
                    final tournamentId = tournament.id;
                    final name = data['name'] ?? 'Unknown Tournament';
                    final entryFee = (data['entryFee'] ?? 0.0).toDouble();
                    final prizeAmount = (data['prizeAmount'] ?? 0.0).toDouble();
                    final playerCount = data['playerCount'] ?? 8;
                    final currentPlayers = data['currentPlayers'] ?? 0;
                    final status = data['status'] ?? 'pending';
                    final startDate = data['startDate'] != null
                        ? (data['startDate'] as Timestamp).toDate()
                        : null;
                    final endDate = data['endDate'] != null
                        ? (data['endDate'] as Timestamp).toDate()
                        : null;
                    final roomCode = data['roomCode'] ?? 'N/A';

                    return Card(
                      color: Colors.black,
                      margin: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tournament Name
                            Row(
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  color: Colors.yellow[700],
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Color(0xFFFFD600),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Entry Fee
                            Row(
                              children: [
                                Icon(Icons.attach_money,
                                    color: Colors.green[400], size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'Entry: ₹${entryFee.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Prize Pool
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet,
                                    color: Colors.green[400], size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'Prize pool: ₹${prizeAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Players
                            Row(
                              children: [
                                Icon(Icons.group,
                                    color: Colors.yellow[700], size: 18),
                                const SizedBox(width: 4),
                                const Text(
                                  'Players: ',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                                Text(
                                  '$currentPlayers',
                                  style: TextStyle(
                                      color: Colors.yellow[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                Text(
                                  '/$playerCount joined',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Room Code
                            Row(
                              children: [
                                Icon(Icons.code,
                                    color: Colors.blue[400], size: 18),
                                const SizedBox(width: 4),
                                const Text(
                                  'Room Code: ',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                                Text(
                                  roomCode,
                                  style: TextStyle(
                                      color: Colors.blue[400],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Start Time
                            if (startDate != null)
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Starts: ${DateFormat('d MMM, h:mm a').format(startDate)}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 15),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),

                            // End Time
                            if (endDate != null)
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ends: ${DateFormat('d MMM, h:mm a').format(endDate)}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 15),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),

                            // Status
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                                const SizedBox(width: 4),
                                const Text(
                                  'Status: ',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 15),
                                ),
                                Text(
                                  status == 'ongoing'
                                      ? 'Joined'
                                      : status.toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'ongoing'
                                        ? Colors.green
                                        : status == 'completed'
                                            ? Colors.blue
                                            : status == 'cancelled'
                                                ? Colors.red
                                                : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Action Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Center(
                                  child: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.4,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TournamentDetailsScreen(
                                              tournamentId: tournament.id,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.yellow[700],
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'View Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.4,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          final tournamentData = tournament
                                              .data() as Map<String, dynamic>?;
                                          final shareText =
                                              'Check out this Contest: ${tournamentData?['name']} and room code: ${tournamentData?['roomCode']}';

                                          await Share.share(shareText);

                                          Fluttertoast.showToast(
                                            msg: 'Contest details shared!',
                                            backgroundColor: Colors.green,
                                            textColor: Colors.white,
                                          );
                                        } catch (error) {
                                          print('Share error: $error');
                                          Fluttertoast.showToast(
                                            msg:
                                                'Failed to share. Please try again.',
                                            backgroundColor: Colors.red,
                                            textColor: Colors.white,
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.yellow[700],
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Share Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          // const Card(
          //   child: Padding(
          //     padding: EdgeInsets.all(16.0),
          //     child: Column(
          //       children: [
          //         Icon(
          //           Icons.info_outline,
          //           size: 48,
          //           color: Colors.blue,
          //         ),
          //         SizedBox(height: 16),
          //         Text(
          //           'How to Join',
          //           style: TextStyle(
          //             fontSize: 18,
          //             fontWeight: FontWeight.bold,
          //           ),
          //         ),
          //         SizedBox(height: 8),
          //         Text(
          //           '1. Ask the tournament creator for the room code\n2. Enter the 6-character room code above\n3. Click "Join Tournament" to participate',
          //           textAlign: TextAlign.center,
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'upcoming':
        return Colors.blue;
      case 'ongoing':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
