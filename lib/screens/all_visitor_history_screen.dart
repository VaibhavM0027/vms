import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/visitor_model.dart';
import 'visitor_history_screen.dart';

class AllVisitorHistoryScreen extends StatelessWidget {
  const AllVisitorHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Visitors'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visitors')
            .where('isRegistered', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No registered visitors found'),
            );
          }

          final visitors = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Visitor.fromMap(data, doc.id);
          }).toList();

          return ListView.builder(
            itemCount: visitors.length,
            itemBuilder: (context, index) {
              final visitor = visitors[index];
              final hasHistory = visitor.visitHistory != null && 
                                visitor.visitHistory!.isNotEmpty;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(visitor.name.isNotEmpty 
                        ? visitor.name[0].toUpperCase() 
                        : '?'),
                  ),
                  title: Text(visitor.name),
                  subtitle: Text(visitor.contact),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasHistory)
                        const Icon(Icons.history, color: Colors.blue),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    // Only navigate if we have a valid ID
                    if (visitor.id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VisitorHistoryScreen(
                            visitorId: visitor.id!,
                            visitorName: visitor.name,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot view history: Invalid visitor ID'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}