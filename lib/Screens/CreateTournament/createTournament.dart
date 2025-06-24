import 'package:chess_cash/Screens/CreateTournament/TournamentDetails.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/CreateTournamentProvider/CreateTournamentProvider.dart';

class CreateTournament extends StatefulWidget {
  const CreateTournament({super.key});

  @override
  State<CreateTournament> createState() => _CreateTournamentState();
}

class _CreateTournamentState extends State<CreateTournament> {
  final _formKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  final _tournamentCodeController = TextEditingController();
  final Map<int, TextEditingController> _timerControllers = {};
  bool _showJoinSection = false;

  @override
  void initState() {
    super.initState();
    _initializeTimerControllers();
  }

  void _initializeTimerControllers() {
    _timerControllers.clear();
    for (int i = 1; i <= 5; i++) {
      // Initialize for max possible rounds
      _timerControllers[i] = TextEditingController(text: '10');
    }
  }

  void _updateTimerControllers(CreateTournamentProvider provider) {
    for (int i = 1; i <= provider.numberOfRounds; i++) {
      final timerValue = provider.roundTimers[i]?.toString() ?? '10';
      if (_timerControllers[i]?.text != timerValue) {
        _timerControllers[i]?.text = timerValue;
      }
    }
  }

  @override
  void dispose() {
    _tournamentCodeController.dispose();
    for (var controller in _timerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament'),
      ),
      body: Consumer<CreateTournamentProvider>(
        builder: (context, provider, child) {
          _updateTimerControllers(provider);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toggle buttons for Create/Join
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _showJoinSection = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_showJoinSection ? Theme.of(context).primaryColor : Colors.grey[300],
                          foregroundColor: !_showJoinSection ? Colors.white : Colors.black,
                        ),
                        child: const Text('Create Tournament'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _showJoinSection = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showJoinSection ? Theme.of(context).primaryColor : Colors.grey[300],
                          foregroundColor: _showJoinSection ? Colors.white : Colors.black,
                        ),
                        child: const Text('Join Tournament'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (!_showJoinSection) ...[
                  // Create Tournament Section
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Tournament Name',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: provider.setTournamentName,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a tournament name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Combined Tournament Start Date and Time
                        ListTile(
                          title: const Text('Tournament Start Date & Time'),
                          subtitle: Text(provider.startDateTime == null
                              ? 'Select date and time'
                              : '${provider.startDateTime!.day}/${provider.startDateTime!.month}/${provider.startDateTime!.year} at ${provider.startDateTime!.hour.toString().padLeft(2, '0')}:${provider.startDateTime!.minute.toString().padLeft(2, '0')}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: provider.startDateTime ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: provider.startDateTime != null ? TimeOfDay.fromDateTime(provider.startDateTime!) : TimeOfDay.now(),
                              );
                              if (time != null) {
                                final combinedDateTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                                provider.setStartDateTime(combinedDateTime);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // DropdownButton for Max Players
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: provider.maxPlayers,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              items: [2, 4, 8, 16, 32]
                                  .map((number) => DropdownMenuItem(
                                        value: number,
                                        child: Text('$number players'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  provider.setMaxPlayers(value);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dynamic Timer Fields
                        Text(
                          'Match Timers (${provider.numberOfRounds} ${provider.numberOfRounds == 1 ? 'Round' : 'Rounds'})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Timer fields for each round
                        ...List.generate(provider.numberOfRounds, (index) {
                          final round = index + 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Round $round',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Timer field
                                  Row(
                                    children: [
                                      const Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Timer:',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Minutes',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          keyboardType: TextInputType.number,
                                          controller: _timerControllers[round],
                                          onChanged: (value) {
                                            final minutes = int.tryParse(value);
                                            if (minutes != null && minutes > 0) {
                                              provider.setRoundTimer(round, minutes);
                                            }
                                          },
                                          validator: (value) {
                                            final minutes = int.tryParse(value ?? '');
                                            if (minutes == null || minutes <= 0) {
                                              return 'Enter valid minutes';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Combined Date and Time picker for round
                                  ListTile(
                                    title: const Text('Match Date & Time'),
                                    subtitle: Text(provider.roundDateTimes[round] == null
                                        ? 'Select date and time'
                                        : '${provider.roundDateTimes[round]!.day}/${provider.roundDateTimes[round]!.month}/${provider.roundDateTimes[round]!.year} at ${provider.roundDateTimes[round]!.hour.toString().padLeft(2, '0')}:${provider.roundDateTimes[round]!.minute.toString().padLeft(2, '0')}'),
                                    trailing: const Icon(Icons.calendar_today),
                                    onTap: () async {
                                      // Determine the minimum date for this round
                                      DateTime minimumDate = DateTime.now();
                                      if (round == 1) {
                                        // First round must be after tournament start
                                        minimumDate = provider.startDateTime ?? DateTime.now();
                                      } else {
                                        // Other rounds must be after previous round
                                        final previousRoundDateTime = provider.roundDateTimes[round - 1];
                                        if (previousRoundDateTime != null) {
                                          minimumDate = previousRoundDateTime;
                                        }
                                      }

                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: provider.roundDateTimes[round] ?? minimumDate,
                                        firstDate: minimumDate,
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (date != null) {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: provider.roundDateTimes[round] != null ? TimeOfDay.fromDateTime(provider.roundDateTimes[round]!) : TimeOfDay.now(),
                                        );
                                        if (time != null) {
                                          final combinedDateTime = DateTime(
                                            date.year,
                                            date.month,
                                            date.day,
                                            time.hour,
                                            time.minute,
                                          );

                                          // Validate the selected datetime
                                          bool isValid = true;
                                          String errorMessage = '';

                                          if (round == 1) {
                                            // First round must be after tournament start
                                            if (provider.startDateTime != null && combinedDateTime.isBefore(provider.startDateTime!)) {
                                              isValid = false;
                                              errorMessage = 'Round 1 must be after tournament start';
                                            }
                                          } else {
                                            // Other rounds must be after previous round
                                            final previousRoundDateTime = provider.roundDateTimes[round - 1];
                                            if (previousRoundDateTime != null && combinedDateTime.isBefore(previousRoundDateTime)) {
                                              isValid = false;
                                              errorMessage = 'Round $round must be after Round ${round - 1}';
                                            }
                                          }

                                          if (isValid) {
                                            provider.setRoundDateTime(round, combinedDateTime);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(errorMessage),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              try {
                                final docRef = await provider.createTournament();
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TournamentDetails(
                                      tournamentId: docRef.id,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Create Tournament'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Join Tournament Section
                  Form(
                    key: _joinFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _tournamentCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Tournament Code',
                            border: OutlineInputBorder(),
                            hintText: 'Enter 6-digit tournament code',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter tournament code';
                            }
                            if (value.length != 6) {
                              return 'Tournament code must be 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (_joinFormKey.currentState!.validate()) {
                              try {
                                await provider.joinTournamentByCode(_tournamentCodeController.text.toUpperCase());
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Successfully joined tournament!')),
                                );
                                _tournamentCodeController.clear();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Join Tournament'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
