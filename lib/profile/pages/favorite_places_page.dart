import 'package:flutter/material.dart';

class FavoritePlacesPage extends StatelessWidget {
  const FavoritePlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Favorite Places")),

      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return const ListTile(
            leading: Icon(Icons.favorite),
            title: Text("Favorite Place"),
            subtitle: Text("Place description"),
          );
        },
      ),
    );
  }
}
