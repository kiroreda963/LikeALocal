import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/place_model.dart';
import '../../Providers/PlaceProvider.dart';
import '../widgets/featured_place_card.dart';
import '../widgets/hidden_gem_card.dart';
import '../widgets/trending_places_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _didFetch = false;
  Place? _recommendedPlace;
  bool _loadingRecommendation = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetch) {
      _didFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final placesProvider = Provider.of<PlacesProvider>(
          context,
          listen: false,
        );
        placesProvider.fetchPlaces();
        placesProvider.fetchHiddenGems();
        _loadRecommendation();
      });
    }
  }

  Future<void> _loadRecommendation() async {
    final placesProvider = context.read<PlacesProvider>();
    if (placesProvider.places.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final place = await placesProvider.getRecommendedPlace(userId);

    if (!mounted) return;
    setState(() {
      _recommendedPlace = place;
      _loadingRecommendation = false;
    });
  }

  void _openRecommendedOnMap() {
    final place = _recommendedPlace;
    if (place == null) return;
    context.read<PlacesProvider>().openPlaceOnMap(place);
  }

  @override
  Widget build(BuildContext context) {
    final placesProvider = Provider.of<PlacesProvider>(context);

    if (!_loadingRecommendation &&
        _recommendedPlace == null &&
        placesProvider.places.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecommendation());
    }

    final trendingPlaces = placesProvider.places.map((place) {
      return TrendingPlaceData(
        imageUrl: place.imageUrl,
        name: place.placeName,
        location: place.category, // or add real location field later
        distance: '2 km', // placeholder for now (you can calculate later)
        rating: place.rating,
        category: place.category,
      );
    }).toList();

    final hiddenGems = placesProvider.hiddenGems.map((place) {
      return HiddenGemData(
        imageUrl: place.imageUrl,
        name: place.placeName,
        description: place.description,
        location: place.category, // or add real location field later
        category: place.category,
        rating: place.rating,
      );
    }).toList();

    // final hiddenGems = [
    //   HiddenGemData(
    //     imageUrl:
    //         'https://cdn.britannica.com/65/114465-050-8C96BD81/Hall-of-Mirrors-ceiling-Jules-Hardouin-Mansart-Charles.jpg',
    //     name: 'Manial Palace Museum',
    //     description:
    //         'A stunning royal palace with gardens, Islamic architecture, and a small museum inside. Very peaceful and not crowded.',
    //     location: 'Roda Island (El Manial), Cairo',
    //     category: 'Cultural',
    //     rating: 4.5,
    //   ),
    //   HiddenGemData(
    //     imageUrl:
    //         'https://cdn.britannica.com/65/114465-050-8C96BD81/Hall-of-Mirrors-ceiling-Jules-Hardouin-Mansart-Charles.jpg',
    //     name: 'Manial Palace Museum',
    //     description:
    //         'A stunning royal palace with gardens, Islamic architecture, and a small museum inside. Very peaceful and not crowded.',
    //     location: 'Roda Island (El Manial), Cairo',
    //     category: 'Cultural',
    //     rating: 4.5,
    //   ),
    // ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _recommendedPlace != null
                ? 'Recommended for you'
                : 'Based on your taste...',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),

          if (_loadingRecommendation)
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_recommendedPlace != null)
            GestureDetector(
              onTap: _openRecommendedOnMap,
              child: FeaturedPlaceCard(
                imageUrl: _recommendedPlace!.imageUrl,
                name: _recommendedPlace!.placeName,
                location: _recommendedPlace!.category,
                distance: _recommendedPlace!.priceRange,
                category: _recommendedPlace!.category,
                rating: _recommendedPlace!.rating,
                reviewCount: _recommendedPlace!.reviewCount > 0
                    ? '${_recommendedPlace!.reviewCount} reviews'
                    : 'New spot',
              ),
            )
          else
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'Favorite places to get personalized picks',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Trending Places (scrollable horizontally)
          TrendingPlacesSection(places: trendingPlaces),
          const SizedBox(height: 22),

          // Hidden Gems Section
          const Text(
            'Hidden Gems',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          // Hidden Gem cards
          ...hiddenGems.map(
            (gem) => HiddenGemCard(
              imageUrl: gem.imageUrl,
              name: gem.name,
              description: gem.description,
              location: gem.location,
              category: gem.category,
              rating: gem.rating,
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class HiddenGemData {
  final String imageUrl;
  final String name;
  final String description;
  final String location;
  final String category;
  final double rating;

  const HiddenGemData({
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.location,
    required this.category,
    required this.rating,
  });
}
