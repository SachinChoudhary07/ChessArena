import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/gameProvider/GameProvider.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:chess_cash/Models/chat_message.dart';
import 'package:chess_cash/Services/moderation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Widgets/GameEndDialog.dart';

// -------------------------------------------------------------------------
// Friend request status enumeration (top-level)
// -------------------------------------------------------------------------

enum FriendStatus { none, pending, requestReceived, friends }

// screens/game_screen.dart
class GameScreen extends StatefulWidget {
  final String roomCode;
  final String? tournamentId; // Optional tournament ID

  const GameScreen({
    super.key,
    required this.roomCode,
    this.tournamentId, // Add optional parameter
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ChessGameProvider _gameProvider;
  bool _isInitialized = false;
  bool _isShowingPromotionDialog = false;
  DocumentSnapshot? _latestGameSnapshot;

  // ---------------------------------------------------------
  // Friend request variables
  // ---------------------------------------------------------
  FriendStatus _friendStatus = FriendStatus.none;
  StreamSubscription<DocumentSnapshot>? _friendSubscription;
  String? _opponentUID;
  bool _isChatOpen = false; // Track chat open state

  @override
  void initState() {
    super.initState();
    print("🎮 GameScreen: Initializing game screen");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  @override
  void dispose() {
    print("🎮 GameScreen: Disposing game screen");
    // Cancel friend request listener
    _friendSubscription?.cancel();
    // _gameProvider.dispose();
    super.dispose();
  }

  String? player1Name;
  String? player2Name;
  String? gameName = '';
  String? player1Image;
  String? player2Image;
  num player1Elo = 0.0;
  num player2Elo = 0.0;

  Future<void> _initializeGame() async {
    if (_isInitialized) return;
    _isInitialized = true;
    print("🎮 GameScreen: Starting game initialization");
    _gameProvider = Provider.of<ChessGameProvider>(context, listen: false);
    _gameProvider.initializeBoard();

    _gameProvider.setLoading(true);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      print("🎮 GameScreen: Fetching game data for room ${widget.roomCode}");
      CollectionReference<Map<String, dynamic>> gameCollection;
      if (widget.tournamentId != null) {
        gameCollection = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId!)
            .collection('matches');
      } else {
        gameCollection = FirebaseFirestore.instance.collection('games');
      }

      final gameDoc = await gameCollection.doc(widget.roomCode).get();

      if (gameDoc.exists) {
        final data = gameDoc.data() as Map<String, dynamic>;
        print("🎮 GameScreen: Game data fetched successfully");

        final player1UID = data['player1'];
        final player2UID = data['player2'];
        print("🎮 GameScreen: Player1: $player1UID, Player2: $player2UID");

        final player1Snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(player1UID)
            .get();
        final player2Snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(player2UID)
            .get();

        player1Name = player1Snapshot.data()?['username'] ?? 'Player 1';
        player2Name = player2Snapshot.data()?['username'] ?? 'Player 2';
        gameName = data['gameName'] ?? 'Chess Match';
        print("🎮 GameScreen: Players loaded - $player1Name vs $player2Name");

        player1Image = player1Snapshot.data()?['profileImage'] ?? '';
        player2Image = player2Snapshot.data()?['profileImage'] ?? '';
        player1Elo = player1Snapshot.data()?['eloRating'] ?? 0;
        player2Elo = player2Snapshot.data()?['eloRating'] ?? 0;

        // Store opponent UID for friend logic
        _opponentUID =
            (player1UID == currentUser.uid) ? player2UID : player1UID;

        // Start listening for friend request / friendship status
        _listenToFriendStatus();

        // Check if already friends
        _checkExistingFriendship();

        PieceColor playerColor;
        if (player1UID == currentUser.uid) {
          playerColor = data['player1Color'] == 'white'
              ? PieceColor.white
              : PieceColor.black;
          print(
              "🎮 GameScreen: Current user is Player 1 with color: $playerColor");
        } else {
          playerColor = data['player2Color'] == 'white'
              ? PieceColor.white
              : PieceColor.black;
          print(
              "🎮 GameScreen: Current user is Player 2 with color: $playerColor");
        }

        _gameProvider.initializeGame(
          widget.roomCode,
          currentUser.uid,
          playerColor,
          tournamentId: widget.tournamentId,
          round: data['round'] as int?,
          matchNumber: data['matchNumber'] as int?,
        );
        print("🎮 GameScreen: Game initialized successfully");
      } else {
        print("❌ GameScreen: Game document not found!");
      }
    } else {
      print("❌ GameScreen: No authenticated user found!");
    }
  }

  String _getOpponentName() {
    final myColor =
        Provider.of<ChessGameProvider>(context, listen: false).playerColor;
    return myColor == PieceColor.white
        ? (player2Name ?? 'Opponent')
        : (player1Name ?? 'Opponent');
  }

  Future<bool> _onBackPressed() async {
    return false;
  }

  Future<void> _handlePlayerExit() async {
    print("🎮 GameScreen: Processing player exit");
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final gameDocRef =
        FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    final snapshot = await gameDocRef.get();
    if (!snapshot.exists) {
      print("❌ GameScreen: Game document not found during exit");
      return;
    }

    final data = snapshot.data()!;
    final player1UID = data['player1'];
    final player2UID = data['player2'];

    final opponentUID =
        (player1UID == currentUser.uid) ? player2UID : player1UID;

    print("🎮 GameScreen: Updating game status to resignation");
    await gameDocRef.update({
      'gameStatus': 'resignation',
      'winner': opponentUID,
      'endedBy': currentUser.uid,
      'endReason': 'Player Resign',
    });

    print("🎮 GameScreen: Player exit processed successfully");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You left the game. ${_getOpponentName()} wins!')),
    );
  }

  // void handleGameStatus(String status) {
  //   switch (status) {
  //     case 'win':
  //       statusText = 'You Win!';
  //       statusColor = Colors.green;
  //       break;
  //
  //     case 'lose':
  //       statusText = 'You Lost!';
  //       statusColor = Colors.red;
  //       break;
  //
  //     case 'draw':
  //       statusText = 'It\'s a Draw!';
  //       statusColor = Colors.grey;
  //       break;
  //
  //     case 'resignation':
  //       final currentUser = FirebaseAuth.instance.currentUser;
  //       final winnerId = gameProvider.winner;
  //       final youWon = winnerId == currentUser?.uid;
  //
  //       statusText = youWon
  //           ? 'You Win! Your opponent left the game.'
  //           : 'You Lost! You left the game.';
  //       statusColor = youWon ? Colors.green : Colors.red;
  //       break;
  //
  //     default:
  //       statusText = 'Game Over';
  //       statusColor = Colors.black;
  //   }
  //
  //   notifyListeners(); // if inside ChangeNotifier
  // }

  // ---------------------------------------------------------
  // Friend request Firestore helpers
  // ---------------------------------------------------------

  String _combinedFriendDocId(String uidA, String uidB) {
    // Ensure consistent docId irrespective of order
    return (uidA.compareTo(uidB) < 0) ? '${uidA}_$uidB' : '${uidB}_$uidA';
  }

  void _listenToFriendStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final docId = _combinedFriendDocId(currentUser.uid, _opponentUID!);
    _friendSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(docId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (!snapshot.exists) {
        // Only set to none if not already friends
        if (_friendStatus != FriendStatus.friends) {
          setState(() {
            _friendStatus = FriendStatus.none;
          });
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status']; // 'pending', 'accepted', 'rejected'
      final requester = data['requester'];

      if (status == 'accepted') {
        setState(() {
          _friendStatus = FriendStatus.friends;
        });
      } else if (status == 'pending') {
        if (requester == currentUser.uid) {
          setState(() {
            _friendStatus = FriendStatus.pending;
          });
        } else {
          // Current user received a request
          setState(() {
            _friendStatus = FriendStatus.requestReceived;
          });
        }
      } else if (status == 'rejected') {
        // Treat rejection same as no request so users can send again
        setState(() {
          _friendStatus = FriendStatus.none;
        });
      } else {
        setState(() {
          _friendStatus = FriendStatus.none;
        });
      }
    });
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final docId = _combinedFriendDocId(currentUser.uid, _opponentUID!);
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(docId)
        .set({
      'requester': currentUser.uid,
      'addressee': _opponentUID,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _acceptFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final docId = _combinedFriendDocId(currentUser.uid, _opponentUID!);
    final batch = FirebaseFirestore.instance.batch();

    // Update request status
    final reqRef =
        FirebaseFirestore.instance.collection('friend_requests').doc(docId);
    batch.update(reqRef,
        {'status': 'accepted', 'respondedAt': FieldValue.serverTimestamp()});

    // Add each other to friends subcollection
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final oppRef =
        FirebaseFirestore.instance.collection('users').doc(_opponentUID!);

    batch.set(userRef.collection('friends').doc(_opponentUID!), {
      'uid': _opponentUID,
      'since': FieldValue.serverTimestamp(),
    });

    batch.set(oppRef.collection('friends').doc(currentUser.uid), {
      'uid': currentUser.uid,
      'since': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> _rejectFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final docId = _combinedFriendDocId(currentUser.uid, _opponentUID!);

    // Delete the request document so that a new request can be sent later
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(docId)
        .delete();

    if (mounted) {
      setState(() {
        _friendStatus = FriendStatus.none;
      });
    }
  }

  // ---------------------------------------------------------
  // Initial check: are we already friends?
  // ---------------------------------------------------------

  Future<void> _checkExistingFriendship() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .doc(_opponentUID!)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _friendStatus = FriendStatus.friends;
      });
    }
  }

  // ---------------------------------------------------------
  // UI helpers for friend request action row & banner
  // ---------------------------------------------------------

  Widget _actionIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color? iconColor,
    Color? backgroundColor,
    Color? borderColor,
    String? tooltip,
  }) {
    final enabled = onPressed != null;
    final fg = iconColor ??
        (enabled ? ColorResources.textPrimary : ColorResources.textSecondary);
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: backgroundColor ?? ColorResources.elevatedSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor ?? ColorResources.divider,
                width: 1,
              ),
            ),
            child: Icon(icon, size: 22, color: fg.withOpacity(enabled ? 1 : 0.55)),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    // Only show friend actions for opponent info (top)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
      child: Row(
        children: [
          _actionIconButton(
            icon: _isChatOpen
                ? Icons.chat_bubble_rounded
                : Icons.forum_rounded,
            tooltip: 'Chat',
            iconColor: _isChatOpen
                ? ColorResources.onPrimary
                : ColorResources.textPrimary,
            backgroundColor: _isChatOpen
                ? ColorResources.primary
                : ColorResources.elevatedSurface,
            borderColor: _isChatOpen
                ? ColorResources.primaryLight
                : ColorResources.divider,
            onPressed: () {
              setState(() {
                _isChatOpen = !_isChatOpen;
              });
              if (_isChatOpen) {
                _showChatInputDialog();
              }
            },
          ),
          const SizedBox(width: 8),

          // Display the most recent message inline (fades after 15 s)
          Expanded(
            child: Consumer<ChessGameProvider>(
              builder: (_, provider, __) {
                final messages = provider.chatMessages;
                final latestMessage =
                    messages.isNotEmpty ? messages.last : null;
                if (latestMessage == null || latestMessage.text.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: ColorResources.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ColorResources.divider),
                  ),
                  child: Text(
                    latestMessage.text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColorResources.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          ..._friendActionIcons(),
        ],
      ),
    );
  }

  List<Widget> _friendActionIcons() {
    switch (_friendStatus) {
      case FriendStatus.none:
        return [
          _actionIconButton(
            icon: Icons.person_add_alt_1_rounded,
            tooltip: 'Add friend',
            iconColor: ColorResources.accentSoft,
            borderColor: ColorResources.primary.withOpacity(0.45),
            onPressed: _sendFriendRequest,
          ),
        ];
      case FriendStatus.pending:
        return [
          _actionIconButton(
            icon: Icons.hourglass_top_rounded,
            tooltip: 'Request pending',
            iconColor: ColorResources.warning,
            borderColor: ColorResources.warning.withOpacity(0.4),
            onPressed: null,
          ),
        ];
      case FriendStatus.friends:
        return [
          _actionIconButton(
            icon: Icons.verified_rounded,
            tooltip: 'Friends',
            iconColor: ColorResources.success,
            borderColor: ColorResources.success.withOpacity(0.45),
            onPressed: null,
          ),
        ];
      case FriendStatus.requestReceived:
        return [
          _actionIconButton(
            icon: Icons.check_rounded,
            tooltip: 'Accept',
            iconColor: ColorResources.onPrimary,
            backgroundColor: ColorResources.success,
            borderColor: ColorResources.primaryLight,
            onPressed: _acceptFriendRequest,
          ),
          const SizedBox(width: 8),
          _actionIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Decline',
            iconColor: ColorResources.error,
            borderColor: ColorResources.error.withOpacity(0.45),
            onPressed: _rejectFriendRequest,
          ),
        ];
    }
  }

  // ---------------------------------------------------------
  // Chat helpers
  // ---------------------------------------------------------
  void _showChatInputDialog() {
    final TextEditingController chatController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        // Get keyboard height and adjust bottom sheet accordingly
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
        final screenHeight = MediaQuery.of(ctx).size.height;
        final bottomSheetHeight = screenHeight * 0.6 + keyboardHeight;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: bottomSheetHeight,
          decoration: const BoxDecoration(
            color: ColorResources.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: ColorResources.elevatedSurface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _isChatOpen = false;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Chat messages area - will expand from top when keyboard appears
              Expanded(
                child: Consumer<ChessGameProvider>(
                  builder: (_, provider, __) {
                    final messages = provider.chatMessages;
                    print(
                        "🎮 GameScreen: Chat messages count: ${messages.length}");
                    if (messages.isNotEmpty) {
                      print(
                          "🎮 GameScreen: Latest message: ${messages.last.text}");
                    }
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              // Remove reverse to show messages from top to bottom
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                // Show messages in chronological order (oldest first)
                                final message = messages[index];
                                return _buildMessageBubble(message);
                              },
                            ),
                    );
                  },
                ),
              ),

              // Input area - stays at bottom but moves up with keyboard
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 +
                      keyboardHeight, // Add keyboard height to bottom padding
                ),
                decoration: const BoxDecoration(
                  color: ColorResources.elevatedSurface,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColorResources.elevatedSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: chatController,
                          style: const TextStyle(color: Colors.white),
                          maxLength: 100,
                          autofocus: false,
                          // Don't auto-focus to prevent immediate keyboard
                          decoration: const InputDecoration(
                            hintText: 'Send a message...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            counterText: '',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () {
                        final text = chatController.text.trim();
                        if (text.isNotEmpty) {
                          Provider.of<ChessGameProvider>(context, listen: false)
                              .sendChat(text);
                          chatController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMyMessage =
        message.senderId == FirebaseAuth.instance.currentUser?.uid;

    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMyMessage
            ? null
            : () => _showModerationSheet(message),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMyMessage
                ? ColorResources.primary
                : ColorResources.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!isMyMessage) ...[
                const SizedBox(width: 4),
                const Icon(Icons.more_horiz, color: Colors.white54, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showModerationSheet(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report message'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ModerationService.reportUser(
                    reportedUid: message.senderId,
                    reason: 'abusive_chat',
                    messageText: message.text,
                    roomCode: widget.roomCode,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Block player'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ModerationService.blockUser(message.senderId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Player blocked. You can leave the game.')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        // backgroundColor: Colors.brown.shade100,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(AppConstants.appName),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // We'll get move counts from the latest snapshot
                    final snapshot = _latestGameSnapshot;
                    int moveCountWhite = 0;
                    int moveCountBlack = 0;
                    if (snapshot != null && snapshot.data() != null) {
                      final data = snapshot.data() as Map<String, dynamic>;
                      moveCountWhite = (data['moveCountWhite'] ?? 0) as int;
                      moveCountBlack = (data['moveCountBlack'] ?? 0) as int;
                    }
                    _showGameMenu(context,
                        moveCountWhite: moveCountWhite,
                        moveCountBlack: moveCountBlack);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ColorResources.elevatedSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorResources.divider),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      size: 20,
                      color: ColorResources.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _getGameStream(),
          builder: (context, snapshot) {
            // Store the latest snapshot for use in the menu
            _latestGameSnapshot = snapshot.data;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              _handleDrawOffer(data);
            }

            return Consumer<ChessGameProvider>(
              builder: (context, gameProvider, child) {
                if (gameProvider.isLoading) {
                  return const Loader();
                }

                // Show promotion dialog if needed
                if (gameProvider.isPromotionPending &&
                    !_isShowingPromotionDialog) {
                  _isShowingPromotionDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showPromotionDialog(gameProvider);
                  });
                }

                return Column(
                  children: [
                    _buildPlayerInfo(
                      isOpponent: true,
                      timeLeft: gameProvider.playerColor == PieceColor.white
                          ? gameProvider.blackTimeLeft
                          : gameProvider.whiteTimeLeft,
                      isActive: !gameProvider.isMyTurn,
                    ),

                    _buildActionRow(),

                    // Chess board
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: _buildChessBoard(gameProvider),
                        ),
                      ),
                    ),

                    // Current player info and timer
                    _buildPlayerInfo(
                      isOpponent: false,
                      timeLeft: gameProvider.playerColor == PieceColor.white
                          ? gameProvider.whiteTimeLeft
                          : gameProvider.blackTimeLeft,
                      isActive: gameProvider.isMyTurn,
                    ),
                    _buildGameStatus(gameProvider),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Stream<DocumentSnapshot> _getGameStream() {
    CollectionReference<Map<String, dynamic>> gameCollection;
    if (widget.tournamentId != null) {
      gameCollection = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId!)
          .collection('matches');
    } else {
      gameCollection = FirebaseFirestore.instance.collection('games');
    }

    return gameCollection.doc(widget.roomCode).snapshots();
  }

  bool _isShowingDrawOfferDialog = false;

  void _handleDrawOffer(Map<String, dynamic> data) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final drawOfferedBy = data['drawOfferedBy'];
    final drawAcceptedBy = data['drawAcceptedBy'];

    // Check if a draw offer was made by the opponent
    if (drawOfferedBy != null &&
        drawOfferedBy != currentUser.uid &&
        !_isShowingDrawOfferDialog &&
        drawAcceptedBy == null) {
      _isShowingDrawOfferDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDrawOfferDialog();
      });
    }

    // Check if draw was accepted
    if (drawAcceptedBy != null && data['gameStatus'] == 'draw') {
      // Game ended in draw, show game end dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showGameEndDialog(
              _gameProvider, false); // Draw is neither win nor loss
        }
      });
    }

    // Reset draw offer dialog flag if draw offer was cleared
    if (drawOfferedBy == null) {
      _isShowingDrawOfferDialog = false;
    }
  }

  Widget _buildPlayerInfo({
    required bool isOpponent,
    required int timeLeft,
    required bool isActive,
  }) {
    final gameProvider = Provider.of<ChessGameProvider>(context, listen: false);
    final isWhitePlayer = gameProvider.playerColor == PieceColor.white;

    final playerName = isOpponent
        ? (isWhitePlayer
            ? (player2Name ?? 'Opponent')
            : (player1Name ?? 'Opponent'))
        : (isWhitePlayer ? (player1Name ?? 'You') : (player2Name ?? 'You'));

    final playerElo = isOpponent
        ? (isWhitePlayer ? player2Elo : player1Elo)
        : (isWhitePlayer ? player1Elo : player2Elo);

    final playerImage = (isOpponent
            ? (isWhitePlayer ? player2Image : player1Image)
            : (isWhitePlayer ? player1Image : player2Image)) ??
        '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorResources.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isActive ? ColorResources.primaryLight : ColorResources.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isActive ? ColorResources.success : ColorResources.divider,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: playerImage,
                fit: BoxFit.cover,
                placeholder: (context, url) => Image.asset(
                  'assets/white_peice/White_King.png',
                  fit: BoxFit.cover,
                ),
                errorWidget: (context, url, error) => const Icon(Icons.person),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ColorResources.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'ELO ${playerElo.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ColorResources.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: timeLeft < 60
                    ? ColorResources.error.withOpacity(0.2)
                    : ColorResources.elevatedSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: timeLeft < 60
                        ? ColorResources.error
                        : ColorResources.divider)),
            child: Text(
              gameProvider.formatTime(timeLeft),
              style: TextStyle(
                color: timeLeft < 60
                    ? ColorResources.warning
                    : ColorResources.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessBoard(ChessGameProvider gameProvider) {
    final board = gameProvider.board;
    if (board.length != 8 || board.any((row) => row.length != 8)) {
      return const Center(child: CircularProgressIndicator());
    }

    // Determine if the board needs to be flipped so that the current
    // player always sees their own pieces at the bottom of the screen.
    final shouldFlipBoard = gameProvider.playerColor == PieceColor.black;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorResources.divider, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          // UI coordinates drawn by GridView
          final uiRow = index ~/ 8;
          final uiCol = index % 8;

          // Convert to actual board coordinates depending on orientation
          final row = shouldFlipBoard ? 7 - uiRow : uiRow;
          final col = shouldFlipBoard ? 7 - uiCol : uiCol;

          final position = ChessPosition(row, col);
          final piece = board[row][col];
          // selection highlighting handled elsewhere
          final isPossibleMove = gameProvider.possibleMoves.contains(position);
          final isWhiteSquare = (row + col) % 2 == 0;
          final isSelected = gameProvider.selectedPosition == position;

          final isKingInCheckSquare = gameProvider.kingInCheck != null &&
              gameProvider.kingInCheck == position;

          return GestureDetector(
            onTap: () => gameProvider.onSquareTapped(row, col),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              color: isWhiteSquare
                  ? ColorResources.lightSquare
                  : ColorResources.darkSquare,
              child: Stack(
                children: [
                  if (isSelected)
                    Container(color: ColorResources.selectedSquare),
                  if (isKingInCheckSquare)
                    Container(color: ColorResources.checkSquare),
                  if (isPossibleMove && !isKingInCheckSquare)
                    Center(
                      child: Container(
                        width: piece != null ? 36 : 10,
                        height: piece != null ? 36 : 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: piece != null
                              ? Border.all(
                                  color: ColorResources.accent.withOpacity(0.7),
                                  width: 2,
                                )
                              : null,
                          color: piece == null
                              ? ColorResources.validMove
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  Center(
                    child: piece != null ? _buildPieceWidget(piece) : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPieceWidget(ChessPiece piece) {
    final imagePath = _getPieceImagePath(piece);
    return Image.asset(
      imagePath,
      fit: BoxFit.contain,
      width: 40,
      height: 40,
    );
  }

  String _getPieceImagePath(ChessPiece piece) {
    final colorPrefix = piece.color == PieceColor.white ? 'White' : 'Black';
    final pieceType = piece.type.toString().split('.').last;
    return 'assets/${piece.color == PieceColor.white ? 'white_peice' : 'black_peice'}/'
        '${colorPrefix}_${pieceType[0].toUpperCase()}${pieceType.substring(1)}.png';
  }

  Widget _buildGameStatus(ChessGameProvider gameProvider) {
    String statusText = '';
    Color statusColor = ColorResources.primaryLight;

    final winnerColor = gameProvider.winner;
    final playerColor = gameProvider.playerColor.toString().split('.').last;
    final youWon = winnerColor == playerColor;
    final isGameOver =
        gameProvider.gameStatus != null && gameProvider.gameStatus != 'playing';

    if (!isGameOver) {
      statusText = gameProvider.isMyTurn ? 'Your Turn' : 'Opponent\'s Turn';
      statusColor = gameProvider.isMyTurn
          ? ColorResources.success
          : ColorResources.warning;
    } else {
      switch (gameProvider.gameStatus) {
        case 'checkmate':
          statusText = youWon ? 'Checkmate! You Win!' : 'Checkmate! You Lose!';
          statusColor = youWon ? Colors.green : Colors.red;
          break;

        case 'stalemate':
        case 'draw':
          statusText = 'Draw!';
          statusColor = Colors.grey;
          break;

        case 'resignation':
          statusText = youWon
              ? 'You Win! Your opponent left the game.'
              : 'You Lost! You left the game.';
          statusColor = youWon ? Colors.green : Colors.red;
          break;

        case 'timeout':
          statusText =
              youWon ? 'You Win! Opponent timed out.' : 'You Lost! Time\'s up.';
          statusColor = youWon ? Colors.green : Colors.red;
          break;
      }

      // ✅ Show dialog instead of automatic navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showGameEndDialog(gameProvider, youWon);
        }
      });
      // // Add navigation delay when game ends
      // Future.delayed(const Duration(seconds: 2), () {
      //   if (mounted) {
      //     Navigator.of(context).pushAndRemoveUntil(
      //         MaterialPageRoute(builder: (context) => BottomNavBar()),
      //         (route) => false); // Navigate to dashboard and clear stack
      //   }
      // });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ColorResources.surface,
        border: Border(top: BorderSide(color: statusColor.withOpacity(0.6))),
      ),
      child: Text(
        statusText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

// Add this new method for the game end dialog
  void _showGameEndDialog(ChessGameProvider gameProvider, bool youWon) {
    // Prevent multiple dialogs
    if (_isShowingGameEndDialog) return;
    _isShowingGameEndDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false, // Must tap OK to dismiss
      builder: (BuildContext context) {
        return GameEndDialog(
          gameProvider: gameProvider,
          youWon: youWon,
          player1Name: player1Name ?? 'Player 1',
          player2Name: player2Name ?? 'Player 2',
          roomCode: widget.roomCode,
          onOkPressed: () {
            Navigator.of(context).pop(); // Close dialog
            // Clean up game state
            final provider =
                Provider.of<ChessGameProvider>(context, listen: false);
            provider.resetGameState();
            // Navigate to home
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const BottomNavBar()),
              (route) => false,
            );
          },
        );
      },
    );
  }

// Add this flag to prevent multiple dialogs
  bool _isShowingGameEndDialog = false;

  void _showGameMenu(BuildContext context,
      {required int moveCountWhite, required int moveCountBlack}) {
    print("🎮 GameScreen: Opening game menu");
    final bool canAbort = moveCountWhite == 0 || moveCountBlack == 0;
    final bool canResign = moveCountWhite > 0 && moveCountBlack > 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          decoration: BoxDecoration(
            color: ColorResources.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ColorResources.divider),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColorResources.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Game options',
                      style: TextStyle(
                        color: ColorResources.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (canAbort)
                  _gameMenuTile(
                    icon: Icons.close_rounded,
                    iconBg: ColorResources.error.withOpacity(0.15),
                    iconColor: ColorResources.error,
                    title: 'Abort',
                    subtitle: 'End before moves are played',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmAbort();
                    },
                  ),
                if (canResign)
                  _gameMenuTile(
                    icon: Icons.flag_rounded,
                    iconBg: ColorResources.warning.withOpacity(0.15),
                    iconColor: ColorResources.warning,
                    title: 'Resign',
                    subtitle: 'Forfeit this game',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmResign();
                    },
                  ),
                _gameMenuTile(
                  icon: Icons.handshake_rounded,
                  iconBg: ColorResources.primary.withOpacity(0.18),
                  iconColor: ColorResources.accentSoft,
                  title: 'Offer draw',
                  subtitle: 'Ask your opponent to split the point',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDraw();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _gameMenuTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: ColorResources.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ColorResources.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ColorResources.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ColorResources.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmResign() {
    print("🎮 GameScreen: Showing resign confirmation dialog");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resign Game'),
          content: const Text('Are you sure you want to resign?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print("🎮 GameScreen: Player confirmed resignation");
                _gameProvider.resignGame();
              },
              child: const Text('Resign'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDraw() {
    print("🎮 GameScreen: Showing draw offer confirmation dialog");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Offer Draw'),
          content: const Text('Do you want to offer a draw to your opponent?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print("🎮 GameScreen: Player confirmed draw offer");
                _offerDraw();
              },
              child: const Text('Offer Draw'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _offerDraw() async {
    print("🎮 GameScreen: Offering draw to opponent");
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Update game document to indicate draw offer
      CollectionReference<Map<String, dynamic>> gameCollection;
      if (widget.tournamentId != null) {
        gameCollection = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId!)
            .collection('matches');
      } else {
        gameCollection = FirebaseFirestore.instance.collection('games');
      }

      await gameCollection.doc(widget.roomCode).update({
        'drawOfferedBy': currentUser.uid,
        'drawOfferedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw offer sent to opponent'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print("❌ GameScreen: Error offering draw: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send draw offer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDrawOfferDialog() {
    print("🎮 GameScreen: Showing draw offer dialog");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Draw Offer'),
          content:
              Text('${_getOpponentName()} has offered a draw. Do you accept?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectDraw();
              },
              child: const Text('Reject'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptDraw();
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptDraw() async {
    print("🎮 GameScreen: Accepting draw offer");
    try {
      CollectionReference<Map<String, dynamic>> gameCollection;
      if (widget.tournamentId != null) {
        gameCollection = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId!)
            .collection('matches');
      } else {
        gameCollection = FirebaseFirestore.instance.collection('games');
      }

      await gameCollection.doc(widget.roomCode).update({
        'gameStatus': 'draw',
        'winner': null,
        'drawAcceptedBy': FirebaseAuth.instance.currentUser?.uid,
        'drawAcceptedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw accepted! Game ended in a draw.'),
          backgroundColor: Colors.grey,
        ),
      );
    } catch (e) {
      print("❌ GameScreen: Error accepting draw: $e");
    } finally {
      _isShowingDrawOfferDialog = false;
    }
  }

  Future<void> _rejectDraw() async {
    print("🎮 GameScreen: Rejecting draw offer");
    try {
      CollectionReference<Map<String, dynamic>> gameCollection;
      if (widget.tournamentId != null) {
        gameCollection = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId!)
            .collection('matches');
      } else {
        gameCollection = FirebaseFirestore.instance.collection('games');
      }

      await gameCollection.doc(widget.roomCode).update({
        'drawOfferedBy': null,
        'drawOfferedAt': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw offer rejected. Game continues.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print("❌ GameScreen: Error rejecting draw: $e");
    } finally {
      _isShowingDrawOfferDialog = false;
    }
  }

  // void _confirmLeaveGame() {
  //   print("🎮 GameScreen: Showing leave game confirmation dialog");
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Leave Game'),
  //         content: Text(
  //             "If you leave, your opponent (${_getOpponentName()}) will win the match.\nAre you sure you want to exit?"),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               Navigator.pop(context);
  //               print(
  //                   "🎮 GameScreen: Player confirmed leave , that will going to call resign");
  //               _gameProvider.resignGame();
  //             },
  //             child: const Text('Yes, Exit'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  void _showPromotionDialog(ChessGameProvider gameProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final pieceColor = gameProvider.playerColor;
        return AlertDialog(
          title: const Text('Choose Promotion Piece'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPromotionPiece(PieceType.queen, pieceColor!, gameProvider),
              _buildPromotionPiece(PieceType.rook, pieceColor, gameProvider),
              _buildPromotionPiece(PieceType.bishop, pieceColor, gameProvider),
              _buildPromotionPiece(PieceType.knight, pieceColor, gameProvider),
            ],
          ),
        );
      },
    ).then((_) {
      _isShowingPromotionDialog = false;
    });
  }

  Widget _buildPromotionPiece(
    PieceType type,
    PieceColor color,
    ChessGameProvider gameProvider,
  ) {
    final imagePath = _getPieceImagePath(ChessPiece(type: type, color: color));
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        gameProvider.handlePromotion(type);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown),
          color: Colors.white,
        ),
        child: Center(
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            width: 40,
            height: 40,
          ),
        ),
      ),
    );
  }

  void _confirmAbort() {
    print("🎮 GameScreen: Showing abort confirmation dialog");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Abort Game'),
          content: const Text('Are you sure you want to abort the game?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print("🎮 GameScreen: Player confirmed abort");
                // Implement abort logic here (e.g., update Firestore, end game as aborted)
                _gameProvider.abortGame();
              },
              child: const Text('Abort'),
            ),
          ],
        );
      },
    );
  }
}

// models/chess_piece.dart
class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  // Convert to map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'color': color.toString().split('.').last,
      'hasMoved': hasMoved,
    };
  }

  // Create from map for Firebase
  static ChessPiece? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return ChessPiece(
      type: PieceType.values
          .firstWhere((e) => e.toString().split('.').last == map['type']),
      color: PieceColor.values
          .firstWhere((e) => e.toString().split('.').last == map['color']),
      hasMoved: map['hasMoved'] ?? false,
    );
  }

  ChessPiece copyWith({bool? hasMoved}) {
    return ChessPiece(
      type: type,
      color: color,
      hasMoved: hasMoved ?? this.hasMoved,
    );
  }
}

enum PieceType { king, queen, rook, bishop, knight, pawn }

enum PieceColor { white, black }

// models/chess_position.dart
class ChessPosition {
  final int row;
  final int col;

  const ChessPosition(this.row, this.col);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChessPosition && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  bool isValid() {
    return row >= 0 && row < 8 && col >= 0 && col < 8;
  }

  Map<String, dynamic> toMap() {
    return {'row': row, 'col': col};
  }

  static ChessPosition fromMap(Map<String, dynamic> map) {
    return ChessPosition(map['row'], map['col']);
  }
}

// models/chess_move.dart
class ChessMove {
  final ChessPosition from;
  final ChessPosition to;
  final ChessPiece piece;
  final ChessPiece? capturedPiece;
  final DateTime timestamp;
  final String playerId;

  ChessMove({
    required this.from,
    required this.to,
    required this.piece,
    this.capturedPiece,
    required this.timestamp,
    required this.playerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'from': from.toMap(),
      'to': to.toMap(),
      'piece': piece.toMap(),
      'capturedPiece': capturedPiece?.toMap(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'playerId': playerId,
    };
  }

  static ChessMove fromMap(Map<String, dynamic> map) {
    return ChessMove(
      from: ChessPosition.fromMap(map['from']),
      to: ChessPosition.fromMap(map['to']),
      piece: ChessPiece.fromMap(map['piece'])!,
      capturedPiece: ChessPiece.fromMap(map['capturedPiece']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      playerId: map['playerId'],
    );
  }
}
