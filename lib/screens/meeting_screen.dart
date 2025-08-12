import 'package:flutter/material.dart';
import 'checkout_screen.dart';

class MeetingScreen extends StatelessWidget {
  final String visitorName;

  const MeetingScreen({required this.visitorName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Meeting in Progress')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Meeting in progress with $visitorName',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            Icon(Icons.meeting_room, size: 100, color: Colors.blue),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                );
              },
              child: Text('End Meeting & Check-Out'),
            )
          ],
        ),
      ),
    );
  }
}
