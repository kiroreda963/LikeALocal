import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:likealocal/home/pages/explore_page.dart';
import 'package:provider/provider.dart';

import 'auth/auth_provider.dart';
import 'auth/pages/auth_page.dart';
import 'Providers/PlaceProvider.dart';
import 'messaging/pages/inbox_screen.dart';
import 'home/pages/home_page_main.dart';

import './add_place/pages/add_place_page.dart';
import './subscription/pages/subscription_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlacesProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LikeALocal',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),

      // TEMPORARY FOR TESTING
      initialRoute: '/subscription',

      routes: {
        '/auth': (context) => const AuthScreen(),

        '/home': (context) => const MainHomePage(),

        '/chat': (context) =>
            const InboxScreen(
              currentUserId: 'OGGRI7AVFca8FbUgogDjPqp0QsD2',
            ),

        '/add-place': (context) => const AddPlacePage(),

        '/explore': (context) => const ExplorePage(),

        '/subscription': (context) => const SubscriptionPage(),
      },
    );
  }
}