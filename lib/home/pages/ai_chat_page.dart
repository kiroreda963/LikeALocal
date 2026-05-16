import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiRecommendationService _aiService = AiRecommendationService();

  final UserTasteProfile _profile = UserTasteProfile();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Would you like a fancy dinner recommendation ?',
      fromUser: false,
      timestamp: DateTime(2026, 5, 11, 11, 40),
    ),
  ];

  bool _isThinking = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = (quickText ?? _messageController.text).trim();
    if (text.isEmpty || _isThinking) return;

    _messageController.clear();
    _profile.learnFrom(text);

    setState(() {
      _messages.add(ChatMessage(text: text, fromUser: true));
      _isThinking = true;
    });
    _scrollToBottom();

    final reply = await _aiService.recommend(
      userMessage: text,
      profile: _profile,
      history: _messages,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: reply, fromUser: false));
      _isThinking = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEDEDED),
      child: Column(
        children: [
          const _AiHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 18),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isThinking && index == _messages.length) {
                  return const _TypingBubble();
                }
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),
          _SmartSuggestions(onTap: _sendMessage),
          _MessageComposer(
            controller: _messageController,
            enabled: !_isThinking,
            onSend: () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}

class _AiHeader extends StatelessWidget {
  const _AiHeader();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.black54, width: 1)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 28),
              onPressed: () => Navigator.maybePop(context),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundImage: NetworkImage(
                    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120',
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF111111),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'AI Assistant',
                    style: TextStyle(
                      color: Color(0xFF143C23),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'online',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 25),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.fromUser ? Colors.black : Colors.white;
    final textColor = message.fromUser ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: message.fromUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.fromUser) const _SmallAvatar(),
              if (!message.fromUser) const SizedBox(width: 6),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 245),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(14),
                    border: message.fromUser
                        ? null
                        : Border.all(color: Colors.black, width: 1),
                    boxShadow: message.fromUser
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: EdgeInsets.only(
              left: message.fromUser ? 0 : 42,
              right: message.fromUser ? 8 : 0,
            ),
            child: Text(
              message.timeLabel,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 10,
      backgroundImage: NetworkImage(
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _SmallAvatar(),
          SizedBox(width: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(14)),
              border: Border.fromBorderSide(BorderSide(color: Colors.black)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Text('Thinking...', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartSuggestions extends StatelessWidget {
  final ValueChanged<String> onTap;

  const _SmartSuggestions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Cheap cozy dinner',
      'Quiet hidden gems',
      'Outdoor coffee',
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final text = suggestions[index];
          return ActionChip(
            label: Text(text),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onPressed: () => onTap(text),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: suggestions.length,
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(23, 10, 15, 10),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 39,
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFEFEFEF),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            IconButton(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send_outlined, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class AiRecommendationService {
  Future<String> recommend({
    required String userMessage,
    required UserTasteProfile profile,
    required List<ChatMessage> history,
  }) async {
    final recentContext = history
        .take(history.isEmpty ? 0 : history.length - 1)
        .map((message) => '${message.fromUser ? 'User' : 'Assistant'}: ${message.text}')
        .join('\n');

    final prompt = '''
You are LikeALocal's AI Assistant. Recommend local places in a concise,
friendly chat style. Personalize using this learned profile:
${profile.summary}

Recent chat:
$recentContext

User message: $userMessage

Give 2-3 specific recommendations. Include why it fits their style,
expected budget/atmosphere when relevant, and one follow-up question.
''';

    try {
      final response = await http.get(
        Uri.parse(
          'https://gen.pollinations.ai/text/${Uri.encodeComponent(prompt)}?model=openai',
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final reply = response.body.trim();
        if (reply.isNotEmpty) return reply;
      }
    } catch (_) {
      return _fallbackRecommendation(userMessage, profile);
    }

    return _fallbackRecommendation(userMessage, profile);
  }

  String _fallbackRecommendation(String message, UserTasteProfile profile) {
    final atmosphere = profile.atmosphere ?? 'cozy';
    final budget = profile.budget ?? 'medium budget';
    final placeType = profile.placeType ?? 'hidden gems';

    return 'I learned you lean toward $atmosphere $placeType with a $budget. '
        'Try Arcade Hub for a playful stop, Asian County for a low-key dinner, '
        'or Smart Gym if you want something active nearby. Want me to narrow it '
        'by distance, food, or mood?';
  }
}

class UserTasteProfile {
  String? placeType;
  String? budget;
  String? atmosphere;

  void learnFrom(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('food') ||
        lower.contains('dinner') ||
        lower.contains('coffee') ||
        lower.contains('restaurant')) {
      placeType = 'food and drink spots';
    } else if (lower.contains('gym') || lower.contains('active')) {
      placeType = 'active places';
    } else if (lower.contains('hidden') || lower.contains('local')) {
      placeType = 'hidden gems';
    }

    if (lower.contains('cheap') ||
        lower.contains('budget') ||
        lower.contains('affordable')) {
      budget = 'low budget';
    } else if (lower.contains('fancy') || lower.contains('premium')) {
      budget = 'premium budget';
    }

    if (lower.contains('quiet') || lower.contains('calm')) {
      atmosphere = 'quiet';
    } else if (lower.contains('cozy') || lower.contains('romantic')) {
      atmosphere = 'cozy';
    } else if (lower.contains('fun') || lower.contains('lively')) {
      atmosphere = 'lively';
    }
  }

  String get summary {
    return [
      if (placeType != null) 'preferred place type: $placeType',
      if (budget != null) 'budget: $budget',
      if (atmosphere != null) 'atmosphere: $atmosphere',
      if (placeType == null && budget == null && atmosphere == null)
        'no strong preferences learned yet',
    ].join(', ');
  }
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.fromUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get timeLabel {
    final hour = timestamp.hour == 0
        ? 12
        : timestamp.hour > 12
            ? timestamp.hour - 12
            : timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
