import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/place_model.dart';

class PlacesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Place> _places = [];
  List<Place> get places => _places;

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
}
