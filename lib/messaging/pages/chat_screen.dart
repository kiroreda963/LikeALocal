import 'package:flutter/material.dart';
import '../../Models/conversation_model.dart';
import '../../Models/message_model.dart';
import '../messaging_service.dart';
import '../Widgets/avatar_widget.dart';
import '../Widgets/message_bubble.dart';
import '../Widgets/message_input_bar.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final MessagingService _service = MessagingService();

  bool get _isAI => widget.conversation.isAI;

  Stream<List<MessageModel>> get _messageStream => _isAI
      ? _service.aiMessagesStream(widget.currentUserId)
      : _service.messagesStream(widget.conversation.id);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    if (_isAI) {
      await _service.sendAiMessage(
        userId: widget.currentUserId,
        senderId: widget.currentUserId,
        text: text,
      );
    } else {
      await _service.sendMessage(
        conversationId: widget.conversation.id,
        senderId: widget.currentUserId,
        text: text,
      );
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: Column(
        children: [
          // ── Chat App Bar ───────────────────────────────────────────────
          _ChatAppBar(conversation: widget.conversation),

          // ── Messages ───────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isNotEmpty) _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMine = msg.senderId == widget.currentUserId;
                    // Show avatar only on first message or when sender changes
                    final showAvatar =
                        !isMine &&
                        (i == 0 || messages[i - 1].senderId != msg.senderId);
                    return MessageBubble(
                      text: msg.text,
                      isMine: isMine,
                      timestamp: msg.timestamp,
                      senderAvatar: isMine
                          ? null
                          : widget.conversation.participantAvatar,
                      showAvatar: showAvatar,
                    );
                  },
                );
              },
            ),
          ),

          // ── Input Bar ──────────────────────────────────────────────────
          MessageInputBar(onSend: _send),
        ],
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget {
  final ConversationModel conversation;

  const _ChatAppBar({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 8,
        right: 16,
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: Colors.black87,
          ),
          // Avatar
          AvatarWidget(
            imageUrl: conversation.participantAvatar,
            name: conversation.participantName,
            size: 42,
            showOnlineIndicator: true,
            isOnline: conversation.isOnline,
            isAI: conversation.isAI,
          ),
          const SizedBox(width: 10),
          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.participantName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  conversation.isOnline ? 'online' : 'offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: conversation.isOnline
                        ? const Color(0xFF4CAF50)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Settings icon
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
