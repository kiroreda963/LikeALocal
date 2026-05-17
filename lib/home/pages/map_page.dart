import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../Providers/PlaceProvider.dart';
import '../../../Models/place_model.dart';
import '../../../Models/conversation_model.dart';
import '../../../Models/user_model.dart' as user_model;
import '../../../services/place_service.dart';
import '../../messaging/messaging_service.dart';
import '../../services/chat_settings_service.dart';
import '../../messaging/pages/chat_screen.dart';
import '../../../auth/auth_provider.dart' as local_auth;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  static const LatLng _newCairo = LatLng(30.0074, 31.4913);

  Place? _selectedPlace;
  LatLng? _myLocation;
  String _query = '';
  String? _selectedCategoryFilter;
  bool _showFavoritesOnly = false;
  Set<String> _favoritePlaceIds = {};
  user_model.User? _currentUser;
  PlacesProvider? _placesProvider;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlacesProvider>().fetchPlaces();
      _loadCurrentUserInfo();
      _loadFavoritePlaceIds();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<PlacesProvider>();
    if (_placesProvider != provider) {
      _placesProvider?.removeListener(_applyMapFocus);
      _placesProvider = provider;
      _placesProvider!.addListener(_applyMapFocus);
    }
    _applyMapFocus();
  }

  void _applyMapFocus() {
    final focus = _placesProvider?.mapFocusPlace;
    final showReviews = _placesProvider?.mapShowReviewsPlace;
    
    if (focus == null && showReviews == null || !mounted) return;

    if (focus != null) {
      final matches =
          _placesProvider!.places.where((p) => p.id == focus.id);
      final place = matches.isNotEmpty ? matches.first : focus;
      _selectPlace(place);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _placesProvider?.clearMapFocus();
      });
    }

    if (showReviews != null) {
      // Delay slightly to ensure map is ready or bottom sheet can open
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _showReviews(showReviews);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _placesProvider?.clearShowReviewsPlace();
      });
    }
  }

  Future<void> _loadFavoritePlaceIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ids = await context.read<PlacesProvider>().getFavoritePlaceIds(
      user.uid,
    );
    if (!mounted) return;
    setState(() => _favoritePlaceIds = ids);
  }

  void _toggleFavoritesFilter() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view your favorites')),
      );
      return;
    }

    if (!_showFavoritesOnly && _favoritePlaceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No favorites yet — tap the heart on a place to save it'),
        ),
      );
      return;
    }

    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      if (_showFavoritesOnly) {
        _selectedCategoryFilter = null;
      }
    });

    final places = context.read<PlacesProvider>().places;
    final visible = places.where((place) {
      if (!_favoritePlaceIds.contains(place.id)) return false;
      final matchesQuery =
          _query.isEmpty ||
          place.placeName.toLowerCase().contains(_query.toLowerCase()) ||
          place.category.toLowerCase().contains(_query.toLowerCase());
      return matchesQuery;
    }).toList();

    if (_showFavoritesOnly && visible.isNotEmpty) {
      _selectPlace(visible.first);
    } else if (_showFavoritesOnly) {
      setState(() => _selectedPlace = null);
    }
  }

  void _onFavoriteChanged(String placeId, bool isFavorited) {
    setState(() {
      if (isFavorited) {
        _favoritePlaceIds = {..._favoritePlaceIds, placeId};
      } else {
        _favoritePlaceIds = _favoritePlaceIds.where((id) => id != placeId).toSet();
        if (_showFavoritesOnly && _selectedPlace?.id == placeId) {
          _selectedPlace = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _placesProvider?.removeListener(_applyMapFocus);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required for better experience',
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        ),
      );

      if (!mounted) return;

      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_myLocation!, 15.5);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your location')),
        );
      }
    }
  }

  Future<void> _loadCurrentUserInfo() async {
    final user = await context.read<local_auth.AuthProvider>().getAllUserInfo();
    if (!mounted) return;
    setState(() {
      _currentUser = user;
    });
  }

  void _selectPlace(Place place) {
    setState(() => _selectedPlace = place);
    _mapController.move(LatLng(place.latitude, place.longitude), 15.6);
  }

  void _selectPlaceFromFilterList(Place place) {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCategoryFilter = null;
      _showFavoritesOnly = false;
      _selectedPlace = place;
    });
    _mapController.move(LatLng(place.latitude, place.longitude), 15.6);
  }

  double _distanceKm(Place place) {
    final origin = _myLocation ?? _newCairo;
    final placeLatLng = LatLng(place.latitude, place.longitude);
    return PlaceService.calculateDistance(origin, placeLatLng);
  }

 @override
Widget build(BuildContext context) {
  return Consumer<PlacesProvider>(
    builder: (context, placesProvider, _) {
      final places = placesProvider.places;

        final filteredPlaces = places.where((place) {
        final matchesQuery =
            _query.isEmpty ||
            place.placeName.toLowerCase().contains(_query.toLowerCase()) ||
            place.category.toLowerCase().contains(_query.toLowerCase());
        final matchesCategory =
            _selectedCategoryFilter == null ||
            place.category == _selectedCategoryFilter;
        final matchesFavorites =
            !_showFavoritesOnly || _favoritePlaceIds.contains(place.id);
        return matchesQuery && matchesCategory && matchesFavorites;
      }).toList();

      final selectedPlace = _selectedPlace;

        return Scaffold(
        body: Stack(
          children: [
            // Map layer
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: selectedPlace != null
                    ? LatLng(selectedPlace.latitude, selectedPlace.longitude)
                    : _newCairo,
                initialZoom: 15.2,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.likealocal',
                  tileBuilder: (context, tileWidget, tile) {
                    return ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.62,
                        0.12,
                        0.06,
                        0,
                        70,
                        0.08,
                        1.08,
                        0.08,
                        0,
                        52,
                        0.04,
                        0.12,
                        0.68,
                        0,
                        70,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: tileWidget,
                    );
                  },
                ),
                MarkerLayer(
                  markers: [
                    if (_myLocation != null)
                      Marker(
                        point: _myLocation!,
                        width: 24,
                        height: 24,
                        child: const _CurrentLocationMarker(),
                      ),
                    ...filteredPlaces.map((place) {
                      final placeLatLng = LatLng(
                        place.latitude,
                        place.longitude,
                      );
                      return Marker(
                        point: placeLatLng,
                        width: 155,
                        height: 56,
                        alignment: Alignment.centerLeft,
                        child: _PlaceMarkerFirebase(
                          place: place,
                          selected: place.id == selectedPlace?.id,
                          isFavorite: _favoritePlaceIds.contains(place.id),
                          onTap: () => _selectPlace(place),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

            // Top UI Controls
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _MapSearchBar(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 12),
                  _MapFiltersRow(
                    favoritesActive: _showFavoritesOnly,
                    favoriteCount: _favoritePlaceIds.length,
                    onFavoritesTap: _toggleFavoritesFilter,
                    selectedCategory: _selectedCategoryFilter,
                    onCategorySelected: (category) {
                      setState(() {
                        _showFavoritesOnly = false;
                        _selectedCategoryFilter =
                            _selectedCategoryFilter == category ? null : category;
                        final visible = filteredPlaces;
                        if (visible.isNotEmpty) {
                          _selectPlace(visible.first);
                        } else {
                          _selectedPlace = null;
                        }
                      });
                    },
                  ),
                  // Search Results or Category Results
                  if (_query.isNotEmpty ||
                      _selectedCategoryFilter != null ||
                      _showFavoritesOnly)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _SearchResultsFirebase(
                        places: filteredPlaces,
                        onTap: _selectPlaceFromFilterList,
                        filterType: _showFavoritesOnly
                            ? 'My Favorites'
                            : (_selectedCategoryFilter ?? _query),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Controls
            SafeArea(
              top: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 24, bottom: 12),
                      child: _MapControlButton(
                        icon: Icons.my_location,
                        onPressed: () {
                          final target = _myLocation ?? _newCairo;
                          _mapController.move(target, 15.5);
                        },
                      ),
                    ),
                  ),
                  if (selectedPlace != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: _SelectedPlaceSheetFirebase(
                        place: selectedPlace,
                        distanceKm: _distanceKm(selectedPlace),
                        onReviews: () => _showReviews(selectedPlace),
                        onChat: () => _showChatDialog(selectedPlace),
                        onFavoriteChanged: _onFavoriteChanged,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
  void _showReviews(Place place) async {
    final reviews = await context.read<PlacesProvider>().fetchReviews(place.id);
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${place.placeName} Reviews',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFCA28),
                        size: 20,
                      ),
                      Text(
                        place.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (reviews.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'No reviews yet. Be the first to review!',
                              ),
                            )
                          else
                            ...reviews.map((review) {
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              final isMine =
                                  currentUser != null &&
                                  review.userId == currentUser.uid;
                              final displayName = review.userName.isNotEmpty
                                  ? review.userName
                                  : 'Anonymous';
                              final avatarLetter = displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          child: Text(avatarLetter),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      displayName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isMine)
                                                    PopupMenuButton<String>(
                                                      onSelected: (value) async {
                                                        if (value == 'edit') {
                                                          final controller =
                                                              TextEditingController(
                                                                text: review
                                                                    .reviewText,
                                                              );
                                                          double newRating =
                                                              review.rating;
                                                          await showDialog<
                                                            void
                                                          >(
                                                            context: context,
                                                            builder: (context) {
                                                              return StatefulBuilder(
                                                                builder:
                                                                    (
                                                                      context,
                                                                      setState,
                                                                    ) {
                                                                      return AlertDialog(
                                                                        title: Text(
                                                                          'Edit review for ${place.placeName}',
                                                                        ),
                                                                        content: Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            Row(
                                                                              children: List.generate(
                                                                                5,
                                                                                (
                                                                                  i,
                                                                                ) => GestureDetector(
                                                                                  onTap: () => setState(
                                                                                    () => newRating =
                                                                                        (i +
                                                                                                1)
                                                                                            .toDouble(),
                                                                                  ),
                                                                                  child: Icon(
                                                                                    Icons.star,
                                                                                    color:
                                                                                        i <
                                                                                            newRating.toInt()
                                                                                        ? const Color(
                                                                                            0xFFFFCA28,
                                                                                          )
                                                                                        : Colors.grey.shade300,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            const SizedBox(
                                                                              height: 8,
                                                                            ),
                                                                            TextField(
                                                                              controller: controller,
                                                                              maxLines: 4,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        actions: [
                                                                          TextButton(
                                                                            onPressed: () => Navigator.pop(
                                                                              context,
                                                                            ),
                                                                            child: const Text(
                                                                              'Cancel',
                                                                            ),
                                                                          ),
                                                                          ElevatedButton(
                                                                            onPressed: () async {
                                                                              await context
                                                                                  .read<
                                                                                    PlacesProvider
                                                                                  >()
                                                                                  .addOrUpdateReview(
                                                                                    userId: review.userId,
                                                                                    placeId: place.id,
                                                                                    userName: displayName,
                                                                                    reviewText: controller.text,
                                                                                    rating: newRating,
                                                                                  );
                                                                              Navigator.pop(
                                                                                context,
                                                                              );
                                                                              Navigator.pop(
                                                                                context,
                                                                              );
                                                                              _showReviews(
                                                                                place,
                                                                              );
                                                                            },
                                                                            child: const Text(
                                                                              'Save',
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      );
                                                                    },
                                                              );
                                                            },
                                                          );
                                                        } else if (value ==
                                                            'delete') {
                                                          await context
                                                              .read<
                                                                PlacesProvider
                                                              >()
                                                              .deleteReview(
                                                                placeId:
                                                                    place.id,
                                                                reviewId:
                                                                    review.id,
                                                              );
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          _showReviews(place);
                                                        }
                                                      },
                                                      itemBuilder: (context) =>
                                                          [
                                                            const PopupMenuItem(
                                                              value: 'edit',
                                                              child: Text(
                                                                'Edit',
                                                              ),
                                                            ),
                                                            const PopupMenuItem(
                                                              value: 'delete',
                                                              child: Text(
                                                                'Delete',
                                                              ),
                                                            ),
                                                          ],
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  ...List.generate(
                                                    5,
                                                    (i) => Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color:
                                                          i <
                                                              review.rating
                                                                  .toInt()
                                                          ? const Color(
                                                              0xFFFFCA28,
                                                            )
                                                          : Colors
                                                                .grey
                                                                .shade300,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      review.reviewText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 16),
                          // Add Review Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final currentUser =
                                    FirebaseAuth.instance.currentUser;
                                if (currentUser == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please log in to add a review',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                                _showAddReviewDialog(place);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Your Review'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF143C23),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddReviewDialog(Place place) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add a review')),
      );
      return;
    }

    final reviewController = TextEditingController();
    double rating = 4.0;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Review ${place.placeName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rating:'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => GestureDetector(
                            onTap: () =>
                                setState(() => rating = (i + 1).toDouble()),
                            child: Icon(
                              Icons.star,
                              color: i < rating.toInt()
                                  ? const Color(0xFFFFCA28)
                                  : Colors.grey.shade300,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Your Review:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Share your experience...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (reviewController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please write a review')),
                      );
                      return;
                    }

                    final currentUser = _currentUser;
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please log in to leave a review'),
                        ),
                      );
                      return;
                    }

                    await context.read<PlacesProvider>().addOrUpdateReview(
                      userId: currentUser.uid,
                      placeId: place.id,
                      userName: currentUser.name.isNotEmpty
                          ? currentUser.name
                          : 'Anonymous',
                      reviewText: reviewController.text,
                      rating: rating,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review submitted')),
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChatDialog(Place place) {
    var currentUser = _currentUser;
    if (currentUser == null) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in to chat')));
        return;
      }
      currentUser = user_model.User(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'You',
        email: firebaseUser.email ?? '',
        phoneNumber: '',
        photoUrl: firebaseUser.photoURL,
      );
    }

    if (place.authorId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't chat with yourself")),
      );
      return;
    }
    if (place.authorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat for this place')),
      );
      return;
    }

    final messageController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Message about ${place.placeName}'),
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.placeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 4,


                decoration: InputDecoration(
                  hintText: 'Ask about this place...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final messageText = messageController.text.trim();
                if (messageText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please write a message')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _openChatWithAuthor(place, messageText);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              ),
              child: const Text(
                'Send',
                style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, String>> _fetchUserMeta(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final data = userDoc.data() ?? {};
    return {
      'name': (data['name'] as String?)?.trim() ?? 'User',
      'avatar': (data['photoUrl'] as String?) ?? '',
    };
  }

  Future<void> _openChatWithAuthor(Place place, String initialMessage) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final currentUser =
        _currentUser ??
        (firebaseUser != null
            ? user_model.User(
                uid: firebaseUser.uid,
                name: firebaseUser.displayName ?? 'You',
                email: firebaseUser.email ?? '',
                phoneNumber: '',
                photoUrl: firebaseUser.photoURL,
              )
            : null);

    if (currentUser == null) return;

    final authorId = place.authorId;
    if (authorId == currentUser.uid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't chat with yourself")),
      );
      return;
    }
    if (authorId.isEmpty) return;

    final authorMeta = await _fetchUserMeta(authorId);
    final otherUserName = authorMeta['name'] ?? 'User';
    final otherUserAvatar = authorMeta['avatar'] ?? '';

    final blockReason =
        await ChatSettingsService().getMessagingBlockReason(authorId);
    if (blockReason != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blockReason)),
      );
      return;
    }

    final service = MessagingService();
    final conversationId = await service.createOrGetConversation(
      currentUserId: currentUser.uid,
      otherUserId: authorId,
      currentUserName: currentUser.name.isNotEmpty ? currentUser.name : 'You',
      otherUserName: otherUserName,
      currentUserAvatar: currentUser.photoUrl ?? '',
      otherUserAvatar: otherUserAvatar,
      otherUserOnline: true,
    );

    if (initialMessage.isNotEmpty) {
      await service.sendMessage(
        conversationId: conversationId,
        senderId: currentUser.uid,
        text: initialMessage,
      );
    }

    if (!mounted) return;

    final convDoc = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (!convDoc.exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to open chat')));
      return;
    }

    final conversation = ConversationModel.fromDoc(convDoc, currentUser.uid);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: conversation,
          currentUserId: currentUser.uid,
        ),
      ),
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _MapSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 40,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Search places...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
            suffixIcon: controller.text.isEmpty
                ? Icon(Icons.filter_alt_outlined, color: Colors.grey.shade400)
                : IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade500),
                    onPressed: onClear,
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF143C23), width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
class _MapFiltersRow extends StatelessWidget {
  final bool favoritesActive;
  final int favoriteCount;
  final VoidCallback onFavoritesTap;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _MapFiltersRow({
    required this.favoritesActive,
    required this.favoriteCount,
    required this.onFavoritesTap,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Historical Places',
      'Restaurants & Cafes',
      'Shopping',
      'Entertainment',
      'Nightlife',
      'Beaches & Resorts',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: onFavoritesTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: favoritesActive
                      ? const Color(0xFFE91E63)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: favoritesActive
                        ? const Color(0xFFE91E63)
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      favoritesActive ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: favoritesActive
                          ? Colors.white
                          : const Color(0xFFE91E63),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      favoriteCount > 0
                          ? 'Favorites ($favoriteCount)'
                          : 'Favorites',
                      style: TextStyle(
                        color: favoritesActive ? Colors.white : Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...List.generate(categories.length, (index) {
            final category = categories[index];
            final active = selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onCategorySelected(category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF143C23) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF143C23)
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    category,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}class _SearchResultsFirebase extends StatelessWidget {
  final List<Place> places;
  final ValueChanged<Place> onTap;
  final String? filterType;

  const _SearchResultsFirebase({
    required this.places,
    required this.onTap,
    this.filterType,
  });

  @override
  Widget build(BuildContext context) {
    // Determine header text
    String headerText = 'Search Results';
    if (filterType == 'My Favorites') {
      headerText = filterType!;
    } else if (filterType != null &&
        (filterType!.contains('Historical') ||
            filterType!.contains('Restaurant') ||
            filterType!.contains('Shopping') ||
            filterType!.contains('Entertainment') ||
            filterType!.contains('Nightlife') ||
            filterType!.contains('Beaches'))) {
      headerText = filterType!;
    }

    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(vertical: 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with category name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                headerText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            const Divider(height: 8),
            if (places.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No places found',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: places.length,
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return ListTile(
                      dense: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF143C23)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          PlaceService.getIconByName(place.placeName),
                          color: const Color(0xFF143C23),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        place.placeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        place.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7FF00),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.black, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => onTap(place),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaceMarkerFirebase extends StatelessWidget {
  final Place place;
  final bool selected;
  final bool isFavorite;
  final VoidCallback onTap;

  const _PlaceMarkerFirebase({
    required this.place,
    required this.selected,
    this.isFavorite = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = PlaceService.getIconByName(place.placeName);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: selected ? 46 : 42,
            height: selected ? 46 : 42,
            decoration: BoxDecoration(
              color: isFavorite ? const Color(0xFFE91E63) : const Color(0xFF143C23),
              shape: BoxShape.circle,
              border: Border.all(
                color: isFavorite ? const Color(0xFFFFCDD2) : Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isFavorite ? Icons.favorite : icon,
              color: Colors.white,
              size: isFavorite ? 20 : 24,
            ),
          ),
          if (selected)
            Transform.translate(
              offset: const Offset(-3, 0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 100),
                height: 27,
                padding: const EdgeInsets.only(left: 12, right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible( // Already using Flexible, but ensure it works
                      child: Text(
                        place.placeName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF219357),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5FF00),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            place.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Icon(Icons.star, color: Colors.black, size: 7),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class _SelectedPlaceSheetFirebase extends StatefulWidget {
  final Place place;
  final double distanceKm;
  final VoidCallback onReviews;
  final VoidCallback onChat;
  final void Function(String placeId, bool isFavorited)? onFavoriteChanged;

  const _SelectedPlaceSheetFirebase({
    required this.place,
    required this.distanceKm,
    required this.onReviews,
    required this.onChat,
    this.onFavoriteChanged,
  });

  @override
  State<_SelectedPlaceSheetFirebase> createState() =>
      _SelectedPlaceSheetFirebaseState();
}

class _SelectedPlaceSheetFirebaseState
    extends State<_SelectedPlaceSheetFirebase> {
  bool _isFavorited = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFavorited();
  }

  Future<void> _checkFavorited() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final isFavorited = await context.read<PlacesProvider>().isFavorited(
        currentUser.uid,
        widget.place.id,
      );
      if (mounted) {
        setState(() => _isFavorited = isFavorited);
      }
    }
  }

  @override
  void didUpdateWidget(_SelectedPlaceSheetFirebase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id) {
      _checkFavorited();
    }
  }

  Future<void> _toggleFavorite() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add favorites')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isFavorited) {
        await context.read<PlacesProvider>().removeFavorite(
          currentUser.uid,
          widget.place.id,
        );
        widget.onFavoriteChanged?.call(widget.place.id, false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await context.read<PlacesProvider>().addFavorite(
          currentUser.uid,
          widget.place.id,
        );
        widget.onFavoriteChanged?.call(widget.place.id, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
      await _checkFavorited();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating favorite')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showShareDialog(BuildContext context, Place place) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final isPremium = userDoc.data()?['isPremium'] ?? false;

    if (!isPremium) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upgrade to Pro'),
            content: const Text('Sharing places is a Pro feature. Upgrade to Pro to share places with friends!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final friends = List<String>.from(userData?['friends'] ?? []);

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Share Place with', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  const Text('Friends', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  if (friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No friends to share with.'),
                    )
                  else
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(friends[index])
                                .get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData) return const SizedBox();
                              final data = userSnap.data!.data() as Map<String, dynamic>?;
                              final name = data?['name'] ?? 'User';

                              return ListTile(
                                title: Text(name),
                                trailing: const Icon(Icons.send, color: Color(0xFF143C23)),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _sharePlaceToUser(friends[index], place);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  const Divider(),
                  const Text('Groups', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('conversations')
                        .where('participants', arrayContains: currentUser.uid)
                        .where('isGroup', isEqualTo: true)
                        .snapshots(),
                    builder: (context, groupSnap) {
                      if (!groupSnap.hasData) return const SizedBox();
                      final groups = groupSnap.data!.docs;
                      if (groups.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No groups.'),
                        );
                      }
                      
                      return SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final data = groups[index].data() as Map<String, dynamic>;
                            final name = data['participantName'] ?? 'Group';
                            return ListTile(
                              title: Text(name),
                              trailing: const Icon(Icons.send, color: Color(0xFF143C23)),
                              onTap: () async {
                                Navigator.pop(context);
                                await _sharePlaceToGroup(groups[index].id, place);
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sharePlaceToUser(String targetUserId, Place place) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final sortedIds = [currentUser.uid, targetUserId]..sort();
    final conversationId = 'chat_${sortedIds.join('_')}';

    await _sendMessage(conversationId, place.id);
  }

  Future<void> _sharePlaceToGroup(String groupId, Place place) async {
    await _sendMessage(groupId, place.id);
  }

  Future<void> _sendMessage(String conversationId, String placeId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
      'senderId': currentUser.uid,
      'text': 'Shared a place',
      'timestamp': Timestamp.now(),
      'isRead': false,
      'type': 'place',
      'placeId': placeId,
    });

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .update({
      'lastMessage': 'Shared a place',
      'lastMessageTime': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Place shared!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 73,
              height: 88,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.place.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.place.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: const Color(0xFFEDEDED),
                                child: Icon(
                                  PlaceService.getIconByName(
                                    widget.place.placeName,
                                  ),
                                  color: Colors.black54,
                                ),
                              ),
                        )
                      : Container(
                          color: const Color(0xFFEDEDED),
                          child: Icon(
                            PlaceService.getIconByName(widget.place.placeName),
                            color: Colors.black54,
                          ),
                        ),
                  const Positioned(left: 2, top: 4, child: _TopRatedBadge()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.place.placeName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Color(0xFFFFCA28), size: 16),
                    Text(
                      widget.place.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.directions, color: Color(0xFF143C23)),
                      onPressed: () async {
                        final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${widget.place.latitude},${widget.place.longitude}');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open maps')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.distanceKm.toStringAsFixed(1)} KM - ${widget.place.category}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Reviews Button
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.rate_review_outlined,
                        label: 'Reviews',
                        onTap: widget.onReviews,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Chat Button
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.chat_outlined,
                        label: 'Chat',
                        onTap: currentUser != null
                            ? widget.onChat
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please log in to chat'),
                                  ),
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Share Button
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: () => _showShareDialog(context, widget.place),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Favorite Button
                    GestureDetector(
                      onTap: _isLoading ? null : _toggleFavorite,
                      child: Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: _isFavorited
                              ? const Color(0xFFFF2323)
                              : const Color(0xFFFFC4C9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                _isFavorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isFavorited
                                    ? Colors.white
                                    : const Color(0xFFFF6375),
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRatedBadge extends StatelessWidget {
  const _TopRatedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE7FF00),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'TOP RATED',
        style: TextStyle(
          color: Colors.black,
          fontSize: 5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: const Color(0xFF1B6E38), size: 29),
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF89CEFF), width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF3E61FF),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
