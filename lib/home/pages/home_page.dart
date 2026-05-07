import 'package:flutter/material.dart';
import '../widgets/featured_place_card.dart';
import '../widgets/hidden_gem_card.dart';
import '../widgets/trending_places_section.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final trendingPlaces = [
      TrendingPlaceData(
        imageUrl:
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400',
        name: 'Al Khal Egyptian Restaurant',
        location: 'City Stars Mall',
        distance: '2 km',
        rating: 4.2,
        category: 'Restaurant',
      ),
      TrendingPlaceData(
        imageUrl:
            'https://images.unsplash.com/photo-1514190051997-0f6f39ca5cde?w=400',
        name: 'Al Khal Egyptian Restaurant',
        location: 'City Stars Mall',
        distance: '2 km',
        rating: 4.2,
        category: 'Restaurant',
      ),
      TrendingPlaceData(
        imageUrl:
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400',
        name: 'Nile View Restaurant',
        location: 'Corniche',
        distance: '3.5 km',
        rating: 4.5,
        category: 'Restaurant',
      ),
      TrendingPlaceData(
        imageUrl:
            'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=400',
        name: 'Cairo Jazz Club',
        location: 'Mohandessin',
        distance: '5 km',
        rating: 4.3,
        category: 'Nightlife',
      ),
    ];

    final hiddenGems = [
      HiddenGemData(
        imageUrl:
            'https://cdn.britannica.com/65/114465-050-8C96BD81/Hall-of-Mirrors-ceiling-Jules-Hardouin-Mansart-Charles.jpg',
        name: 'Manial Palace Museum',
        description:
            'A stunning royal palace with gardens, Islamic architecture, and a small museum inside. Very peaceful and not crowded.',
        location: 'Roda Island (El Manial), Cairo',
        category: 'Cultural',
        rating: 4.5,
      ),
      HiddenGemData(
        imageUrl:
            'https://cdn.britannica.com/65/114465-050-8C96BD81/Hall-of-Mirrors-ceiling-Jules-Hardouin-Mansart-Charles.jpg',
        name: 'Manial Palace Museum',
        description:
            'A stunning royal palace with gardens, Islamic architecture, and a small museum inside. Very peaceful and not crowded.',
        location: 'Roda Island (El Manial), Cairo',
        category: 'Cultural',
        rating: 4.5,
      ),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle
          const Text(
            'Based on your taste...',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),

          // Featured Place
          FeaturedPlaceCard(
            imageUrl:
                'https://images.squarespace-cdn.com/content/v1/56c13cc00442627a08632989/1585432288121-15NNGMB5XEP5CJ1YSGL3/egyptianmuseum.jpg',
            name: 'The Egyptian Museum',
            location: 'El-Tahrir square',
            distance: '2 km',
            category: 'Cultural',
            rating: 4.8,
            reviewCount: '5k reviews',
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
