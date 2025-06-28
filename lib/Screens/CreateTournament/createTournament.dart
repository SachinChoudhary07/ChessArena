import 'package:chess_cash/Providers/CreateTournamentProvider/CreateTournamentProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

class CreateTournament extends StatefulWidget {
  const CreateTournament({super.key});

  @override
  State<CreateTournament> createState() => _CreateTournamentState();
}

class _CreateTournamentState extends State<CreateTournament> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _roomCodeController = TextEditingController();

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
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament'),
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
                    labelText: 'Tournament Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a tournament name';
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
                  subtitle: Text(provider.startDate == null ? 'Select start date' : '${provider.startDate!.day}/${provider.startDate!.month}/${provider.startDate!.year}'),
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
                  subtitle: Text(provider.endDate == null ? 'Select end date' : '${provider.endDate!.day}/${provider.endDate!.month}/${provider.endDate!.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: provider.endDate ?? (provider.startDate ?? DateTime.now()),
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
                          final previousRoundTime = provider.roundTimes[round - 1];
                          if (previousRoundTime != null) {
                            minimumDate = previousRoundTime;
                          }
                        }

                        final date = await showDatePicker(
                          context: context,
                          initialDate: provider.roundTimes[round] ?? minimumDate,
                          firstDate: minimumDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: provider.roundTimes[round] != null ? TimeOfDay.fromDateTime(provider.roundTimes[round]!) : TimeOfDay.now(),
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
                              final tournamentRef = await provider.createTournament();
                              final roomCode = _generateRoomCode();

                              // Update tournament with room code
                              await tournamentRef.update({'roomCode': roomCode});

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Tournament Created Successfully! You have been automatically joined. Room Code: $roomCode'),
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
                            'Create Tournament',
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
            'Join Tournament',
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
            onPressed: () {
              if (_roomCodeController.text.isNotEmpty) {
                // TODO: Implement join tournament logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Joining tournament with code: ${_roomCodeController.text}'),
                    backgroundColor: Colors.blue,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a room code'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Join Tournament',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'How to Join',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Ask the tournament creator for the room code\n2. Enter the 6-character room code above\n3. Click "Join Tournament" to participate',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
