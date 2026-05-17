import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../Providers/PlaceProvider.dart';
import '../../Models/place_model.dart';


class FavoritePlacesPage extends StatelessWidget {
  const FavoritePlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final provider = context.read<PlacesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorite Places')),
      body: user == null
          ? const Center(
              child: Text('Please log in to view your favorite places.'),
            )
          : FutureBuilder<List<Place>>(
              future: provider.getFavorites(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load favorites: ${snapshot.error}'),
                  );
                }

                final favorites = snapshot.data ?? [];
                if (favorites.isEmpty) {
                  return const Center(
                    child: Text('No favorite places yet.'),
                  );
                }

                return ListView.separated(
                  itemCount: favorites.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = favorites[index];
                   return ListTile(
  leading: const Icon(Icons.favorite, color: Colors.red),
  title: Text(place.placeName),
  subtitle: Text(place.category),
  onTap: () {
    provider.openPlaceOnMap(place);

    Navigator.pop(context);
  },
);
                  },
                );
              },
            ),
    );
  }
}
