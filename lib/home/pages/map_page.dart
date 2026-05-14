import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MapTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.account_circle_outlined, color: Colors.black87),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black87),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  static const LatLng _newCairo = LatLng(30.0074, 31.4913);

  final List<HiddenGemPlace> _places = const [
    HiddenGemPlace(
      name: 'Arcade Hub',
      category: PlaceCategory.hiddenGems,
      position: LatLng(30.0091, 31.4936),
      rating: 4.8,
      owner: 'Mina',
      imageUrl:
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300',
      reviews: [
        'Small, colorful arcade with rare machines and friendly staff.',
        'Great for a quick hangout after coffee nearby.',
        'The owner keeps the machines in surprisingly good shape.',
      ],
    ),
    HiddenGemPlace(
      name: 'Smart Gym',
      category: PlaceCategory.hiddenGems,
      position: LatLng(30.0121, 31.4962),
      rating: 4.2,
      owner: 'Omar',
      imageUrl:
          'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=300',
      reviews: [
        'Quiet in the morning and has all the essentials.',
        'Good coaches, no tourist crowd.',
      ],
    ),
    HiddenGemPlace(
      name: 'Asian County',
      category: PlaceCategory.foodAndDrink,
      position: LatLng(30.0045, 31.4889),
      rating: 4.9,
      owner: 'Nour',
      imageUrl:
          'https://images.unsplash.com/photo-1553621042-f6e147245754?w=300',
      reviews: [
        'Tiny spot, huge portions, excellent noodles.',
        'Feels like the kind of place locals keep to themselves.',
      ],
    ),
    HiddenGemPlace(
      name: 'Garden 8 Walk',
      category: PlaceCategory.touristAreas,
      position: LatLng(30.0118, 31.4881),
      rating: 4.5,
      owner: 'LikeALocal',
      imageUrl:
          'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=300',
      reviews: ['Easy walk, lots of food nearby, good evening atmosphere.'],
    ),
  ];

  PlaceCategory? _selectedCategory;
  HiddenGemPlace? _selectedPlace;
  LatLng? _myLocation;
  String _query = '';

  List<HiddenGemPlace> get _filteredPlaces {
    return _places.where((place) {
      final matchesCategory =
          _selectedCategory == null || place.category == _selectedCategory;
      final matchesQuery =
          _query.isEmpty ||
          place.name.toLowerCase().contains(_query.toLowerCase()) ||
          place.category.label.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedPlace = _places.first;
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // The map remains useful even if location is unavailable.
    }
  }

  void _selectPlace(HiddenGemPlace place) {
    setState(() => _selectedPlace = place);
    _mapController.move(place.position, 15.6);
  }

  double _distanceKm(HiddenGemPlace place) {
    final origin = _myLocation ?? _newCairo;
    return Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          place.position.latitude,
          place.position.longitude,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlace = _selectedPlace;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: selectedPlace?.position ?? _newCairo,
            initialZoom: 15.2,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                ..._filteredPlaces.map(
                  (place) => Marker(
                    point: place.position,
                    width: 155,
                    height: 56,
                    alignment: Alignment.centerLeft,
                    child: _PlaceMarker(
                      place: place,
                      selected: place == selectedPlace,
                      onTap: () => _selectPlace(place),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
              const SizedBox(height: 14),
              _CategoryFilters(
                selected: _selectedCategory,
                onSelected: (category) {
                  setState(() {
                    _selectedCategory = _selectedCategory == category
                        ? null
                        : category;
                    final visible = _filteredPlaces;
                    if (visible.isNotEmpty) {
                      _selectedPlace = visible.first;
                    }
                  });
                  final place = _filteredPlaces.firstOrNull;
                  if (place != null) _selectPlace(place);
                },
              ),
              if (_query.isNotEmpty)
                _SearchResults(places: _filteredPlaces, onTap: _selectPlace),
              const Spacer(),
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
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 30),
                  child: _SelectedPlaceSheet(
                    place: selectedPlace,
                    distanceKm: _distanceKm(selectedPlace),
                    onReviews: () => _showReviews(selectedPlace),
                    onChat: () => _openChat(selectedPlace),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showReviews(HiddenGemPlace place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                      '${place.name} Reviews',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.star, color: Color(0xFFFFCA28), size: 20),
                  Text(
                    place.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...place.reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          review,
                          style: const TextStyle(fontSize: 14, height: 1.35),
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
  }

  void _openChat(HiddenGemPlace place) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening chat with ${place.owner}...')),
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
        width: 220,
        height: 34,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.94),
            hintText: 'SEARCH',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
            suffixIcon: controller.text.isEmpty
                ? Icon(Icons.filter_alt_outlined, color: Colors.grey.shade400)
                : IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade500),
                    onPressed: onClear,
                  ),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  final PlaceCategory? selected;
  final ValueChanged<PlaceCategory> onSelected;

  const _CategoryFilters({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: PlaceCategory.values.map((category) {
        final active = selected == category;
        return GestureDetector(
          onTap: () => onSelected(category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 29,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              category.label.toUpperCase(),
              style: TextStyle(
                color: active ? Colors.white : Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<HiddenGemPlace> places;
  final ValueChanged<HiddenGemPlace> onTap;

  const _SearchResults({required this.places, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: places.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No hidden gems found'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: places.map((place) {
                  return ListTile(
                    dense: true,
                    leading: Icon(place.icon, color: const Color(0xFF143C23)),
                    title: Text(
                      place.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(place.category.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFCA28),
                          size: 16,
                        ),
                        Text(place.rating.toStringAsFixed(1)),
                      ],
                    ),
                    onTap: () => onTap(place),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

class _PlaceMarker extends StatelessWidget {
  final HiddenGemPlace place;
  final bool selected;
  final VoidCallback onTap;

  const _PlaceMarker({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = place.owner == 'You';
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: selected ? 46 : 42,
            height: selected ? 46 : 42,
            decoration: BoxDecoration(
              color: isMine ? const Color(0xFFFF2323) : const Color(0xFF143C23),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(place.icon, color: Colors.white, size: 24),
          ),
          if (selected)
            Transform.translate(
              offset: const Offset(-3, 0),
              child: Container(
                height: 27,
                padding: const EdgeInsets.only(left: 12, right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        color: Color(0xFF219357),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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

class _SelectedPlaceSheet extends StatelessWidget {
  final HiddenGemPlace place;
  final double distanceKm;
  final VoidCallback onReviews;
  final VoidCallback onChat;

  const _SelectedPlaceSheet({
    required this.place,
    required this.distanceKm,
    required this.onReviews,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.11),
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
                  Image.network(
                    place.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFEDEDED),
                      child: Icon(place.icon, color: Colors.black54),
                    ),
                  ),
                  const Positioned(left: 2, top: 4, child: _TopRatedBadge()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const Icon(Icons.star, color: Color(0xFFFFCA28), size: 18),
                    Text(
                      place.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${distanceKm.toStringAsFixed(1)} KM away - New Cairo',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _SheetButton(
                      icon: Icons.rate_review_outlined,
                      label: 'Reviews',
                      onTap: onReviews,
                    ),
                    const SizedBox(width: 6),
                    _SheetButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat',
                      onTap: onChat,
                    ),
                    const Spacer(),
                    Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC4C9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bookmark_border,
                        color: Color(0xFFFF6375),
                        size: 23,
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

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 29,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black, size: 17),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w600,
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

enum PlaceCategory {
  hiddenGems('Hidden Gems', Icons.diamond_outlined),
  foodAndDrink('Food & Drink', Icons.restaurant),
  touristAreas('Tourist Areas', Icons.map_outlined);

  final String label;
  final IconData icon;

  const PlaceCategory(this.label, this.icon);
}

class HiddenGemPlace {
  final String name;
  final PlaceCategory category;
  final LatLng position;
  final double rating;
  final String owner;
  final String imageUrl;
  final List<String> reviews;

  const HiddenGemPlace({
    required this.name,
    required this.category,
    required this.position,
    required this.rating,
    required this.owner,
    required this.imageUrl,
    required this.reviews,
  });

  IconData get icon {
    if (name.toLowerCase().contains('gym')) return Icons.fitness_center;
    if (name.toLowerCase().contains('arcade')) return Icons.sports_esports;
    return category.icon;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
