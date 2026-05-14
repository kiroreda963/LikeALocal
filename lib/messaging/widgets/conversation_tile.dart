import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Models/conversation_model.dart';
import 'avatar_widget.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final bool isPinned; // true for the AI tile at top

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isPinned = false,
  });

  String _formatTime(Timestamp ts) {
    final now = DateTime.now();
    final dt = ts.toDate();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    return 'YESTERDAY';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPinned ? const Color(0xFFF0F0F0) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              AvatarWidget(
                imageUrl: conversation.participantAvatar,
                name: conversation.participantName,
                size: 50,
                showOnlineIndicator: true,
                isOnline: conversation.isOnline,
                isAI: conversation.isAI,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          conversation.participantName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _formatTime(conversation.lastMessageTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
