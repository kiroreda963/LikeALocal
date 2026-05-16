import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../Models/place_model.dart';
import 'dart:math';

class PlaceService {
  // Convert Place model to HiddenGemPlace-compatible format
  static Place convertToPlace(Map<String, dynamic> data, String docId) {
    return Place.fromMap(data, docId);
  }

  // Get icon based on place category
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'restaurant':
      case 'foodanddrink':
        return Icons.restaurant;
      case 'gym':
      case 'fitness':
      case 'hiddengems':
        return Icons.fitness_center;
      case 'tourist':
      case 'touristareas':
        return Icons.map_outlined;
      case 'arcade':
        return Icons.sports_esports;
      default:
        return Icons.location_on;
    }
  }

  // Get icon based on place name for special cases
  static IconData getIconByName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('gym')) return Icons.fitness_center;
    if (lower.contains('arcade')) return Icons.sports_esports;
    if (lower.contains('restaurant') || lower.contains('cafe') || lower.contains('food')) {
      return Icons.restaurant;
    }
    return Icons.location_on;
  }

  // Calculate distance between two points
  static double calculateDistance(LatLng from, LatLng to) {
    const double PI = 3.1415926535897932;
    const double EARTH_RADIUS = 6371; // Radius of the earth in km

    double latFrom = from.latitude * PI / 180;
    double lonFrom = from.longitude * PI / 180;
    double latTo = to.latitude * PI / 180;
    double lonTo = to.longitude * PI / 180;

    double latDelta = latTo - latFrom;
    double lonDelta = lonTo - lonFrom;

    double a =
        (sin(latDelta / 2) * sin(latDelta / 2)) +
        (cos(latFrom) *
            cos(latTo) *
            sin(lonDelta / 2) *
            sin(lonDelta / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = EARTH_RADIUS * c;

    return distance;
  }
}
