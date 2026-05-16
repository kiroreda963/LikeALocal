class Review {
  final String id;
  final String userId;
  final String placeId;
  final String userName;
  final String reviewText;
  final double rating;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.userName,
    required this.reviewText,
    required this.rating,
    required this.createdAt,
  });

  // Convert Firestore/JSON to Review object
  factory Review.fromMap(Map<String, dynamic> map, String docId) {
    return Review(
      id: docId,
      userId: map['userId'] ?? '',
      placeId: map['placeId'] ?? '',
      userName: map['userName'] ?? '',
      reviewText: map['reviewText'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  // Convert Review object to Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'placeId': placeId,
      'userName': userName,
      'reviewText': reviewText,
      'rating': rating,
      'createdAt': createdAt,
    };
  }
}
