import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Models/place_model.dart';
import '../../Models/user_model.dart' as user_model;
import '../../Models/conversation_model.dart';
import '../../messaging/messaging_service.dart';
import '../../services/chat_settings_service.dart';
import '../../Providers/PlaceProvider.dart';
import '../../messaging/pages/chat_screen.dart';
import '../../auth/auth_provider.dart' as local_auth;

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlacesProvider>().fetchPlaces();
    });
  }

  void _openOnMap(Place place) {
    context.read<PlacesProvider>().openPlaceOnMap(place);
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<Map<String, String>> _fetchUserMeta(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final data = userDoc.data() ?? {};
    return {
      'name': (data['name'] as String?)?.trim() ?? 'User',
      'avatar': (data['photoUrl'] as String?) ?? '',
    };
  }

  Future<void> _openChatWithAuthor(Place place) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to chat with the post owner'),
        ),
      );
      return;
    }

    final currentUser =
        await context.read<local_auth.AuthProvider>().getAllUserInfo() ??
        user_model.User(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'You',
          email: firebaseUser.email ?? '',
          phoneNumber: '',
          photoUrl: firebaseUser.photoURL,
        );

    if (place.authorId == currentUser.uid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't chat with yourself")),
      );
      return;
    }
    if (place.authorId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open chat for this place'),
        ),
      );
      return;
    }

    final authorMeta = await _fetchUserMeta(place.authorId);

    final blockReason = await ChatSettingsService().getMessagingBlockReason(
      place.authorId,
    );
    if (blockReason != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blockReason)),
      );
      return;
    }

    final service = MessagingService();
    final conversationId = await service.createOrGetConversation(
      currentUserId: currentUser.uid,
      otherUserId: place.authorId,
      currentUserName: currentUser.name.isNotEmpty ? currentUser.name : 'You',
      otherUserName: authorMeta['name'] ?? 'User',
      currentUserAvatar: currentUser.photoUrl ?? '',
      otherUserAvatar: authorMeta['avatar'] ?? '',
      otherUserOnline: true,
    );

    final convDoc = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (!convDoc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open chat conversation')),
      );
      return;
    }

    final conversation = ConversationModel.fromDoc(convDoc, currentUser.uid);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: conversation,
          currentUserId: currentUser.uid,
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();
    final categories = [
      'Top Rated',
      'Trending Now',
      'Feeling Hungry',
      'Looking for a Breeze',
      'Up Late?',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Explore',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [

              const Center(
                child: Text("Price Range", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['All', r'$', r'$$', r'$$$',r'$$$$'].map((price) {
                  final isSelected = provider.selectedPrice == price;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(price),
                      selected: isSelected,
                      selectedColor: Colors.grey.shade400,
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (bool selected) {
                        provider.setPriceRange(selected ? price : 'All');
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: 5,
                itemBuilder: (context, index) {
                  final categories = [
                    'Top Rated', 'Trending Now',
                    'Feeling Hungry', 'Looking for a Breeze',
                    'Up Late?'
                  ];
                  final category = categories[index];
                  final isSelected = provider.selectedCategory == category;

                  return InkWell(
                    onTap: () => provider.setCategory(isSelected ? 'All' : category),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.grey.shade400 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.filteredPlaces.length,
                itemBuilder: (context, index) {
                  final place = provider.filteredPlaces[index];
                  return _buildPlaceCard(
                    place: place,
                    name: place.placeName,
                    description: place.description,
                    rating: place.rating.toString(),
                    imageUrl: place.imageUrl,
                    longitude: place.longitude,
                    latitude: place.latitude,
                    locationUrl: 'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceCard({
    required Place place,
    required String name,
    required String description,
    required String rating,
    required String imageUrl,
    required String locationUrl,
    required double longitude,
    required double latitude,

  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // FIX: Wrap Title in Expanded to prevent the "Yellow Stripes" overflow
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.stars, size: 20, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              // THE ICON: Fetching the imageUrl from Firebase as a small thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(width: 60, height: 60, color: Colors.grey[200]),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCardButton('Look \nOn maps', Icons.location_on_outlined, () => _openOnMap(place)),
              const SizedBox(width: 8),
              _buildCardButton('Chat with Post Owner', Icons.chat_bubble_outline, () => _openChatWithAuthor(place)),
            ],
          )],
              ),
    );
  }

  Widget _buildCardButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Icon(icon, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
