import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    final timestamp = map['timestamp'] as Timestamp?;
    return Message(
      id: id,
      senderId: map['senderId'] as String,
      content: map['content'] as String,
      timestamp: timestamp?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
