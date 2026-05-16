class Place {
  final String id;
  final String placeName;
  final String author;
  final String priceRange;
  final double longitude;
  final double latitude;
  final String description;
  final String category;
  final double rating;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final List<String> favoredByUsers;
  final int reviewCount;

  Place({
    required this.id,
    required this.placeName,
    required this.author,
    required this.priceRange,
    required this.longitude,
    required this.latitude,
    required this.description,
    required this.category,
    required this.rating,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.favoredByUsers = const [],
    this.reviewCount = 0,
  });

  // Convert Firestore/JSON to Place object
  factory Place.fromMap(Map<String, dynamic> map, String docId) {
    return Place(
      id: docId,
      placeName: map['placeName'] ?? '',
      author: map['author'] ?? '',
      priceRange: map['priceRange'] ?? '',
      longitude: (map['longitude'] ?? 0).toDouble(),
      latitude: (map['latitude'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      favoredByUsers: List<String>.from(map['favoredByUsers'] ?? []),
      reviewCount: map['reviewCount'] ?? 0,
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
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt,
      'favoredByUsers': favoredByUsers,
      'reviewCount': reviewCount,
    };
  }

  // Create a copy with updated fields
  Place copyWith({
    String? id,
    String? placeName,
    String? author,
    String? priceRange,
    String? description,
    String? category,
    double? rating,
    String? imageUrl,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    List<String>? favoredByUsers,
    int? reviewCount,
  }) {
    return Place(
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
      author: author ?? this.author,
      priceRange: priceRange ?? this.priceRange,
      description: description ?? this.description,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      favoredByUsers: favoredByUsers ?? this.favoredByUsers,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}
