import 'package:chess_cash/Constant/app_constant.dart';
import 'package:squares/squares.dart';

class GameModel {
  String gameId;
  String gameCreatorUid;
  String userId;
  String positonFen;
  String winnerId;
  String whitesTime;
  String blacksTime;
  String whitsCurrentMove;
  String blacksCurrentMove;
  String boardState;
  String playState;
  bool isWhitesTurn;
  bool isGameOver;
  int squareState;
  List<Move> moves;

  GameModel({
    required this.gameId,
    required this.gameCreatorUid,
    required this.userId,
    required this.positonFen,
    required this.winnerId,
    required this.whitesTime,
    required this.blacksTime,
    required this.whitsCurrentMove,
    required this.blacksCurrentMove,
    required this.boardState,
    required this.playState,
    required this.isWhitesTurn,
    required this.isGameOver,
    required this.squareState,
    required this.moves,
  });

  Map<String, dynamic> toMap() {
    return {
      AppConstants.gameId: gameId,
      AppConstants.gameCreatorUid: gameCreatorUid,
      AppConstants.userId: userId,
      AppConstants.positonFen: positonFen,
      AppConstants.winnerId: winnerId,
      AppConstants.whitesTime: whitesTime,
      AppConstants.blacksTime: blacksTime,
      AppConstants.whitsCurrentMove: whitsCurrentMove,
      AppConstants.blacksCurrentMove: blacksCurrentMove,
      AppConstants.boardState: boardState,
      AppConstants.playState: playState,
      AppConstants.isWhitesTurn: isWhitesTurn,
      AppConstants.isGameOver: isGameOver,
      AppConstants.squareState: squareState,
      AppConstants.moves: moves,
    };
  }

  factory GameModel.fromMap(Map<String, dynamic> map) {
    return GameModel(
      gameId: map[AppConstants.gameId] ?? '',
      gameCreatorUid: map[AppConstants.gameCreatorUid] ?? '',
      userId: map[AppConstants.userId] ?? '',
      positonFen: map[AppConstants.positonFen] ?? '',
      winnerId: map[AppConstants.winnerId] ?? '',
      whitesTime: map[AppConstants.whitesTime] ?? '',
      blacksTime: map[AppConstants.blacksTime] ?? '',
      whitsCurrentMove: map[AppConstants.whitsCurrentMove] ?? '',
      blacksCurrentMove: map[AppConstants.blacksCurrentMove] ?? '',
      boardState: map[AppConstants.boardState] ?? '',
      playState: map[AppConstants.playState] ?? '',
      isWhitesTurn: map[AppConstants.isWhitesTurn] ?? false,
      isGameOver: map[AppConstants.isGameOver] ?? false,
      squareState: map[AppConstants.squareState] ?? 0,
      moves: List<Move>.from(map[AppConstants.moves] ?? []),
    );
  }
}
