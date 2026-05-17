import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Providers/PlaceProvider.dart';
import './edit_profile_page.dart';
import './favorite_places_page.dart';
import './saved_places_page.dart';
import './chat_settings_page.dart';
import './friends_groups_page.dart';
import '../../subscription/pages/subscription_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final displayName = data?['name'] ?? user?.email ?? 'User';
              final profileBio = data?['bio'] ?? '';
              final photoUrl = data?['photoUrl'] ?? '';

              return Column(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.black12,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isNotEmpty
                          ? null
                          : const Icon(
                              Icons.person,
                              size: 55,
                              color: Colors.black,
                            ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Center(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Center(
                    child: Text(
                      profileBio.isNotEmpty
                          ? profileBio
                          : 'Traveler & Explorer',
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('reviews')
                    .where('userId', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, reviewsSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting ||
                      reviewsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 18.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;
                  final addedCount =
                      (userData?['addedPlaces'] as List?)?.length ?? 0;
                  final favoriteCount =
                      (userData?['favoredPlaces'] as List?)?.length ?? 0;
                  final reviewCount = reviewsSnapshot.data?.docs.length ?? 0;

                  final isSuperUser = addedCount >= 4 && reviewCount >= 5;

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSuperUser
                                    ? Colors.amber.shade100
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSuperUser
                                        ? Icons.verified_rounded
                                        : Icons.rocket_launch_rounded,
                                    color: isSuperUser
                                        ? Colors.amber.shade800
                                        : Colors.blue.shade800,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isSuperUser
                                        ? 'Super User'
                                        : 'Active Explorer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSuperUser
                                          ? Colors.amber.shade800
                                          : Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildActivityStat('Places added', '$addedCount'),
                            _buildActivityStat('Reviews', '$reviewCount'),
                            _buildActivityStat('Favorites', '$favoriteCount'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isSuperUser
                              ? 'You have added $addedCount places and written $reviewCount reviews. Great work!'
                              : 'Add more places and reviews to unlock the Super User badge.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 30),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),

            child: Column(
              children: [
                _buildTile(
                  context,
                  icon: Icons.edit,
                  title: "Edit Profile",
                  page: const EditProfilePage(),
                ),
                _divider(),
                _buildTile(
                  context,
                  icon: Icons.people_outline,
                  title: "Friends & Groups",
                  page: const FriendsGroupsPage(),
                ),

                _divider(),

                _buildTile(
                  context,
                  icon: Icons.favorite_border,
                  title: "Favorite Places",
                  page: const FavoritePlacesPage(),
                ),

                _divider(),

                _buildTile(
                  context,
                  icon: Icons.bookmark_border,
                  title: "My Places",
                  page: const SavedPlacesPage(),
                ),

                _divider(),

                _buildTile(
                  context,
                  icon: Icons.chat_outlined,
                  title: "Chat & Privacy",
                  page: const ChatSettingsPage(),
                ),
                _divider(),
                _buildTile(
                  context,
                  icon: Icons.workspace_premium,
                  title: "Subscriptions",
                  page: const SubscriptionPage(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),

            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              Navigator.pushReplacementNamed(context, '/auth');
            },

            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 20, endIndent: 20);
  }
}
