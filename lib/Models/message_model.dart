import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final bool isRead;
  final String type; // 'text' or 'place'
  final String? placeId;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isRead,
    this.type = 'text',
    this.placeId,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isReadValue = data['isRead'];
    bool isRead = false;
    if (isReadValue is bool) {
      isRead = isReadValue;
    } else if (isReadValue is String) {
      isRead = isReadValue.toLowerCase() == 'true';
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: isRead,
      type: data['type'] ?? 'text',
      placeId: data['placeId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'text': text,
    'timestamp': timestamp,
    'isRead': isRead,
    'type': type,
    'placeId': placeId,
  };
}
