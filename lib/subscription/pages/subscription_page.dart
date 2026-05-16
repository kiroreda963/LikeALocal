import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool isPremium = false;
  bool isLoading = false;

  Future<void> activatePremium() async {
    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'isPremium': true,
        'plan': 'monthly',
        'price': 4.99,
        'activatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        isPremium = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Premium activated successfully!"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error activating premium: $e"),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: const Color(0xFFF5EAEA),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Go Premium",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF5EAEA),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                isPremium ? Icons.verified : Icons.workspace_premium,
                size: 70,
                color: const Color(0xFFA05C74),
              ),
            ),

            const SizedBox(height: 30),

            Text(
              isPremium ? "Premium Active" : "Explore Like A Local",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              isPremium
                  ? "You now have access to premium LikeALocal features."
                  : "Unlock smarter travel tools, exclusive local discoveries, and premium experiences.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 40),

            premiumFeature(Icons.place, "Unlimited hidden gem uploads"),
            premiumFeature(Icons.travel_explore, "AI travel recommendations"),
            premiumFeature(Icons.map, "Advanced interactive maps"),
            premiumFeature(Icons.bookmark, "Save unlimited favorite places"),
            premiumFeature(Icons.star, "Access exclusive local spots"),
            premiumFeature(Icons.notifications_active, "Priority travel alerts"),

            const SizedBox(height: 40),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EAEA),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  Text(
                    isPremium ? "Plan Activated" : "\$4.99 / month",
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA05C74),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    isPremium ? "Enjoy your premium access" : "Cancel anytime",
                    style: const TextStyle(color: Colors.black54),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed:
                          isPremium || isLoading ? null : activatePremium,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA05C74),
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : Text(
                              isPremium ? "Premium Active" : "Start Premium",
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
              color: const Color(0xFFF5EAEA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFA05C74)),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}