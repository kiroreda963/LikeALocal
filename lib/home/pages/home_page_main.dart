import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/PlaceProvider.dart';
import '../../profile/pages/profile_page.dart';
import '../widgets/top_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'explore_page.dart';
import 'home_page.dart';
import 'map_page.dart';

class MainHomePage extends StatelessWidget {
  const MainHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  PlacesProvider? _placesProvider;
  String _userName = 'Traveler';

  final List<Widget> _pages = const [
    HomePage(),
    ExplorePage(),
    MapPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final name = userDoc.data()?['name'] as String?;
    final email = currentUser.email;
    if (!mounted) return;

    setState(() {
      _userName = name?.trim().isNotEmpty == true
          ? name!
          : email?.split('@').first ?? 'Traveler';
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<PlacesProvider>();
    if (_placesProvider != provider) {
      _placesProvider?.removeListener(_onPlacesProviderChanged);
      _placesProvider = provider;
      _placesProvider!.addListener(_onPlacesProviderChanged);
    }
  }

  @override
  void dispose() {
    _placesProvider?.removeListener(_onPlacesProviderChanged);
    super.dispose();
  }

  void _onPlacesProviderChanged() {
    final focus = _placesProvider?.mapFocusPlace;
    if (focus != null && _currentIndex != 2 && mounted) {
      setState(() => _currentIndex = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: _currentIndex == 0 ? TopBar(userName: _userName) : null,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
