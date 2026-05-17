import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/user_model.dart' as user_model;

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  User? get user => _user;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _user = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  // 🔐 Sign Up
  Future<String?> signUp(
    String email,
    String password,
    String name,
    String phoneNumber,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .set({
        'email': email,
        'name': name,
        'phoneNumber': phoneNumber,
        'isPremium': false,
        'aiMessageCount': 0,
      });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🔑 Login
  Future<String?> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🚪 Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String?> getUser() async {
    try {
      final uid = _auth.currentUser!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      return doc.data()?['name'];
    } catch (e) {
      return null;
    }
  }

  Future<String?> getUserName() async {
    try {
      final uid = _auth.currentUser!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      return doc.data()?['name'];
    } catch (e) {
      return null;
    }
  }

  // 👤 Get All User Info
  Future<user_model.User?> getAllUserInfo() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return null;
      }

      final uid = firebaseUser.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        return user_model.User.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
