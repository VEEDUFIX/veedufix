import 'package:flutter/material.dart';

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          ListTile(
            title: Text('Bathroom repair'),
            subtitle: Text('Pending acceptance'),
          ),
          Divider(),
          ListTile(
            title: Text('Fan installation'),
            subtitle: Text('Job started'),
          ),
        ],
      ),
    );
  }
}
