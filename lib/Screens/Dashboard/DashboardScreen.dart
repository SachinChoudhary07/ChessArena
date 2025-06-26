import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/GameScreens/MatchMakingScreen.dart';
import 'package:chess_cash/Screens/PaidMatch/PlayPaidMatch.dart';
import 'package:chess_cash/Screens/TournamentScreens/tournaments_screen.dart';
import 'package:chess_cash/Screens/create_contest.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Constant/ui_helper.dart';
import '../../Providers/CreateTournamentProvider/CreateTournamentProvider.dart';

class Dashboardscreen extends StatefulWidget {
  const Dashboardscreen({super.key});

  @override
  State<Dashboardscreen> createState() => _DashboardscreenState();
}

class _DashboardscreenState extends State<Dashboardscreen> {
  String selectedTime = '3 min';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: ColorResources.primaryColor,
        body: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.only(top: 20, bottom: 20, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 33,
                  ),
                ),
                Image.asset(
                  AppConstants.splashIcon,
                  height: 200,
                ),
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ColorResources.secondaryColor)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled_sharp),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              value: selectedTime,
                              items: <String>[
                                '1 min',
                                '3 min',
                                '5 min',
                                '10 min',
                                '15 min',
                                '30 min'
                              ]
                                  .map((number) => DropdownMenuItem(
                                        value: number,
                                        child: Text(
                                          number,
                                          style: TextStyle(
                                              color: ColorResources
                                                  .secondaryColor),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedTime = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Helper.heightSizedBox(10),
                _buildButton(AppConstants.playFreeMatch, Icons.play_arrow,
                    ColorResources.secondaryColor, () {
                  _startMatchmaking();
                }),
                _buildButton(AppConstants.joinPaidContest, Icons.attach_money,
                    ColorResources.secondaryColor, () {
                  push(context, const PlayPaidMatch());
                }),
                _buildButton(AppConstants.tournaments, Icons.emoji_events,
                    ColorResources.secondaryColor, () {
                  push(context, const TournamentsScreen());
                }),
                _buildButton(
                    AppConstants.createContest,
                    Icons.compare_arrows_sharp,
                    ColorResources.secondaryColor, () {
                  push(context, const CreateTournament());
                }),
                _buildButton(
                    AppConstants.playWithFriends,
                    Icons.people_outline_rounded,
                    ColorResources.secondaryColor, () {
                  push(context, const PlayWithFriends());
                }),
                Helper.heightSizedBox(20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, iconColor, onTap) {
    return Column(
      children: [
        Helper.heightSizedBox(10),
        InkWell(
          splashColor: Colors.black,
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              decoration: BoxDecoration(
                  border: Border.all(color: ColorResources.secondaryColor),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: iconColor,
                    size: 35,
                  ),
                  Helper.widthSizedBox(),
                  Text(
                    text,
                    style: TextStyle(
                        color: ColorResources.secondaryColor, fontSize: 18),
                  )
                ],
              )),
        ),
        Helper.heightSizedBox(10)
      ],
    );
  }

  void _startMatchmaking() async {
    if (kDebugMode) {
      print(
          "🎮 Dashboard: Starting matchmaking with time limit: $selectedTime");
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchMakingScreen(time: selectedTime),
      ),
    );
  }
}

class CreateTournament extends StatefulWidget {
  const CreateTournament({super.key});

  @override
  State<CreateTournament> createState() => _CreateTournamentState();
}

class _CreateTournamentState extends State<CreateTournament> {
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
                      prefixText: '\$',
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
                      prefixText: '\$',
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
                                await provider.createTournament();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
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
      ),
    );
  }
}
