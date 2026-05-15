class Place {
  
  final String placeName;
  final String author;
  final String priceRange;
  final String description;
  final String category;
  final double rating;
  final String imageUrl;
  final String documentId;
  

  Place({
    
    required this.documentId,
    required this.placeName,
    required this.author,
    required this.priceRange,
    required this.description,
    required this.category,
    required this.rating,
    required this.imageUrl,
  });

  // Convert Firestore/JSON to Place object
  factory Place.fromMap(Map<String, dynamic> map, String documentId) {
    return Place(
      
      documentId: documentId,
      placeName: map['placeName'] ?? '',
      author: map['author'] ?? '',
      priceRange: map['priceRange'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      imageUrl: map['imageName'] ?? '',
    );
  }

  // Convert Place object to Map
  Map<String, dynamic> toMap() {
    return {
      'placeName': placeName,
      'author': author,
      'priceRange': priceRange,
      'description': description,
      'category': category,
      'rating': rating,
      'imageUrl': imageUrl,
    };
  }
}
