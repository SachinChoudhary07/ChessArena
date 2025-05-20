import 'dart:developer';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Screens/Dashboard/DashboardScreen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:stockfish/stockfish.dart';

import '../../Providers/gameProvider/GameProvider.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Stockfish? stockfish;

  @override
  void initState() {
    //stockfish = Stockfish();
    final gameProvider = context.read<GameProvider>();
    gameProvider.resetGame(newGame: false);
    gameProvider.fetchUserProfile();

    if (mounted) {
      // letOtherPlayerPlayFirst();
    }
    super.initState();
  }

  @override
  void dispose() {
    stockfish?.dispose();
    super.dispose();
  }

  void letOtherPlayerPlayFirst() {
    // wait for widget to rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gameProvider = context.read<GameProvider>();

      if (gameProvider.vsComputer) {
        if (gameProvider.state.state == PlayState.theirTurn &&
            !gameProvider.aiThinking) {
          gameProvider.setAiThinking(true);

          // wait auntil stockfish is ready
          await waitUntilReady();

          // get the current position of the board and sent to stockfish
          stockfish?.stdin =
              '${UCICommands.position} ${gameProvider.getPositionFen()}';

          // set stockfish level
          stockfish?.stdin =
              '${UCICommands.goMoveTime} ${gameProvider.gameLevel * 1000}';

          stockfish?.stdout.listen((event) {
            if (event.contains(UCICommands.bestMove)) {
              final bestMove = event.split(' ')[1];
              gameProvider.makeStringMove(bestMove);
              gameProvider.setAiThinking(false);
              gameProvider.setSquaresState().whenComplete(() {
                if (gameProvider.player == Squares.white) {
                  // check if we can play whitesTimer
                  if (gameProvider.playWhitesTimer) {
                    // pause timer for black
                    gameProvider.pauseBlacksTimer();

                    startTimer(
                      isWhiteTimer: true,
                      onNewGame: () {},
                    );

                    gameProvider.setPlayWhitesTimer(value: false);
                  }
                } else {
                  if (gameProvider.playBlacksTimer) {
                    // pause timer for white
                    gameProvider.pauseWhitesTimer();

                    startTimer(
                      isWhiteTimer: false,
                      onNewGame: () {},
                    );

                    gameProvider.setPlayBlactsTimer(value: false);
                  }
                }
              });
            }
          });
        }
      } else {
        // listen for game changes in fireStore
        gameProvider.listenForGameChanges(
          context: context,
          uid: gameProvider.userId,
          name: gameProvider.userName,
          email: gameProvider.email ?? '',
          image: gameProvider.profileImageUrl ?? '',
          createdAt: gameProvider.createdAt ?? '',
          playerRating: gameProvider.playerRating ?? 234,
        );
      }
    });
  }

  void _onMove(Move move) async {
    log('move: ${move.toString()}');
    log('String move: ${move.algebraic()}');
    final gameProvider = context.read<GameProvider>();
    bool result = gameProvider.makeSquaresMove(move);
    if (result) {
      gameProvider.setSquaresState().whenComplete(() async {
        if (gameProvider.player == Squares.white) {
          // check if we are playing vs computer
          if (gameProvider.vsComputer) {
            // pause timer for white
            gameProvider.pauseWhitesTimer();

            startTimer(
              isWhiteTimer: false,
              onNewGame: () {},
            );
            // set whites bool flag to true so that we dont run this code agin until true
            gameProvider.setPlayWhitesTimer(value: true);
          } else {
            // play and save white's move to fireStore
            await gameProvider.playMoveAndSaveToFireStore(
              context: context,
              move: move,
              isWhitesMove: true,
            );
          }
        } else {
          if (gameProvider.vsComputer) {
            // pause timer for black
            gameProvider.pauseBlacksTimer();

            startTimer(
              isWhiteTimer: true,
              onNewGame: () {},
            );
            // set blacks bool flag to true so that we dont run this code agin until true
            gameProvider.setPlayBlactsTimer(value: true);
          } else {
            // play and save black's move to fireStore
            await gameProvider.playMoveAndSaveToFireStore(
              context: context,
              move: move,
              isWhitesMove: false,
            );
          }
        }
      });
    }

    if (gameProvider.vsComputer) {
      if (gameProvider.state.state == PlayState.theirTurn &&
          !gameProvider.aiThinking) {
        gameProvider.setAiThinking(true);

        // wait auntil stockfish is ready
        await waitUntilReady();

        // get the current position of the board and sent to stockfish
        stockfish?.stdin =
            '${UCICommands.position} ${gameProvider.getPositionFen()}';

        // set stockfish level
        stockfish?.stdin =
            '${UCICommands.goMoveTime} ${gameProvider.gameLevel * 1000}';

        stockfish?.stdout.listen((event) {
          if (event.contains(UCICommands.bestMove)) {
            final bestMove = event.split(' ')[1];
            gameProvider.makeStringMove(bestMove);
            gameProvider.setAiThinking(false);
            gameProvider.setSquaresState().whenComplete(() {
              if (gameProvider.player == Squares.white) {
                // check if we can play whitesTimer
                if (gameProvider.playWhitesTimer) {
                  // pause timer for black
                  gameProvider.pauseBlacksTimer();

                  startTimer(
                    isWhiteTimer: true,
                    onNewGame: () {},
                  );

                  gameProvider.setPlayWhitesTimer(value: false);
                }
              } else {
                if (gameProvider.playBlacksTimer) {
                  // pause timer for white
                  gameProvider.pauseWhitesTimer();

                  startTimer(
                    isWhiteTimer: false,
                    onNewGame: () {},
                  );

                  gameProvider.setPlayBlactsTimer(value: false);
                }
              }
            });
          }
        });
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    // listen if its game over
    checkGameOverListener();
  }

  Future<void> waitUntilReady() async {
    while (stockfish?.state.value != StockfishState.ready) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void checkGameOverListener() {
    final gameProvider = context.read<GameProvider>();

    gameProvider.gameOverListerner(
      context: context,
      stockfish: stockfish,
      onNewGame: () {
        // start new game
      },
    );
  }

  void startTimer({
    required bool isWhiteTimer,
    required Function onNewGame,
  }) {
    final gameProvider = context.read<GameProvider>();
    if (isWhiteTimer) {
      // start timer for White
      gameProvider.startWhitesTimer(
        context: context,
        stockfish: stockfish,
        onNewGame: onNewGame,
      );
    } else {
      // start timer for black
      gameProvider.startBlacksTimer(
        context: context,
        stockfish: stockfish,
        onNewGame: onNewGame,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.read<GameProvider>();
    final userModel = context.read<GameProvider>().fetchUserProfile();
    return PopScope(
      canPop: false,
      onPopInvoked: (didpop) async {
        if (didpop) return;
        bool? leave = await _showExitConfirmDialog(context);
        if (leave != null && leave) {
          stockfish?.stdin = UCICommands.stop;
          await Future.delayed(const Duration(milliseconds: 200))
              .whenComplete(() {
            // if the user confirms, navigate to home screen
            pushAndRemoveUntil(context, Dashboardscreen(), false);
            // Navigator.pushNamedAndRemoveUntil(
            //     context, Dashboardscreen(), (route) => false);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // leading: IconButton(
          //   icon: const Icon(
          //     Icons.arrow_back,
          //     color: Colors.white,
          //   ),
          //   onPressed: () {
          //     // TODO show dialog if sure
          //     Navigator.pop(context);
          //   },
          // ),
          backgroundColor: Colors.blue,
          title: const Text(
            'Flutter Chess',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              onPressed: () {
                gameProvider.resetGame(newGame: false);
              },
              icon: const Icon(Icons.start, color: Colors.white),
            ),
            IconButton(
              onPressed: () {
                gameProvider.flipTheBoard();
              },
              icon: const Icon(Icons.rotate_left, color: Colors.white),
            ),
          ],
        ),
        body: Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            String whitesTimer = getTimerToDisplay(
              gameProvider: gameProvider,
              isUser: true,
            );
            String blacksTimer = getTimerToDisplay(
              gameProvider: gameProvider,
              isUser: false,
            );
            return Column(
              //mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // opponents data
                showOpponentsData(
                  gameProvider: gameProvider,
                  uid: gameProvider.userId,
                  name: gameProvider.userName,
                  email: gameProvider.email ?? '',
                  image: gameProvider.profileImageUrl ?? '',
                  createdAt: gameProvider.createdAt ?? '',
                  playerRating: gameProvider.playerRating ?? 234,
                  timeToShow: blacksTimer,
                ),

                gameProvider.vsComputer
                    ? Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: BoardController(
                          state: gameProvider.flipBoard
                              ? gameProvider.state.board.flipped()
                              : gameProvider.state.board,
                          playState: gameProvider.state.state,
                          pieceSet: PieceSet.merida(),
                          theme: BoardTheme.brown,
                          moves: gameProvider.state.moves,
                          onMove: _onMove,
                          onPremove: _onMove,
                          markerTheme: MarkerTheme(
                            empty: MarkerTheme.dot,
                            piece: MarkerTheme.corners(),
                          ),
                          promotionBehaviour: PromotionBehaviour.autoPremove,
                        ),
                      )
                    : buildChessBoard(
                        gameProvider: gameProvider,
                        uid: gameProvider.userId,
                        name: gameProvider.userName,
                        email: gameProvider.email ?? '',
                        image: gameProvider.profileImageUrl ?? '',
                        createdAt: gameProvider.createdAt ?? '',
                        playerRating: gameProvider.playerRating ?? 234,
                      ),

                // our data
                ListTile(
                  leading: gameProvider.profileImageUrl == ''
                      ? CircleAvatar(
                          radius: 25,
                          backgroundImage: AssetImage('assets/images/king.png'),
                        )
                      : CircleAvatar(
                          radius: 25,
                          backgroundImage:
                              NetworkImage(gameProvider.profileImageUrl ?? ''),
                        ),
                  title: Text(gameProvider.userName),
                  subtitle: Text('Rating: ${gameProvider.playerRating}'),
                  trailing: Text(
                    whitesTimer,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget buildChessBoard({
    required GameProvider gameProvider,
    required String uid,
    required String name,
    required String email,
    required String image,
    required String createdAt,
    required int playerRating,
  }) {
    bool isOurTurn =
        gameProvider.isWhitesTurn == (gameProvider.gameCreatorUid == uid);

    log('CHESS UID: ${gameProvider.player}');

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: BoardController(
        state: gameProvider.flipBoard
            ? gameProvider.state.board.flipped()
            : gameProvider.state.board,
        playState: isOurTurn ? PlayState.ourTurn : PlayState.theirTurn,
        pieceSet: PieceSet.merida(),
        theme: BoardTheme.brown,
        moves: gameProvider.state.moves,
        onMove: _onMove,
        onPremove: _onMove,
        markerTheme: MarkerTheme(
          empty: MarkerTheme.dot,
          piece: MarkerTheme.corners(),
        ),
        promotionBehaviour: PromotionBehaviour.autoPremove,
      ),
    );
  }

  getState({required GameProvider gameProvider}) {
    if (gameProvider.flipBoard) {
      return gameProvider.state.board.flipped();
    } else {
      gameProvider.state.board;
    }
  }

  Widget showOpponentsData({
    required GameProvider gameProvider,
    required String uid,
    required String name,
    required String email,
    required String image,
    required String createdAt,
    required int playerRating,
    required String timeToShow,
  }) {
    if (gameProvider.vsComputer) {
      return ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: AssetImage('assets/images/king.png'),
        ),
        title: const Text('Stockfish'),
        subtitle: Text('Rating: ${gameProvider.gameLevel * 1000}'),
        trailing: Text(
          timeToShow,
          style: const TextStyle(fontSize: 16),
        ),
      );
    } else {
      // check is we are the creator of this game
      if (gameProvider.gameCreatorUid == uid) {
        return ListTile(
          leading: gameProvider.userPhoto == ''
              ? CircleAvatar(
                  radius: 25,
                  backgroundImage: AssetImage('assets/images/king.png'),
                )
              : CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(gameProvider.userPhoto),
                ),
          title: Text(gameProvider.userName),
          subtitle: Text('Rating: ${gameProvider.userRating}'),
          trailing: Text(
            timeToShow,
            style: const TextStyle(fontSize: 16),
          ),
        );
      } else {
        return ListTile(
          leading: gameProvider.gameCreatorPhoto == ''
              ? CircleAvatar(
                  radius: 25,
                  backgroundImage: AssetImage('assets/images/king.png'),
                )
              : CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(gameProvider.gameCreatorPhoto),
                ),
          title: Text(gameProvider.gameCreatorName),
          subtitle: Text('Rating: ${gameProvider.gameCreatorRating}'),
          trailing: Text(
            timeToShow,
            style: const TextStyle(fontSize: 16),
          ),
        );
      }
    }
  }

  Future<bool?> _showExitConfirmDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Leave Game?',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Are you sure to leave this game?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  String getTimerToDisplay({
    required GameProvider gameProvider,
    required bool isUser,
  }) {
    String timer = '';
    // check if is user
    if (isUser) {
      if (gameProvider.player == Squares.white) {
        timer = gameProvider.whitesTime.toString().substring(2, 7);
      }
      if (gameProvider.player == Squares.black) {
        timer = gameProvider.blacksTime.toString().substring(2, 7);
      }
    } else {
      // if its not user do the opposite
      if (gameProvider.player == Squares.white) {
        timer = gameProvider.blacksTime.toString().substring(2, 7);
      }
      if (gameProvider.player == Squares.black) {
        timer = gameProvider.whitesTime.toString().substring(2, 7);
      }
    }

    return timer;
  }
}
