import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../Models/message_model.dart';
import '../../Models/place_model.dart';
import '../../Providers/PlaceProvider.dart';
import '../../messaging/messaging_service.dart';
import '../../services/ai_recommendation_service.dart';
import '../../services/place_service.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiRecommendationService _aiService = AiRecommendationService();
  final MessagingService _messagingService = MessagingService();
  PlacesProvider? _placesProvider;

  final UserTasteProfile _profile = UserTasteProfile();
  UserPlaceContext _placeContext = const UserPlaceContext();

  LatLng? _currentLocation;
  String? _userId;
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _placesProvider = context.read<PlacesProvider>();
      _placesProvider!.addListener(_onPlacesUpdated);
      await _loadCurrentLocation();
      await _loadUserPlaces();
      final userId = _userId;
      if (userId != null) {
        await _messagingService.ensureAiWelcomeMessage(userId);
      }
    });
  }

  void _onPlacesUpdated() {
    final catalog = context.read<PlacesProvider>().places;
    if (catalog.isEmpty || !mounted) return;

    setState(() {
      _placeContext = _buildPlaceContext(
        favorites: _placeContext.favorites,
        myPlaces: _placeContext.myPlaces,
        catalog: catalog,
      );
    });
  }

  Future<void> _loadUserPlaces() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final placesProvider = context.read<PlacesProvider>();

    if (placesProvider.places.isEmpty) {
      placesProvider.fetchPlaces();
    }

    var favorites = <Place>[];
    var myPlaces = <Place>[];

    if (user != null) {
      favorites = await placesProvider.getFavorites(user.uid);
      myPlaces = await placesProvider.getUserAddedPlaces(user.uid);
    }

    if (!mounted) return;

    final catalog = placesProvider.places;

    setState(() {
      _placeContext = _buildPlaceContext(
        favorites: favorites,
        myPlaces: myPlaces,
        catalog: catalog,
      );
    });
  }

  UserPlaceContext _buildPlaceContext({
    required List<Place> favorites,
    required List<Place> myPlaces,
    required List<Place> catalog,
  }) {
    final distances = <String, String>{};
    if (_currentLocation != null) {
      for (final place in {...favorites, ...myPlaces, ...catalog}) {
        distances[place.id] = PlaceService.formatDistance(
          PlaceService.calculateDistance(
            _currentLocation!,
            LatLng(place.latitude, place.longitude),
          ),
        );
      }
    }

    return UserPlaceContext(
      favorites: favorites,
      myPlaces: myPlaces,
      catalog: catalog,
      placeDistances: distances,
      currentLocationMessage: _currentLocation != null
          ? 'Distances are approximate from your current location.'
          : '',
    );
  }

  Future<void> _loadCurrentLocation() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          if (!mounted) return;
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
      }
    } catch (_) {
      // If location is unavailable, continue without it.
    }
  }

  @override
  void dispose() {
    _placesProvider?.removeListener(_onPlacesUpdated);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(
    String text, {
    required List<MessageModel> existingMessages,
  }) async {
    final userId = _userId;
    if (text.isEmpty || _isThinking || userId == null) return;

    await _loadUserPlaces();

    _messageController.clear();
    _profile.learnFrom(text);

    setState(() => _isThinking = true);
    _scrollToBottom();

    await _messagingService.sendAiMessage(
      userId: userId,
      senderId: userId,
      text: text,
    );

    final history =
        [
              ...existingMessages,
              MessageModel(
                id: '',
                senderId: userId,
                text: text,
                timestamp: Timestamp.now(),
                isRead: false,
              ),
            ]
            .map(
              (message) => (
                role: message.senderId == userId ? 'User' : 'Assistant',
                text: message.text,
              ),
            )
            .toList();

    final reply = await _aiService.recommend(
      userMessage: text,
      profile: _profile,
      history: history,
      placeContext: _placeContext,
    );

    await _messagingService.sendAiMessage(
      userId: userId,
      senderId: MessagingService.aiSenderId,
      text: reply,
    );

    if (!mounted) return;
    setState(() => _isThinking = false);
    _scrollToBottom();
  }

  List<ChatMessage> _toChatMessages(List<MessageModel> messages) {
    final userId = _userId;
    return messages
        .map(
          (message) => ChatMessage(
            text: message.text,
            fromUser: message.senderId == userId,
            timestamp: message.timestamp.toDate(),
          ),
        )
        .toList();
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
    final userId = _userId;

    if (userId == null) {
      return _chatScaffold(
        Column(
          children: [
            const _AiHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 18),
                children: [
                  _ChatBubble(
                    message: ChatMessage(
                      text: MessagingService.aiWelcomeMessage,
                      fromUser: false,
                    ),
                  ),
                ],
              ),
            ),
            _SmartSuggestions(placeContext: _placeContext, onTap: (_) {}),
            _MessageComposer(controller: _messageController, enabled: false),
          ],
        ),
      );
    }

    return StreamBuilder<List<MessageModel>>(
      stream: _messagingService.aiMessagesStream(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _chatScaffold(
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load chat: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _chatScaffold(
            const Center(child: CircularProgressIndicator()),
          );
        }

        final stored = snapshot.data ?? [];
        final messages = _toChatMessages(stored);
        if (messages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        }

        void send(String text) => _sendMessage(text, existingMessages: stored);

        return _chatScaffold(
          Column(
            children: [
              const _AiHeader(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 18),
                  itemCount: messages.length + (_isThinking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isThinking && index == messages.length) {
                      return const _TypingBubble();
                    }
                    return _ChatBubble(message: messages[index]);
                  },
                ),
              ),
              _SmartSuggestions(placeContext: _placeContext, onTap: send),
              _MessageComposer(
                controller: _messageController,
                enabled: !_isThinking,
                onSend: () => send(_messageController.text.trim()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chatScaffold(Widget body) {
    return Scaffold(backgroundColor: const Color(0xFFEDEDED), body: body);
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
    final alignment = message.fromUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
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
  final UserPlaceContext placeContext;
  final ValueChanged<String> onTap;

  const _SmartSuggestions({required this.placeContext, required this.onTap});

  List<String> get _suggestions {
    if (placeContext.favorites.isNotEmpty) {
      final fav = placeContext.favorites.first;
      return [
        'Similar to ${fav.placeName}',
        'More ${fav.category} spots',
        'Hidden gems near my favorites',
      ];
    }
    if (placeContext.myPlaces.isNotEmpty) {
      final mine = placeContext.myPlaces.first;
      return [
        'More like ${mine.placeName}',
        'Best ${mine.category} nearby',
        'Quiet spots like my places',
      ];
    }
    return const ['Cheap cozy dinner', 'Quiet hidden gems', 'Outdoor coffee'];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final text = _suggestions[index];
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
        itemCount: _suggestions.length,
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController? controller;
  final bool enabled;
  final VoidCallback? onSend;

  const _MessageComposer({this.controller, required this.enabled, this.onSend});

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
                  onSubmitted: (_) => onSend?.call(),
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

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.fromUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

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
