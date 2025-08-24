import 'package:flutter/material.dart';

class ParameterCard extends StatelessWidget {
  final String label;
  final String value;

  const ParameterCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(12),
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
        leading: Icon(Icons.bolt),
      ),
    );
  }
}