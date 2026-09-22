import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single chat message that is displayed inline during the game.
///
/// We purposely keep it minimal because we only ever show the *latest* message –
/// there is no history / list scrolling requirement.
///
/// ``latestChat`` field structure inside every game document:
/// {
///   "text"   : "Good luck!",      // String – the message body
///   "sender" : "uid123",           // String – sender's uid
///   "ts"     : Timestamp(..)        // Firestore server timestamp
/// }
///
/// If you change that map structure, adjust [fromMap] accordingly.
///
/// This class lives in *Models* so that both the provider and the UI can import it
/// without introducing circular dependencies.
class ChatMessage {
  final String id; // Unique identifier for the message
  final String senderId;
  final String text;
  final DateTime time;

  const ChatMessage(
      {required this.id,
      required this.senderId,
      required this.text,
      required this.time});

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    DateTime timestamp;

    // Handle different timestamp formats from Firestore
    if (map['ts'] is Timestamp) {
      timestamp = (map['ts'] as Timestamp).toDate();
    } else if (map['ts'] is DateTime) {
      timestamp = map['ts'] as DateTime;
    } else {
      timestamp = DateTime.now();
    }

    return ChatMessage(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: map['sender'] ?? '',
      text: map['text'] ?? '',
      time: timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender': senderId,
        'text': text,
        'ts': time,
      };
}
