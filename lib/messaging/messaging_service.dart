import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/message_model.dart';
import '../Models/conversation_model.dart';

class MessagingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference get _conversations => _db.collection('conversations');

  CollectionReference _messages(String conversationId) =>
      _conversations.doc(conversationId).collection('messages');

  // ── Conversations ──────────────────────────────────────────────────────────

  /// Stream of all conversations for the current user, ordered by last message.
  /// Pass in the current user's uid to filter their conversations.
  Stream<List<ConversationModel>> conversationsStream(String currentUserId) {
    return _conversations
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ConversationModel.fromDoc(d, currentUserId))
              .toList(),
        );
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  /// Real-time stream of messages in a conversation.
  Stream<List<MessageModel>> messagesStream(String conversationId) {
    return _messages(conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessageModel.fromDoc(d)).toList());
  }

  /// Send a message and update the conversation's lastMessage metadata.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final now = Timestamp.now();

    final batch = _db.batch();

    // Add the message document
    final msgRef = _messages(conversationId).doc();
    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': now,
      'isRead': false,
    });

    // Update conversation metadata
    final convRef = _conversations.doc(conversationId);
    batch.update(convRef, {'lastMessage': text, 'lastMessageTime': now});

    await batch.commit();
  }

  /// Create or return an existing one-on-one conversation between two users.
  Future<String> createOrGetConversation({
    required String currentUserId,
    required String otherUserId,
    required String currentUserName,
    required String otherUserName,
    String currentUserAvatar = '',
    String otherUserAvatar = '',
    bool otherUserOnline = true,
  }) async {
    final sortedIds = [currentUserId, otherUserId]..sort();
    final conversationId = 'chat_${sortedIds.join('_')}';
    final participants = List<String>.from(sortedIds);
    final convRef = _conversations.doc(conversationId);
    final now = Timestamp.now();

    await convRef.set({
      'participants': participants,
      'participantId': otherUserId,
      'participantName': otherUserName,
      'participantAvatar': otherUserAvatar,
      'isOnline': otherUserOnline,
      'userMeta': {
        currentUserId: {
          'name': currentUserName,
          'avatar': currentUserAvatar,
          'isOnline': false,
        },
        otherUserId: {
          'name': otherUserName,
          'avatar': otherUserAvatar,
          'isOnline': otherUserOnline,
        },
      },
      'lastMessage': '',
      'lastMessageTime': now,
      'isAI': false,
    }, SetOptions(merge: true));

    return conversationId;
  }

  // ── AI conversation messages (stored under 'ai_assistant' convo) ──────────

  Stream<List<MessageModel>> aiMessagesStream(String userId) {
    final convId = 'ai_$userId';
    return _messages(convId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessageModel.fromDoc(d)).toList());
  }

  Future<void> sendAiMessage({
    required String userId,
    required String senderId,
    required String text,
  }) async {
    final convId = 'ai_$userId';
    final now = Timestamp.now();

    final convRef = _conversations.doc(convId);
    final msgRef = _messages(convId).doc();

    final batch = _db.batch();

    // Upsert conversation doc in case it doesn't exist yet
    batch.set(convRef, {
      'participantId': 'ai',
      'participantName': 'AI Assistant',
      'participantAvatar': '',
      'lastMessage': text,
      'lastMessageTime': now,
      'isOnline': true,
      'isAI': true,
      'participants': [userId, 'ai'],
    }, SetOptions(merge: true));

    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': now,
      'isRead': false,
    });

    await batch.commit();
  }
}
