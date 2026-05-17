import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // for navigatorKey
import '../messaging/pages/chat_screen.dart';
import '../profile/pages/friends_groups_page.dart';
import '../Providers/PlaceProvider.dart';

class MessageNotificationService {
  MessageNotificationService._();
  static final MessageNotificationService instance =
      MessageNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _friendRequestSubscription;
  final Map<String, Timestamp> _lastNotifiedByConversation = {};
  final Set<String> _notifiedFriendRequests = {};
  bool _initialized = false;
  bool _skipInitialSnapshot = true;
  bool _skipInitialFriendRequestSnapshot = true;
  String? _listeningUserId;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint('Error handling notification click: $e');
          }
        }
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'] as String?;
    if (type == 'message') {
      final conversationId = data['conversationId'] as String?;
      final userId = _listeningUserId;
      if (conversationId != null && userId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              currentUserId: userId,
            ),
          ),
        );
      }
    } else if (type == 'place_added' || type == 'nearby') {
      final placeId = data['placeId'] as String?;
      if (placeId != null) {
        final placesProvider = Provider.of<PlacesProvider>(
          context,
          listen: false,
        );
        final place = placesProvider.places
            .where((p) => p.id == placeId)
            .firstOrNull;
        if (place != null) {
          placesProvider.openPlaceOnMap(place);
        }
      }
    } else if (type == 'friend_request') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FriendsGroupsPage()),
      );
    } else if (type == 'new_review') {
      final placeId = data['placeId'] as String?;
      if (placeId != null) {
        final placesProvider = Provider.of<PlacesProvider>(
          context,
          listen: false,
        );
        final place = placesProvider.places
            .where((p) => p.id == placeId)
            .firstOrNull;
        if (place != null) {
          placesProvider.openReviewsOnMap(place);
        }
      }
    }
  }

  void startListening(String userId) {
    if (_listeningUserId == userId && _subscription != null) return;

    stopListening();
    _listeningUserId = userId;
    _skipInitialSnapshot = true;
    _lastNotifiedByConversation.clear();

    _subscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen(
          _onConversationsUpdate,
          onError: (Object e) {
            debugPrint('Message notification listener error: $e');
          },
        );

    _friendRequestSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          _onFriendRequestsUpdate,
          onError: (Object e) {
            debugPrint('Friend request notification listener error: $e');
          },
        );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _friendRequestSubscription?.cancel();
    _friendRequestSubscription = null;
    _listeningUserId = null;
    _notifiedFriendRequests.clear();
  }

  void _onConversationsUpdate(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (_skipInitialSnapshot) {
      _skipInitialSnapshot = false;
      for (final doc in snapshot.docs) {
        final time = doc.data()['lastMessageTime'] as Timestamp?;
        if (time != null) {
          _lastNotifiedByConversation[doc.id] = time;
        }
      }
      return;
    }

    final userId = _listeningUserId;
    if (userId == null) return;

    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;

      final doc = change.doc;
      final data = doc.data();
      if (data == null) continue;
      if (data['isAI'] as bool? ?? false) continue;

      final lastSenderId = data['lastSenderId'] as String?;
      if (lastSenderId == null || lastSenderId == userId) continue;

      final lastTime = data['lastMessageTime'] as Timestamp?;
      if (lastTime == null) continue;

      final previous = _lastNotifiedByConversation[doc.id];
      if (previous != null && lastTime.compareTo(previous) <= 0) continue;

      _lastNotifiedByConversation[doc.id] = lastTime;

      final senderName = _senderDisplayName(data, userId);
      final preview = (data['lastMessage'] as String?)?.trim() ?? 'New message';

      _showNotification(
        id: doc.id.hashCode,
        title: senderName,
        body: preview,
        payload: jsonEncode({'type': 'message', 'conversationId': doc.id}),
      );
    }
  }

  void _onFriendRequestsUpdate(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (_skipInitialFriendRequestSnapshot) {
      _skipInitialFriendRequestSnapshot = false;
      for (final doc in snapshot.docs) {
        _notifiedFriendRequests.add(doc.id);
      }
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final doc = change.doc;
      if (_notifiedFriendRequests.contains(doc.id)) continue;

      final data = doc.data();
      if (data == null) continue;
      final senderId = data['senderId'] as String?;
      if (senderId == null) continue;

      _notifiedFriendRequests.add(doc.id);

      FirebaseFirestore.instance.collection('users').doc(senderId).get().then((
        userDoc,
      ) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final senderName = userData?['name'] as String? ?? 'Someone';
        _showNotification(
          id: doc.id.hashCode,
          title: 'Friend request received',
          body: '$senderName sent you a friend request.',
          payload: jsonEncode({'type': 'friend_request'}),
        );
      });
    }
  }

  String _senderDisplayName(Map<String, dynamic> data, String currentUserId) {
    final userMeta = data['userMeta'] as Map<String, dynamic>?;
    if (userMeta != null) {
      for (final entry in userMeta.entries) {
        if (entry.key != currentUserId) {
          final meta = entry.value as Map<String, dynamic>?;
          final name = meta?['name'] as String?;
          if (name != null && name.isNotEmpty) return name;
        }
      }
    }
    return data['participantName'] as String? ?? 'New message';
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
