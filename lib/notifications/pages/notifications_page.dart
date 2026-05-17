import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../Models/conversation_model.dart';
import '../../Models/place_model.dart';
import '../../services/place_service.dart';
import '../../Providers/PlaceProvider.dart';
import '../../messaging/pages/chat_screen.dart';
import '../../profile/pages/friends_groups_page.dart';

enum NotificationType {
  newPlace,
  message,
  review,
  superUser,
  nearbyPlace,
  friendRequest,
}

class NotificationEntry {
  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final DateTime createdAt;

  NotificationEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<NotificationEntry> _notifications = [];

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
      _notifications = [];
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please sign in to view notifications.';
          _loading = false;
        });
        return;
      }

      final entries = <NotificationEntry>[];
      entries.addAll(await _fetchSuperUserNotification(user.uid));
      entries.addAll(await _fetchMessageNotifications(user.uid));
      entries.addAll(await _fetchFriendRequestNotifications(user.uid));
      entries.addAll(await _fetchReviewNotifications(user.uid));
      entries.addAll(await _fetchNearbyPlaceNotification(user.uid));
      entries.addAll(await _fetchNewPlaceNotifications());

      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _notifications = entries;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load notifications.';
        _loading = false;
      });
    }
  }

  Future<List<NotificationEntry>> _fetchNewPlaceNotifications() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('places')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    return snapshot.docs.map((doc) {
      final place = Place.fromMap(doc.data(), doc.id);
      final time = place.createdAt.toLocal();
      return NotificationEntry(
        id: 'new_place_${place.id}',
        type: NotificationType.newPlace,
        title: 'New place added',
        subtitle: '${place.placeName} was added recently.',
        createdAt: time,
      );
    }).toList();
  }

  Future<List<NotificationEntry>> _fetchMessageNotifications(
    String userId,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .limit(10)
        .get();

    final entries = <NotificationEntry>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lastSenderId = data['lastSenderId'] as String?;
      final isAI = data['isAI'] as bool? ?? false;
      final lastMessage = (data['lastMessage'] as String?)?.trim() ?? '';
      if (lastMessage.isEmpty || isAI || lastSenderId == null) continue;
      if (lastSenderId == userId) continue;

      final conversation = ConversationModel.fromDoc(doc, userId);
      entries.add(
        NotificationEntry(
          id: 'message_${doc.id}',
          type: NotificationType.message,
          title: 'New message from ${conversation.participantName}',
          subtitle: lastMessage,
          createdAt: conversation.lastMessageTime.toDate().toLocal(),
        ),
      );
    }

    return entries;
  }

  Future<List<NotificationEntry>> _fetchFriendRequestNotifications(
    String userId,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    final entries = <NotificationEntry>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final senderId = data['senderId'] as String?;
      if (senderId == null) continue;

      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      final senderData = senderDoc.data() as Map<String, dynamic>?;
      final senderName = senderData?['name'] as String? ?? 'A friend';

      final rawCreatedAt = data['createdAt'];
      final createdAt = rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate().toLocal()
          : DateTime.now();

      entries.add(
        NotificationEntry(
          id: 'friend_request_${doc.id}',
          type: NotificationType.friendRequest,
          title: 'Friend request from $senderName',
          subtitle: 'Tap to manage pending requests.',
          createdAt: createdAt,
        ),
      );
    }

    return entries;
  }

  Future<List<NotificationEntry>> _fetchReviewNotifications(
    String userId,
  ) async {
    final placeSnapshot = await FirebaseFirestore.instance
        .collection('places')
        .where('authorId', isEqualTo: userId)
        .get();

    if (placeSnapshot.docs.isEmpty) return [];

    final entries = <NotificationEntry>[];
    for (final placeDoc in placeSnapshot.docs) {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('places')
          .doc(placeDoc.id)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      if (reviewsSnapshot.docs.isEmpty) continue;
      final place = Place.fromMap(placeDoc.data(), placeDoc.id);
      for (final reviewDoc in reviewsSnapshot.docs) {
        final rawCreatedAt = reviewDoc.data()['createdAt'];
        final time = rawCreatedAt is Timestamp
            ? rawCreatedAt.toDate().toLocal()
            : DateTime.now();
        final authorName =
            (reviewDoc.data()['userName'] as String?)?.trim() ?? 'Someone';
        final reviewText =
            (reviewDoc.data()['reviewText'] as String?)?.trim() ?? '';
        entries.add(
          NotificationEntry(
            id: 'review_${place.id}_${reviewDoc.id}',
            type: NotificationType.review,
            title: 'New review for ${place.placeName}',
            subtitle:
                '$authorName wrote: ${reviewText.isEmpty ? 'A new review was added.' : reviewText}',
            createdAt: time,
          ),
        );
      }
    }

    return entries;
  }

  Future<List<NotificationEntry>> _fetchSuperUserNotification(
    String userId,
  ) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final addedPlaces = List<String>.from(userDoc.data()?['addedPlaces'] ?? []);
    final reviewSnapshot = await FirebaseFirestore.instance
        .collectionGroup('reviews')
        .where('userId', isEqualTo: userId)
        .get();

    final reviewCount = reviewSnapshot.docs.length;
    final isSuperUser = addedPlaces.length >= 4 && reviewCount >= 5;
    if (!isSuperUser) return [];

    return [
      NotificationEntry(
        id: 'super_user_$userId',
        type: NotificationType.superUser,
        title: 'Super User unlocked!',
        subtitle:
            'You have added ${addedPlaces.length} places and written $reviewCount reviews.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<List<NotificationEntry>> _fetchNearbyPlaceNotification(
    String userId,
  ) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return [];
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return [];
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (!mounted) {
      return [];
    }

    final currentLocation = LatLng(position.latitude, position.longitude);
    final placesProvider = Provider.of<PlacesProvider>(context, listen: false);
    List<Place> places = placesProvider.places;
    if (places.isEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('places')
          .get();
      places = snapshot.docs
          .map((doc) => Place.fromMap(doc.data(), doc.id))
          .toList();
    }

    if (places.isEmpty) return [];

    Place? closest;
    double? closestDistance;

    for (final place in places) {
      final placeLocation = LatLng(place.latitude, place.longitude);
      final distance = PlaceService.calculateDistance(
        currentLocation,
        placeLocation,
      );
      if (closestDistance == null || distance < closestDistance) {
        closestDistance = distance;
        closest = place;
      }
    }

    if (closest == null || closestDistance == null || closestDistance > 5.0) {
      return [];
    }

    return [
      NotificationEntry(
        id: 'nearby_place_${closest.id}',
        type: NotificationType.nearbyPlace,
        title: 'You are nearby ${closest.placeName}',
        subtitle:
            'Only ${PlaceService.formatDistance(closestDistance)} away from a nearby spot.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.chat_bubble_outline;
      case NotificationType.review:
        return Icons.rate_review;
      case NotificationType.superUser:
        return Icons.star;
      case NotificationType.nearbyPlace:
        return Icons.location_on;
      case NotificationType.newPlace:
        return Icons.place;
      case NotificationType.friendRequest:
        return Icons.person_add;
    }
  }

  String _formatTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black87),
              onPressed: _refreshNotifications,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'You have no new notifications yet. Check back after a new place is added, a message arrives, or when someone reviews your place.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: Icon(
                _iconForType(notification.type),
                color: Colors.black87,
              ),
            ),
            title: Text(notification.title),
            subtitle: Text(notification.subtitle),
            trailing: Text(
              _formatTime(notification.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            onTap: () async {
              final parts = notification.id.split('_');
              final type = notification.type;

              if (type == NotificationType.message) {
                final conversationId = parts.last;
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: conversationId,
                        currentUserId: user.uid,
                      ),
                    ),
                  );
                }
              } else if (type == NotificationType.newPlace ||
                  type == NotificationType.nearbyPlace) {
                final placeId = parts.last;
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
              } else if (type == NotificationType.friendRequest) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsGroupsPage()),
                );
              } else if (type == NotificationType.review) {
                final placeId = parts[1]; // review_{placeId}_{reviewId}
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
            },
          );
        },
      ),
    );
  }
}
