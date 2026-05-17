import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Models/place_model.dart';
import '../Models/review_model.dart';
import '../services/ai_recommendation_service.dart';

class PlacesProvider with ChangeNotifier {
  static const String _placesCacheKey = 'cached_places';
  static const String _hiddenGemsCacheKey = 'cached_hidden_gems';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Place> _places = [];
  List<Place> _hiddenGems = [];
  Map<String, List<Review>> _reviewsCache = {};
  final Map<String, String> _userNameCache = {};
  bool _cacheLoaded = false;

  // 🔄 Stream subscriptions
  StreamSubscription<QuerySnapshot>? _placesSubscription;
  StreamSubscription<QuerySnapshot>? _hiddenGemsSubscription;

  List<Place> get places => _places;
  List<Place> get hiddenGems => _hiddenGems;
  String get selectedCategory => _selectedCategory;

  String _selectedCategory = 'All';
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Place? _mapFocusPlace;
  Place? get mapFocusPlace => _mapFocusPlace;

  Place? _mapShowReviewsPlace;
  Place? get mapShowReviewsPlace => _mapShowReviewsPlace;

  /// Switch to the map tab and focus this place (see MainShell + MapPage).
  void openPlaceOnMap(Place place) {
    _mapFocusPlace = place;
    notifyListeners();
  }

  void openReviewsOnMap(Place place) {
    _mapFocusPlace = place;
    _mapShowReviewsPlace = place;
    notifyListeners();
  }

  void clearShowReviewsPlace() {
    if (_mapShowReviewsPlace == null) return;
    _mapShowReviewsPlace = null;
    notifyListeners();
  }

  void clearMapFocus() {
    if (_mapFocusPlace == null) return;
    _mapFocusPlace = null;
    notifyListeners();
  }

  /// Top pick for the home featured card based on favorites and added places.
  Future<Place?> getRecommendedPlace(String? userId) async {
    if (_places.isEmpty) return null;

    var favorites = <Place>[];
    var myPlaces = <Place>[];

    if (userId != null) {
      favorites = await getFavorites(userId);
      myPlaces = await getUserAddedPlaces(userId);
    }

    final placeContext = UserPlaceContext(
      favorites: favorites,
      myPlaces: myPlaces,
      catalog: _places,
    );

    final ranked = placeContext.rankedCandidates(UserTasteProfile());
    if (ranked.isEmpty) return _places.first;

    if (placeContext.hasPersonalPlaces) {
      final personalIds = {
        ...favorites.map((p) => p.id),
        ...myPlaces.map((p) => p.id),
      };
      for (final place in ranked) {
        if (!personalIds.contains(place.id)) return place;
      }
    }

    return ranked.first;
  }

  // ============================================
  // 🔄 REAL-TIME PLACES FETCHING WITH STREAMS
  // ============================================
  void fetchPlaces() {
    // Cancel existing subscription to prevent duplicates
    _placesSubscription?.cancel();

    _isLoading = true;
    _error = null;
    notifyListeners();

    _placesSubscription = _firestore
        .collection('places')
        .snapshots()
        .listen(
          (snapshot) {
            try {
              _places = snapshot.docs
                  .map((doc) => Place.fromMap(doc.data(), doc.id))
                  .toList();

              // Sort by rating (highest first)
              _places.sort((a, b) {
                return b.rating.compareTo(a.rating);
              });

              unawaited(_savePlacesCache());
              _isLoading = false;
              _error = null;
              notifyListeners(); // Rebuild UI with new data
            } catch (e) {
              _error = e.toString();
              _isLoading = false;
              notifyListeners();
            }
          },
          onError: (error) {
            _error = error.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  // ============================================
  // 🎲 REAL-TIME HIDDEN GEMS WITH STREAMS
  // ============================================
  void fetchHiddenGems() {
    _hiddenGemsSubscription?.cancel();

    _isLoading = true;
    _error = null;
    notifyListeners();

    _hiddenGemsSubscription = _firestore
        .collection('places')
        .snapshots()
        .listen(
          (snapshot) {
            try {
              _hiddenGems = snapshot.docs
                  .map((doc) => Place.fromMap(doc.data(), doc.id))
                  .toList();

              _hiddenGems.shuffle(Random());
              _hiddenGems = _hiddenGems.take(5).toList();

              unawaited(_saveHiddenGemsCache());
              _isLoading = false;
              _error = null;
              notifyListeners();
            } catch (e) {
              _error = e.toString();
              _isLoading = false;
              notifyListeners();
            }
          },
          onError: (error) {
            _error = error.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  // ➕ Add new place
  Future<void> addPlace(Place place) async {
    try {
      await _firestore.collection('places').add(place.toMap());
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
    notifyListeners();
  }

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

  String _selectedPrice = 'All';
  String get selectedPrice => _selectedPrice;

  void setPriceRange(String price) {
    _selectedPrice = price;
    notifyListeners();
  }

  DocumentReference _favoriteDoc(String userId, String placeId) {
    final docId = 'favorite_${userId}_$placeId';
    return _firestore.collection('favorites').doc(docId);
  }

  CollectionReference get _favoritesCollection =>
      _firestore.collection('favorites');

  Future<void> _syncFavoriteArrayWithUserDoc(
    String userId,
    String placeId,
    bool add,
  ) async {
    final userDoc = _firestore.collection('users').doc(userId);
    await userDoc.set({
      'favoredPlaces': add
          ? FieldValue.arrayUnion([placeId])
          : FieldValue.arrayRemove([placeId]),
    }, SetOptions(merge: true));
  }

  // ❤️ Add favorite
  Future<void> addFavorite(String userId, String placeId) async {
    try {
      await _favoriteDoc(userId, placeId).set({
        'userId': userId,
        'placeId': placeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _syncFavoriteArrayWithUserDoc(userId, placeId, true);
    } catch (e) {
      debugPrint('Error adding favorite: $e');
    }
  }

  // 🚫 Remove favorite
  Future<void> removeFavorite(String userId, String placeId) async {
    try {
      await _favoriteDoc(userId, placeId).delete();
      await _syncFavoriteArrayWithUserDoc(userId, placeId, false);
    } catch (e) {
      debugPrint('Error removing favorite: $e');
    }
  }

  // ✅ Check if favorited
  Future<bool> isFavorited(String userId, String placeId) async {
    try {
      final doc = await _favoriteDoc(userId, placeId).get();
      if (doc.exists) return true;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      final data = userDoc.data();
      final favoredPlaces = List<String>.from(data?['favoredPlaces'] ?? []);
      return favoredPlaces.contains(placeId);
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      return false;
    }
  }

  Future<List<Place>> _fetchPlacesByIds(List<String> placeIds) async {
    if (placeIds.isEmpty) return [];

    final places = <Place>[];
    for (var i = 0; i < placeIds.length; i += 10) {
      final end = min(i + 10, placeIds.length);
      final chunk = placeIds.sublist(i, end);

      final placesSnapshot = await _firestore
          .collection('places')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      places.addAll(
        placesSnapshot.docs
            .map((doc) => Place.fromMap(doc.data(), doc.id))
            .toList(),
      );
    }
    return places;
  }

  // 📚 Get favorite place ids only (for map filtering)
  Future<Set<String>> getFavoritePlaceIds(String userId) async {
    try {
      final snapshot = await _favoritesCollection
          .where('userId', isEqualTo: userId)
          .get();
      final favoriteIds = snapshot.docs
          .map((doc) => doc['placeId'] as String)
          .toSet();

      if (favoriteIds.isNotEmpty) {
        return favoriteIds;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return {};
      final data = userDoc.data();
      return Set<String>.from(data?['favoredPlaces'] ?? []);
    } catch (e) {
      debugPrint('Error getting favorite ids: $e');
      return {};
    }
  }

  // 📚 Get favorites list
  Future<List<Place>> getFavorites(String userId) async {
    try {
      final favoriteIds = await getFavoritePlaceIds(userId);
      return _fetchPlacesByIds(favoriteIds.toList());
    } catch (e) {
      debugPrint('Error getting favorites: $e');
      return [];
    }
  }

  // 📍 Get places the user added ("My places")
  Future<List<Place>> getUserAddedPlaces(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];
      final data = userDoc.data();
      final addedPlaceIds = List<String>.from(data?['addedPlaces'] ?? []);

      return _fetchPlacesByIds(addedPlaceIds);
    } catch (e) {
      debugPrint('Error getting user added places: $e');
      return [];
    }
  }

  Future<void> loadCache() async {
    if (_cacheLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPlaces = prefs.getString(_placesCacheKey);
      if (cachedPlaces != null) {
        final decoded = jsonDecode(cachedPlaces) as List<dynamic>;
        _places = decoded
            .cast<Map<String, dynamic>>()
            .map((item) => Place.fromMap(item, item['id'] as String))
            .toList();
      }

      final cachedHiddenGems = prefs.getString(_hiddenGemsCacheKey);
      if (cachedHiddenGems != null) {
        final decodedHidden = jsonDecode(cachedHiddenGems) as List<dynamic>;
        _hiddenGems = decodedHidden
            .cast<Map<String, dynamic>>()
            .map((item) => Place.fromMap(item, item['id'] as String))
            .toList();
      }

      _cacheLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached places: $e');
    }
  }

  Future<void> _savePlacesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _places.map((place) => place.toJson()).toList();
      await prefs.setString(_placesCacheKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving places cache: $e');
    }
  }

  Future<void> _saveHiddenGemsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _hiddenGems.map((place) => place.toJson()).toList();
      await prefs.setString(_hiddenGemsCacheKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving hidden gems cache: $e');
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
        final currentRating = (placeDoc['rating'] ?? 0.0).toDouble();

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
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 🔁 Add or update a user's review for a place
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

      _reviewsCache.remove(placeId);

      final placeIndex = _places.indexWhere((p) => p.id == placeId);
      if (placeIndex != -1) {
        _places[placeIndex] = _places[placeIndex].copyWith(
          rating: newRating,
          reviewCount: count,
        );
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ❌ Delete a review by id
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

      _reviewsCache.remove(placeId);

      final placeIndex = _places.indexWhere((p) => p.id == placeId);
      if (placeIndex != -1) {
        _places[placeIndex] = _places[placeIndex].copyWith(
          rating: newRating,
          reviewCount: count,
        );
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 🔎 Get current user's review for a place
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
      final ids = await getFavoritePlaceIds(userId);
      return ids.toList();
    } catch (e) {
      return [];
    }
  }

  @override
  void dispose() {
    _placesSubscription?.cancel();
    _hiddenGemsSubscription?.cancel();
    super.dispose();
  }
}
