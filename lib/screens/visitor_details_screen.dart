import 'package:flutter/material.dart';

class VisitorDetailsScreen extends StatelessWidget {
  final String visitorId;
  const VisitorDetailsScreen({super.key, required this.visitorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Details')),
      body: Center(child: Text('Details for: $visitorId')),
    );
  }
}
