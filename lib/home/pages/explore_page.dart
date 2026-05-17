import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Providers/PlaceProvider.dart';
import '../../Models/place_model.dart';
import '../../Models/user_model.dart' as user_model;
import '../../Models/conversation_model.dart';
import '../../messaging/messaging_service.dart';
import '../../services/chat_settings_service.dart';
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
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discover new places',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Browse trending spots and refine your search by budget or mood.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Price range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', r'$', r'$$', r'$$$', r'$$$$']
                          .map((price) {
                        final isSelected = provider.selectedPrice == price;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: ChoiceChip(
                            label: Text(price),
                            selected: isSelected,
                            selectedColor: Colors.black,
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                            onSelected: (selected) {
                              provider.setPriceRange(selected ? price : 'All');
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Explore categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: categories.map((category) {
                      final isSelected = provider.selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        selectedColor: Colors.black,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.grey.shade300,
                        ),
                        onSelected: (_) => provider.setCategory(
                          isSelected ? 'All' : category,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  if (provider.filteredPlaces.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No places match your filters yet. Try another category or price range.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    )
                  else
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
                          rating: place.rating.toStringAsFixed(1),
                          imageUrl: place.imageUrl,
                          onMapTap: () => _openOnMap(place),
                          onChatTap: () => _openChatWithAuthor(place),
                        );
                      },
                    ),
                ],
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
    required VoidCallback onMapTap,
    required VoidCallback onChatTap,
  }) {
    return Material(
      elevation: 0.8,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    place.category,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildCardButton(
                  'View on map',
                  Icons.location_on_outlined,
                  onMapTap,
                ),
                const SizedBox(width: 10),
                _buildCardButton(
                  'Chat owner',
                  Icons.chat_bubble_outline,
                  onChatTap,
                ),
              ],
            ),
          ],
        ),
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
              Icon(icon, size: 18, color: Colors.black54),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
