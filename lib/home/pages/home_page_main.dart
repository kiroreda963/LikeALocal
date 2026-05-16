import 'package:flutter/material.dart';
import 'package:likealocal/home/pages/explore_page.dart';
import '../widgets/top_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_page.dart';
import '../../auth/auth_provider.dart';
import 'package:provider/provider.dart';
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
  late final Future<String?> _userNameFuture;

  // Pages can be extended as needed
  final List<Widget> _pages = const [
    HomePage(),
    ExplorePage(),
    MapPage(),
    Center(child: Text('Profile')),
  ];

  @override
  void initState() {
    super.initState();
    _userNameFuture = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).getUserName();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _userNameFuture,
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'Guest';

        return Scaffold(
          backgroundColor: const Color(0xFFF8F8F8),

          // ── Isolated Top Bar ──
          appBar: TopBar(userName: userName),
          // ── Page Body ──
          body: IndexedStack(index: _currentIndex, children: _pages),
          // ── Isolated Bottom Nav Bar ──
          bottomNavigationBar: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        );
      },
    );
  }
}
