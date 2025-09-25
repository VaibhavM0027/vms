import 'package:flutter/material.dart';
import '../models/visitor_model.dart';

class VisitorCard extends StatelessWidget {
  final Visitor visitor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const VisitorCard(
      {super.key, required this.visitor, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.grey[850],
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          backgroundImage: (visitor.photoUrl != null && visitor.photoUrl!.isNotEmpty)
              ? NetworkImage(visitor.photoUrl!)
              : (visitor.idImageUrl != null && visitor.idImageUrl!.isNotEmpty)
                  ? NetworkImage(visitor.idImageUrl!)
                  : null,
          child: ((visitor.photoUrl == null || visitor.photoUrl!.isEmpty) && (visitor.idImageUrl == null || visitor.idImageUrl!.isEmpty))
              ? Text(
                  visitor.name.isNotEmpty ? visitor.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                )
              : null,
        ),
        title: Text(
          visitor.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  visitor.contact,
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    visitor.email,
                    style: TextStyle(color: Colors.grey[300]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Host: ${visitor.hostName.isNotEmpty ? visitor.hostName : 'No Host'}',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.info, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Purpose: ${visitor.purpose}',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(visitor.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                visitor.status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: trailing,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
