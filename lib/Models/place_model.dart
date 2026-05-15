class Place {
  final String placeName;
  final String description;
  final String category;
  final double rating;
  final String imageUrl;
  final String location;
  final String priceRange;
  final String? website; // NEW: Optional field
  final String? phoneNumber; // NEW: Optional field

  Place({
    required this.placeName,
    required this.description,
    required this.category,
    required this.rating,
    required this.imageUrl,
    required this.location,
    required this.priceRange,
    this.website,
    this.phoneNumber
  });

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      placeName: map['placeName'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      location: map['location'] ?? '',
      priceRange: map['priceRange'] ?? '',
      website: map['website'], // Will be null if not in Firestore
      phoneNumber: map['phoneNumber'], // Will be null if not in Firestore
    );
  }
}