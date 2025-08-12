import 'package:flutter/material.dart';
import '../models/visitor_model.dart';
import '../utils/helpers.dart';

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
      child: ListTile(
        onTap: onTap,
        title: Text(visitor.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('Host: ${visitor.hostName}')],
        ),
        trailing: trailing,
      ),
    );
  }
}
