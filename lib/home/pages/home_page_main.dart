import 'package:flutter/material.dart';
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

  // Pages can be extended as needed
  final List<Widget> _pages = const [
    HomePage(),
    ExplorePage(),
    MapPage(),
    Center(child: Text('Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      // ── Isolated Top Bar ──
      appBar: _currentIndex == 1
          ? null
          : _currentIndex == 2
          ? const MapTopBar()
          : TopBar(userName: 'Kirolos'),
      // ── Page Body ──
      body: IndexedStack(index: _currentIndex, children: _pages),
      // ── Isolated Bottom Nav Bar ──
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
