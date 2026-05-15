class Place {
  final String placeName;
  final String author;
  final String priceRange;
  final double longitude;
  final double latitude;
  final String description;
  final String category;
  final double rating;
  final String imageUrl;

  Place({
    required this.placeName,
    required this.author,
    required this.priceRange,
    required this.longitude,
    required this.latitude,
    required this.description,
    required this.category,
    required this.rating,
    required this.imageUrl,
  });

  // Convert Firestore/JSON to Place object
  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      placeName: map['placeName'] ?? '',
      author: map['author'] ?? '',
      priceRange: map['priceRange'] ?? '',
      longitude: (map['longitude'] ?? 0).toDouble(),
      latitude: (map['latitude'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  // Convert Place object to Map
  Map<String, dynamic> toMap() {
    return {
      'placeName': placeName,
      'author': author,
      'priceRange': priceRange,
      'longitude': longitude,
      'latitude': latitude,
      'description': description,
      'category': category,
      'rating': rating,
      'imageUrl': imageUrl,
    };
  }
}
