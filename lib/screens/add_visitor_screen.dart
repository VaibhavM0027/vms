import 'package:flutter/material.dart';

class AddVisitorScreen extends StatelessWidget {
  const AddVisitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Visitor')),
      body: const Center(child: Text('Add Visitor Form')),
    );
  }
}
