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

  factory ConversationModel.fromDoc(
    DocumentSnapshot doc,
    String currentUserId,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationModel.fromMap(data, doc.id, currentUserId);
  }

  /// Resolves the correct other-participant from [data] relative to
  /// [currentUserId]. Works whether the doc was created by the current user
  /// or the other user, and whether or not [userMeta] is present.
  factory ConversationModel.fromMap(
    Map<String, dynamic> data,
    String docId,
    String currentUserId,
  ) {
    final isAI = data['isAI'] as bool? ?? false;

    // ── AI conversation: no userMeta, just use stored fields ──────────────
    if (isAI) {
      return ConversationModel(
        id: docId,
        participantId: data['participantId'] as String? ?? 'ai',
        participantName: data['participantName'] as String? ?? 'AI Assistant',
        participantAvatar: data['participantAvatar'] as String? ?? '',
        lastMessage: data['lastMessage'] as String? ?? '',
        lastMessageTime:
            data['lastMessageTime'] as Timestamp? ?? Timestamp.now(),
        isOnline: data['isOnline'] as bool? ?? true,
        isAI: true,
      );
    }

    // ── Regular conversation: resolve other participant from userMeta ──────
    final participants = List<String>.from(
      (data['participants'] as List?) ?? [],
    );

    // Always pick the uid that is NOT the current user.
    final otherId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => data['participantId'] as String? ?? '',
    );

    // userMeta is the authoritative source for name/avatar/online status.
    // Fall back to top-level fields only for legacy docs without userMeta,
    // and only when those fields actually point to the other user (not us).
    final userMeta = data['userMeta'] as Map<String, dynamic>?;
    final otherMeta = userMeta?[otherId] as Map<String, dynamic>?;

    final storedParticipantId = data['participantId'] as String? ?? '';
    // Top-level participantName/Avatar are valid only if they point to otherId.
    // If they point to the current user (written by the other side), ignore them.
    final topLevelIsOther = storedParticipantId == otherId;

    final participantName =
        otherMeta?['name'] as String? ??
        (topLevelIsOther ? data['participantName'] as String? ?? '' : '');

    final participantAvatar =
        otherMeta?['avatar'] as String? ??
        (topLevelIsOther ? data['participantAvatar'] as String? ?? '' : '');

    final isOnline =
        otherMeta?['isOnline'] as bool? ??
        (topLevelIsOther ? data['isOnline'] as bool? ?? false : false);

    return ConversationModel(
      id: docId,
      participantId: otherId,
      participantName: participantName,
      participantAvatar: participantAvatar,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageTime: data['lastMessageTime'] as Timestamp? ?? Timestamp.now(),
      isOnline: isOnline,
      isAI: false,
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
