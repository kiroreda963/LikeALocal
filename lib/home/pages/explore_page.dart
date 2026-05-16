import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/PlaceProvider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $urlString");
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlacesProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Explore', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              _buildCardButton('Look \nOn maps', Icons.location_on_outlined, () => _launchURL(locationUrl)),
              const SizedBox(width: 8),
             _buildCardButton("Chat with Post Owner", Icons.chat_bubble_outline, () => ("gg") )
              ],
          )],
              ),
    );
  }

  Widget _buildCardButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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