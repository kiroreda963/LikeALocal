import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Models/place_model.dart';

class MyPlacesPage extends StatelessWidget {
  const MyPlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Places"),
      ),

      body: FutureBuilder(
        future: FirebaseFirestore.instance.collection('myPlaces').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No places found"),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final placeId = data['placeId'];

              return FutureBuilder(
                future: FirebaseFirestore.instance
                    .collection('places')
                    .doc(placeId)
                    .get(),
                builder: (context, placeSnapshot) {
                  if (!placeSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final placeData = placeSnapshot.data!.data();

                  if (placeData == null) {
                    return const SizedBox();
                  }

                  final place = Place.fromMap(
                    placeData,
                    placeSnapshot.data!.id,
                  );

                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),

                      leading: Image.network(
                        "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400",
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),

                      title: Text(place.placeName),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),

                          Text(
                            place.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 5),

                          Text(
                            place.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}