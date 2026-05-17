import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../Models/place_model.dart';

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
    if (lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('food')) {
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
        (cos(latFrom) * cos(latTo) * sin(lonDelta / 2) * sin(lonDelta / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = EARTH_RADIUS * c;

    return distance;
  }

  static String formatDistance(double kilometers) {
    if (kilometers < 1) {
      return '${(kilometers * 1000).round()} m';
    }
    return '${kilometers.toStringAsFixed(kilometers < 10 ? 1 : 0)} km';
  }

  static final Map<String, String> _reverseGeocodeCache = {};

  static Future<String> reverseGeocode(LatLng position) async {
    final cacheKey = '${position.latitude},${position.longitude}';
    if (_reverseGeocodeCache.containsKey(cacheKey)) {
      return _reverseGeocodeCache[cacheKey]!;
    }

    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': position.latitude.toString(),
      'lon': position.longitude.toString(),
    });

    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'LikeALocalApp/1.0 (https://likealocal.example)',
        },
      );
      if (response.statusCode != 200) {
        return '';
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final address = body['address'] as Map<String, dynamic>?;
      if (address == null) return '';

      final city =
          address['city'] ??
          address['town'] ??
          address['village'] ??
          address['suburb'] ??
          address['hamlet'];
      final state = address['state'] ?? address['county'];
      final formatted = [city, state]
          .where((part) => part != null && part.toString().trim().isNotEmpty)
          .map((part) => part.toString())
          .join(', ');

      if (formatted.isNotEmpty) {
        _reverseGeocodeCache[cacheKey] = formatted;
        return formatted;
      }

      final displayName = body['display_name'] as String?;
      if (displayName != null && displayName.isNotEmpty) {
        final fallback = displayName.split(',').take(2).join(', ').trim();
        _reverseGeocodeCache[cacheKey] = fallback;
        return fallback;
      }
    } catch (_) {
      return '';
    }

    return '';
  }

  static Future<String> getPlaceLabel(Place place) async {
    if (place.locationName != null && place.locationName!.trim().isNotEmpty) {
      return place.locationName!;
    }

    final position = LatLng(place.latitude, place.longitude);
    return await reverseGeocode(position);
  }
}
