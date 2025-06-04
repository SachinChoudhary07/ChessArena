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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tournament'),
      ),
      body: Consumer<CreateTournamentProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
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
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(provider.startDate == null ? 'Select date' : '${provider.startDate!.day}/${provider.startDate!.month}/${provider.startDate!.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        provider.setStartDate(date);
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(provider.startTime == null ? 'Select time' : provider.startTime!.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        provider.setStartTime(time);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Maximum Players',
                      border: OutlineInputBorder(),
                    ),
                    value: provider.maxPlayers,
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
          );
        },
      ),
    );
  }
}
