import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:likealocal/home/pages/explore_page.dart';
import 'package:provider/provider.dart';
import 'auth/auth_provider.dart';
import 'auth/pages/auth_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Providers/PlaceProvider.dart';
import 'messaging/pages/inbox_screen.dart';
import 'home/pages/home_page_main.dart';
import '../messaging/messaging_service.dart';
import './add_place/pages/add_place_page.dart';
import './home/pages/map_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  // await FirebaseFirestore.instance.collection('conversations').doc('conv1').set(
  //   {
  //     'participants': ['OGGRI7AVFca8FbUgogDjPqp0QsD2', 'user2'],
  //     'lastMessage': '',
  //     'lastMessageTime': Timestamp.now(),
  //   },
  // );
  // sendmessage(senderId, Text) async {
  //   final messagingService = MessagingService();
  //   await messagingService.sendMessage(
  //     conversationId: 'conv1',
  //     senderId: senderId,
  //     text: Text,
  //   );
  //   print('Message sent!');
  // }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlacesProvider()),
      ],
      child: MyApp(),
    ),
  );
  // await sendmessage("OGGRI7AVFca8FbUgogDjPqp0QsD2", 'Hello from main!');
  // await Future.delayed(Duration(seconds: 20));
  // await sendmessage("user2", 'Hello from user2!');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const MainHomePage(),
        '/add-place': (context) => const AddPlacePage(),
        '/explore': (context) => const ExplorePage(),
      },
    );
  }
}
