import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Models/conversation_model.dart';
import '../messaging_service.dart';
import '../widgets/conversation_tile.dart';
import 'chat_screen.dart';

class InboxScreen extends StatelessWidget {
  /// The currently logged-in user's uid (pass from your auth state).
  final String currentUserId;

  const InboxScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final service = MessagingService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, color: Colors.grey),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Pinned AI Tile ─────────────────────────────────────────────
          ConversationTile(
            conversation: aiConversation,
            isPinned: true,
            onTap: () => _openChat(context, aiConversation),
          ),

          // ── Section header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'RECENT CONVERSATIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),

          // ── Firestore conversations list ───────────────────────────────
          Expanded(
            child: StreamBuilder<List<ConversationModel>>(
              stream: service.conversationsStream(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final convs = snapshot.data ?? [];
                if (convs.isEmpty) {
                  return Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: convs.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.grey.shade100,
                    indent: 78,
                  ),
                  itemBuilder: (context, i) {
                    final conv = convs[i];
                    return ConversationTile(
                      conversation: conv,
                      onTap: () => _openChat(context, conv),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, ConversationModel conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(conversation: conv, currentUserId: currentUserId),
      ),
    );
  }
}
