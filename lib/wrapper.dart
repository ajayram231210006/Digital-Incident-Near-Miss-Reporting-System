import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'homepage.dart';
import 'login.dart';
import 'reporter_dashboard.dart';
import 'supervisor_dashboard.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          // fetch role from Realtime Database and choose page
          return FutureBuilder<DatabaseEvent>(
            future: FirebaseDatabase.instance
                .ref('users/${user.uid}/role')
                .once(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final role = snap.data?.snapshot.value as String?;
              if (role == 'reporter') {
                return ReporterDashboard(user: user);
              } else if (role == 'supervisor') {
                return SupervisorDashboard(user: user);
              }
              return const HomePage();
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
