import 'package:flutter/material.dart';

class SavedPlacesPage extends StatelessWidget {
  const SavedPlacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Places")),

      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return const ListTile(
            leading: Icon(Icons.bookmark),
            title: Text("Saved Place"),
            subtitle: Text("Place description"),
          );
        },
      ),
    );
  }
}
