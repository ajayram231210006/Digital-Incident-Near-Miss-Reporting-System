import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reporter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person, size: 72),
              const SizedBox(height: 12),
              Text('Welcome', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                user?.email ?? 'No email available',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fingerprint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'UID: ${FirebaseAuth.instance.currentUser?.uid ?? "-"}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ReporterPage(user: user),
                        ),
                      );
                    }
                  },
                  child: const Text('Report Incident'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
