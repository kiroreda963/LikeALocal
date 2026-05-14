import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'auth/auth_provider.dart';
import 'auth/pages/auth_page.dart';
import 'home/pages/home_page_main.dart';
import 'add_place/pages/add_place_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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

      // TEMPORARY: open Add Place screen directly
      initialRoute: '/add-place',

      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const MainHomePage(),
        '/add-place': (context) => const AddPlacePage(),
      },
    );
  }
}