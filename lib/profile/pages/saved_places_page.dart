import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../Providers/PlaceProvider.dart';
import '../../Models/place_model.dart';

class SavedPlacesPage extends StatelessWidget {
  const SavedPlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final provider = context.read<PlacesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Places')),
      body: user == null
          ? const Center(
              child: Text('Please log in to view your places.'),
            )
          : FutureBuilder<List<Place>>(
              future: provider.getUserAddedPlaces(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load places: ${snapshot.error}'),
                  );
                }

                final savedPlaces = snapshot.data ?? [];
                if (savedPlaces.isEmpty) {
                  return const Center(
                    child: Text('No places added yet.'),
                  );
                }

                return ListView.separated(
                  itemCount: savedPlaces.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = savedPlaces[index];
                    return ListTile(
                      leading: const Icon(Icons.bookmark, color: Color(0xFF143C23)),
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
