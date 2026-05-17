import 'package:flutter/material.dart';
import 'trending_place_card.dart';

class TrendingPlacesSection extends StatelessWidget {
  final List<TrendingPlaceData> places;
  final Function(int index)? onTap;

  const TrendingPlacesSection({super.key, required this.places, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trending Places',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return TrendingPlaceCard(
                  imageUrl: place.imageUrl,
                  name: place.name,
                  location: place.location,
                  distance: place.distance,
                  rating: place.rating,
                  category: place.category,
                  onTap: () => onTap?.call(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TrendingPlaceData {
  final String imageUrl;
  final String name;
  final String location;
  final String distance;
  final double rating;
  final String category;

  const TrendingPlaceData({
    required this.imageUrl,
    required this.name,
    required this.location,
    required this.distance,
    required this.rating,
    required this.category,
  });
}
