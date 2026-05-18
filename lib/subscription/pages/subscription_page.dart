import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/auth_provider.dart' as local_auth;

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool isPremium = false;
  bool isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubscriptionStatus();
    });
  }

  Future<void> _loadSubscriptionStatus() async {
    final authProvider = context.read<local_auth.AuthProvider>();
    final user = await authProvider.getAllUserInfo();
    if (!mounted) return;

    setState(() {
      _userId = user?.uid;
      isPremium = user?.isPremium ?? false;
    });
  }

  Future<void> _togglePremium() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to manage subscription')),
      );
      return;
    }

    final uid = _userId ?? firebaseUser.uid;
    final nextValue = !isPremium;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isPremium': nextValue,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _userId = uid;
        isPremium = nextValue;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nextValue
                ? 'Premium activated successfully!'
                : 'Unsubscribed from premium successfully!',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error updating subscription: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Subscription',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: 390,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    isPremium ? Icons.verified : Icons.workspace_premium,
                    size: 70,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  isPremium ? 'Premium Active' : 'Explore Like A Local',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isPremium
                      ? 'You now have access to premium LikeALocal features.'
                      : 'Unlock smarter travel tools, exclusive local discoveries, and premium experiences.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 40),
                premiumFeature(Icons.place, 'Unlimited hidden gem uploads'),
                premiumFeature(
                  Icons.travel_explore,
                  'Unlimited AI travel recommendations',
                ),
                premiumFeature(
                  Icons.bookmark,
                  'Save unlimited favorite places',
                ),
                premiumFeature(Icons.share, 'Share places with friends'),
                premiumFeature(Icons.star, 'Access exclusive local spots'),
                premiumFeature(
                  Icons.group,
                  'Create chatting groups with other travelers',
                ),
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isPremium ? 'Plan Activated' : '\$4.99 / month',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isPremium
                            ? 'Enjoy your premium access'
                            : 'Cancel anytime',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _togglePremium,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            disabledBackgroundColor: Colors.grey.shade500,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  isPremium
                                      ? 'Cancel Premium'
                                      : 'Start Premium',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget premiumFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
