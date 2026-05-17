import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../Models/place_model.dart';
import '../../Providers/PlaceProvider.dart';
import '../../services/place_service.dart';
import '../widgets/featured_place_card.dart';
import '../widgets/hidden_gem_card.dart';
import '../widgets/trending_places_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _didFetch = false;
  Place? _recommendedPlace;
  bool _loadingRecommendation = true;
  bool _recommendationScheduled = false;
  LatLng? _currentLocation;
  final Map<String, String> _placeLocationLabels = {};
  bool _locationLabelsScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetch) {
      _didFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final placesProvider = Provider.of<PlacesProvider>(context, listen: false);
        await placesProvider.loadCache();
        await _loadCurrentLocation();
        placesProvider.fetchPlaces();
        placesProvider.fetchHiddenGems();
        await _loadRecommendation();
      });
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          if (!mounted) return;
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
      }
    } catch (_) {
      // Fail silently; distance display will fallback.
    }
  }

  Future<void> _resolvePlaceLocationLabels(List<Place> places) async {
    final placesToResolve = places
        .where((place) => !_placeLocationLabels.containsKey(place.id))
        .toList();
    if (placesToResolve.isEmpty) return;

    final results = await Future.wait(
      placesToResolve.map((place) async {
        final label = await PlaceService.getPlaceLabel(place);
        return label.isNotEmpty ? label : place.displayLocation;
      }),
    );

    if (!mounted) return;
    setState(() {
      for (var i = 0; i < placesToResolve.length; i++) {
        _placeLocationLabels[placesToResolve[i].id] = results[i];
      }
    });
  }

  Future<void> _loadRecommendation() async {
    final placesProvider = context.read<PlacesProvider>();
    if (placesProvider.places.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingRecommendation = false;
        _recommendationScheduled = false;
      });
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final place = await placesProvider.getRecommendedPlace(userId);
      if (!mounted) return;
      setState(() {
        _recommendedPlace = place;
        _loadingRecommendation = false;
        _recommendationScheduled = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRecommendation = false;
        _recommendationScheduled = false;
      });
    }
  }

  void _openRecommendedOnMap() {
    final place = _recommendedPlace;
    if (place == null) return;
    context.read<PlacesProvider>().openPlaceOnMap(place);
  }

  String _formattedDistance(Place place) {
    if (_currentLocation == null) {
      return 'Location unavailable';
    }
    final placeLocation = LatLng(place.latitude, place.longitude);
    final distance = PlaceService.calculateDistance(_currentLocation!, placeLocation);
    return PlaceService.formatDistance(distance);
  }

  String _displayLocationForPlace(Place place) {
    return _placeLocationLabels[place.id] ?? place.displayLocation;
  }

  @override
  Widget build(BuildContext context) {
    final placesProvider = Provider.of<PlacesProvider>(context);

    if (!_loadingRecommendation &&
        _recommendedPlace == null &&
        !_recommendationScheduled &&
        placesProvider.places.isNotEmpty) {
      _recommendationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecommendation());
    }

    if (!_locationLabelsScheduled &&
        (placesProvider.places.isNotEmpty || placesProvider.hiddenGems.isNotEmpty)) {
      _locationLabelsScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final allPlaces = {
          ...placesProvider.places.take(6),
          ...placesProvider.hiddenGems.take(5),
          if (_recommendedPlace != null) _recommendedPlace!,
        }.toList();
        await _resolvePlaceLocationLabels(allPlaces);
        if (!mounted) return;
        setState(() {
          _locationLabelsScheduled = false;
        });
      });
    }

    final trendingPlaces = placesProvider.places.map((place) {
      return TrendingPlaceData(
        imageUrl: place.imageUrl,
        name: place.placeName,
        location: _displayLocationForPlace(place),
        distance: _formattedDistance(place),
        rating: place.rating,
        category: place.category,
      );
    }).toList();

    final hiddenGems = placesProvider.hiddenGems.map((place) {
      return HiddenGemData(
        imageUrl: place.imageUrl,
        name: place.placeName,
        description: place.description,
        location: _displayLocationForPlace(place),
        category: place.category,
        rating: place.rating,
      );
    }).toList();

    // final hiddenGems = [
    //   HiddenGemData(
    //     imageUrl:
    //         'https://cdn.britannica.com/65/114465-050-8C96BD81/Hall-of-Mirrors-ceiling-Jules-Hardouin-Mansart-Charles.jpg',
    //     name: 'Manial Palace Museum',
    //     description:
    //         'A stunning royal palace with gardens, Islamic architecture, and a small museum inside. Very peaceful and not crowded.',
    //     location: 'Roda Island (El Manial), Cairo',
    //     category: 'Cultural',
    //     rating: 4.5,
    //   ),
    //   HiddenGemData(
    //     imageUrl:
    //         'https://cdn.britannica.com/65/114465-050-8C96BD81/Hall-of-Mirrors-ceiling-Jules-Hardouin-Mansart-Charles.jpg',
    //     name: 'Manial Palace Museum',
    //     description:
    //         'A stunning royal palace with gardens, Islamic architecture, and a small museum inside. Very peaceful and not crowded.',
    //     location: 'Roda Island (El Manial), Cairo',
    //     category: 'Cultural',
    //     rating: 4.5,
    //   ),
    // ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _recommendedPlace != null
                ? 'Recommended for you'
                : 'Based on your taste...',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),

          if (_loadingRecommendation)
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_recommendedPlace != null)
            GestureDetector(
              onTap: _openRecommendedOnMap,
              child: FeaturedPlaceCard(
                imageUrl: _recommendedPlace!.imageUrl,
                name: _recommendedPlace!.placeName,
                location: _displayLocationForPlace(_recommendedPlace!),
                distance: _formattedDistance(_recommendedPlace!),
                category: _recommendedPlace!.category,
                rating: _recommendedPlace!.rating,
                reviewCount: _recommendedPlace!.reviewCount > 0
                    ? '${_recommendedPlace!.reviewCount} reviews'
                    : 'New spot',
              ),
            )
          else
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'Favorite places to get personalized picks',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Trending Places (scrollable horizontally)
          TrendingPlacesSection(
            places: trendingPlaces,
            onTap: (index) {
              final place = placesProvider.places[index];
              placesProvider.openPlaceOnMap(place);
            },
          ),
          const SizedBox(height: 22),

          // Hidden Gems Section
          const Text(
            'Hidden Gems',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          // Hidden Gem cards
          ...placesProvider.hiddenGems.map(
            (place) => HiddenGemCard(
              imageUrl: place.imageUrl,
              name: place.placeName,
              description: place.description,
              location: _displayLocationForPlace(place),
              category: place.category,
              rating: place.rating,
              onTap: () {
                placesProvider.openPlaceOnMap(place);
              },
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class HiddenGemData {
  final String imageUrl;
  final String name;
  final String description;
  final String location;
  final String category;
  final double rating;

  const HiddenGemData({
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.location,
    required this.category,
    required this.rating,
  });
}
