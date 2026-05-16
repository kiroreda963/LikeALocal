import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/place_model.dart';
import '../Models/review_model.dart';
import 'dart:math';

class PlacesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Place> _places = [];
  List<Place> _hiddenGems = [];
  Map<String, List<Review>> _reviewsCache = {};
  final Map<String, String> _userNameCache = {};

  List<Place> get places => _places;
  List<Place> get hiddenGems => _hiddenGems;
  String get selectedCategory => _selectedCategory;

  String _selectedCategory = 'All';
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // 🔄 Fetch all places from Firestore
  Future<void> fetchPlaces() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final snapshot = await _firestore.collection('places').get();

      _places = snapshot.docs
          .map((doc) => Place.fromMap(doc.data(), doc.id))
          .toList();
      _places.sort((a, b) {
        return b.rating.compareTo(a.rating); // highest rating first
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchHiddenGems() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final snapshot = await _firestore.collection('places').get();

      _hiddenGems = snapshot.docs
          .map((doc) => Place.fromMap(doc.data(), doc.id))
          .toList();

      // Shuffle randomly
      _hiddenGems.shuffle(Random());

      // Take only 5 places
      _hiddenGems = _hiddenGems.take(5).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ➕ Add new place
  Future<void> addPlace(Place place) async {
    try {
      await _firestore.collection('places').add(place.toMap());

      await fetchPlaces(); // refresh list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<Place> get filteredPlaces {
    return _places.where((p) {
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesPrice =
          _selectedPrice == 'All' || p.priceRange == _selectedPrice;
      return matchesCategory && matchesPrice;
    }).toList();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners(); // UI will rebuild when a category is clicked
  }

  // 🔍 Get single place by id (optional)
  // 🔍 Get single place by id
  Future<Place?> getPlaceById(String id) async {
    try {
      final doc = await _firestore.collection('places').doc(id).get();

      if (doc.exists) {
        return Place.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _selectedPrice = 'All'; // Default state
  String get selectedPrice => _selectedPrice;

  void setPriceRange(String price) {
    _selectedPrice = price;
    notifyListeners();
  }

// In your PlaceProvider or UserProvider
Future<void> addFavorite(String userId, String placeId) async {
  try {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    await userDoc.update({
      'favoredPlaces': FieldValue.arrayUnion([placeId])
    });
  } catch (e) {
    debugPrint('Error adding favorite: $e');
  }
}

Future<void> removeFavorite(String userId, String placeId) async {
  try {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    await userDoc.update({
      'favoredPlaces': FieldValue.arrayRemove([placeId])
    });
  } catch (e) {
    debugPrint('Error removing favorite: $e');
  }
}

Future<bool> isFavorited(String userId, String placeId) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!userDoc.exists) return false;
    
    final favoredPlaces = List<String>.from(userDoc['favoredPlaces'] ?? []);
    return favoredPlaces.contains(placeId);
  } catch (e) {
    debugPrint('Error checking favorite: $e');
    return false;
  }
}

Future<List<Place>> getFavorites(String userId) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!userDoc.exists) return [];
    
    final favoredPlaceIds = List<String>.from(userDoc['favoredPlaces'] ?? []);
    
    if (favoredPlaceIds.isEmpty) return [];
    
    final placesSnapshot = await FirebaseFirestore.instance
        .collection('places')
        .where(FieldPath.documentId, whereIn: favoredPlaceIds)
        .get();
    
    return placesSnapshot.docs
        .map((doc) => Place.fromMap(doc.data(), doc.id))
        .toList();
  } catch (e) {
    debugPrint('Error getting favorites: $e');
    return [];
  }
}

  // 📝 Add review to place
  Future<void> addReview({
    required String userId,
    required String placeId,
    required String userName,
    required String reviewText,
    required double rating,
  }) async {
    try {
      final placeRef = _firestore.collection('places').doc(placeId);

      // Add review to subcollection
      await _firestore
          .collection('places')
          .doc(placeId)
          .collection('reviews')
          .add({
            'userId': userId,
            'placeId': placeId,
            'userName': userName,
            'reviewText': reviewText,
            'rating': rating,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Update place rating and review count
      final placeDoc = await placeRef.get();
      if (placeDoc.exists) {
        final currentReviewCount = placeDoc['reviewCount'] ?? 0;
        final currentRating = placeDoc['rating'] ?? 0.0;

        // Calculate new average rating
        final newRating =
            ((currentRating * currentReviewCount) + rating) /
            (currentReviewCount + 1);

        await placeRef.update({
          'reviewCount': currentReviewCount + 1,
          'rating': newRating,
        });
      }

      // Clear reviews cache for this place
      _reviewsCache.remove(placeId);

      // Update local place
      final placeIndex = _places.indexWhere((p) => p.id == placeId);
      if (placeIndex != -1) {
        final updatedPlace = _places[placeIndex].copyWith(
          reviewCount: _places[placeIndex].reviewCount + 1,
          rating:
              ((_places[placeIndex].rating * _places[placeIndex].reviewCount) +
                  rating) /
              (_places[placeIndex].reviewCount + 1),
        );
        _places[placeIndex] = updatedPlace;
        notifyListeners();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 🔁 Add or update a user's review for a place (prevent duplicates)
  Future<void> addOrUpdateReview({
    required String userId,
    required String placeId,
    required String userName,
    required String reviewText,
    required double rating,
  }) async {
    try {
      final reviewsRef = _firestore
          .collection('places')
          .doc(placeId)
          .collection('reviews');

      // Check if the user already has a review
      final existing = await reviewsRef
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final docId = existing.docs.first.id;
        await reviewsRef.doc(docId).update({
          'userName': userName,
          'reviewText': reviewText,
          'rating': rating,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await reviewsRef.add({
          'userId': userId,
          'placeId': placeId,
          'userName': userName,
          'reviewText': reviewText,
          'rating': rating,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Recalculate rating and reviewCount from all reviews for accuracy
      final snapshot = await reviewsRef.get();
      final count = snapshot.docs.length;
      double sum = 0.0;
      for (final d in snapshot.docs) {
        final r = (d.data()['rating'] ?? 0).toDouble();
        sum += r;
      }
      final newRating = count == 0 ? 0.0 : (sum / count);

      final placeRef = _firestore.collection('places').doc(placeId);
      await placeRef.update({'rating': newRating, 'reviewCount': count});

      // Clear cache and update local place
      _reviewsCache.remove(placeId);
      final placeIndex = _places.indexWhere((p) => p.id == placeId);
      if (placeIndex != -1) {
        _places[placeIndex] = _places[placeIndex].copyWith(
          rating: newRating,
          reviewCount: count,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ❌ Delete a review by id and update place stats
  Future<void> deleteReview({
    required String placeId,
    required String reviewId,
  }) async {
    try {
      final reviewsRef = _firestore
          .collection('places')
          .doc(placeId)
          .collection('reviews');
      await reviewsRef.doc(reviewId).delete();

      // Recalculate rating and reviewCount
      final snapshot = await reviewsRef.get();
      final count = snapshot.docs.length;
      double sum = 0.0;
      for (final d in snapshot.docs) {
        final r = (d.data()['rating'] ?? 0).toDouble();
        sum += r;
      }
      final newRating = count == 0 ? 0.0 : (sum / count);

      final placeRef = _firestore.collection('places').doc(placeId);
      await placeRef.update({'rating': newRating, 'reviewCount': count});

      // Clear cache and update local place
      _reviewsCache.remove(placeId);
      final placeIndex = _places.indexWhere((p) => p.id == placeId);
      if (placeIndex != -1) {
        _places[placeIndex] = _places[placeIndex].copyWith(
          rating: newRating,
          reviewCount: count,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 🔎 Get current user's review for a place (if any)
  Future<Review?> getUserReviewForPlace(String userId, String placeId) async {
    try {
      final snapshot = await _firestore
          .collection('places')
          .doc(placeId)
          .collection('reviews')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return Review.fromMap(doc.data(), doc.id);
    } catch (e) {
      return null;
    }
  }

  // 📖 Fetch reviews for a place
  Future<List<Review>> fetchReviews(String placeId) async {
    try {
      // Check cache first
      if (_reviewsCache.containsKey(placeId)) {
        return _reviewsCache[placeId]!;
      }

      final snapshot = await _firestore
          .collection('places')
          .doc(placeId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .get();

      final reviews = <Review>[];
      for (final doc in snapshot.docs) {
        var rev = Review.fromMap(doc.data(), doc.id);

        // If username missing or obviously placeholder, try to resolve from users collection
        final lowerName = rev.userName.trim().toLowerCase();
        if (rev.userName.isEmpty ||
            lowerName.contains('anon') ||
            lowerName.contains('anom') ||
            lowerName == 'anonymous') {
          final uid = rev.userId;
          if (_userNameCache.containsKey(uid)) {
            rev = Review(
              id: rev.id,
              userId: rev.userId,
              placeId: rev.placeId,
              userName: _userNameCache[uid]!,
              reviewText: rev.reviewText,
              rating: rev.rating,
              createdAt: rev.createdAt,
            );
          } else if (uid.isNotEmpty) {
            final userDoc = await _firestore.collection('users').doc(uid).get();
            String resolvedName = '';
            if (userDoc.exists && userDoc.data() != null) {
              final nameField = userDoc.data()!['name'];
              if (nameField != null) resolvedName = nameField.toString();
            }
            if (resolvedName.isNotEmpty) {
              _userNameCache[uid] = resolvedName;
              rev = Review(
                id: rev.id,
                userId: rev.userId,
                placeId: rev.placeId,
                userName: resolvedName,
                reviewText: rev.reviewText,
                rating: rev.rating,
                createdAt: rev.createdAt,
              );
            }
          }
        }

        reviews.add(rev);
      }

      _reviewsCache[placeId] = reviews;
      return reviews;
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  // 👤 Fetch user favorites
  Future<List<String>> fetchUserFavorites(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.map((doc) => doc['placeId'] as String).toList();
    } catch (e) {
      return [];
    }
  }
}
