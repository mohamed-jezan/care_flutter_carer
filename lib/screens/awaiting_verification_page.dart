import 'package:flutter/material.dart';

class AwaitingVerificationPage extends StatelessWidget {
  const AwaitingVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Icon(
                  Icons.verified_user,
                  size: 100,
                  color: Colors.orange,
                ),

                SizedBox(height: 30),

                Text(
                  "Your Details Will Be Verified",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 20),

                Text(
                  "Thank you for completing your onboarding.\n\n"
                  "Our verification team is now reviewing your submitted details.\n\n"
                  "This usually takes 24–48 hours. "
                  "You will receive a notification once verification is completed.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}