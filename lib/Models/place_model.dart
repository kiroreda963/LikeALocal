class Place {
  final String id;
  final String placeName;
  final String authorId;
  final String priceRange;
  final double longitude;
  final double latitude;
  final String description;
  final String category;
  final double rating;
  final String imageUrl;
  final DateTime createdAt;
  final List<String> favoredByUsers;
  final int reviewCount;
  final String? locationName;

  Place({
    required this.id,
    required this.placeName,
    required this.authorId,
    required this.priceRange,
    required this.longitude,
    required this.latitude,
    required this.description,
    required this.category,
    required this.rating,
    required this.imageUrl,
    required this.createdAt,
    this.favoredByUsers = const [],
    this.reviewCount = 0,
    this.locationName,
  });

  // Convert Firestore/JSON to Place object
  factory Place.fromMap(Map<String, dynamic> map, String docId) {
    DateTime createdAtValue;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is String) {
      createdAtValue = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else if (rawCreatedAt != null) {
      createdAtValue = (rawCreatedAt as dynamic).toDate();
    } else {
      createdAtValue = DateTime.now();
    }

    return Place(
      id: docId,
      placeName: map['placeName'] ?? '',
      authorId: map['authorId'] ?? '',
      priceRange: map['priceRange'] ?? '',
      longitude: (map['longitude'] ?? 0).toDouble(),
      latitude: (map['latitude'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      createdAt: createdAtValue,
      favoredByUsers: List<String>.from(map['favoredByUsers'] ?? []),
      reviewCount: map['reviewCount'] ?? 0,
      locationName: map['locationName'] as String?,
    );
  }

  // Convert Place object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'placeName': placeName,
      'authorId': authorId,
      'priceRange': priceRange,
      'longitude': longitude,
      'latitude': latitude,
      'description': description,
      'category': category,
      'rating': rating,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'favoredByUsers': favoredByUsers,
      'reviewCount': reviewCount,
      if (locationName != null) 'locationName': locationName,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placeName': placeName,
      'authorId': authorId,
      'priceRange': priceRange,
      'longitude': longitude,
      'latitude': latitude,
      'description': description,
      'category': category,
      'rating': rating,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'favoredByUsers': favoredByUsers,
      'reviewCount': reviewCount,
      'locationName': locationName,
    };
  }

  // Create a copy with updated fields
  Place copyWith({
    String? id,
    String? placeName,
    String? authorId,
    String? priceRange,
    String? description,
    String? category,
    double? rating,
    String? imageUrl,
    DateTime? createdAt,
    List<String>? favoredByUsers,
    int? reviewCount,
    String? locationName,
  }) {
    return Place(
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
      authorId: authorId ?? this.authorId,
      priceRange: priceRange ?? this.priceRange,
      description: description ?? this.description,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      longitude: this.longitude,
      latitude: this.latitude,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      favoredByUsers: favoredByUsers ?? this.favoredByUsers,
      reviewCount: reviewCount ?? this.reviewCount,
      locationName: locationName ?? this.locationName,
    );
  }

  String get displayLocation {
    if (locationName != null && locationName!.trim().isNotEmpty) {
      return locationName!;
    }
    return category;
  }
}
