import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/place_model.dart';
import 'dart:math';

class PlacesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Place> _places = [];
  List<Place> _hiddenGems = [];
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

      _places = snapshot.docs.map((doc) => Place.fromMap(doc.data())).toList();
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
          .map((doc) => Place.fromMap(doc.data()))
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
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesPrice = _selectedPrice == 'All' || p.priceRange == _selectedPrice;
      return matchesCategory && matchesPrice;
    }).toList();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners(); // UI will rebuild when a category is clicked
  }

  // 🔍 Get single place by id (optional)
  Future<Place?> getPlaceById(String id) async {
    try {
      final doc = await _firestore.collection('places').doc(id).get();

      if (doc.exists) {
        return Place.fromMap(doc.data()!);
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
}
