import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'edit_profile_page.dart';
import 'favorite_places_page.dart';
import 'my_places_page.dart';

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
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),

          const Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.black12,
              child: Icon(
                Icons.person,
                size: 55,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 15),

          Center(
            child: Text(
              user?.email ?? "User",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 5),

          const Center(
            child: Text(
              "Traveler & Explorer",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
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
                  icon: Icons.favorite_border,
                  title: "Favourite Places",
                  page: const FavoritePlacesPage(),
                ),

                _divider(),

                _buildTile(
                  context,
                  icon: Icons.bookmark_border,
                  title: "My Places",
                  page: const MyPlacesPage(),
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
    );
  }
}