import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String participantId;
  final String participantName;
  final String participantAvatar; // URL or asset path
  final String lastMessage;
  final Timestamp lastMessageTime;
  final bool isOnline;
  final bool isAI;

  ConversationModel({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.participantAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isOnline,
    this.isAI = false,
  });

  factory ConversationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      id: doc.id,
      participantId: data['participantId'] ?? '',
      participantName: data['participantName'] ?? '',
      participantAvatar: data['participantAvatar'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      isOnline: data['isOnline'] ?? false,
      isAI: data['isAI'] ?? false,
    );
  }
}

/// Hardcoded AI conversation — always pinned at top, not stored in Firestore
final ConversationModel aiConversation = ConversationModel(
  id: 'ai_assistant',
  participantId: 'ai',
  participantName: 'AI Assistant',
  participantAvatar: '', // use icon fallback
  lastMessage: 'Would you like a fado dinner recommendation?',
  lastMessageTime: Timestamp.now(),
  isOnline: true,
  isAI: true,
);
