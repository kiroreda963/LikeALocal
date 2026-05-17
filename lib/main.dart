import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:likealocal/home/pages/explore_page.dart';
import 'package:provider/provider.dart';
import 'auth/auth_provider.dart';
import 'auth/pages/auth_page.dart';
import 'Providers/PlaceProvider.dart';
import 'home/pages/home_page_main.dart';
import './add_place/pages/add_place_page.dart';
import 'services/message_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await MessageNotificationService.instance.initialize();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        MessageNotificationService.instance.startListening(user.uid);
      } else {
        MessageNotificationService.instance.stopListening();
      }
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      MessageNotificationService.instance.startListening(currentUser.uid);
    }
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.user != null) {
      return const MainHomePage();
    }
    return const AuthScreen();
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const MainHomePage(),
        '/add-place': (context) => const AddPlacePage(),
        '/explore': (context) => const ExplorePage(),
      },
    );
  }
}
